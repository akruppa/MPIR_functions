; ============================================================================
; addlsh1_n( Op1, Op2: pLimb; Size: tCounter; Op3: pLimb ):tBaseVal
; Linux      RDI  RSI         RDX             RCX         :RAX
; Win7       RCX  RDX         R8              R9          :RAX
;
; Description:
; The function shifts Op1 left one bit, adds this to Op2, stores the result
; in Op3 and hands back the total carry. There is a gain in execution speed
; compared to separate shift and add by interleaving the elementary operations
; and reducing memory access. The factor depends on the size of the operands
; (the cache hierarchy in which the operands can be handled).
;
; Caveats:
; - for asm the processor MUST support LAHF/SAHF in 64 bit mode!
; - the total carry can range from 0-2!
;
; Comments:
; - asm version implemented, tested & benched on 16.05.2015 by jn
; - improved asm version implemented, tested & benched on 30.07.2015 by jn
; - On Nehalem per limb saving is 1 cycle in LD1$, LD2$ and 1-2 in LD3$
; - includes LAHF / SAHF
; - includes prefetching
; - includes XMM save & restore
; ============================================================================

BITS 64

global  addlsh1_n:function (addlsh1_n.end - addlsh1_n)

segment .text

%ifdef USE_WIN64

    %define Op1     RCX
    %define Op2     RDX
    %define Size    R8
    %define Op3     R9
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

    %define Limb0   RBX         ; SAVE!
    %define Limb1   RDI         ; SAVE!
    %define Limb2   RSI         ; SAVE!
    %define Limb3   R10
    %define Limb4   R11
    %define Limb5   R12         ; SAVE!
    %define Limb6   R13         ; SAVE!
    %define Limb7   R14         ; SAVE!
    %define Limb8   R15         ; SAVE!

    %define SaveRBX XMM0        ; use available scratch XMM to
    %define SaveRSI XMM1        ; save as many regs as possible
    %define SaveRDI XMM2
    %define SaveR12 XMM3
    %define SaveR13 XMM4
    %define SaveR14 XMM5

%endif

%ifdef USE_LINUX64

    %define Op1     RDI
    %define Op2     RSI
    %define Size    RDX
    %define Op3     RCX
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

    %define Limb0   RBX         ; SAVE!
    %define Limb1   R8
    %define Limb2   R9
    %define Limb3   R10
    %define Limb4   R11
    %define Limb5   R12         ; SAVE!
    %define Limb6   R13         ; SAVE!
    %define Limb7   R14         ; SAVE!
    %define Limb8   R15         ; SAVE!

    %define SaveRBX XMM0        ; use available scratch XMM to save all regs
    %define SaveR12 XMM1
    %define SaveR13 XMM2
    %define SaveR14 XMM3
    %define SaveR15 XMM4
  %ifdef USE_PREFETCH
    %define SaveRBP XMM5
  %endif

%endif

    align   32
addlsh1_n:

%ifdef USE_WIN64
  %ifdef USE_PREFETCH
    sub     RSP, 16
    mov     [RSP+8], R15
    mov     [RSP], RBP
  %else
    sub     RSP, 8
    mov     [RSP], R15
  %endif
    movq    SaveRBX, RBX
    movq    SaveRSI, RSI
    movq    SaveRDI, RDI
    movq    SaveR12, R12
    movq    SaveR13, R13
    movq    SaveR14, R14
%endif

%ifdef USE_LINUX64
  %ifdef USE_PREFETCH
    movq    SaveRBP, RBP
  %endif
    movq    SaveRBX, RBX
    movq    SaveR12, R12
    movq    SaveR13, R13
    movq    SaveR14, R14
    movq    SaveR15, R15
%endif

  %ifdef USE_PREFETCH
    mov     Offs, PREFETCH_STRIDE   ; Attn: check if redefining Offs
  %endif

    ; prepare shift & addition with loop-unrolling 8
    xor     Limb0, Limb0
    lahf                        ; memorize clear carry (from "xor" above)

    test    Size, 1
    je      .addlsh1_n_two

    mov     Limb1, [Op1]
    shrd    Limb0, Limb1, 63

    sahf
    mov     RAX, [Op2]
    adc     Limb0, RAX
    mov     [Op3], Limb0
    lahf

    add     Op1, 8
    add     Op2, 8
    add     Op3, 8
    mov     Limb0, Limb1

  .addlsh1_n_two:

    test    Size, 2
    je      .addlsh1_n_four

    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63

    sahf
    mov     RAX, [Op2]
    adc     Limb0, RAX
    mov     [Op3], Limb0
    mov     RAX, [Op2+8]
    adc     Limb1, RAX
    mov     [Op3+8], Limb1
    lahf

    add     Op1, 16
    add     Op2, 16
    add     Op3, 16
    mov     Limb0, Limb2

  .addlsh1_n_four:

    test    Size, 4
    je      .addlsh1_n_test

    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    shrd    Limb2, Limb3, 63
    shrd    Limb3, Limb4, 63

    sahf
    mov     RAX, [Op2]
    adc     Limb0, RAX
    mov     [Op3], Limb0
    mov     RAX, [Op2+8]
    adc     Limb1, RAX
    mov     [Op3+8], Limb1
    mov     RAX, [Op2+16]
    adc     Limb2, RAX
    mov     [Op3+16], Limb2
    mov     RAX, [Op2+24]
    adc     Limb3, RAX
    mov     [Op3+24], Limb3
    lahf

    add     Op1, 32
    add     Op2, 32
    add     Op3, 32
    mov     Limb0, Limb4
    jmp     .addlsh1_n_test

    ; main loop
    ; - 2.40-2.50 cycles per limb in L1D$
    ; - 2.6       cycles per limb in L2D$
    ; - 2.80-3.30 cycles per limb in L3D$
    align   16
  .addlsh1_n_loop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
    prefetchnta [Op2+Offs]
  %endif

    mov     Limb1, [Op1]        ; prepare shifted oct-limb from Op1
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63
    shrd    Limb2, Limb3, 63
    mov     Limb4, [Op1+24]
    mov     Limb5, [Op1+32]
    mov     Limb6, [Op1+40]
    shrd    Limb3, Limb4, 63
    shrd    Limb4, Limb5, 63
    shrd    Limb5, Limb6, 63
    mov     Limb7, [Op1+48]
    mov     Limb8, [Op1+56]
    shrd    Limb6, Limb7, 63
    shrd    Limb7, Limb8, 63

    sahf                        ; restore carry
    mov     RAX, [Op2]          ; add Op2 to oct-limb and store in Op3
    adc     Limb0, RAX          ; on Nehalem going via RAX prooved faster
    mov     [Op3], Limb0        ; than the shorter code 'adc Limb0, [Op2]'!
    mov     RAX, [Op2+8]
    adc     Limb1, RAX
    mov     [Op3+8], Limb1
    mov     RAX, [Op2+16]
    adc     Limb2, RAX
    mov     [Op3+16], Limb2
    mov     RAX, [Op2+24]
    adc     Limb3, RAX
    mov     [Op3+24], Limb3
    mov     RAX, [Op2+32]
    adc     Limb4, RAX
    mov     [Op3+32], Limb4
    mov     RAX, [Op2+40]
    adc     Limb5, RAX
    mov     [Op3+40], Limb5
    mov     RAX, [Op2+48]
    adc     Limb6, RAX
    mov     [Op3+48], Limb6
    mov     RAX, [Op2+56]
    adc     Limb7, RAX
    mov     [Op3+56], Limb7
    lahf                        ; remember carry for next round

    add     Op1, 64
    add     Op2, 64
    add     Op3, 64
    mov     Limb0, Limb8

  .addlsh1_n_test:

    sub     Size, 8
    jnc     .addlsh1_n_loop

    ; housekeeping - hand back total carry
    shr     Limb0, 63
    sahf
    adc     Limb0, 0            ; =0/1/2 depending on final carry and shift
    mov     RAX, Limb0

  .Exit:

%ifdef USE_LINUX64
    movq    R15, SaveR15
    movq    R14, SaveR14
    movq    R13, SaveR13
    movq    R12, SaveR12
    movq    RBX, SaveRBX
  %ifdef USE_PREFETCH
    movq    RBP, SaveRBP
  %endif
%endif

%ifdef USE_WIN64
    movq    SaveR14, R14
    movq    SaveR13, R13
    movq    SaveR12, R12
    movq    SaveRDI, RDI
    movq    SaveRSI, RSI
    movq    SaveRBX, RBX
  %ifdef USE_PREFETCH
    mov     [RSP], RBP
    mov     [RSP+8], R15
    add     RSP, 16
  %else
    mov     [RSP], R15
    add     RSP, 8
  %endif
%endif

    ret
.end:
