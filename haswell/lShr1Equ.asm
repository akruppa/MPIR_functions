; ============================================================================
; lShr1Equ( Op1: pLimb; Size1: tCounter; ShrIn: tBaseVal; Op2: pLimb ):tBaseVal
; Linux     RDI         RSI              RDX              RCX         :RAX
; Win7      RCX         RDX              R8               R9          :RAX
;
; Description:
; The function shifts Op1 right by one bit, stores the result in Op2 (non-
; destructive shr) and hands back the shifted-out least significant bit of Op1.
; At the topmost limb a shift-in value is incorporated. The function operates
; increasing in memory supporting in place shifts.
;
; Caveats:
; - the AVX version uses mnemonics only available on Haswell, Broadwell and
;   Skylake cores
; - the behaviour of cache prefetching in combination with AVX shifting seems
;   somewhat erratic
;    - slight (a few clock cycles) degradation for 1/2 LD1$ sizes
;    - slight (a few percent) improvement for full LD1$ sizes
;    - substantial (>10%) improvement for 1/2 LD2$ sizes
;    - slight (a few percent) improvement for full LD2$ sizes
;    - slight (a few percent) degradation for 1/2 LD3$ sizes
;    - substantial (around 10%) degradation for full LD3$ sizes
;
; Comments:
; - AVX based version implemented, tested & benched on 21.02.2016 by jn
; - includes cache prefetching
; ============================================================================

BITS 64

global      lShr1Equ:function (lShr1Equ.end - lShr1Equ)

segment     .text

%ifdef USE_WIN64

    %define Op1         RCX
    %define Size1       RDX
    %define ShrIn       R8
    %define Op2         R9
    %define Limb1       R10
    %define Limb2       R11
    %define Offs        512     ; used direct def. to stay in Win scratch regs

    %define ShlDL0      XMM3    ; Attn: this must match ShlQL0 definition

    %define QLimb0      YMM0
    %define QLimb1      YMM1
    %define ShrQL0      YMM2
    %define ShlQL0      YMM3
    %define ShrQL1      YMM4
    %define ShlQL1      YMM5

%endif

%ifdef USE_LINUX64

    %define Op1         RDI
    %define Size1       RSI
    %define ShrIn       RDX
    %define Op2         RCX
    %define Limb1       R8
    %define Limb2       R9
    %define Offs        512     ; used direct def. to stay in Win scratch regs

    %define ShlDL0      XMM3    ; Attn: this must match ShlQL0 definition

    %define QLimb0      YMM0
    %define QLimb1      YMM1
    %define ShrQL0      YMM2
    %define ShlQL0      YMM3
    %define ShrQL1      YMM4
    %define ShlQL1      YMM5

%endif

    align   32
lShr1Equ:

    xor     EAX, EAX
    or      Size1, Size1
    je      .Exit

    mov     RAX, [Op1]
    mov     Limb1, RAX
    shl     RAX, 63

    sub     Size1, 1
    je      .lShr1EquPost       ; Size1=1 =>

    cmp     Size1, 8
    jc      .lShr1EquFour       ; AVX inefficient =>

    ; first align Op2 to 32 bytes
    test    Op2, 8
    je      .lShr1EquAlign16

    mov     Limb2, [Op1+8]
    shrd    Limb1, Limb2, 1
    mov     [Op2], Limb1
    mov     Limb1, Limb2

    add     Op1, 8
    add     Op2, 8
    sub     Size1, 1

  .lShr1EquAlign16:

    test    Op2, 16
    je      .lShr1EquAVX

    mov     Limb2, [Op1+8]
    shrd    Limb1, Limb2, 1
    mov     [Op2], Limb1
    mov     Limb1, [Op1+16]
    shrd    Limb2, Limb1, 1
    mov     [Op2+8], Limb2

    add     Op1, 16
    add     Op2, 16
    sub     Size1, 2

  .lShr1EquAVX:

    ; pre-fetch first quad-limb
    vmovdqu QLimb0, [Op1]
    vpsllq  ShlQL0, QLimb0, 63

    add     Op1, 32
    sub     Size1, 4
    jmp     .lShr1EquAVXCheck

    ; main loop (prefetching enabled, unloaded data cache)
    ; - 0.60      cycles per limb in LD1$
    ; - 0.60-0.75 cycles per limb in LD2$
    ; - 0.75-1.00 cycles per limb in LD3$
    align   16
  .lShr1EquAVXLoop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
  %endif

    vmovdqu   QLimb1, [Op1]
    vpsrlq    ShrQL0, QLimb0, 1
    vmovdqu   QLimb0, [Op1+32]
    vpsllq    ShlQL1, QLimb1, 63
    vpblendd  ShlQL0, ShlQL0, ShlQL1, 00000011b
    vpermq    ShlQL0, ShlQL0, 00111001b
    vpor      ShrQL0, ShrQL0, ShlQL0
    vpsrlq    ShrQL1, QLimb1, 1
    vpsllq    ShlQL0, QLimb0, 63
    vpblendd  ShlQL1, ShlQL1, ShlQL0, 00000011b
    vpermq    ShlQL1, ShlQL1, 00111001b
    vmovdqa   [Op2], ShrQL0
    vpor      ShrQL1, ShrQL1, ShlQL1
    vmovdqa   [Op2+32], ShrQL1

    add     Op1, 64
    add     Op2, 64

  .lShr1EquAVXCheck:

    sub     Size1, 8
    jnc     .lShr1EquAVXLoop

    ; I am mixing in a single SSE4.1 instruction into otherwise pure AVX2
    ; this is generating stalls on Haswell & Broadwell architecture (Agner Fog)
    ; but it is only executed once and there is no AVX2 based alternative
    mov     Limb2, [Op1]
    mov     Limb1, Limb2
    shl     Limb2, 63
    vpsrlq  ShrQL0, QLimb0, 1
    pinsrq  ShlDL0, Limb2, 0            ; SSE4.1
    vpermq  ShlQL0, ShlQL0, 00111001b
    vpor    ShrQL0, ShrQL0, ShlQL0
    vmovdqa [Op2], ShrQL0

    add     Op2, 32
    add     Size1, 8

    ; shift remaining max. 7 limbs with SHRD mnemonic
  .lShr1EquFour:

    add     Op1, 8
    test    Size1, 4
    je      .lShr1EquTwo

    mov     Limb2, [Op1]
    shrd    Limb1, Limb2, 1
    mov     [Op2], Limb1
    mov     Limb1, [Op1+8]
    shrd    Limb2, Limb1, 1
    mov     [Op2+8], Limb2
    mov     Limb2, [Op1+16]
    shrd    Limb1, Limb2, 1
    mov     [Op2+16], Limb1
    mov     Limb1, [Op1+24]
    shrd    Limb2, Limb1, 1
    mov     [Op2+24], Limb2

    add     Op1, 32
    add     Op2, 32

  .lShr1EquTwo:

    test    Size1, 2
    je      .lShr1EquOne

    mov     Limb2, [Op1]
    shrd    Limb1, Limb2, 1
    mov     [Op2], Limb1
    mov     Limb1, [Op1+8]
    shrd    Limb2, Limb1, 1
    mov     [Op2+8], Limb2

    add     Op1, 16
    add     Op2, 16

  .lShr1EquOne:

    test    Size1, 1
    je      .lShr1EquPost

    mov     Limb2, [Op1]
    shrd    Limb1, Limb2, 1
    mov     [Op2], Limb1
    mov     Limb1, Limb2

    add     Op2, 8

    ; store most significant limb considering shift-in part
  .lShr1EquPost:

    shrd    Limb1, ShrIn, 1
    mov     [Op2], Limb1

  .Exit:

    ret
.end:
