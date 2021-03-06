; ============================================================================
; lShl1Equ( Op1: pLimb; Size1: tCounter; ShlIn: tBaseBal; Op2: pLimb ):tBaseVal;
; Linux     RDI         RSI              RDX              RCX         :RAX
; Win7      RCX         RDX              R8               R9          :RAX
;
; Description:
; The function shifts Op1 left by one bit, stores the result in Op2 (non-
; destructive shl) and hands back the shifted-out most significant bit of Op1.
; For the least significant limb a shift-in value is incorporated. The
; function operates decreasing in memory supporting in-place operation.
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
; - implemented, tested and benched on 21.02.2016 by jn
; - includes cache prefetching
; ============================================================================

BITS 64

global      lShl1Equ:function (lShl1Equ.end - lShl1Equ)

segment     .text

%ifdef USE_WIN64

    %define Op1         RCX
    %define Size1       RDX
    %define ShlIn       R8
    %define Op2         R9
    %define Limb1       R10
    %define Limb2       R11
    %define Offs        -512    ; used direct def. to stay in Win scratch regs

    %define ShrDL0      XMM3    ; ATTN: this must match ShrQL0 definition

    %define QLimb0      YMM0
    %define QLimb1      YMM1
    %define ShlQL0      YMM2
    %define ShrQL0      YMM3
    %define ShlQL1      YMM4
    %define ShrQL1      YMM5

%endif

%ifdef USE_LINUX64

    %define Op1         RDI
    %define Size1       RSI
    %define ShlIn       RDX
    %define Op2         RCX
    %define Limb1       R8
    %define Limb2       R9
    %define Offs        -512    ; used direct def. to stay in Win scratch regs

    %define ShrDL0      XMM3    ; ATTN: this must match ShrQL0 definition

    %define QLimb0      YMM0
    %define QLimb1      YMM1
    %define ShlQL0      YMM2
    %define ShrQL0      YMM3
    %define ShlQL1      YMM4
    %define ShrQL1      YMM5

%endif

    align   32
lShl1Equ:

    xor     EAX, EAX
    sub      Size1, 1
    jc      .Exit               ; Size1=0 =>

    lea     Op1, [Op1+8*Size1]
    lea     Op2, [Op2+8*Size1]

    mov     Limb1, [Op1]
    shld    RAX, Limb1, 1

    or      Size1, Size1
    je      .lShl1EquPost       ; Size1=1 =>

    cmp     Size1, 8
    jc      .lShl1EquFour       ; AVX inefficient =>

    ; first align Op2 to 32 bytes
    test    Op2, 8
    jne     .lShl1EquA16

    mov     Limb2, [Op1-8]
    shld    Limb1, Limb2, 1
    mov     [Op2], Limb1
    mov     Limb1, Limb2

    sub     Op1, 8
    sub     Op2, 8
    sub     Size1, 1

  .lShl1EquA16:

    test    Op2, 16
    jne     .lShl1EquAVX

    mov     Limb2, [Op1-8]
    shld    Limb1, Limb2, 1
    mov     [Op2], Limb1
    mov     Limb1, [Op1-16]
    shld    Limb2, Limb1, 1
    mov     [Op2-8], Limb2

    sub     Op1, 16
    sub     Op2, 16
    sub     Size1, 2

  .lShl1EquAVX:

    ; pre-fetch first quad-limb
    vmovdqu QLimb0, [Op1-24]
    vpsrlq  ShrQL0, QLimb0, 63
    vpermq  ShrQL0, ShrQL0, 10010011b

    sub     Op1, 32
    sub     Size1, 4
    jmp     .lShl1EquAVXCheck

    ; main loop requires on entry:
    ; - 0.60      cycles per limb in LD1$
    ; - 0.60-0.75 cycles per limb in LD2$
    ; - 0.75-1.00 cycles per limb in LD3$
    align   16
  .lShl1EquAVXLoop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
  %endif

    vmovdqu   QLimb1, [Op1-24]
    vpsllq    ShlQL0, QLimb0, 1
    vmovdqu   QLimb0, [Op1-56]
    vpsrlq    ShrQL1, QLimb1, 63
    vpermq    ShrQL1, ShrQL1, 10010011b
    vpblendd  ShrQL0, ShrQL0, ShrQL1, 00000011b
    vpor      ShlQL0, ShlQL0, ShrQL0
    vpsllq    ShlQL1, QLimb1, 1
    vpsrlq    ShrQL0, QLimb0, 63
    vpermq    ShrQL0, ShrQL0, 10010011b
    vpblendd  ShrQL1, ShrQL1, ShrQL0, 00000011b
    vmovdqa   [Op2-24], ShlQL0
    vpor      ShlQL1, ShlQL1, ShrQL1
    vmovdqa   [Op2-56], ShlQL1

    sub     Op1, 64
    sub     Op2, 64

  .lShl1EquAVXCheck:

    sub     Size1, 8
    jnc     .lShl1EquAVXLoop

    ; I am mixing in a single SSE4.1 instruction into otherwise pure AVX2
    ; this is generating stalls on Haswell & Broadwell architecture (Agner Fog)
    ; but it is only executed once and there is no AVX2 based alternative
    mov     Limb2, [Op1]
    mov     Limb1, Limb2
    shr     Limb2, 63
    vpsllq  ShlQL0, QLimb0, 1
    pinsrq  ShrDL0, Limb2, 0        ; SSE4.1
    vpor    ShlQL0, ShlQL0, ShrQL0
    vmovdqa [Op2-24], ShlQL0

    sub     Op2, 32
    add     Size1, 8

    ; shift remaining max. 7 limbs with SHLD mnemonic
  .lShl1EquFour:

    sub     Op1, 8
    test    Size1, 4
    je      .lShl1EquTwo

    mov     Limb2, [Op1]
    shld    Limb1, Limb2, 1
    mov     [Op2], Limb1
    mov     Limb1, [Op1-8]
    shld    Limb2, Limb1, 1
    mov     [Op2-8], Limb2
    mov     Limb2, [Op1-16]
    shld    Limb1, Limb2, 1
    mov     [Op2-16], Limb1
    mov     Limb1, [Op1-24]
    shld    Limb2, Limb1, 1
    mov     [Op2-24], Limb2

    sub     Op1, 32
    sub     Op2, 32

  .lShl1EquTwo:

    test    Size1, 2
    je      .lShl1EquOne

    mov     Limb2, [Op1]
    shld    Limb1, Limb2, 1
    mov     [Op2], Limb1
    mov     Limb1, [Op1-8]
    shld    Limb2, Limb1, 1
    mov     [Op2-8], Limb2

    sub     Op1, 16
    sub     Op2, 16

  .lShl1EquOne:

    test    Size1, 1
    je      .lShl1EquPost

    mov     Limb2, [Op1]
    shld    Limb1, Limb2, 1
    mov     [Op2], Limb1
    mov     Limb1, Limb2

    sub     Op2, 8

  .lShl1EquPost:

    shld    Limb1, ShlIn, 1
    mov     [Op2], Limb1

  .Exit:

    ret
.end:
