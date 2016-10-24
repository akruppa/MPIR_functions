; =============================================================================
; Elementary Arithmetic Assembler Routines using AVX
; for Intel Architectures Haswell, Broadwell and Skylake
;
; (c) Jens Nurmann - 2016
;
; A general note on the use of cache prefetching. Several routines contain
; cache prefetching - typically those where I have unrolled loops by 8 as the
; data size then is 64 bytes <=> one cache line. The prefetching degrades the
; performance on small (<1,000 limb) sized operands a bit (<2%) but it
; increases performance on large (>1,000 limb) sized operands substantially
; (>10%). The prefetch stride is set to 512 on Skylake generally.
;
; I implemented cache prefetching because I measured a significant speed boost
; also in the recursive routines like Toom-Cook 33 - even though speed on the
; small scale operands is reduced.
;
; If you feel unsure about cache prefetching you can disable it by commenting
; out the define for perfetching (USE_PREFETCH). You should do also if you
; know in advance that your application will only work with small sized
; operands.
;
; What I haven't implemented so far is an adaptive prefetching mechanism -
; meaning the size of the prefetch stride adapts to the size of the input
; operands.
; ----------------------------------------------------------------------------
; History:
;
; Date       Author Version Action
; ---------- ------ ------- --------------------------------------------------
; 28.03.2016 jn     0.00.01 generated excerpt for MPIR containing
;                           - lCmp
;                           - lCpyInc
;                           - lCpyDec
;                           - lShr1Equ
;                           - lShl1Equ
;                           - lShrEqu
;                           - lShlEqu
; ============================================================================

%define     USE_LINUX64
;%define     USE_WIN64
;%define     USE_PREFETCH

global      lShrEqu:function
global      lShlEqu:function

segment     .text

; ============================================================================
; lShrEqu( Op1: pLimb; Size1: tCounter; ShrIn: tBaseVal; Shift: tCounter; Op2: pLimb ):tBaseVal
; Linux    RDI         RSI              RDX              RCX              R8          :RAX
;
; Description:
; The function shifts Op1 right by Shift bits, stores the result in Op2 (non-
; destructive shr) and hands back the shifted-out least significant bits of
; Op1. At the topmost limb a shift-in value is incorporated. The function
; operates increasing in memory supporting in place shifts.
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

%ifdef USE_LINUX64

    %define Op1         RDI
    %define Size1       RSI
    %define ShrIn       RDX
    %define Shift       RCX
    %define Op2         R8
    %define Limb1       R9
    %define Limb2       R10
  %ifdef USE_PREFETCH
    %define Offs        R11
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
    vpblendd  ShlQL0, ShlQL0, ShlQL1, 0b00000011
    vpermq    ShlQL0, ShlQL0, 0b00111001
    vpor      ShrQL0, ShrQL0, ShlQL0
    vpsrlvq   ShrQL1, QLimb1, ShrQLCnt
    vpsllvq   ShlQL0, QLimb0, ShlQLCnt
    vpblendd  ShlQL1, ShlQL1, ShlQL0, 0b00000011
    vpermq    ShlQL1, ShlQL1, 0b00111001
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
    vpermq  ShlQL0, ShlQL0, 0b00111001
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

    shrd    Limb1, ShrIn, CL
    mov     [Op2], Limb1

  .Exit:

    ret

; ============================================================================
; lShlEqu( Op1: pLimb; Size1: tCounter; ShlIn: tBaseBal; Shift: tCounter; Op2: pLimb ):tBaseVal;
; Linux    RDI         RSI              RDX              RCX              R8          :RAX
;
; Description:
; The function shifts Op1 left by n bit, stores the result in Op2 (non-
; destructive shl) and hands back the shifted-out most significant bits of Op1.
; For the least significant limb a shift-in value is incorporated. The
; function operates decreasing in memory supporting in-place operation.
;
; Result:
; - Op2[ Size1-1..0 ] := ( Op1[ Size1-1..0 ]:ShlIn ) << 1
; - Op1[ 0 ] >> 63
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
; - implemented, tested and benched on 31.03.2016 by jn
; - includes prefetching
; ============================================================================

%ifdef USE_LINUX64

    %define Op1         RDI
    %define Size1       RSI
    %define ShrIn       RDX
    %define Shift       RCX
    %define Op2         R8
    %define Limb1       R9
    %define Limb2       R10
  %ifdef USE_PREFETCH
    %define Offs        R11
  %endif

  %ifdef USE_AVX
    %define ShrDL0      XMM3    ; Attn: this must match ShrQL0 definition
    %define ShlDLCnt    XMM6    ; Attn: this must match ShlQlCnt definition
    %define ShrDLCnt    XMM7    ; Attn: this must match ShrQlCnt definition

    %define QLimb0      YMM0
    %define QLimb1      YMM1
    %define ShlQL0      YMM2
    %define ShrQL0      YMM3
    %define ShlQL1      YMM4
    %define ShrQL1      YMM5
    %define ShlQLCnt    YMM6
    %define ShrQLCnt    YMM7
  %endif

%endif

    align   32
