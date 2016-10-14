; ============================================================================
; sumdiff_n( Op1, Op2: pLimb; Size: tCounter; Op3, Op4: pLimb ):tBaseVal;
; Linux      RDI  RSI         RDX             RCX  R8          :RAX
; Win7       RCX  RDX         R8              R9   Stack       :RAX
;
; Description:
; The function adds Op2 to Op1 and stores the result in Op3 while at the same
; time subtracting Op2 from Op1 with result in Op4. The final carries from
; addition and subtraction are handed back as a combined tBaseVal. There is a
; gain in execution speed compared to separate addition and subtraction by
; reducing memory access. The factor depends on the size of the operands (the
; cache hierarchy in which the operands can be handled).
;
; Comments:
; - asm version implemented, tested & benched on 10.06.2015 by jn
; - On Nehalem per limb saving is 0.5 cycle in LD1$, LD2$ and LD3$
; - includes prefetching
; - includes XMM save & restore
; ============================================================================

BITS 64

global  sumdiff_n:function

segment .text

%ifdef USE_WIN64

    %define Op1     RCX
    %define Op2     RDX
    %define Size    R8
    %define Op3     R9
    %define Op4     RBX             ; SAVE!

    %define Limb0   RBP             ; SAVE!
    %define Limb1   RSI             ; SAVE!
    %define Limb2   RDI             ; SAVE!
    %define Limb3   R10
    %define Limb4   R11
    %define Limb5   R12             ; SAVE!
    %define Limb6   R13             ; SAVE!
    %define Limb7   R14             ; SAVE!
    %define Limb8   R15             ; SAVE!

  %ifdef USE_PREFETCH
    %define Offs    PREFETCH_STRIDE ; no more regs avail. => fallback to const
  %endif

    %define SaveRBX XMM0            ; use scratch XMM for fast save & restore
    %define SaveRBP XMM1            ; R14 and R15 handled via stack
    %define SaveRSI XMM2
    %define SaveRDI XMM3
    %define SaveR12 XMM4
    %define SaveR13 XMM5

%endif

%ifdef USE_LINUX64

    %define Op1     RDI
    %define Op2     RSI
    %define Size    RDX
    %define Op3     RCX
    %define Op4     R8

    %define Limb0   RBP             ; SAVE!
    %define Limb1   RBX             ; SAVE!
    %define Limb2   R9
    %define Limb3   R10
    %define Limb4   R11
    %define Limb5   R12             ; SAVE!
    %define Limb6   R13             ; SAVE!
    %define Limb7   R14             ; SAVE!
    %define Limb8   R15             ; SAVE!

  %ifdef USE_PREFETCH
    %define Offs    PREFETCH_STRIDE ; no more regs avail. => fallback to const
  %endif

    %define SaveRBX XMM0            ; use scratch XMM for fast save & restore
    %define SaveRBP XMM1
    %define SaveR12 XMM2
    %define SaveR13 XMM3
    %define SaveR14 XMM4
    %define SaveR15 XMM5

%endif

    align   32
sumdiff_n:

  %ifdef USE_WIN64
    sub     RSP, 16
    mov     [RSP+8], R15
    mov     [RSP], R14

    movq    SaveR13, R13
    movq    SaveR12, R12
    movq    SaveRDI, RDI
    movq    SaveRSI, RSI
    movq    SaveRBP, RBP
    movq    SaveRBX, RBX
  %endif

  %ifdef USE_LINUX64
    movq    SaveR15, R15
    movq    SaveR14, R14
    movq    SaveR13, R13
    movq    SaveR12, R12
    movq    SaveRBP, RBP
    movq    SaveRBX, RBX
  %endif

    xor     EAX, EAX            ; clear add & sub carry

    test    Size, 1
    je      .sumdiff_n_two

    mov     Limb1, [Op1]
    mov     Limb5, [Op2]
    mov     Limb2, Limb1
    add     Limb2, Limb5
    mov     [Op3], Limb2

    sbb     AL, AL

    sub     Limb1, Limb5
    mov     [Op4], Limb1

    sbb     AH, AH

    add     Op1, 8
    add     Op2, 8
    add     Op3, 8
    add     Op4, 8

  .sumdiff_n_two:

    test    Size, 2
    je      .sumdiff_n_four

    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    mov     Limb5, [Op2]
    mov     Limb6, [Op2+8]

    add     AL, AL

    mov     Limb3, Limb1
    adc     Limb3, Limb5
    mov     [Op3], Limb3
    mov     Limb4, Limb2
    adc     Limb4, Limb6
    mov     [Op3+8], Limb4

    sbb     AL, AL
    add     AH, AH

    sbb     Limb1, Limb5
    mov     [Op4], Limb1
    sbb     Limb2, Limb6
    mov     [Op4+8], Limb2

    sbb     AH, AH

    add     Op1, 16
    add     Op2, 16
    add     Op3, 16
    add     Op4, 16

  .sumdiff_n_four:

    test    Size, 4
    je      .sumdiff_n_test

    add     AL, AL

    ; slight change of scheme here - avoid too many
    ; memory to reg or reg to memory moves in a row
    mov     Limb1, [Op1]
    mov     Limb5, [Op2]
    mov     Limb0, Limb1
    adc     Limb0, Limb5
    mov     [Op3], Limb0
    mov     Limb2, [Op1+8]
    mov     Limb6, [Op2+8]
    mov     Limb0, Limb2
    adc     Limb0, Limb6
    mov     [Op3+8], Limb0
    mov     Limb3, [Op1+16]
    mov     Limb7, [Op2+16]
    mov     Limb0, Limb3
    adc     Limb0, Limb7
    mov     [Op3+16], Limb0
    mov     Limb4, [Op1+24]
    mov     Limb8, [Op2+24]
    mov     Limb0, Limb4
    adc     Limb0, Limb8
    mov     [Op3+24], Limb0

    sbb     AL, AL
    add     AH, AH

    sbb     Limb1, Limb5
    mov     [Op4], Limb1
    sbb     Limb2, Limb6
    mov     [Op4+8], Limb2
    sbb     Limb3, Limb7
    mov     [Op4+16], Limb3
    sbb     Limb4, Limb8
    mov     [Op4+24], Limb4

    sbb     AH, AH

    add     Op1, 32
    add     Op2, 32
    add     Op3, 32
    add     Op4, 32
    jmp     .sumdiff_n_test

    ; main loop - values below are best case - up to 50% fluctuation possible!
    ; - 3.50      cycles per limb in LD1$
    ; - 3.50      cycles per limb in LD2$
    ; - 5.10-5.50 cycles per limb in LD3$
    align   16
  .sumdiff_n_loop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
    prefetchnta [Op2+Offs]
  %endif

    add     AL, AL              ; set carry for addition

    mov     Limb1, [Op1]        ; add the first quad-limb
    mov     Limb5, [Op2]
    mov     Limb0, Limb1
    adc     Limb0, Limb5
    mov     [Op3], Limb0
    mov     Limb2, [Op1+8]
    mov     Limb6, [Op2+8]
    mov     Limb0, Limb2
    adc     Limb0, Limb6
    mov     [Op3+8], Limb0
    mov     Limb3, [Op1+16]
    mov     Limb7, [Op2+16]
    mov     Limb0, Limb3
    adc     Limb0, Limb7
    mov     [Op3+16], Limb0
    mov     Limb4, [Op1+24]
    mov     Limb8, [Op2+24]
    mov     Limb0, Limb4
    adc     Limb0, Limb8
    mov     [Op3+24], Limb0

    sbb     AL, AL              ; memorize add-carry
    add     AH, AH              ; set carry for subtraction

    sbb     Limb1, Limb5        ; now sub the first quad-limb
    mov     [Op4], Limb1
    sbb     Limb2, Limb6
    mov     [Op4+8], Limb2
    sbb     Limb3, Limb7
    mov     [Op4+16], Limb3
    sbb     Limb4, Limb8
    mov     [Op4+24], Limb4

    mov     Limb1, [Op1+32]     ; sub the second quad-limb
    mov     Limb5, [Op2+32]
    mov     Limb0, Limb1
    sbb     Limb0, Limb5
    mov     [Op4+32], Limb0
    mov     Limb2, [Op1+40]
    mov     Limb6, [Op2+40]
    mov     Limb0, Limb2
    sbb     Limb0, Limb6
    mov     [Op4+40], Limb0
    mov     Limb3, [Op1+48]
    mov     Limb7, [Op2+48]
    mov     Limb0, Limb3
    sbb     Limb0, Limb7
    mov     [Op4+48], Limb0
    mov     Limb4, [Op1+56]
    mov     Limb8, [Op2+56]
    mov     Limb0, Limb4
    sbb     Limb0, Limb8
    mov     [Op4+56], Limb0

    sbb     AH, AH              ; memorize sub-carry
    add     AL, AL              ; set carry for addition

    adc     Limb1, Limb5        ; add the second quad-limb
    mov     [Op3+32], Limb1
    adc     Limb2, Limb6
    mov     [Op3+40], Limb2
    adc     Limb3, Limb7
    mov     [Op3+48], Limb3
    adc     Limb4, Limb8
    mov     [Op3+56], Limb4

    sbb     AL, AL              ; memorize add-carry

    add     Op1, 64
    add     Op2, 64
    add     Op3, 64
    add     Op4, 64

  .sumdiff_n_test:

    sub     Size, 8
    jnc     .sumdiff_n_loop

    ; hand back carries
  .sumdiff_n_post:

    add     AL, AL
    rcl     AL, 1               ; add-carry back as bit #1
    add     AH, AH
    rcl     AL, 1               ; sub-carry back as bit #0
    and     EAX, 3              ; depending on definition this can be omitted

  .Exit:

  %ifdef USE_WIN64
    movq    RBX, SaveRBX
    movq    RBP, SaveRBP
    movq    RSI, SaveRSI
    movq    RDI, SaveRDI
    movq    R12, SaveR12
    movq    R13, SaveR13

    mov     R14, [RSP]
    mov     R15, [RSP+8]
    add     RSP, 16
  %endif

  %ifdef USE_LINUX64
    movq    R15, SaveR15
    movq    R14, SaveR14
    movq    R13, SaveR13
    movq    R12, SaveR12
    movq    RBP, SaveRBP
    movq    RBX, SaveRBX
  %endif

    ret
