; ============================================================================
; lShrEqu( Op1, Op2: pLimb; Size1, Shift: tCounter ):tBaseVal
; Linux    RDI  RSI         RDX    RCX              :RAX
;
; Description:
; The function shifts Op1 right by Shift bits, stores the result in Op2 (non-
; destructive shr) and hands back the shifted-out least significant bits of
; Op1. The function operates increasing in memory supporting in place shifts.
;
; Result:
; - Op2[ Size1-1..0 ] := ( ShrIn:Op1[ Size1-1..0 ] ) >> Shift
; - Op1[ 0 ] << ( 64-Shift )
;
; Caveats:
; - caller must ensure that Shift is in [ 1..63 ]!
; - currently Linux64 support only!
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
; - implemented, tested and benchmarked on 30.03.2016 by jn
; - includes prefetching
; ============================================================================

BITS 64

global      lShrEqu:function (lShrEqu.end - lShrEqu)

segment     .text

%ifdef USE_LINUX64

    %define Op1         RDI
    %define Op2         RSI
    %define Size1       RDX
    %define Shift       RCX
    %define Limb1       R8
    %define Limb2       R9
  %ifdef USE_PREFETCH
    %define Offs        R10
  %endif

  %ifdef USE_AVX
    %define ShlDL0      XMM3    ; Attn: this must match ShlQL0 definition
    %define ShrDLCnt    XMM6    ; Attn: this must match ShrQlCnt definition
    %define ShlDLCnt    XMM7    ; Attn: this must match ShlQlCnt definition

    %define QLimb0      YMM0
    %define QLimb1      YMM1
    %define ShrQL0      YMM2
    %define ShlQL0      YMM3
    %define ShrQL1      YMM4
    %define ShlQL1      YMM5
    %define ShrQLCnt    YMM6
    %define ShlQLCnt    YMM7
  %endif

%endif

    align   32
lShrEqu:

    xor     EAX, EAX
    or      Size1, Size1
    je      .Exit

    mov     Limb1, [Op1]
    shrd    RAX, Limb1, CL

    sub     Size1, 1
    je      .lShrEquPost        ; Size1=1 =>

  %ifdef USE_PREFETCH
    mov     Offs, 512
  %endif

    cmp     Size1, 8
    jc      .lShrEquFour        ; AVX inefficient =>

    ; first align Op2 to 32 bytes
    test    Op2, 8
    je      .lShrEquAlign16

    mov     Limb2, [Op1+8]
    shrd    Limb1, Limb2, CL
    mov     [Op2], Limb1
    mov     Limb1, Limb2

    add     Op1, 8
    add     Op2, 8
    sub     Size1, 1

  .lShrEquAlign16:

    test    Op2, 16
    je      .lShrEquAVX

    mov     Limb2, [Op1+8]
    shrd    Limb1, Limb2, CL
    mov     [Op2], Limb1
    mov     Limb1, [Op1+16]
    shrd    Limb2, Limb1, CL
    mov     [Op2+8], Limb2

    add     Op1, 16
    add     Op2, 16
    sub     Size1, 2

  .lShrEquAVX:

    ; initialize AVX shift counter
    vmovq   ShrDLCnt, RCX
    neg     RCX
    and     RCX, 63             ; must do, as AVX shifts set result=0 if Shift>63!
    vmovq   ShlDLCnt, RCX
    neg     RCX
    and     RCX, 63             ; must do, as AVX shifts set result=0 if Shift>63!
    vpbroadcastq ShrQLCnt, ShrDLCnt
    vpbroadcastq ShlQLCnt, ShlDLCnt

    ; pre-fetch first quad-limb
    vmovdqu QLimb0, [Op1]
    vpsllvq ShlQL0, QLimb0, ShlQLCnt

    add     Op1, 32
    sub     Size1, 4
    jmp     .lShrEquAVXCheck

    ; main loop (prefetching enabled, unloaded data cache)
    ; - 0.60      cycles per limb in LD1$
    ; - 0.60-0.70 cycles per limb in LD2$
    ; - 0.70-0.90 cycles per limb in LD3$
    align   16
  .lShrEquAVXLoop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
  %endif

    vmovdqu   QLimb1, [Op1]
    vpsrlvq   ShrQL0, QLimb0, ShrQLCnt
    vmovdqu   QLimb0, [Op1+32]
    vpsllvq   ShlQL1, QLimb1, ShlQLCnt
    vpblendd  ShlQL0, ShlQL0, ShlQL1, 00000011b
    vpermq    ShlQL0, ShlQL0, 00111001b
    vpor      ShrQL0, ShrQL0, ShlQL0
    vpsrlvq   ShrQL1, QLimb1, ShrQLCnt
    vpsllvq   ShlQL0, QLimb0, ShlQLCnt
    vpblendd  ShlQL1, ShlQL1, ShlQL0, 00000011b
    vpermq    ShlQL1, ShlQL1, 00111001b
    vmovdqa   [Op2], ShrQL0
    vpor      ShrQL1, ShrQL1, ShlQL1
    vmovdqa   [Op2+32], ShrQL1

    add     Op1, 64
    add     Op2, 64

  .lShrEquAVXCheck:

    sub     Size1, 8
    jnc     .lShrEquAVXLoop

    ; I am mixing in a single SSE4.1 instruction into otherwise pure AVX2
    ; this is generating stalls on Haswell & Broadwell architecture (Agner Fog)
    ; but it is only executed once and there is no AVX2 based alternative
    mov     Limb1, [Op1]
    xor     Limb2, Limb2
    shrd    Limb2, Limb1, CL
    vpsrlvq ShrQL0, QLimb0, ShrQLCnt
    pinsrq  ShlDL0, Limb2, 0            ; SSE4.1
    vpermq  ShlQL0, ShlQL0, 00111001b
    vpor    ShrQL0, ShrQL0, ShlQL0
    vmovdqa [Op2], ShrQL0

    add     Op2, 32
    add     Size1, 8

    ; shift remaining max. 7 limbs with SHRD mnemonic
  .lShrEquFour:

    add     Op1, 8
    test    Size1, 4
    je      .lShrEquTwo

    mov     Limb2, [Op1]
    shrd    Limb1, Limb2, CL
    mov     [Op2], Limb1
    mov     Limb1, [Op1+8]
    shrd    Limb2, Limb1, CL
    mov     [Op2+8], Limb2
    mov     Limb2, [Op1+16]
    shrd    Limb1, Limb2, CL
    mov     [Op2+16], Limb1
    mov     Limb1, [Op1+24]
    shrd    Limb2, Limb1, CL
    mov     [Op2+24], Limb2

    add     Op1, 32
    add     Op2, 32

  .lShrEquTwo:

    test    Size1, 2
    je      .lShrEquOne

    mov     Limb2, [Op1]
    shrd    Limb1, Limb2, CL
    mov     [Op2], Limb1
    mov     Limb1, [Op1+8]
    shrd    Limb2, Limb1, CL
    mov     [Op2+8], Limb2

    add     Op1, 16
    add     Op2, 16

  .lShrEquOne:

    test    Size1, 1
    je      .lShrEquPost

    mov     Limb2, [Op1]
    shrd    Limb1, Limb2, CL
    mov     [Op2], Limb1
    mov     Limb1, Limb2

    add     Op2, 8

    ; store most significant limb considering shift-in part
  .lShrEquPost:

    shr     Limb1, CL
    mov     [Op2], Limb1

  .Exit:

    ret
.end:
