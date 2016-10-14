; =============================================================================
; Elementary Arithmetic Assembler Routines
; for Intel Architectures Haswell, Broadwell and Skylake
;
; (c) Jens Nurmann - 2014-2016
; ----------------------------------------------------------------------------
; History:
;
; Date       Author Version Action
; ---------- ------ ------- --------------------------------------------------
; 27.03.2016 jn     0.00.01 generated excerpt for MPIR containing
;                           - mul_1
; ============================================================================

%define USE_LINUX64
;%define USE_WIN64

global      mul_1:function

segment     .text

; ============================================================================
; mul_1( Op1: pLimb; Size: tCounter; Op2: tBaseVal; Op3: pLimb ):tCounter;
; Linux  RDI         RSI             RDX            RCX         :RAX
; Win7   RCX         RDX             R8             R9          :RAX
;
; TODO:
; - check if loop-unrolling by 8 and prefetching can increase speed in LD2$
;
; Description:
; The function multiplies a limb array by a limb value and hands back the new
; most significant limb.
;
; Result:
; - Op3[ 0..Size-1 ] := Op2*Op1[ 0..Size-1 ]
; - Op3[ Size ]
;
; Caveats:
; - the caller should ensure that Op2>0!
;
; Comments:
; - implemented, tested and benchmarked on 17.11.2015 by jn
; - faster version implemented, tested and benched on 16.03.2016
; - includes XMM save & restore
; ============================================================================

%ifdef USE_WIN64

    %define Op1     RCX
    %define SizeI   RDX
    %define Size    RBX         ; SAVE!
    %define Op2I    R8
    %define Op2     RDX
    %define Op3     R9
    %define MulLo0  RSI         ; SAVE!
    %define MulHi0  RDI         ; SAVE!
    %define MulLo1  R8
    %define MulHi1  R10
    %define MulLo2  R11
    %define MulHi2  R12         ; SAVE!
    %define MulLo3  R13         ; SAVE!
    %define MulHi3  RAX

    %define SaveRBX XMM0        ; use scratch XMM for save and restore
    %define SaveRSI XMM1
    %define SaveRDI XMM2
    %define SaveR12 XMM3
    %define SaveR13 XMM4

%endif

%ifdef USE_LINUX64

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
    %define MulHi3  RAX

    %define SaveR12 XMM1
    %define SaveR13 XMM2
    %define SaveR14 XMM3

%endif

    align   32
sMul1:

  %ifdef USE_WIN64
    movq    SaveRBX, RBX
    movq    SaveRSI, RSI
    movq    SaveRDI, RDI
    movq    SaveR12, R12
    movq    SaveR13, R13

    mov     Size, SizeI
    mov     Op2, Op2I
  %endif

  %ifdef USE_LINUX64
    movq    SaveR14, R14
    movq    SaveR13, R13
    movq    SaveR12, R12
  %endif

    xor     MulHi3, MulHi3

    sub     Size, 4
    jc      .sMul1Post          ; separate handling of remaining max. 3 limb =>

    ; prepare a quad-limb for main-loop entry
    mulx    MulHi0, MulLo0, [Op1]
    mulx    MulHi1, MulLo1, [Op1+8]
    mulx    MulHi2, MulLo2, [Op1+16]
    mulx    MulHi3, MulLo3, [Op1+24]

    add     Op1, 32

    add     MulLo1, MulHi0
    adc     MulLo2, MulHi1
    adc     MulLo3, MulHi2
    adc     MulHi3, 0

    jmp     .sMul1Check         ; enter main loop

    ; main loop (unloaded cache)
    ; - 1.35      cycles per limb in L1D$
    ; - 1.50-1.60 cycles per limb in L2D$
    ; - 1.60-1.70 cycles per limb in L3D$
    align   32
  .sMul1Loop:

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

  .sMul1Check:

    sub     Size, 4
    jnc     .sMul1Loop

    ; store remaining quad-limb from main loop
    mov     [Op3], MulLo0
    mov     [Op3+8], MulLo1
    mov     [Op3+16], MulLo2
    mov     [Op3+24], MulLo3

    add     Op3, 32

  .sMul1Post:

    and     Size, 3
    je      .Exit

    cmp     Size, 2
    ja      .sMul1Post3
    je      .sMul1Post2

  .sMul1Post1:

    mulx    MulHi0, MulLo0, [Op1]
    add     MulLo0, MulHi3
    adc     MulHi0, 0
    mov     [Op3], MulLo0
    mov     MulHi3, MulHi0
    jmp     .Exit

  .sMul1Post2:

    mulx    MulHi0, MulLo0, [Op1]
    mulx    MulHi1, MulLo1, [Op1+8]
    add     MulLo0, MulHi3
    adc     MulLo1, MulHi0
    adc     MulHi1, 0
    mov     [Op3], MulLo0
    mov     [Op3+8], MulLo1
    mov     MulHi3, MulHi1
    jmp     .Exit

  .sMul1Post3:

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
    mov     MulHi3, MulHi2

  .Exit:

  %ifdef USE_LINUX64
    movq    R12, SaveR12
    movq    R13, SaveR13
    movq    R14, SaveR14
  %endif

  %ifdef USE_WIN64
    movq    R13, SaveR13
    movq    R12, SaveR12
    movq    RDI, SaveRDI
    movq    RSI, SaveRSI
    movq    RBX, SaveRBX
  %endif

    ret

