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

global      lCmp:function
global      lCpyInc:function
global      lCpyDec:function
global      lShr1Equ:function
global      lShl1Equ:function
global      lShrEqu:function
global      lShlEqu:function

segment     .text

; ============================================================================
; lCmp( Op1: pLimb; Size1: tCounter; Op2: pLimb; Size2: tCounter ):INT64;
; Linux RDI         RSI              RDX         RCX              :RAX
; Win7  RCX         RDX              R8          R9               :RAX
;
; Description:
; The function compares the limb arrays Op1 & Op2 interpreting them as natural
; numbers. Two arrays with size=0 are equal by definition.
;
; Result:
; - comparison evaluation of Op1 & Op2: range [ -1/0/1 ] (for [ </=/> ])
;
; Caveats:
; - this one returns an INT64!
;
; Comments:
; - AVX version implemented, tested & benched on 04.01.2016 by jn
; - reduced number of AVX regs to five - now fitting Win64 scratch definition
; - corrected a severe bug in AVX version due to incorrect understanding of
;   VPTEST mnemonic - new version still on same speed level as initial version
; - AVX version roughly 1.5 to 3 times faster than non-AVX, depending on cache
;   level and data alignment
; =============================================================================

%ifdef USE_WIN64

    %define Op1     RCX
    %define Size1   RDX
    %define Op2     R8
    %define Size2   R9
    %define Greater R10
    %define Smaller R11

    %define QLOp2_0 YMM0
    %define QLOp2_1 YMM1
    %define QLOp2_2 YMM2
    %define QLOp2_3 YMM3

    %define QLZero  YMM4

%endif

%ifdef USE_LINUX64

    %define Op1     RDI
    %define Size1   RSI
    %define Op2     RDX
    %define Size2   RCX
    %define Greater R8
    %define Smaller R9

    %define QLOp2_0 YMM0
    %define QLOp2_1 YMM1
    %define QLOp2_2 YMM2
    %define QLOp2_3 YMM3

    %define QLZero  YMM4

%endif

    align   32
lCmp:

    mov     Greater, 1
    mov     Smaller, -1
    xor     RAX, RAX

    cmp     Size1, Size2
    jne     .lCmpSet            ; fast exit => sizes don't match

    lea     Op1, [Op1+8*Size1]
    lea     Op2, [Op2+8*Size1]

    cmp     Size1, 20
    jc      .lCmpEightCheck     ; AVX inefficient =>

    ; direct check of the topmost four limb for two reasons
    ;  - if the compared arrays are computational unrelated there is a good
    ;    chance that we generate a fast out - or, if the arrays stem from a
    ;    divide and conquer process of computation the difference is either in
    ;    the topmost limbs or deep inside the array
    ;  - for efficiency reasons we need to align at least one operand pointer
    ;    to 32 byte to use AVX. Checking the topmost four limb guarantees that
    ;    the alignment is done efficient without exceeding the array bounds

  .lCmpTopFour:

    mov     Size2, [Op1-8]      ; Size2 is free to use here
    cmp     Size2, [Op2-8]
    jne     .lCmpSet

    mov     Size2, [Op1-16]
    cmp     Size2, [Op2-16]
    jne     .lCmpSet

    mov     Size2, [Op1-24]
    cmp     Size2, [Op2-24]
    jne     .lCmpSet

    mov     Size2, [Op1-32]
    cmp     Size2, [Op2-32]
    jne     .lCmpSet

    sub     Op1, 32
    sub     Op2, 32
    sub     Size1, 4

  .lCmpAVX:

    ; align Op1 to 32 byte boundary
    mov     Size2, Op1
    neg     Size2
    and     Size2, 24
    add     Op1, Size2
    add     Op2, Size2
    shr     Size2, 3
    add     Size1, Size2

    ; wrt code density set Op1 & Op2 to the beginning of top quad-limb
    sub     Op1, 32
    sub     Op2, 32

    ; prepare AVX main loop
    vpcmpeqq QLZero, QLZero, QLZero

    vmovdqu QLOp2_0, [Op2]
    vmovdqu QLOp2_1, [Op2-32]
    vmovdqu QLOp2_2, [Op2-64]
    vmovdqu QLOp2_3, [Op2-96]
    sub     Size1, 16

    mov     Size2, 128
    jmp     .lCmpAVXCheck

    ; main loop (prefetching disabled; unloaded cache)
    ; - 0.4 cycles per limb in LD1$
    ; - 0.5 cycles per limb in LD2$
    ; - 0.5 cycles per limb in LD3$
    align   16
  .lCmpAVXLoop:

    sub     Op2, Size2

    vpsubq  QLOp2_0, QLOp2_0, [Op1]
    vpsubq  QLOp2_1, QLOp2_1, [Op1-32]
    vpsubq  QLOp2_2, QLOp2_2, [Op1-64]
    vpsubq  QLOp2_3, QLOp2_3, [Op1-96]

    sub     Op1, Size2

    vptest  QLOp2_0, QLZero
    jne     .lCmpXxx
    vmovdqu QLOp2_0, [Op2]
    vptest  QLOp2_1, QLZero
    jne     .lCmpXxx
    vmovdqu QLOp2_1, [Op2-32]
    vptest  QLOp2_2, QLZero
    jne     .lCmpXxx
    vmovdqu QLOp2_2, [Op2-64]
    vptest  QLOp2_3, QLZero
    jne     .lCmpXxx
    vmovdqu QLOp2_3, [Op2-96]

  .lCmpAVXCheck:

    sub     Size1, 16
    jnc     .lCmpAVXLoop

    vpsubq  QLOp2_0, QLOp2_0, [Op1]
    vpsubq  QLOp2_1, QLOp2_1, [Op1-32]
    vpsubq  QLOp2_2, QLOp2_2, [Op1-64]
    vpsubq  QLOp2_3, QLOp2_3, [Op1-96]

    ; check pending four quad-limb
    vptest  QLOp2_0, QLZero
    jne     .lCmpXxx
    vptest  QLOp2_1, QLZero
    jne     .lCmpXxx
    vptest  QLOp2_2, QLZero
    jne     .lCmpXxx
    vptest  QLOp2_3, QLZero
    jne     .lCmpXxx

    add     Size1, 16
    je      .Exit               ; complete array compared 'equal' by AVX =>

    ; no difference detected in AVX comparison - check rmmaining max. 15 limb
    sub     Op1, 96
    sub     Op2, 96
    jmp     .lCmpEightCheck

    ; AVX detected a difference - evaluate for larger or smaller
  .lCmpXxx:

    add     Op1, 32
    add     Op2, 32
    mov     Size1, 16
    jmp     .lCmpEightCheck

    ; test remaining (max. 20) limb with CMP mnemonic to identify < / = / >
    ; Op1 and Op2 point above most significant limb here
    align   16
  .lCmpEight:

    mov     Size2, [Op1-8]
    cmp     Size2, [Op2-8]
    jne     .lCmpSet

    mov     Size2, [Op1-16]
    cmp     Size2, [Op2-16]
    jne     .lCmpSet

    mov     Size2, [Op1-24]
    cmp     Size2, [Op2-24]
    jne     .lCmpSet

    mov     Size2, [Op1-32]
    cmp     Size2, [Op2-32]
    jne     .lCmpSet

    mov     Size2, [Op1-40]
    cmp     Size2, [Op2-40]
    jne     .lCmpSet

    mov     Size2, [Op1-48]
    cmp     Size2, [Op2-48]
    jne     .lCmpSet

    mov     Size2, [Op1-56]
    cmp     Size2, [Op2-56]
    jne     .lCmpSet

    mov     Size2, [Op1-64]
    cmp     Size2, [Op2-64]
    jne     .lCmpSet

    sub     Op1, 64
    sub     Op2, 64

  .lCmpEightCheck:

    sub     Size1, 8
    jnc     .lCmpEight

  .lCmpFour:

    test    Size1, 4
    je      .lCmpTwo

    mov     Size2, [Op1-8]
    cmp     Size2, [Op2-8]
    jne     .lCmpSet

    mov     Size2, [Op1-16]
    cmp     Size2, [Op2-16]
    jne     .lCmpSet

    mov     Size2, [Op1-24]
    cmp     Size2, [Op2-24]
    jne     .lCmpSet

    mov     Size2, [Op1-32]
    cmp     Size2, [Op2-32]
    jne     .lCmpSet

    sub     Op1, 32
    sub     Op2, 32

  .lCmpTwo:

    test    Size1, 2
    je      .lCmpOne

    mov     Size2, [Op1-8]
    cmp     Size2, [Op2-8]
    jne     .lCmpSet

    mov     Size2, [Op1-16]
    cmp     Size2, [Op2-16]
    jne     .lCmpSet

    sub     Op1, 16
    sub     Op2, 16

  .lCmpOne:

    test   Size1, 1
    je     .Exit

    mov     Size2, [Op1-8]
    cmp     Size2, [Op2-8]

  .lCmpSet:

    cmova   RAX, Greater
    cmovb   RAX, Smaller

  .Exit:

    ret

; =============================================================================
; lCpyInc( Op1: pLimb; Size1: tCounter; Op2: pLimb ):tCounter;
; Linux    RDI         RSI              RDX         :RAX
; Win7     RCX         RDX              R8          :RAX
;
; Description:
; The function copies a given number of limb from source to destination (while
; moving low to high in memory) and hands back the size (in limb) of the
; destination.
;
; Result:
; - Op2[ 0..size-1 ] = Op1[ 0..size-1 ]
; - number of copied limb: range [ 0..max tCounter ]
;
; Caveats:
; - if size 0 is given the content of the destination will remain untouched!
; - if Op1=Op2 no copy is done!
;
; Comments:
; - AVX-based version implemented, tested & benched on 05.01.2016 by jn
; - did some experiments with AVX based version with following results
;   - AVX can be faster in L1$ (30%), L2$ (10%) if dest. is aligned on 32 byte
;   - AVX is generally faster on small sized operands (<=100 limb) due too
;     start-up overhead of "rep movsq" - however this could also be achieved by
;     simple copy loop
;   - the break-even between AVX and "rep movsq" is around 10,000 limb
; - the prologue & epilogue can still be optimized!
; =============================================================================

%ifdef USE_WIN64

    %define Op1     RCX
    %define Size1   RDX
    %define Op2     R8
    %define Limb    R9

    %define Offs    R10

    %define DLimb0  XMM0

    %define QLimb0  YMM0
    %define QLimb1  YMM1
    %define QLimb2  YMM2
    %define QLimb3  YMM3

%endif

%ifdef USE_LINUX64

    %define Op1     RDI
    %define Size1   RSI
    %define Op2     RDX
    %define Limb    RCX

    %define Offs    R10

    %define DLimb0  XMM0

    %define QLimb0  YMM0
    %define QLimb1  YMM1
    %define QLimb2  YMM2
    %define QLimb3  YMM3

%endif

    align   32
