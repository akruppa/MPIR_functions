; =============================================================================
; Elementary Arithmetic Assembler Routines
; for Intel Architectures Westmere, Nehalem, Sandy Bridge and Ivy Bridge
;
; (c) Jens Nurmann - 2014-2016
;
; A general note on the use of cache prefetching. Several routines contain
; cache prefetching - typically those where I have unrolled loops by 8 as the
; data size then is 64 bytes <=> one cache line. The prefetching degrades the
; performance on small (<1,000 limb) sized operands a bit (<2%) but it
; increases performance on large (>1,000 limb) sized operands substantially
; (>10%). The prefetch stride is set to 256 on Nehalem generally.
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
;
; A general note on the use of LAHF / SAHF. Several routines use this scheme
; to propagate a carry through a loop. Whereever I left this in place I
; benched it successfully against schemes like SBB reg, reg / ADD reg, reg
; ----------------------------------------------------------------------------
; History:
;
; Date       Author Version Action
; ---------- ------ ------- --------------------------------------------------
; 26.03.2016 jn     0.00.01 generated excerpt for MPIR containing
;                           - sumdiff_n
;                           - addlsh1_n
;                           - sublsh1_n
;                           - rsh1add_n
;                           - rsh1sub_n
;
; Comment:
; Considering the following (optimal?) Toom-33 pseude-code from Marco Bodrato
; I would have expected requirement for lsh1add_n / rsh1sub_n / sublsh1_n (and
; potentially rsh1add_n if emulating sign operations). lsh1add_n seems to be
; missing from your choice!?
;
;   // W0 = U0 + U2; W4 = V0 + V2
;   // W3 = W0 - U1; W2 = W4 - V1
;   // W0 = W0 + U1; W4 = W4 + V1
;   // W1 = W2 * W3; W2 = W0 * W4
;   // W0 =(W0 + U2)<<1 - U0; W4 =(W4 + V2)<<1 - V0
;   // W3 = W0 * W4; W0 = U0 * V0; W4 = U2 * V2
;   // W3 =(W3 - W1)/3; W1 =(W2 - W1)>>1
;   // W2 = W2 - W0
;   // W3 =(W3 - W2)>>1 - W4<<1
;   // W2 = W2 - W1
;   // W3 = W4*x + W3*y
;   // W1 = W2*x + W1*y
;   // W1 = W1 - W3
;   // W  = W3*x^3+ W1*x*y^2 + W0*y^4
; ============================================================================

%define USE_LINUX64
;%define USE_WIN64
;%define USE_PREFETCH
;%define PREFETCH_STRIDE 256

global  rsh1add_n:function
global  rsh1sub_n:function