lShlEqu:

    xor     EAX, EAX
    sub      Size1, 1
    jc      .Exit               ; Size1=0 =>

    lea     Op1, [Op1+8*Size1]
    lea     Op2, [Op2+8*Size1]

    mov     Limb1, [Op1]
    shld    RAX, Limb1, CL

    or      Size1, Size1
    je      .lShlEquPost        ; Size1=1 =>

  %ifdef USE_PREFETCH
    mov     Offs, -512
  %endif

    cmp     Size1, 8
    jc      .lShlEquFour        ; AVX inefficient =>

    ; first align Op2 to 32 bytes
    test    Op2, 8
    jne     .lShlEquA16

    mov     Limb2, [Op1-8]
    shld    Limb1, Limb2, CL
    mov     [Op2], Limb1
    mov     Limb1, Limb2

    sub     Op1, 8
    sub     Op2, 8
    sub     Size1, 1

  .lShlEquA16:

    test    Op2, 16
    jne     .lShlEquAVX

    mov     Limb2, [Op1-8]
    shld    Limb1, Limb2, CL
    mov     [Op2], Limb1
    mov     Limb1, [Op1-16]
    shld    Limb2, Limb1, CL
    mov     [Op2-8], Limb2

    sub     Op1, 16
    sub     Op2, 16
    sub     Size1, 2

  .lShlEquAVX:

    ; initialize AVX shift counter
    vmovq   ShlDLCnt, RCX
    neg     RCX
    and     RCX, 63             ; must do, as AVX shifts set result=0 if Shift>63!
    vmovq   ShrDLCnt, RCX
    neg     RCX
    and     RCX, 63             ; must do, as AVX shifts set result=0 if Shift>63!
    vpbroadcastq ShlQLCnt, ShlDLCnt
    vpbroadcastq ShrQLCnt, ShrDLCnt

    ; pre-fetch first quad-limb
    vmovdqu QLimb0, [Op1-24]
    vpsrlvq ShrQL0, QLimb0, ShrQLCnt
    vpermq  ShrQL0, ShrQL0, 0b10010011

    sub     Op1, 32
    sub     Size1, 4
    jmp     .lShlEquAVXCheck

    ; main loop (prefetching enabled; unloaded cache)
    ; - 0.60      cycles per limb in LD1$
    ; - 0.60-0.70 cycles per limb in LD2$
    ; - 0.70-0.90 cycles per limb in LD3$
    align   16
  .lShlEquAVXLoop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
  %endif

    vmovdqu   QLimb1, [Op1-24]
    vpsllvq   ShlQL0, QLimb0, ShlQLCnt
    vmovdqu   QLimb0, [Op1-56]
    vpsrlvq   ShrQL1, QLimb1, ShrQLCnt
    vpermq    ShrQL1, ShrQL1, 0b10010011
    vpblendd  ShrQL0, ShrQL0, ShrQL1, 0b00000011
    vpor      ShlQL0, ShlQL0, ShrQL0
    vpsllvq   ShlQL1, QLimb1, ShlQLCnt
    vpsrlvq   ShrQL0, QLimb0, ShrQLCnt
    vpermq    ShrQL0, ShrQL0, 0b10010011
    vpblendd  ShrQL1, ShrQL1, ShrQL0, 0b00000011
    vmovdqa   [Op2-24], ShlQL0
    vpor      ShlQL1, ShlQL1, ShrQL1
    vmovdqa   [Op2-56], ShlQL1

    sub     Op1, 64
    sub     Op2, 64

  .lShlEquAVXCheck:

    sub     Size1, 8
    jnc     .lShlEquAVXLoop

    ; I am mixing in a single SSE4.1 instruction into otherwise pure AVX2
    ; this is generating stalls on Haswell & Broadwell architecture (Agner Fog)
    ; but it is only executed once and there is no AVX2 based alternative
    mov     Limb1, [Op1]
    xor     Limb2, Limb2
    shld    Limb2, Limb1, CL
    vpsllvq ShlQL0, QLimb0, ShlQLCnt
    pinsrq  ShrDL0, Limb2, 0        ; SSE4.1
    vpor    ShlQL0, ShlQL0, ShrQL0
    vmovdqa [Op2-24], ShlQL0

    sub     Op2, 32
    add     Size1, 8

    ; shift remaining max. 7 limbs with SHLD mnemonic
  .lShlEquFour:

    sub     Op1, 8
    test    Size1, 4
    je      .lShlEquTwo

    mov     Limb2, [Op1]
    shld    Limb1, Limb2, CL
    mov     [Op2], Limb1
    mov     Limb1, [Op1-8]
    shld    Limb2, Limb1, CL
    mov     [Op2-8], Limb2
    mov     Limb2, [Op1-16]
    shld    Limb1, Limb2, CL
    mov     [Op2-16], Limb1
    mov     Limb1, [Op1-24]
    shld    Limb2, Limb1, CL
    mov     [Op2-24], Limb2

    sub     Op1, 32
    sub     Op2, 32

  .lShlEquTwo:

    test    Size1, 2
    je      .lShlEquOne

    mov     Limb2, [Op1]
    shld    Limb1, Limb2, CL
    mov     [Op2], Limb1
    mov     Limb1, [Op1-8]
    shld    Limb2, Limb1, CL
    mov     [Op2-8], Limb2

    sub     Op1, 16
    sub     Op2, 16

  .lShlEquOne:

    test    Size1, 1
    je      .lShlEquPost

    mov     Limb2, [Op1]
    shld    Limb1, Limb2, CL
    mov     [Op2], Limb1
    mov     Limb1, Limb2

    sub     Op2, 8

  .lShlEquPost:

    shld    Limb1, ShlIn, CL
    mov     [Op2], Limb1

  .Exit:

    ret