lCpyInc:

    mov     RAX, Size1
    cmp     Op1, Op2
    je      .Exit               ; no copy required =>

    or      RAX, RAX
    je      .Exit               ; size=0 =>

    ; align the destination (Op2) to 32 byte
    test    Op2, 8
    je      .lCpyIncA32

    mov     Limb, [Op1]
    mov     [Op2], Limb
    dec     Size1
    je      .Exit

    add     Op1, 8
    add     Op2, 8

  .lCpyIncA32:

    test    Op2, 16
    je      .lCpyIncAVX

    mov     Limb, [Op1]
    mov     [Op2], Limb
    dec     Size1
    je      .Exit

    mov     Limb, [Op1+8]
    mov     [Op2+8], Limb
    dec     Size1
    je      .Exit

    add     Op1, 16
    add     Op2, 16

  .lCpyIncAVX:

    mov     Offs, 128
    jmp     .lCpyIncAVXCheck

    ; main loop (prefetching disabled; unloaded cache)
    ; - lCpyInc is slightly slower than lCpyDec through all cache levels?!
    ; - 0.30      cycles / limb in L1$
    ; - 0.60      cycles / limb in L2$
    ; - 0.70-0.90 cycles / limb in L3$
    align   16
  .lCpyIncAVXLoop:

    vmovdqu QLimb0, [Op1]
    vmovdqu QLimb1, [Op1+32]
    vmovdqu QLimb2, [Op1+64]
    vmovdqu QLimb3, [Op1+96]
    vmovdqa [Op2], QLimb0
    vmovdqa [Op2+32], QLimb1
    vmovdqa [Op2+64], QLimb2
    vmovdqa [Op2+96], QLimb3

    add     Op1, Offs
    add     Op2, Offs

  .lCpyIncAVXCheck:

    sub     Size1, 16
    jnc     .lCpyIncAVXLoop

    add     Size1, 16
    je      .Exit               ; AVX copied operand fully =>

    ; copy remaining max. 15 limb
    test    Size1, 8
    je      .lCpyIncFour

    vmovdqu QLimb0, [Op1]
    vmovdqu QLimb1, [Op1+32]
    vmovdqa [Op2], QLimb0
    vmovdqa [Op2+32], QLimb1

    add     Op1, 64
    add     Op2, 64

  .lCpyIncFour:

    test    Size1, 4
    je      .lCpyIncTwo

    vmovdqu QLimb0, [Op1]
    vmovdqa [Op2], QLimb0

    add     Op1, 32
    add     Op2, 32

  .lCpyIncTwo:

    test    Size1, 2
    je      .lCpyIncOne

    movdqu  DLimb0, [Op1]
    movdqa  [Op2], DLimb0

    add     Op1, 16
    add     Op2, 16

  .lCpyIncOne:

    test    Size1, 1
    je      .Exit

    mov     Limb, [Op1]
    mov     [Op2], Limb

  .Exit:

    ret

; ============================================================================
; lCpyDec( Op1: pLimb; Size1: tCounter; Op2: pLimb ):tCounter
; Linux    RDI         RSI              RDX         :RAX
; Win7     RCX         RDX              R8          :RAX
;
; Description:
; The function copies a given number of limb from source to destination (while
; moving high to low in memory) and hands back the size (in limb) of the
; destination.
;
; Result:
; - Op2[ 0..size-1 ] = Op1[ 0..size-1 ]
; - number of copied limb: range [ 0..max tCounter ]
;
; Caveats:
; - if size 0 is given the content of the destination will remain untouched!
; - if Op1=Op2 no copy is done!
;
; Comments:
; - AVX-based version implemented, tested & benched on 05.01.2016 by jn
; - did some experiments with AVX based version with following results
;   - AVX can be faster in L1$-L3$ if destination is aligned on 32 byte
;   - AVX is generally faster on small sized operands (<=100 limb) due too
;     start-up overhead of "rep movsq" - however this could also be achieved by
;     simple copy loop
;   - startup overhead of "rep movsq" with negative direction is 200 cycles!!!
;   - negative direction is unfavourable compared to positive "rep movsq" and
;     to AVX.
; ============================================================================

%ifdef USE_WIN64

    %define Op1     RCX
    %define Size1   RDX
    %define Op2     R8
    %define Limb    R9

    %define Offs    R10

    %define DLimb0  XMM0

    %define QLimb0  YMM0
    %define QLimb1  YMM1
    %define QLimb2  YMM2
    %define QLimb3  YMM3

%endif

%ifdef USE_LINUX64

    %define Op1     RDI
    %define Size1   RSI
    %define Op2     RDX
    %define Limb    RCX

    %define Offs    R10

    %define DLimb0  XMM0

    %define QLimb0  YMM0
    %define QLimb1  YMM1
    %define QLimb2  YMM2
    %define QLimb3  YMM3

%endif

    align   32
lCpyDec:

    mov     RAX, Size1
    cmp     Op1, Op2
    je      .Exit               ; no copy required =>

    or      RAX, RAX
    je      .Exit               ; Size=0 =>

    lea     Op1, [Op1+8*Size1-8]
    lea     Op2, [Op2+8*Size1-8]

    ; align the destination (Op2) to 32 byte
    test    Op2, 8
    jne     .lCpyDecA32

    mov     Limb, [Op1]
    mov     [Op2], Limb
    dec     Size1
    je      .Exit

    sub     Op1, 8
    sub     Op2, 8

  .lCpyDecA32:

    test    Op2, 16
    jnz     .lCpyDecAVX

    mov     Limb, [Op1]
    mov     [Op2], Limb
    dec     Size1
    je      .Exit

    mov     Limb, [Op1-8]
    mov     [Op2-8], Limb
    dec     Size1
    je      .Exit

    sub     Op1, 16
    sub     Op2, 16

  .lCpyDecAVX:

    mov     Offs, 128
    jmp     .lCpyDecAVXCheck

    ; main loop (prefetching disabled; unloaded cache)
    ; - 0.30      cycles / limb in L1$
    ; - 0.60      cycles / limb in L2$
    ; - 0.70-0.90 cycles / limb in L3$
    align   16
  .lCpyDecAVXLoop:

    vmovdqu QLimb0, [Op1-24]
    vmovdqu QLimb1, [Op1-56]
    vmovdqu QLimb2, [Op1-88]
    vmovdqu QLimb3, [Op1-120]
    vmovdqa [Op2-24], QLimb0
    vmovdqa [Op2-56], QLimb1
    vmovdqa [Op2-88], QLimb2
    vmovdqa [Op2-120], QLimb3

    sub     Op1, Offs
    sub     Op2, Offs

  .lCpyDecAVXCheck:

    sub     Size1, 16
    jnc     .lCpyDecAVXLoop

    add     Size1, 16
    je      .Exit               ; AVX copied operand fully =>

    ; copy remaining max. 15 limb
    test    Size1, 8
    je      .lCpyDecFour

    vmovdqu QLimb0, [Op1-24]
    vmovdqu QLimb1, [Op1-56]
    vmovdqa [Op2-24], QLimb0
    vmovdqa [Op2-56], QLimb1

    sub     Op1, 64
    sub     Op2, 64

  .lCpyDecFour:

    test    Size1, 4
    je      .lCpyDecTwo

    vmovdqu QLimb0, [Op1-24]
    vmovdqa [Op2-24], QLimb0

    sub     Op1, 32
    sub     Op2, 32

  .lCpyDecTwo:

    test    Size1, 2
    je      .lCpyDecOne

    movdqu  DLimb0, [Op1-8]
    movdqa  [Op2-8], DLimb0

    sub     Op1, 16
    sub     Op2, 16

  .lCpyDecOne:

    test    Size1, 1
    je      .Exit

    mov     Limb, [Op1]
    mov     [Op2], Limb

  .Exit:

    ret

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
    vpblendd  ShlQL0, ShlQL0, ShlQL1, 0b00000011
    vpermq    ShlQL0, ShlQL0, 0b00111001
    vpor      ShrQL0, ShrQL0, ShlQL0
    vpsrlq    ShrQL1, QLimb1, 1
    vpsllq    ShlQL0, QLimb0, 63
    vpblendd  ShlQL1, ShlQL1, ShlQL0, 0b00000011
    vpermq    ShlQL1, ShlQL1, 0b00111001
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
    vpermq  ShlQL0, ShlQL0, 0b00111001
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
    vpermq  ShrQL0, ShrQL0, 0b10010011

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
    vpermq    ShrQL1, ShrQL1, 0b10010011
    vpblendd  ShrQL0, ShrQL0, ShrQL1, 0b00000011
    vpor      ShlQL0, ShlQL0, ShrQL0
    vpsllq    ShlQL1, QLimb1, 1
    vpsrlq    ShrQL0, QLimb0, 63
    vpermq    ShrQL0, ShrQL0, 0b10010011
    vpblendd  ShrQL1, ShrQL1, ShrQL0, 0b00000011
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

