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

BITS 64

global      lCpyInc:function (lCpyInc.end - lCpyInc)

segment     .text

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
.end:
