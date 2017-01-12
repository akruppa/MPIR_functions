; =============================================================================
; Elementary Arithmetic Assembler Routines
; for Intel Architectures Haswell, Broadwell and Skylake
;
; (c) Jens Nurmann - 2017
; ----------------------------------------------------------------------------
; History:
;
; Date       Author Version Action
; ---------- ------ ------- --------------------------------------------------
; 04.01.2017 jn     0.00.01 generated excerpt for MPIR containing
;                           - mul_1
; ============================================================================

; ============================================================================
; sMul1( Op1; Size; Op2; Op3 ):tCounter;
; Linux  RDI  RSI   RDX  RCX  :RAX
; Win    RCX  RDX   R8   R9   :RAX
;
; Description:
; The function multiplies a limb array by a limb value including generation of
; a new most significant limb and hands back the size of the resulting array.
; To get to 1.25 cycles/limb I rolled out the core loop by 8. This requires
; two more checks & jumps compared with a roll-out by 4 - so the function is
; not the fastest on small (<8) limb arrays.
;
; Result:
; Op3[ 0..Size ] := Op2 * Op1[ 0..Size-1 ]
; index to most significant, non-zero limb: range [ Size..Size+1 ]
;
; Caveats:
; - the caller must ensure that Op1, Op2>0!
; - size of limb array can change (+1)!
;
; Comments:
; - implemented, tested and benchmarked on 17.11.2015 by jn
; - faster version implemented, tested and benched on 16.03.2016 by jn
; - faster version implemented, tested and benched on 03.01.2017 by jn
; - includes XMM save & restore
; - includes MULX
; ============================================================================

; the following register allocation scheme is valid for Linux

    %define Op1     RDI
    %define Size    RSI
    %define Op2     RDX
    %define Op3     RCX

    %define MulLo0  R8
    %define MulHi0  R9
    %define MulLo1  R10
    %define MulHi1  R11
    %define MulLo2  R12         ; SAVE!
    %define MulHi2  R13         ; SAVE!
    %define MulLo3  R14         ; SAVE!
    %define MulHi3  RBX         ; SAVE!

    %define SaveRBX XMM0
    %define SaveR12 XMM1
    %define SaveR13 XMM2
    %define SaveR14 XMM3

    align   32
sMul1:

    ; this is how I save registers under Linux
    movq    SaveR14, R14
    movq    SaveR13, R13
    movq    SaveR12, R12
    movq    SaveRBX, RBX

    xor     MulHi3, MulHi3

    mov     RAX, Size           ; may be increased by 1 at the end
    sub     Size, 4
    jc      .Post               ; separate handling of remaining max. 3 limb =>

    ; prepare a quadlimb for main-loop entry
    mulx    MulHi0, MulLo0, [Op1]
    mulx    MulHi1, MulLo1, [Op1+8]
    mulx    MulHi2, MulLo2, [Op1+16]
    mulx    MulHi3, MulLo3, [Op1+24]
    add     Op1, 32
    add     MulLo1, MulHi0
    adc     MulLo2, MulHi1
    adc     MulLo3, MulHi2
    adc     MulHi3, 0

    jmp     .Check              ; enter main loop =>

    ; main loop (unloaded operands)
    ; - 1.25      cycles per limb in L1D$
    ; - 1.25      cycles per limb in L2D$
    ; - 1.60-1.72 cycles per limb in L3D$
    align   32
  .Loop:

    mov     [Op3], MulLo0
    mulx    MulHi0, MulLo0, [Op1]
    mov     [Op3+8], MulLo1
    mulx    MulHi1, MulLo1, [Op1+8]
    mov     [Op3+16], MulLo2
    mulx    MulHi2, MulLo2, [Op1+16]
    add     MulLo0, MulHi3
    mov     [Op3+24], MulLo3
    mulx    MulHi3, MulLo3, [Op1+24]
    adc     MulLo1, MulHi0
    adc     MulLo2, MulHi1
    adc     MulLo3, MulHi2

    mov     [Op3+32], MulLo0
    mulx    MulHi0, MulLo0, [Op1+32]
    mov     [Op3+40], MulLo1
    mulx    MulHi1, MulLo1, [Op1+40]
    mov     [Op3+48], MulLo2
    mulx    MulHi2, MulLo2, [Op1+48]
    adc     MulLo0, MulHi3
    mov     [Op3+56], MulLo3
    mulx    MulHi3, MulLo3, [Op1+56]
    adc     MulLo1, MulHi0
    adc     MulLo2, MulHi1
    adc     MulLo3, MulHi2
    adc     MulHi3, 0

    add     Op1, 64
    add     Op3, 64

  .Check:

    sub     Size, 8
    jnc     .Loop

    ; core loop roll-out 8 can generate dangling quad-limb
    test    Size, 4
    je      .Store              ; no dangling quad-limb =>

    mov     [Op3], MulLo0
    mulx    MulHi0, MulLo0, [Op1]
    mov     [Op3+8], MulLo1
    mulx    MulHi1, MulLo1, [Op1+8]
    mov     [Op3+16], MulLo2
    mulx    MulHi2, MulLo2, [Op1+16]
    add     MulLo0, MulHi3
    mov     [Op3+24], MulLo3
    mulx    MulHi3, MulLo3, [Op1+24]
    adc     MulLo1, MulHi0
    adc     MulLo2, MulHi1
    adc     MulLo3, MulHi2
    adc     MulHi3, 0

    add     Op1, 32
    add     Op3, 32

    ; store remaining quad-limb from main loop
  .Store:
    mov     [Op3], MulLo0
    mov     [Op3+8], MulLo1
    mov     [Op3+16], MulLo2
    mov     [Op3+24], MulLo3
    add     Op3, 32

    ; handle final 0-3 single limb of Op1
  .Post:

    and     Size, 3
    je      .Post0

    cmp     Size, 2
    ja      .Post3
    je      .Post2

  .Post1:

    mulx    MulHi0, MulLo0, [Op1]
    add     MulLo0, MulHi3
    adc     MulHi0, 0
    mov     [Op3], MulLo0
    mov     [Op3+8], MulHi0
    sub     MulHi0, 1
    jmp     .Size

  .Post2:

    mulx    MulHi0, MulLo0, [Op1]
    mulx    MulHi1, MulLo1, [Op1+8]
    add     MulLo0, MulHi3
    adc     MulLo1, MulHi0
    adc     MulHi1, 0
    mov     [Op3], MulLo0
    mov     [Op3+8], MulLo1
    mov     [Op3+16], MulHi1
    sub     MulHi1, 1
    jmp     .Size

  .Post3:

    mulx    MulHi0, MulLo0, [Op1]
    mulx    MulHi1, MulLo1, [Op1+8]
    mulx    MulHi2, MulLo2, [Op1+16]
    add     MulLo0, MulHi3
    adc     MulLo1, MulHi0
    adc     MulLo2, MulHi1
    adc     MulHi2, 0
    mov     [Op3], MulLo0
    mov     [Op3+8], MulLo1
    mov     [Op3+16], MulLo2
    mov     [Op3+24], MulHi2
    sub     MulHi2, 1
    jmp     .Size

  .Post0:

    mov     [Op3], MulHi3
    sub     MulHi3, 1

  .Size:

    cmc
    adc     RAX, 0

  .Exit:

    ; restore registers the Linux way
    movq    RBX, SaveRBX
    movq    R12, SaveR12
    movq    R13, SaveR13
    movq    R14, SaveR14

    ret

