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

BITS 64

global      lCpyDec:function (lCpyDec.end - lCpyDec)

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
.end:
