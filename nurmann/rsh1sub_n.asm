include(`../config.m4')
define(`USE_LINUX64',1)
#define(`USE_PREFETCH',1)


# ============================================================================
# lShr1SubEqu( Op1, Op2: pLimb; const NumLimbs: tCounter; Op3: pLimb ):tBaseVal
# Linux        %rdi  %rsi               %rdx             %rcx         :%rax
# Win7         %rcx  %rdx               %r8              %r9          :%rax
#
# Description:
# The function subtracts Op2 from Op1, shifts this right one bit, stores the
# result in Op3 and hands back the total carry. Though in theory the carry is
# absorbed by the shift right it is still signalled to the upper layer to
# indicate an overflow has happened. There is a gain in execution speed
# compared to separate shift and subtraction by interleaving the elementary
# operations and reducing memory access. The factor depends on the size of the
# operands (the cache level in which the operands can be handled) and the core
# used.
#
#  Op3 := (Op1 - Op2)>>1
#
# Caveats:
#
#
#
# Comments:
# - Skylake asm version implemented, tested & benched on $17.10.2015 by jn
# - on an i7 $6700K per limb saving is $1 cycle in L1$, L2$ and L3$
# - includes LAHF / SAHF
# - includes prefetching


ifdef(`USE_LINUX64',`

  define(`Op1',   %rsi)
  define(`Op2',   %rdx)
  define(`NumLimbs',  %rcx)
  define(`Op3',   %rdi)
  ifdef(`USE_PREFETCH',`
    define(`Offs',  %rbp)        # SAVE!
  ')

  define(`Limb0', %rbx)         # SAVE!
  define(`Limb1', %r8)
  define(`Limb2', %r9)
  define(`Limb3', %r10)
  define(`Limb4', %r11)
  define(`Limb5', %r12)         # SAVE!
  define(`Limb6', %r13)         # SAVE!
  define(`Limb7', %r14)         # SAVE!
  define(`Limb8', %r15)         # SAVE!
')

ifdef(`USE_WIN64',`

  define(`Op1',   %rcx)
  define(`Op2',   %rdx)
  define(`NumLimbs',  %r8)
  define(`Op3',   %r9)
  ifdef(`USE_PREFETCH',`
    define(`Offs',  %rbp)         # SAVE!
  ')

  define(`Limb0', %rbx)         # SAVE!
  define(`Limb1', %rdi)         # SAVE!
  define(`Limb2', %rsi)         # SAVE!
  define(`Limb3', %r10)
  define(`Limb4', %r11)
  define(`Limb5', %r12)         # SAVE!
  define(`Limb6', %r13)         # SAVE!
  define(`Limb7', %r14)         # SAVE!
  define(`Limb8', %r15)         # SAVE!

')

ASM_START()
	TEXT
	ALIGN(32)
PROLOGUE(mpn_rsh1sub_n)

lShr1SubEqu:

  ifdef(`USE_WIN64',`
    ifdef(`USE_PREFETCH',`
      sub   $64, %rsp
      mov   Offs, 56(%rsp)
    ',`
      sub   $56, %rsp
    ')
      mov   Limb8, 48(%rsp)
      mov   Limb7, 40(%rsp)
      mov   Limb6, 32(%rsp)
      mov   Limb5, 24(%rsp)
      mov   Limb2, 16(%rsp)
      mov   Limb1, 8(%rsp)
      mov   Limb0, (%rsp)
  ')

  ifdef(`USE_LINUX64',`
    ifdef(`USE_PREFETCH',`
      sub   $48, %rsp
      mov   Offs, 40(%rsp)
    ',`
      sub   $40, %rsp
    ')
      mov   Limb8, 32(%rsp)
      mov   Limb7, 24(%rsp)
      mov   Limb6, 16(%rsp)
      mov   Limb5, 8(%rsp)
      mov   Limb0, (%rsp)
  ')

  ifdef(`USE_PREFETCH',`
    prefetchnta (Op1)
    prefetchnta (Op2)
    mov     $512, %ebp            # Attn: check if redefining Offs
  ')
    xor     %rax, %rax

    # prepare shift & subtraction with loop-unrolling $8
    mov     (Op1), Limb0
    sub     (Op2), Limb0
    lahf                        # memorize carry

    bt      $0, Limb0
    adc     $0, %rax            # move low bit into rax

    add     $8, Op1
    add     $8, Op2
    sub     $1, NumLimbs
    jc      0f #Exit

    test    $1, NumLimbs             # a good %r8 / R16 / R32 macro would help!
    jz      .lShr1SubEquTwo

    sahf
    mov     (Op1), Limb1
    sbb     (Op2), Limb1
    lahf

    shrd    $1, Limb1, Limb0
    mov     Limb0, (Op3)

    add     $8, Op1
    add     $8, Op2
    add     $8, Op3
    mov     Limb1, Limb0

  .lShr1SubEquTwo:

    test    $2, NumLimbs             # a good %r8 / R16 / R32 macro would help!
    jz      .lShr1SubEquFour

    sahf
    mov     (Op1), Limb1
    mov     8(Op1), Limb2
    sbb     (Op2), Limb1
    sbb     8(Op2), Limb2
    lahf

    shrd    $1, Limb1, Limb0
    shrd    $1, Limb2, Limb1
    mov     Limb0, (Op3)
    mov     Limb1, 8(Op3)

    add     $16, Op1
    add     $16, Op2
    add     $16, Op3
    mov     Limb2, Limb0

  .lShr1SubEquFour:

    test    $4, NumLimbs             # a good %r8 / R16 / R32 macro would help!
    jz      .lShr1SubEquCheck   # enter main-loop =>

    sahf
    mov     (Op1), Limb1
    mov     8(Op1), Limb2
    mov     16(Op1), Limb3
    mov     24(Op1), Limb4
    sbb     (Op2), Limb1
    sbb     8(Op2), Limb2
    sbb     16(Op2), Limb3
    sbb     24(Op2), Limb4
    lahf

    shrd    $1, Limb1, Limb0
    shrd    $1, Limb2, Limb1
    shrd    $1, Limb3, Limb2
    shrd    $1, Limb4, Limb3
    mov     Limb0, (Op3)
    mov     Limb1, 8(Op3)
    mov     Limb2, 16(Op3)
    mov     Limb3, 24(Op3)

    add     $32, Op1
    add     $32, Op2
    add     $32, Op3
    mov     Limb4, Limb0
    jmp     .lShr1SubEquCheck   # enter main-loop =>

    # main loop: <1.3 cycles per limb in L1$
    # combining elements in multiples of four prooved fastest on Skylake
    .align   32
  .lShr1SubEquLoop:

  ifdef(`USE_PREFETCH',`
    prefetchnta (Op1,Offs,)
    prefetchnta (Op2,Offs,)
  ')

    sahf                        # restore carry ...
    mov     (Op1), Limb1        # generate subtracted oct-limb from Op1 and Op2
    mov     8(Op1), Limb2
    mov     16(Op1), Limb3
    mov     24(Op1), Limb4
    sbb     (Op2), Limb1
    sbb     8(Op2), Limb2
    sbb     16(Op2), Limb3
    sbb     24(Op2), Limb4
    mov     32(Op1), Limb5
    mov     40(Op1), Limb6
    mov     48(Op1), Limb7
    mov     56(Op1), Limb8
    sbb     32(Op2), Limb5
    sbb     40(Op2), Limb6
    sbb     48(Op2), Limb7
    sbb     56(Op2), Limb8
    lahf                        # ... and memorize carry again

    shrd    $1, Limb1, Limb0     # shift oct-limbs and store in Op3
    shrd    $1, Limb2, Limb1
    shrd    $1, Limb3, Limb2
    shrd    $1, Limb4, Limb3
    mov     Limb0, (Op3)
    mov     Limb1, 8(Op3)
    mov     Limb2, 16(Op3)
    mov     Limb3, 24(Op3)
    shrd    $1, Limb5, Limb4
    shrd    $1, Limb6, Limb5
    shrd    $1, Limb7, Limb6
    shrd    $1, Limb8, Limb7
    mov     Limb4, 32(Op3)
    mov     Limb5, 40(Op3)
    mov     Limb6, 48(Op3)
    mov     Limb7, 56(Op3)

    add     $64, Op1
    add     $64, Op2
    add     $64, Op3
    mov     Limb8, Limb0

  .lShr1SubEquCheck:

    sub     $8, NumLimbs
    jnc     .lShr1SubEquLoop

    # housekeeping - set MSL and return the total carry
    sahf
    rcr     $1, Limb0
    mov     Limb0, (Op3)

    #xor     Limb0, Limb0
    #sahf
    #adc     Limb0, Limb0
    #mov     Limb0, %rax

    xor     %ah, %ah

  0:#Exit:

  ifdef(`USE_LINUX64',`
      mov   (%rsp), Limb0
      mov   8(%rsp), Limb5
      mov   16(%rsp), Limb6
      mov   24(%rsp), Limb7
      mov   32(%rsp), Limb8
    ifdef(`USE_PREFETCH',`
      mov   40(%rsp), Offs
      add   $48, %rsp
    ',`
      add   $40, %rsp
    ')
  ')

  ifdef(`USE_WIN64',`
      mov   (%rsp), Limb0
      mov   8(%rsp), Limb1
      mov   16(%rsp), Limb2
      mov   24(%rsp), Limb5
      mov   32(%rsp), Limb6
      mov   40(%rsp), Limb7
      mov   48(%rsp), Limb8
    ifdef(`USE_PREFETCH',`
      mov   56(%rsp), Offs
      sub   $64, %rsp
    ',`
      sub   %rsp, $56
    ')
  ')

    ret
EPILOGUE()