; ============================================================================
; rsh1add_n( Op1, Op2: pLimb; Size: tCounter; Op3: pLimb ):tBaseVal
; Linux      RDI  RSI         RDX             RCX         :RAX
; Win7       RCX  RDX         R8              R9          :RAX
;
; Description:
; The function adds Op1 to Op2, shifts this right one bit, stores the result
; in Op3 and hands back the total carry. There is a gain in execution speed
; compared to separate shift and addition by interleaving the elementary
; operations and reducing memory access. The factor depends on the size of the
; operands (the cache hierarchy in which the operands can be handled).
;
; Caveats:
; - for asm the processor MUST support LAHF/SAHF in 64 bit mode!
;
; Comments:
; - asm version implemented, tested & benched on 16.05.2015 by jn
; - On Nehalem per limb saving is 0.7 cycles in LD1$, LD2$ and 1-2 in LD3$
; - includes LAHF / SAHF
; - includes prefetching
; - includes XMM safe & restore
; ============================================================================

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
rsh1add_n:

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
    mov     EBP, PREFETCH_STRIDE    ; Attn: check if redefining Offs
  %endif

    ; prepare shift & addition with loop-unrolling 8
    mov     Limb0, [Op1]        ; pre-load first shift value
    add     Limb0, [Op2]
    lahf                        ; memorize carry

    add     Op1, 8
    add     Op2, 8
    sub     Size, 1

    test    Size, 1
    je      .rsh1add_n_two

    mov     Limb1, [Op1]
    mov     RAX, [Op2]
    adc     Limb1, RAX
    lahf

    shrd    Limb0, Limb1, 1
    mov     [Op3], Limb0

    add     Op1, 8
    add     Op2, 8
    add     Op3, 8
    mov     Limb0, Limb1

  .rsh1add_n_two:

    test    Size, 2
    je      .rsh1add_n_four

    sahf
    mov     Limb1, [Op1]
    mov     RAX, [Op2]
    adc     Limb1, RAX
    mov     Limb2, [Op1+8]
    mov     RAX, [Op2+8]
    adc     Limb2, RAX
    lahf

    shrd    Limb0, Limb1, 1
    mov     [Op3], Limb0
    shrd    Limb1, Limb2, 1
    mov     [Op3+8], Limb1

    add     Op1, 16
    add     Op2, 16
    add     Op3, 16
    mov     Limb0, Limb2

  .rsh1add_n_four:

    test    Size, 4
    je      .rsh1add_n_test

    sahf
    mov     Limb1, [Op1]
    mov     RAX, [Op2]
    adc     Limb1, RAX
    mov     Limb2, [Op1+8]
    mov     RAX, [Op2+8]
    adc     Limb2, RAX
    mov     Limb3, [Op1+16]
    mov     RAX, [Op2+16]
    adc     Limb3, RAX
    mov     Limb4, [Op1+24]
    mov     RAX, [Op2+24]
    adc     Limb4, RAX
    lahf

    shrd    Limb0, Limb1, 1
    mov     [Op3], Limb0
    shrd    Limb1, Limb2, 1
    mov     [Op3+8], Limb1
    shrd    Limb2, Limb3, 1
    mov     [Op3+16], Limb2
    shrd    Limb3, Limb4, 1
    mov     [Op3+24], Limb3

    add     Op1, 32
    add     Op2, 32
    add     Op3, 32
    mov     Limb0, Limb4
    jmp     .rsh1add_n_test

    ; main loop (prefetch enabled; unloaded cache)
    ; - 2.40-2.50 cycles per limb in L1D$
    ; - 2.6       cycles per limb in L2D$
    ; - 2.80-3.30 cycles per limb in L3D$
    align   16
  .rsh1add_n_loop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
    prefetchnta [Op2+Offs]
  %endif

    sahf                        ; restore carry ...
    mov     Limb1, [Op1]        ; prepare added oct-limb from Op1, Op2
    mov     RAX, [Op2]
    adc     Limb1, RAX
    mov     Limb2, [Op1+8]
    mov     RAX, [Op2+8]
    adc     Limb2, RAX
    mov     Limb3, [Op1+16]
    mov     RAX, [Op2+16]
    adc     Limb3, RAX
    mov     Limb4, [Op1+24]
    mov     RAX, [Op2+24]
    adc     Limb4, RAX
    mov     Limb5, [Op1+32]
    mov     RAX, [Op2+32]
    adc     Limb5, RAX
    mov     Limb6, [Op1+40]
    mov     RAX, [Op2+40]
    adc     Limb6, RAX
    mov     Limb7, [Op1+48]
    mov     RAX, [Op2+48]
    adc     Limb7, RAX
    mov     Limb8, [Op1+56]
    mov     RAX, [Op2+56]
    adc     Limb8, RAX
    lahf                        ; ... and memorize carry again

    shrd    Limb0, Limb1, 1     ; shift oct-limbs and store in Op3
    mov     [Op3], Limb0
    shrd    Limb1, Limb2, 1
    mov     [Op3+8], Limb1
    shrd    Limb2, Limb3, 1
    mov     [Op3+16], Limb2
    shrd    Limb3, Limb4, 1
    mov     [Op3+24], Limb3
    shrd    Limb4, Limb5, 1
    mov     [Op3+32], Limb4
    shrd    Limb5, Limb6, 1
    mov     [Op3+40], Limb5
    shrd    Limb6, Limb7, 1
    mov     [Op3+48], Limb6
    shrd    Limb7, Limb8, 1
    mov     [Op3+56], Limb7

    add     Op1, 64             ; adjust pointers
    add     Op2, 64
    add     Op3, 64
    mov     Limb0, R15          ; set correct pre-load

  .rsh1add_n_test:

    sub     Size, 8
    jnc     .rsh1add_n_loop

    ; housekeeping - set MSL and return the total carry
    shr     Limb0, 1
    mov     [Op3], Limb0

    xor     Size, Size
    sahf
    adc     Size, Size
    mov     RAX, Size

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

