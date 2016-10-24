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

BITS 64

global      lCmp:function (lCmp.end - lCmp)

segment     .text

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
.end:
