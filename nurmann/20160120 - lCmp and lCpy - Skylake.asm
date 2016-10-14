; =============================================================================
; LongArith Assembler Unit for Architecture Skylake (Intel Core iX 6xxx
;
; (c) Jens Nurmann - 2015-
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
;
; A general note on the use of LAHF / SAHF. Several routines use this scheme
; to propagate a carry through a loop. Whereever I left this in place I
;
; - either benched it successfully against other schemes like SBB reg, reg / 
;   add reg, reg
; - or haven't come around to check if it could be replaced by the new non
;   flag-affecting mnemonics like ADCX / ADOX / SHRX / MULX etc.
;
; ----------------------------------------------------------------------------
; History:
;
; Date       Author Version Action
; ---------- ------ ------- --------------------------------------------------
; 04.01.2016 jn             optimized AVX version of lCmp
; 05.01.2016 jn             optimized AVX version of lCpyInc
; 06.01.2016 jn             optimized AVX version of lCpyDec
; 20.01.2016 jn             excerpt for MPIR
; ============================================================================

%define     USE_LINUX64
;%define     USE_WIN64
%define     USE_AVX

global      lCmp:function

global      lCpyInc:function
global      lCpyDec:function

segment     .text

; ============================================================================
; lCmp( Op1: pLimb; const Size1: tCounter; Op2: pLimb; const Size2: tCounter ):INT64;
; Linux RDI               RSI              RDX               RCX              :RAX
; Win7  RCX               RDX              R8                R9               :RAX
;
; Description:
; The function compares two limb arrays, interpreted as unsigned integers, for
; smaller, equal, greater and returns -1/0/1 accordingly. The use of this in
; the average case is questionable due to the overhead associated with use of
; AVX combined with the fact that the majority of comparisons will bail out
; in the first two limbs of numbers anyway.
;
; TODO:
; - check further improvement by auto aligning reads for one operand
; - check if alignment before second loop can be lifted w/o degradation
;
; Comments:
; - Skylake asm version implemented, tested & benched on 20.09.2015 by jn
; - AVX version implemented, tested & benched on 04.01.2016 by jn
; - AVX version roughly 1.5 to 3 times faster than non-AVX, depending on cache
;   level and data alignment

%ifdef USE_WIN64

  %define   Op1     RCX
  %define   Size1   RDX
  %define   Op2     R8
  %define   Size2   R9
  %define   Greater R10
  %define   Less    R11

%endif

%ifdef USE_LINUX64

  %define   Op1     RDI
  %define   Size1   RSI
  %define   Op2     RDX
  %define   Size2   RCX
  %define   Greater R10
  %define   Less    R11

%endif

    align   32
lCmp:

    mov     Greater, 1
    mov     Less, -1
    cmp     Size1, Size2
    jne     .lCmpSet            ; fast out as sizes don't match =>

    lea     Op1, [Op1+8*Size1]
    lea     Op2, [Op2+8*Size1]

    mov     Size2, 16
    mov     EAX, 128
    sub     Size1, Size2
    jc      .lCmpSlow           ; too small, don't use AVX semantic =>

    ; pre-load first 16 limb from top of Op1, Op2 before entering main loop
    vmovdqu YMM0, [Op1-32]
    vmovdqu YMM1, [Op1-64]
    vmovdqu YMM2, [Op1-96]
    vmovdqu YMM3, [Op1-128]

    vmovdqu YMM4, [Op2-32]
    vmovdqu YMM5, [Op2-64]
    vmovdqu YMM6, [Op2-96]
    vmovdqu YMM7, [Op2-128]

    jmp     .lCmpLoop1Check

    ; main loop: 0.4 cycles per limb in L1$
    ;            0.5 to 0.75 cycles per limb in L2$ (data alignment)
    ;            0.6 to 0.9 cycles per limb in L3$ (data alignment)
    align   32
  .lCmpLoop1:

    sub     Op1, RAX
    sub     Op2, RAX

    vptest  YMM0, YMM4
    jnc     .lCmpSlow2
    vmovdqu YMM0, [Op1-32]
    vmovdqu YMM4, [Op2-32]
    vptest  YMM1, YMM5
    jnc     .lCmpSlow2
    vmovdqu YMM1, [Op1-64]
    vmovdqu YMM5, [Op2-64]
    vptest  YMM2, YMM6
    jnc     .lCmpSlow2
    vmovdqu YMM2, [Op1-96]
    vmovdqu YMM6, [Op2-96]
    vptest  YMM3, YMM7
    jnc     .lCmpSlow2
    vmovdqu YMM3, [Op1-128]
    vmovdqu YMM7, [Op2-128]

  .lCmpLoop1Check:

    sub     Size1, Size2
    jnc     .lCmpLoop1

    sub     Op1, RAX
    sub     Op2, RAX

    ; check remaining 16 limb in YMM regs
    vptest  YMM0, YMM4
    jnc     .lCmpSlow2
    vptest  YMM1, YMM5
    jnc     .lCmpSlow2
    vptest  YMM2, YMM6
    jnc     .lCmpSlow2
    vptest  YMM3, YMM7
    jnc     .lCmpSlow2

    ; at this point Op1, Op2 point to the top of the block that remains to be
    ; checked for inequality. Size1 equals the size of the block in multiple of
    ; limb [-16..-1]
  .lCmpSlow:

    mov     RAX, Size1
    add     RAX, Size2
    cmove   RAX, Size2
    mov     Size2, RAX
    shl     RAX, 3
    sub     Op1, RAX
    sub     Op2, RAX
    xor     EAX, EAX            ; assume operands are equal
    add     Size1, 16
    je      .Exit               ; AVX comparison checked operands fully =>

    ; at this point Op1, Op2 point to the bottom of the block that remains to
    ; be checked for inequality. Size2 equals the size of the block in multiple
    ; of limb [1..16]
  .lCmpSlow2:

    xor    EAX, EAX
    sub    Op1, 8
    sub    Op2, 8

    align   16
  .lCmpLoop2:

    mov     Size1, [Op1+8*Size2]
    cmp     Size1, [Op2+8*Size2]
    jne     .lCmpSet
    dec     Size2
    jne     .lCmpLoop2

  .lCmpSet:

    cmova   RAX, Greater
    cmovb   RAX, Less

  .Exit:

    ret

; =============================================================================
; lCpyInc( Op1: pLimb; const Size1: tCounter; Op2: pLimb ):tCounter;
; Linux    RDI               RSI              RDX         :RAX
; Win7     RCX               RDX              R8          :RAX
;
; Description:
; The function copies a limb array from Op1 to Op2 from bottom to top returning
; the number of limb copied. In the AVX variant there is an initial alignment
; of Op2 to a multiple of 64 byte (cache line size) by individual limb copies.
; Depending on the then given alignment of Op1 unaligned or aligned reads are
; used in combination with aligned writes. The main loop copies 16 limb (128
; byte, 2 cache lines) in one iteration so a post processing of max. 15 limb
; finishes the function.
;
; TODO:
; - detect break-even and design "optimal" variant that switches over
; - optimize pro- & epilogue
;
; Comments:
; - AVX-based version implemented, tested & benched on 05.01.2016 by jn
; - did some experiments with AVX based version with following results
;   - AVX can be faster in L1$ (30%), L2$ (10%) if dest. is aligned on 64 byte
;   - AVX is much faster on small sized operands (<=100 limb) due too start-up
;     overhead of "rep movsq" - however this could also be achieved by
;     simple copy loop
;   - the break-even between AVX and "rep movsq" is around 10,000 limb

%ifdef USE_WIN64

  %define   Op1     RCX
  %define   Size1   RDX
  %define   Op2     R8
  %define   Limb    R9

%endif

%ifdef USE_LINUX64

  %define   Op1     RDI
  %define   Size1   RSI
  %define   Op2     RDX
  %define   Limb    RCX

%endif

    align   32
lCpyInc:

%ifdef USE_AVX

    mov     RAX, Size1
    or      RAX, RAX
    je      .Exit

    ; align destination to 64 byte cache line
    test    Op2, 8
    jz      .lCpyInc32

    mov     Limb, [Op1]
    mov     [Op2], Limb
    dec     Size1
    je      .Exit

    add     Op1, 8
    add     Op2, 8

  .lCpyInc32:

    test    Op2, 16
    jz      .lCpyInc64

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

  .lCpyInc64:

    test    Op2, 32
    je      .lCpyInc16

    mov     Limb, [Op1]
    mov     [Op2], Limb
    dec     Size1
    je      .Exit

    mov     Limb, [Op1+8]
    mov     [Op2+8], Limb
    dec     Size1
    je      .Exit

    mov     Limb, [Op1+16]
    mov     [Op2+16], Limb
    dec     Size1
    je      .Exit

    mov     Limb, [Op1+24]
    mov     [Op2+24], Limb
    dec     Size1
    je      .Exit

    add     Op1, 32
    add     Op2, 32

    ; destination is aligned
  .lCpyInc16:

    sub     Size1, 16
    jc      .lCpyInc8           ; remaining part to small for AVX =>

    test    Op1, 31
    je      .lCpyIncA           ; source was aligned too =>

    vmovdqu YMM0, [Op1]
    vmovdqu YMM1, [Op1+32]
    vmovdqu YMM2, [Op1+64]
    vmovdqu YMM3, [Op1+96]

    sub     Size1, 16
    jc      .lCpyIncPost        ; only one round AVX possible =>

    ; main loop: 0.3 cycles per limb in L1$
    ;            0.5 to 0.75 cycles per limb in L2$ (data alignment)
    ;            0.8 to 1.2 cycles per limb in L3$ (data alignment)
    align   16
  .lCpyIncULoop:

    add     Op1, 128

    vmovdqa [Op2], YMM0
    vmovdqa [Op2+32], YMM1
    vmovdqu YMM0, [Op1]
    vmovdqu YMM1, [Op1+32]
    vmovdqa [Op2+64], YMM2
    vmovdqa [Op2+96], YMM3
    vmovdqu YMM2, [Op1+64]
    vmovdqu YMM3, [Op1+96]

    add     Op2, 128

    sub     Size1, 16
    jnc     .lCpyIncULoop

    jmp     .lCpyIncPost

    align   16
  .lCpyIncA:

    vmovdqa YMM0, [Op1]
    vmovdqa YMM1, [Op1+32]
    vmovdqa YMM2, [Op1+64]
    vmovdqa YMM3, [Op1+96]

    sub     Size1, 16
    jc      .lCpyIncPost        ; only one round AVX possible =>

    ; main loop: 0.3 cycles per limb in L1$
    ;            0.5 to 0.75 cycles per limb in L2$ (data alignment)
    ;            0.8 to 1.2 cycles per limb in L3$ (data alignment)
    align   16
  .lCpyIncALoop:

    add     Op1, 128

    vmovdqa [Op2], YMM0
    vmovdqa [Op2+32], YMM1
    vmovdqa YMM0, [Op1]
    vmovdqa YMM1, [Op1+32]
    vmovdqa [Op2+64], YMM2
    vmovdqa [Op2+96], YMM3
    vmovdqa YMM2, [Op1+64]
    vmovdqa YMM3, [Op1+96]

    add     Op2, 128

    sub     Size1, 16
    jnc     .lCpyIncALoop

  .lCpyIncPost:

    vmovdqa [Op2], YMM0
    vmovdqa [Op2+32], YMM1
    vmovdqa [Op2+64], YMM2
    vmovdqa [Op2+96], YMM3

    add     Op1, 128
    add     Op2, 128

    ; handle remaining max. 15 limb
  .lCpyInc8:

    add     Size1, 16

    test    Size1, 8
    je      .lCpyInc4

    vmovdqu YMM0, [Op1]
    vmovdqu YMM1, [Op1+32]
    vmovdqa [Op2], YMM0
    vmovdqa [Op2+32], YMM1

    add     Op1, 64
    add     Op2, 64

  .lCpyInc4:

    test    Size1, 4
    je      .lCpyInc2

    vmovdqu YMM0, [Op1]
    vmovdqa [Op2], YMM0

    add     Op1, 32
    add     Op2, 32

  .lCpyInc2:

    test    Size1, 2
    je      .lCpyInc1

    movdqu  XMM0, [Op1]
    movdqa  [Op2], XMM0

    add     Op1, 16
    add     Op2, 16

  .lCpyInc1:

    test    Size1, 1
    je      .Exit

    mov     Limb, [Op1]
    mov     [Op2], Limb

  .Exit:

    ret

%else                           ; rep movsq variant - faster above 10,000 limb

  %ifdef USE_WIN64
    sub     RSP, 16
    mov     [RSP+8], RSI
    mov     [RSP], RDI
  %endif

    mov     RAX, Size1
    mov     RSI, Op1
    mov     RDI, Op2
    mov     RCX, RAX
    cmp     RSI, RDI
    je      .Exit

    repe    movsq

  .Exit:

  %ifdef USE_WIN64
    mov     RDI, [RSP]
    mov     RSI, [RSP+8]
    add     RSP, 16
  %endif

    ret

%endif

; ============================================================================
; lCpyDec( Op1: pLimb; const Size1: tCounter; Op2: pLimb ):tCounter
; Linux    RDI               RSI              RDX         :RAX
; Win7     RCX               RDX              R8          :RAX
;
; Description:
; The function copies a limb array from Op1 to Op2 from top to bottom returning
; the number of limb copied. In the AVX variant there is an inital alignment of
; Op2 to a multiple of 64 byte (cache line size) by individual limb copies.
; Depending on the then given alignment of Op1 unaligned or aligned reads are
; used in combination with aligned writes. The main loop copies 16 limb (128
; byte, 2 cache lines) in one iteration so a post processing of max. 15 limb
; finishes the function.
;
; TODO:
; - optimize pro- & epilogue
;
; Comments:
; - rep movsq implemented and tested on 08.08.2014 by jn
; - changed, tested and benchmarked on 17.09.2014 by jn
; - AVX-based version implemented, tested & benched on 05.01.2016 by jn
; - did some experiments with AVX based version with following results
;   - AVX generally faster then "rep movsq" with negative string direction!
;   - the prologue & epilogue can still be optimized!
; - startup overhead of "rep movsq" with negative direction is 200 cycles!!!
; - negative direction "rep movsq" is slower then positive "rep movsq" - looks
;   like the microcode implementation on Skylake is crap!

%ifdef USE_WIN64

  %define   Op1     RCX
  %define   Size1   RDX
  %define   Op2     R8
  %define   Limb    R9

%endif

%ifdef USE_LINUX64

  %define   Op1     RDI
  %define   Size1   RSI
  %define   Op2     RDX
  %define   Limb    RCX

%endif

    align   32
lCpyDec:

    mov     RAX, Size1
    or      RAX, RAX
    je      .Exit

    lea     Op1, [Op1+8*Size1-8]
    lea     Op2, [Op2+8*Size1-8]

    ; align destination to 64 byte cache line
    test    Op2, 8
    jne     .lCpyDec32

    mov     Limb, [Op1]
    mov     [Op2], Limb
    dec     Size1
    je      .Exit

    sub     Op1, 8
    sub     Op2, 8

  .lCpyDec32:

    test    Op2, 16
    jnz     .lCpyDec64

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

  .lCpyDec64:

    test    Op2, 32
    jne     .lCpyDec16

    mov     Limb, [Op1]
    mov     [Op2], Limb
    dec     Size1
    je      .Exit

    mov     Limb, [Op1-8]
    mov     [Op2-8], Limb
    dec     Size1
    je      .Exit

    mov     Limb, [Op1-16]
    mov     [Op2-16], Limb
    dec     Size1
    je      .Exit

    mov     Limb, [Op1-24]
    mov     [Op2-24], Limb
    dec     Size1
    je      .Exit

    sub     Op1, 32
    sub     Op2, 32

    ; destination is aligned
  .lCpyDec16:

    sub     Size1, 16
    jc      .lCpyDec8           ; remaining part to small for AVX =>

    mov     Limb, Op1
    and     Limb, 31
    cmp     Limb, 24
    je      .lCpyDecA           ; source was aligned too =>

    vmovdqu YMM0, [Op1-24]
    vmovdqu YMM1, [Op1-56]
    vmovdqu YMM2, [Op1-88]
    vmovdqu YMM3, [Op1-120]

    sub     Size1, 16
    jc      .lCpyDecPost        ; only one round of AVX possible =>

    ; main loop: 0.3 cycles per limb in L1$
    ;            0.5 to 0.75 cycles per limb in L2$ (data alignment)
    ;            0.8 to 1.2 cycles per limb in L3$ (data alignment)
    align   16
  .lCpyDecULoop:

    sub     Op1, 128

    vmovdqa [Op2-24], YMM0
    vmovdqa [Op2-56], YMM1
    vmovdqu YMM0, [Op1-24]
    vmovdqu YMM1, [Op1-56]
    vmovdqa [Op2-88], YMM2
    vmovdqa [Op2-120], YMM3
    vmovdqu YMM2, [Op1-88]
    vmovdqu YMM3, [Op1-120]

    sub     Op2, 128

    sub     Size1, 16
    jnc     .lCpyDecULoop

    jmp     .lCpyDecPost

    align   16
  .lCpyDecA:

    vmovdqa YMM0, [Op1-24]
    vmovdqa YMM1, [Op1-56]
    vmovdqa YMM2, [Op1-88]
    vmovdqa YMM3, [Op1-120]

    sub     Size1, 16
    jc      .lCpyDecPost        ; only one round of AVX possible =>

    ; main loop: 0.3 cycles per limb in L1$
    ;            0.5 to 0.75 cycles per limb in L2$ (data alignment)
    ;            0.8 to 1.2 cycles per limb in L3$ (data alignment)
    align   16
  .lCpyDecALoop:

    sub     Op1, 128

    vmovdqa [Op2-24], YMM0
    vmovdqa [Op2-56], YMM1
    vmovdqa YMM0, [Op1-24]
    vmovdqa YMM1, [Op1-56]
    vmovdqa [Op2-88], YMM2
    vmovdqa [Op2-120], YMM3
    vmovdqa YMM2, [Op1-88]
    vmovdqa YMM3, [Op1-120]

    sub     Op2, 128

    sub     Size1, 16
    jnc     .lCpyDecALoop

  .lCpyDecPost:

    vmovdqa [Op2-24], YMM0
    vmovdqa [Op2-56], YMM1
    vmovdqa [Op2-88], YMM2
    vmovdqa [Op2-120], YMM3

    ; handle remaining max. 15 limb
  .lCpyDec8:

    add     Size1, 16

    test    Size1, 8
    je      .lCpyDec4

    vmovdqu YMM0, [Op1-24]
    vmovdqu YMM1, [Op1-56]
    vmovdqa [Op2-24], YMM0
    vmovdqa [Op2-56], YMM1

    sub     Op1, 64
    sub     Op2, 64

  .lCpyDec4:

    test    Size1, 4
    je      .lCpyDec2

    vmovdqu YMM0, [Op1-24]
    vmovdqa [Op2-24], YMM0

    sub     Op1, 32
    sub     Op2, 32

  .lCpyDec2:

    test    Size1, 2
    je      .lCpyDec1

    movdqu  XMM0, [Op1-8]
    movdqa  [Op2-8], XMM0

    sub     Op1, 16
    sub     Op2, 16

  .lCpyDec1:

    test    Size1, 1
    je      .Exit

    mov     Limb, [Op1]
    mov     [Op2], Limb

  .Exit:

    ret