; ============================================================================
; rsh1sub_n( Op1, Op2: pLimb; const Size: tCounter; Op3: pLimb ):tBaseVal
; Linux      RDI  RSI               RDX             RCX         :RAX
; Win7       RCX  RDX               R8              R9          :RAX
;
; Description:
; The function subtracts Op2 from Op1, shifts this right one bit, stores the
; result in Op3 and hands back the total carry. Though in theory the carry is
; absorbed by the shift right it is still signalled to the upper layer to
; indicate an overflow has happened. There is a gain in execution speed
; compared to separate shift and subtraction by interleaving the elementary
; operations and reducing memory access. The factor depends on the size of the
; operands (in effect the cache hierarchy in which the operands can be handled).
;
; Caveats:
; - for asm the processor MUST support LAHF/SAHF in 64 bit mode!
;
; Comments:
; - asm version implemented, tested & benched on 16.05.2015 by jn
; - On an i5 430M in asm per limb saving is 0.7 cycles in L1 and L2
; - includes LAHF / SAHF
; - includes prefetching
; ============================================================================

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
shr1sub_n:

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
    mov     EBP, PREFETCH_STRIDE    ; Attn: check if redefining Offs
  %endif

    ; prepare shift & subtraction with loop-unrolling 8
    mov     Limb0, [Op1]        ; pre-load first shift value
    sub     Limb0, [Op2]
    lahf                        ; memorize carry

    add     Op1, 8
    add     Op2, 8
    sub     Size, 1

    test    Size, 1
    je      .shr1sub_n_two

    sahf
    mov     Limb1, [Op1]
    mov     RAX, [Op2]
    sbb     Limb1, RAX
    lahf

    shrd    Limb0, Limb1, 1
    mov     [Op3], Limb0

    add     Op1, 8
    add     Op2, 8
    add     Op3, 8
    mov     Limb0, Limb1

  .shr1sub_n_two:

    test    Size, 2
    je      .shr1sub_n_four

    sahf
    mov     Limb1, [Op1]
    mov     RAX, [Op2]
    sbb     Limb1, RAX
    mov     Limb2, [Op1+8]
    mov     RAX, [Op2+8]
    sbb     Limb2, RAX
    lahf

    shrd    Limb0, Limb1, 1
    mov     [Op3], Limb0
    shrd    Limb1, Limb2, 1
    mov     [Op3+8], Limb1

    add     Op1, 16
    add     Op2, 16
    add     Op3, 16
    mov     Limb0, Limb2

  .shr1sub_n_four:

    test    Size, 4
    je      .shr1sub_n_test

    mov     Limb1, [Op1]
    mov     RAX, [Op2]
    sbb     Limb1, RAX
    mov     Limb2, [Op1+8]
    mov     RAX, [Op2+8]
    sbb     Limb2, RAX
    mov     Limb3, [Op1+16]
    mov     RAX, [Op2+16]
    sbb     Limb3, RAX
    mov     Limb4, [Op1+24]
    mov     RAX, [Op2+24]
    sbb     Limb4, RAX
    lahf

    shrd    Limb0, Limb1, 1
    mov     [Op3], Limb0
    shrd    Limb1, Limb2, 1
    mov     [Op3+8], Limb1
    shrd    Limb2, Limb3, 1
    mov     [Op3+16], Limb2
    shrd    Limb3, Limb4, 1
    mov     [Op3+24], Limb3

    add     Op1, 32
    add     Op2, 32
    add     Op3, 32
    mov     Limb0, Limb4
    jmp     .shr1sub_n_test

    ; main loop (prefetch enabled; unloaded cache)
    ; - 2.40-2.50 cycles per limb in L1D$
    ; - 2.6       cycles per limb in L2D$
    ; - 2.80-3.30 cycles per limb in L3D$
    align   16
  .shr1sub_n_loop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
    prefetchnta [Op2+Offs]
  %endif

    sahf                        ; restore carry ...
    mov     Limb1, [Op1]        ; prepare subtracted oct-limb from Op1, Op2
    mov     RAX, [Op2]
    sbb     Limb1, RAX
    mov     Limb2, [Op1+8]
    mov     RAX, [Op2+8]
    sbb     Limb2, RAX
    mov     Limb3, [Op1+16]
    mov     RAX, [Op2+16]
    sbb     Limb3, RAX
    mov     Limb4, [Op1+24]
    mov     RAX, [Op2+24]
    sbb     Limb4, RAX
    mov     Limb5, [Op1+32]
    mov     RAX, [Op2+32]
    sbb     Limb5, RAX
    mov     Limb6, [Op1+40]
    mov     RAX, [Op2+40]
    sbb     Limb6, RAX
    mov     Limb7, [Op1+48]
    mov     RAX, [Op2+48]
    sbb     Limb7, RAX
    mov     Limb8, [Op1+56]
    mov     RAX, [Op2+56]
    sbb     Limb8, RAX
    lahf                        ; ... and memorize carry again

    shrd    Limb0, Limb1, 1     ; shift oct-limb and store in Op3
    mov     [Op3], Limb0
    shrd    Limb1, Limb2, 1
    mov     [Op3+8], Limb1
    shrd    Limb2, Limb3, 1
    mov     [Op3+16], Limb2
    shrd    Limb3, Limb4, 1
    mov     [Op3+24], Limb3
    shrd    Limb4, Limb5, 1
    mov     [Op3+32], Limb4
    shrd    Limb5, Limb6, 1
    mov     [Op3+40], Limb5
    shrd    Limb6, Limb7, 1
    mov     [Op3+48], Limb6
    shrd    Limb7, Limb8, 1
    mov     [Op3+56], Limb7

    add     Op1, 64             ; adjust pointers
    add     Op2, 64
    add     Op3, 64
    mov     Limb0, Limb8        ; set correct pre-load

  .shr1sub_n_test:

    sub     Size, 8
    jnc     .shr1sub_n_loop

    ; housekeeping - set MSL and return the total carry
    shr     Limb0, 1
    mov     [Op3], Limb0

    xor     Size, Size
    sahf
    adc     Size, Size
    mov     RAX, Size

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
