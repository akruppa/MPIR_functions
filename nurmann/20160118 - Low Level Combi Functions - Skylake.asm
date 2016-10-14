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
; 11.10.2015 jn     0.00.01 first setup - taking over all assembler parts from
; 18.01.2016 jn             excerpt of combi functions for MPIR team 
; ============================================================================

%define     USE_LINUX64
;%define     USE_WIN64
%define     USE_PREFETCH

global      lAddShr1Equ:function;
global      lAddShl1Equ:function;
global      lSubShr1nEqu:function;
global      lSubShr1rEqu:function;
global      lSubShl1nEqu:function;
global      lSubShl1rEqu:function;
global      lShr1AddEqu:function;
global      lShr1SubEqu:function;
global      lShl1AddEqu:function;
global      lShl1SubEqu:function;

segment     .text

; ============================================================================
; lAddShr1Equ( Op1, Op2: pLimb; const Size: tCounter; Op3: pLimb ):tBaseVal
; Linux        RDI  RSI               RDX             RCX         :RAX
; Win7         RCX  RDX               R8              R9          :RAX
;
; Description:
; The function shifts Op1 right one bit, adds this to Op2, stores the result
; in Op3 and hands back the total carry. There is a gain in execution speed
; compared to separate shift and addition by interleaving the elementary 
; operations and reducing memory access. The factor depends on the size of the
; operands (the cache level in which the operands can be handled) and the core 
; used.
;
;  Op3 := Op1>>1 + Op2
;
; Caveats:
; - the limb preceeding the MSL of Op1 will be integrated in shifting!
;
; Comments:
; - Skylake asm version implemented, tested & benched on 10.10.2015 by jn
; - On an i7 6700K  per limb saving is 1 cycle in L1$, L2$ and  L3$
; - includes LAHF / SAHF
; - includes prefetching

%ifdef USE_WIN64

  %define   Op1     RCX
  %define   Op2     RDX
  %define   Size    R8
  %define   Op3     R9
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   RDI         ; SAVE!
  %define   Limb2   RSI         ; SAVE!
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

%ifdef USE_LINUX64

  %define   Op1     RDI
  %define   Op2     RSI
  %define   Size    RDX
  %define   Op3     RCX
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   R8
  %define   Limb2   R9
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

    align   32
lAddShr1Equ:

  %ifdef USE_WIN64
    %ifdef USE_PREFETCH
      sub   RSP, 64
      mov   [RSP+56], Offs
    %else
      sub   RSP, 56
    %endif
      mov   [RSP+48], Limb8
      mov   [RSP+40], Limb7
      mov   [RSP+32], Limb6
      mov   [RSP+24], Limb5
      mov   [RSP+16], Limb2
      mov   [RSP+8], Limb1
      mov   [RSP], Limb0
  %endif

  %ifdef USE_LINUX64
    %ifdef USE_PREFETCH
      sub   RSP, 48
      mov   [RSP+40], Offs
    %else
      sub   RSP, 40
    %endif
      mov   [RSP+32], Limb8
      mov   [RSP+24], Limb7
      mov   [RSP+16], Limb6
      mov   [RSP+8], Limb5
      mov   [RSP], Limb0
  %endif

  %ifdef USE_PREFETCH
    prefetchnta [Op1]
    prefetchnta [Op2]
    mov     EBP, 512            ; Attn: check if redefining Offs
  %endif

    ; prepare shift & addition with loop-unrolling 8
    mov     Limb0, [Op1]        ; pre-load first shift value
    add     Op1, 8
    lahf                        ; memorize clear carry (from "add" above)

    test    Size, 1             ; a good R8 / R16 / R32 macro would help!
    je      .lAddShr1EquTwo     ; no one-limb processing =>

    mov     Limb1, [Op1]
    shrd    Limb0, Limb1, 1

    sahf
    adc     Limb0, [Op2]
    mov     [Op3], Limb0
    lahf

    add     Op1, 8
    add     Op2, 8
    add     Op3, 8
    mov     Limb0, Limb1

  .lAddShr1EquTwo:

    test    Size, 2             ; a good R8 / R16 / R32 macro would help!
    je      .lAddShr1EquFour

    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    shrd    Limb0, Limb1, 1
    shrd    Limb1, Limb2, 1

    sahf
    adc     Limb0, [Op2]
    adc     Limb1, [Op2+8]
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    lahf

    add     Op1, 16
    add     Op2, 16
    add     Op3, 16
    mov     Limb0, Limb2

  .lAddShr1EquFour:

    test    Size, 4             ; a good R8 / R16 / R32 macro would help!
    je      .lAddShr1EquCheck   ; enter main loop =>

    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    shrd    Limb0, Limb1, 1
    shrd    Limb1, Limb2, 1
    shrd    Limb2, Limb3, 1
    shrd    Limb3, Limb4, 1

    sahf
    adc     Limb0, [Op2]
    adc     Limb1, [Op2+8]
    adc     Limb2, [Op2+16]
    adc     Limb3, [Op2+24]
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3
    lahf

    add     Op1, 32
    add     Op2, 32
    add     Op3, 32
    mov     Limb0, Limb4
    jmp     .lAddShr1EquCheck   ; enter main loop =>

    ; main loop: <1.3 cycles per limb in L1$
    ; combining elements in multiples of four prooved fastest on Skylake
    align   32
  .lAddShr1EquLoop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
    prefetchnta [Op2+Offs]
  %endif

    mov     Limb1, [Op1]        ; prepare 8 shifted values from Op1
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    shrd    Limb0, Limb1, 1
    shrd    Limb1, Limb2, 1
    shrd    Limb2, Limb3, 1
    shrd    Limb3, Limb4, 1
    mov     Limb5, [Op1+32]
    mov     Limb6, [Op1+40]
    mov     Limb7, [Op1+48]
    mov     Limb8, [Op1+56]
    shrd    Limb4, Limb5, 1
    shrd    Limb5, Limb6, 1
    shrd    Limb6, Limb7, 1
    shrd    Limb7, Limb8, 1

    sahf                        ; restore carry ...
    adc     Limb0, [Op2]        ; add shifted Op1 to Op2 with result in Op3
    adc     Limb1, [Op2+8]
    adc     Limb2, [Op2+16]
    adc     Limb3, [Op2+24]
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3
    adc     Limb4, [Op2+32]
    adc     Limb5, [Op2+40]
    adc     Limb6, [Op2+48]
    adc     Limb7, [Op2+56]
    mov     [Op3+32], Limb4
    mov     [Op3+40], Limb5
    mov     [Op3+48], Limb6
    mov     [Op3+56], Limb7
    lahf                        ; ... and save again for next round

    add     Op1, 64
    add     Op2, 64
    add     Op3, 64
    mov     Limb0, Limb8

  .lAddShr1EquCheck:

    sub     Size, 8
    jnc     .lAddShr1EquLoop

    ; housekeeping - hand back final carry
    xor     Limb0, Limb0        ; a good R8 / R16 / R32 macro would help!
    sahf
    adc     Limb0, Limb0        ; a good R8 / R16 / R32 macro would help!
    mov     RAX, Limb0

  .Exit:

  %ifdef USE_LINUX64
      mov   Limb0, [RSP]
      mov   Limb5, [RSP+8]
      mov   Limb6, [RSP+16]
      mov   Limb7, [RSP+24]
      mov   Limb8, [RSP+32]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+40]
      add   RSP, 48
    %else
      add   RSP, 40
    %endif
  %endif

  %ifdef USE_WIN64
      mov   Limb0, [RSP]
      mov   Limb1, [RSP+8]
      mov   Limb2, [RSP+16]
      mov   Limb5, [RSP+24]
      mov   Limb6, [RSP+32]
      mov   Limb7, [RSP+40]
      mov   Limb8, [RSP+48]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+56]
      sub   RSP, 64
    %else
      sub   RSP, 56
    %endif
  %endif

    ret

; ============================================================================
; lAddShl1Equ( Op1, Op2: pLimb; const Size: tCounter; Op3: pLimb ):tBaseVal
; Linux        RDI  RSI               RDX             RCX         :RAX
; Win7         RCX  RDX               R8              R9          :RAX
;
; Description:
; The function shifts Op1 left one bit, adds this to Op2, stores the result
; in Op3 and hands back the total carry. There is a gain in execution speed
; compared to separate shift and addition by interleaving the elementary
; operations and reducing memory access. The factor depends on the size of the
; operands (the cache level which in the operands can be handled) and the core
; used.
;
;  Op3 := Op1<<1 + Op2
;
; Caveats:
; - the total carry can range from 0-2!
;
; Comments:
; - Skaylake asm version implemented, tested & benched on 11.10.2015 by jn
; - on an i7 6700K per limb saving is 1 cycle in L1$, L2$ and L3$
; - includes LAHF / SAHF
; - includes prefetching

%ifdef USE_WIN64

  %define   Op1     RCX
  %define   Op2     RDX
  %define   Size    R8
  %define   Op3     R9
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   RDI         ; SAVE!
  %define   Limb2   RSI         ; SAVE!
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

%ifdef USE_LINUX64

  %define   Op1     RDI
  %define   Op2     RSI
  %define   Size    RDX
  %define   Op3     RCX
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   R8
  %define   Limb2   R9
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

    align   32;
lAddShl1Equ:

  %ifdef USE_WIN64
    %ifdef USE_PREFETCH
      sub   RSP, 64
      mov   [RSP+56], Offs
    %else
      sub   RSP, 56
    %endif
      mov   [RSP+48], Limb8
      mov   [RSP+40], Limb7
      mov   [RSP+32], Limb6
      mov   [RSP+24], Limb5
      mov   [RSP+16], Limb2
      mov   [RSP+8], Limb1
      mov   [RSP], Limb0
  %endif

  %ifdef USE_LINUX64
    %ifdef USE_PREFETCH
      sub   RSP, 48
      mov   [RSP+40], Offs
    %else
      sub   RSP, 40
    %endif
      mov   [RSP+32], Limb8
      mov   [RSP+24], Limb7
      mov   [RSP+16], Limb6
      mov   [RSP+8], Limb5
      mov   [RSP], Limb0
  %endif

  %ifdef USE_PREFETCH
    prefetchnta [Op1]
    prefetchnta [Op2]
    mov     EBP, 512            ; Attn: check if redefining Offs
  %endif

    ; prepare shift & addition with loop-unrolling 8
    xor     Limb0, Limb0        ; a good R8 / R16 / R32 macro would help!
    lahf                        ; memorize clear carry (from "xor")

    test    Size, 1             ; a good R8 / R16 / R32 macro would help!
    je      .lAddShl1EquTwo

    mov     Limb1, [Op1]
    shrd    Limb0, Limb1, 63

    sahf
    adc     Limb0, [Op2]
    mov     [Op3], Limb0
    lahf

    add     Op1, 8
    add     Op2, 8
    add     Op3, 8
    mov     Limb0, Limb1

  .lAddShl1EquTwo:

    test    Size, 2             ; a good R8 / R16 / R32 macro would help!
    je      .lAddShl1EquFour

    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63

    sahf
    adc     Limb0, [Op2]
    adc     Limb1, [Op2+8]
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    lahf

    add     Op1, 16
    add     Op2, 16
    add     Op3, 16
    mov     Limb0, Limb2

  .lAddShl1EquFour:

    test    Size, 4             ; a good R8 / R16 / R32 macro would help!
    je      .lAddShl1EquTest    ; enter main loop =>

    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63
    shrd    Limb2, Limb3, 63
    shrd    Limb3, Limb4, 63

    sahf
    adc     Limb0, [Op2]
    adc     Limb1, [Op2+8]
    adc     Limb2, [Op2+16]
    adc     Limb3, [Op2+24]
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3
    lahf

    add     Op1, 16
    add     Op2, 16
    add     Op3, 16
    mov     Limb0, Limb4
    jmp     .lAddShl1EquTest    ; enter main loop =>

    ; main loop: <1.3 cycles per limb in L1$
    ; combining elements in multiples of four prooved fastest on Skylake
    align   32
  .lAddShl1EquLoop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
    prefetchnta [Op2+Offs]
  %endif

    mov     Limb1, [Op1]        ; prepare shifted oct-limb from Op1
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63
    shrd    Limb2, Limb3, 63
    shrd    Limb3, Limb4, 63
    mov     Limb5, [Op1+32]
    mov     Limb6, [Op1+40]
    mov     Limb7, [Op1+48]
    mov     Limb8, [Op1+56]
    shrd    Limb4, Limb5, 63
    shrd    Limb5, Limb6, 63
    shrd    Limb6, Limb7, 63
    shrd    Limb7, Limb8, 63

    sahf                        ; restore carry
    adc     Limb0, [Op2]        ; add Op2 to oct-limb and store in Op3
    adc     Limb1, [Op2+8]
    adc     Limb2, [Op2+16]
    adc     Limb3, [Op2+24]
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3
    adc     Limb4, [Op2+32]
    adc     Limb5, [RSI+40]
    adc     Limb6, [RSI+48]
    adc     Limb7, [RSI+56]
    mov     [Op3+32], Limb4
    mov     [Op3+40], Limb5
    mov     [Op3+48], Limb6
    mov     [Op3+56], Limb7
    lahf                        ; remember carry for next round

    add     Op1, 64
    add     Op2, 64
    add     Op3, 64
    mov     Limb0, Limb8

  .lAddShl1EquTest:

    sub     Size, 8
    jnc     .lAddShl1EquLoop

    ; housekeeping - hand back total carry
    shr     Limb0, 63
    sahf
    adc     Limb0, 0            ; =0/1/2 depending on final carry and shift
    mov     RAX, Limb0

  .Exit:

  %ifdef USE_LINUX64
      mov   Limb0, [RSP]
      mov   Limb5, [RSP+8]
      mov   Limb6, [RSP+16]
      mov   Limb7, [RSP+24]
      mov   Limb8, [RSP+32]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+40]
      add   RSP, 48
    %else
      add   RSP, 40
    %endif
  %endif

  %ifdef USE_WIN64
      mov   Limb0, [RSP]
      mov   Limb1, [RSP+8]
      mov   Limb2, [RSP+16]
      mov   Limb5, [RSP+24]
      mov   Limb6, [RSP+32]
      mov   Limb7, [RSP+40]
      mov   Limb8, [RSP+48]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+56]
      sub   RSP, 64
    %else
      sub   RSP, 56
    %endif
  %endif

    ret

; ============================================================================
; lSubShr1nEqu( Op1, Op2: pLimb; const Size: tCounter; Op3: pLimb ):tBaseVal
; Linux         RDI  RSI               RDX             RCX         :RAX
; Win7          RCX  RDX               R8              R9          :RAX
;
; Description:
; The function shifts Op1 right one bit, subtracts Op2 from it, stores the
; result in Op3 and hands back the total carry. There is a gain in execution
; speed compared to separate shift and subtract by interleaving the elementary
; operations and reducing memory access. The factor depends on the size of the
; operands (the cache level in which the operands can be handled) and the core
; used.
;
;  Op3 := Op1>>1 - Op2
;
; Caveats:
; - the limb preceeding the MSL of Op1 will be integrated in shifting!
; - the total carry is in [-1..1]!
;
; Comments:
; - Skylake asm version implemented, tested & benched on 12.10.2015 by jn
; - On an i7 6700K per limb saving is 1 cycle in L1$, L2$ and L3$
; - includes LAHF / SAHF
; - includes prefetching

%ifdef USE_WIN64

  %define   Op1     RCX
  %define   Op2     RDX
  %define   Size    R8
  %define   Op3     R9
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   RDI         ; SAVE!
  %define   Limb2   RSI         ; SAVE!
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

%ifdef USE_LINUX64

  %define   Op1     RDI
  %define   Op2     RSI
  %define   Size    RDX
  %define   Op3     RCX
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   R8
  %define   Limb2   R9
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

    align   32
lSubShr1nEqu:

  %ifdef USE_WIN64
    %ifdef USE_PREFETCH
      sub   RSP, 64
      mov   [RSP+56], Offs
    %else
      sub   RSP, 56
    %endif
      mov   [RSP+48], Limb8
      mov   [RSP+40], Limb7
      mov   [RSP+32], Limb6
      mov   [RSP+24], Limb5
      mov   [RSP+16], Limb2
      mov   [RSP+8], Limb1
      mov   [RSP], Limb0
  %endif

  %ifdef USE_LINUX64
    %ifdef USE_PREFETCH
      sub   RSP, 48
      mov   [RSP+40], Offs
    %else
      sub   RSP, 40
    %endif
      mov   [RSP+32], Limb8
      mov   [RSP+24], Limb7
      mov   [RSP+16], Limb6
      mov   [RSP+8], Limb5
      mov   [RSP], Limb0
  %endif

  %ifdef USE_PREFETCH
    prefetchnta [Op1]
    prefetchnta [Op2]
    mov     EBP, 512            ; Attn: check if redefining Offs
  %endif

    ; prepare shift & subtraction with loop-unrolling 8
    mov     Limb0, [Op1]        ; pre-load first shift value
    add     Op1, 8
    lahf                        ; memorize clear carry (from "add" above)

    test    Size, 1             ; a good R8 / R16 / R32 macro would help!
    je      .lSubShr1nEquTwo

    mov     Limb1, [Op1]
    shrd    Limb0, Limb1, 1

    sahf
    sbb     Limb0, [Op2]
    mov     [Op3], Limb0
    lahf

    add     Op1, 8
    add     Op2, 8
    add     Op3, 8
    mov     Limb0, Limb1

  .lSubShr1nEquTwo:

    test    Size, 2             ; a good R8 / R16 / R32 macro would help!
    je      .lSubShr1nEquFour

    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    shrd    Limb0, Limb1, 1
    shrd    Limb1, Limb2, 1

    sahf
    sbb     Limb0, [Op2]
    sbb     Limb1, [Op2+8]
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    lahf

    add     Op1, 16
    add     Op2, 16
    add     Op3, 16
    mov     Limb0, Limb2

  .lSubShr1nEquFour:

    test    Size, 4             ; a good R8 / R16 / R32 macro would help!
    je      .lSubShr1nEquCheck  ; enter main loop =>

    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    shrd    Limb0, Limb1, 1
    shrd    Limb1, Limb2, 1
    shrd    Limb2, Limb3, 1
    shrd    Limb3, Limb4, 1

    sahf
    sbb     Limb0, [Op2]
    sbb     Limb1, [Op2+8]
    sbb     Limb2, [Op2+16]
    sbb     Limb3, [Op2+24]
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3
    lahf

    add     Op1, 32
    add     Op2, 32
    add     Op3, 32
    mov     Limb0, Limb4
    jmp     .lSubShr1nEquCheck  ; enter main loop =>

    ; main loop: <1.3 cycles per limb in L1$
    ; combining elements in multiples of four prooved fastest on Skylake
    align   32
  .lSubShr1nEquLoop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
    prefetchnta [Op2+Offs]
  %endif

    mov     Limb1, [Op1]        ; prepare shifted oct-limb from Op1
    mov     Limb2, [Op1+8];
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    shrd    Limb0, Limb1, 1
    shrd    Limb1, Limb2, 1
    shrd    Limb2, Limb3, 1
    shrd    Limb3, Limb4, 1
    mov     Limb5, [Op1+32]
    mov     Limb6, [Op1+40]
    mov     Limb7, [Op1+48]
    mov     Limb8, [Op1+56]
    shrd    Limb4, Limb5, 1
    shrd    Limb5, Limb6, 1
    shrd    Limb6, Limb7, 1
    shrd    Limb7, Limb8, 1

    sahf                        ; restore carry ...
    sbb     Limb0, [Op2]        ; sub Op2 from shifted Op1 with result in Op3
    sbb     Limb1, [Op2+8]
    sbb     Limb2, [Op2+16]
    sbb     Limb3, [Op2+24]
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3
    sbb     Limb4, [Op2+32]
    sbb     Limb5, [Op2+40]
    sbb     Limb6, [Op2+48]
    sbb     Limb7, [Op2+56]
    mov     [Op3+32], Limb4
    mov     [Op3+40], Limb5
    mov     [Op3+48], Limb6
    mov     [Op3+56], Limb7
    lahf                        ; ... and save again for next round

    add     Op1, 64
    add     Op2, 64
    add     Op3, 64
    mov     Limb0, Limb8

  .lSubShr1nEquCheck:

    sub     Size, 8
    jnc     .lSubShr1nEquLoop

    ; housekeeping - hand back final carry
    xor     Limb0, Limb0
    sahf
    adc     Limb0, Limb0
    mov     RAX, Limb0

  .Exit:

  %ifdef USE_LINUX64
      mov   Limb0, [RSP]
      mov   Limb5, [RSP+8]
      mov   Limb6, [RSP+16]
      mov   Limb7, [RSP+24]
      mov   Limb8, [RSP+32]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+40]
      add   RSP, 48
    %else
      add   RSP, 40
    %endif
  %endif

  %ifdef USE_WIN64
      mov   Limb0, [RSP]
      mov   Limb1, [RSP+8]
      mov   Limb2, [RSP+16]
      mov   Limb5, [RSP+24]
      mov   Limb6, [RSP+32]
      mov   Limb7, [RSP+40]
      mov   Limb8, [RSP+48]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+56]
      sub   RSP, 64
    %else
      sub   RSP, 56
    %endif
  %endif

    ret

; ============================================================================
; lSubShr1rEqu( Op1, Op2: pLimb; const Size: tCounter; Op3: pLimb ):tBaseVal
; Linux         RDI  RSI               RDX             RCX         :RAX
; Win7          RCX  RDX               R8              R9          :RAX
;
; Description:
; The function shifts Op2 right one bit, subtracts it from Op1, stores the
; result in Op3 and hands back the total carry. There is a gain in execution
; speed compared to separate shift and subtract by interleaving the elementary
; operations and reducing memory access. The factor depends on the size of the
; operands (the cache level in which the operands can be handled) and the core
; used.
;
;  Op3 := Op1 - Op2>>1
;
; Caveats:
; - the limb preceeding the MSL of Op2 will be integrated in shifting!
; - the total carry is in [-1..1]!
;
; Comments:
; - Skylake asm version implemented, tested & benched on 13.10.2015 by jn
; - on an i7 6700K per limb saving is 1 cycle in L1$, L2§ and L3$
; - includes LAHF / SAHF
; - includes prefetching

%ifdef USE_WIN64

  %define   Op1     RCX
  %define   Op2     RDX
  %define   Size    R8
  %define   Op3     R9
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   RDI         ; SAVE!
  %define   Limb2   RSI         ; SAVE!
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

%ifdef USE_LINUX64

  %define   Op1     RDI
  %define   Op2     RSI
  %define   Size    RDX
  %define   Op3     RCX
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   R8
  %define   Limb2   R9
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

    align   32
lSubShr1rEqu:

  %ifdef USE_WIN64
    %ifdef USE_PREFETCH
      sub   RSP, 64
      mov   [RSP+56], Offs
    %else
      sub   RSP, 56
    %endif
      mov   [RSP+48], Limb8
      mov   [RSP+40], Limb7
      mov   [RSP+32], Limb6
      mov   [RSP+24], Limb5
      mov   [RSP+16], Limb2
      mov   [RSP+8], Limb1
      mov   [RSP], Limb0
  %endif

  %ifdef USE_LINUX64
    %ifdef USE_PREFETCH
      sub   RSP, 48
      mov   [RSP+40], Offs
    %else
      sub   RSP, 40
    %endif
      mov   [RSP+32], Limb8
      mov   [RSP+24], Limb7
      mov   [RSP+16], Limb6
      mov   [RSP+8], Limb5
      mov   [RSP], Limb0
  %endif

  %ifdef USE_PREFETCH
    prefetchnta [Op1]
    prefetchnta [Op2]
    mov     EBP, 512            ; Attn: check if redefining Offs
  %endif

    ; prepare shift & subtraction with loop-unrolling 8
    mov     Limb0, [Op2]        ; pre-load first shift value
    add     Op2, 8
    lahf                        ; memorize clear carry (from "add" above)

    test    Size, 1             ; a good R8 / R16 / R32 macro would help!
    je      .lSubShr1rEquTwo

    mov     Limb1, [Op2]
    shrd    Limb0, Limb1, 1

    sahf
    mov     RAX, [Op1]
    sbb     RAX, Limb0
    mov     [Op3], RAX
    lahf

    add     Op1, 8
    add     Op2, 8
    add     Op3, 8
    mov     Limb0, Limb1

  .lSubShr1rEquTwo:

    test    Size, 2             ; a good R8 / R16 / R32 macro would help!
    je      .lSubShr1rEquFour

    mov     Limb1, [Op2]
    mov     Limb2, [Op2+8]
    shrd    Limb0, Limb1, 1
    shrd    Limb1, Limb2, 1

    sahf
    mov     RAX, [Op1]
    sbb     RAX, Limb0
    mov     [Op3], RAX
    mov     RAX, [Op1+8];
    sbb     RAX, Limb1
    mov     [Op3+8], RAX
    lahf

    add     Op1, 16
    add     Op2, 16
    add     Op3, 16
    mov     Limb0, Limb2

  .lSubShr1rEquFour:

    test    Size, 4             ; a good R8 / R16 / R32 macro would help!
    je      .lSubShr1rEquCheck  ; enter main loop =>

    mov     Limb1, [Op2]
    mov     Limb2, [Op2+8]
    mov     Limb3, [Op2+16]
    mov     Limb4, [Op2+24]
    shrd    Limb0, Limb1, 1
    shrd    Limb1, Limb2, 1
    shrd    Limb2, Limb3, 1
    shrd    Limb3, Limb4, 1

    sahf
    mov     RAX, [Op1]
    sbb     RAX, Limb0
    mov     [Op3], RAX
    mov     RAX, [Op1+8];
    sbb     RAX, Limb1
    mov     [Op3+8], RAX
    mov     RAX, [Op1+16]
    sbb     RAX, Limb2
    mov     [Op3+16], RAX
    mov     RAX, [Op1+24]
    sbb     RAX, Limb3
    mov     [Op3+24], RAX
    lahf

    add     Op1, 32
    add     Op2, 32
    add     Op2, 32
    mov     Limb0, Limb4
    jmp     .lSubShr1rEquCheck  ; enter main loop =>

    ; main loop: <1.5 cycles per limb in L1$
    ; combining the shifts in multiples of eight prooved fastest on Skylake
    align   32
  .lSubShr1rEquLoop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
    prefetchnta [Op2+Offs]
  %endif

    mov     Limb1, [Op2]        ; // prepare shifted oct-limb from Op2
    mov     Limb2, [Op2+8]
    mov     Limb3, [Op2+16]
    mov     Limb4, [Op2+24]
    shrd    Limb0, Limb1, 1
    shrd    Limb1, Limb2, 1
    shrd    Limb2, Limb3, 1
    shrd    Limb3, Limb4, 1
    mov     Limb5, [Op2+32]
    mov     Limb6, [Op2+40]
    mov     Limb7, [Op2+48]
    mov     Limb8, [Op2+56]
    shrd    Limb4, Limb5, 1
    shrd    Limb5, Limb6, 1
    shrd    Limb6, Limb7, 1
    shrd    Limb7, Limb8, 1

    sahf                        ; restore carry ...
    mov     RAX, [Op1]
    sbb     RAX, Limb0          ; sub shifted Op2 from Op1 with result in Op3
    mov     [Op3], RAX;
    mov     RAX, [Op1+8]
    sbb     RAX, Limb1
    mov     [Op3+8], RAX
    mov     RAX, [Op1+16]
    sbb     RAX, Limb2
    mov     [Op3+16], RAX
    mov     RAX, [Op1+24]
    sbb     RAX, Limb3
    mov     [Op3+24], RAX
    mov     RAX, [Op1+32]
    sbb     RAX, Limb4
    mov     [Op3+32], RAX
    mov     RAX, [Op1+40]
    sbb     RAX, Limb5
    mov     [Op3+40], RAX
    mov     RAX, [Op1+48]
    sbb     RAX, Limb6
    mov     [Op3+48], RAX
    mov     RAX, [Op1+56]
    sbb     RAX, Limb7
    mov     [Op3+56], RAX
    lahf                        ; ... save carry for next quad value

    add     Op1, 64
    add     Op2, 64
    add     Op3, 64
    mov     Limb0, Limb8

  .lSubShr1rEquCheck:

    sub     Size, 8
    jnc     .lSubShr1rEquLoop;

    ; housekeeping - hand back final carry
    xor     Limb0, Limb0
    sahf
    adc     Limb0, Limb0
    mov     RAX, Limb0

  .Exit:

  %ifdef USE_LINUX64
      mov   Limb0, [RSP]
      mov   Limb5, [RSP+8]
      mov   Limb6, [RSP+16]
      mov   Limb7, [RSP+24]
      mov   Limb8, [RSP+32]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+40]
      add   RSP, 48
    %else
      add   RSP, 40
    %endif
  %endif

  %ifdef USE_WIN64
      mov   Limb0, [RSP]
      mov   Limb1, [RSP+8]
      mov   Limb2, [RSP+16]
      mov   Limb5, [RSP+24]
      mov   Limb6, [RSP+32]
      mov   Limb7, [RSP+40]
      mov   Limb8, [RSP+48]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+56]
      sub   RSP, 64
    %else
      sub   RSP, 56
    %endif
  %endif

    ret

; ============================================================================
; lSubShl1nEqu( Op1, Op2: pLimb; const Size: tCounter; Op3: pLimb ):tBaseVal
; Linux         RDI  RSI               RDX             RCX         :RAX
; Win7          RCX  RDX               R8              R9          :RAX
;
; Description:
; The function shifts Op1 left one bit, subtracts Op2 from it, stores the
; result in Op3 and hands back the total carry. There is a gain in execution
; speed compared to separate shift and subtract by interleaving the elementary
; operations and reducing memory access. The factor depends on the size of the
; operands (the cache level in which the operands can be handled) and the core
; used.
;
;  Op3 := Op1<<1 - Op2
;
; Caveats:
; - the total carry is in [-1..1]!
;
; Comments:
; - Skylake asm version implemented, tested & benched on 14.10.2015 by jn
; - On an i7 6700K per limb saving is 1 cycle in L1$, L2$ and L3$
; - includes LAHF / SAHF
; - includes prefetching

%ifdef USE_WIN64

  %define   Op1     RCX
  %define   Op2     RDX
  %define   Size    R8
  %define   Op3     R9
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   RDI         ; SAVE!
  %define   Limb2   RSI         ; SAVE!
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

%ifdef USE_LINUX64

  %define   Op1     RDI
  %define   Op2     RSI
  %define   Size    RDX
  %define   Op3     RCX
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   R8
  %define   Limb2   R9
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

    align   32
lSubShl1nEqu:

  %ifdef USE_WIN64
    %ifdef USE_PREFETCH
      sub   RSP, 64
      mov   [RSP+56], Offs
    %else
      sub   RSP, 56
    %endif
      mov   [RSP+48], Limb8
      mov   [RSP+40], Limb7
      mov   [RSP+32], Limb6
      mov   [RSP+24], Limb5
      mov   [RSP+16], Limb2
      mov   [RSP+8], Limb1
      mov   [RSP], Limb0
  %endif

  %ifdef USE_LINUX64
    %ifdef USE_PREFETCH
      sub   RSP, 48
      mov   [RSP+40], Offs
    %else
      sub   RSP, 40
    %endif
      mov   [RSP+32], Limb8
      mov   [RSP+24], Limb7
      mov   [RSP+16], Limb6
      mov   [RSP+8], Limb5
      mov   [RSP], Limb0
  %endif

  %ifdef USE_PREFETCH
    prefetchnta [Op1]
    prefetchnta [Op2]
    mov     EBP, 512            ; Attn: check if redefining Offs
  %endif

    ; prepare shift & subtraction with loop-unrolling 8
    xor     Limb0, Limb0
    lahf                        ; memorize clear carry (from "xor")

    test    Size, 1             ; a good R8 / R16 / R32 macro would help!
    je      .lSubShl1nEquTwo

    mov     Limb1, [Op1]
    shrd    Limb0, Limb1, 63

    sahf
    sbb     Limb0, [Op2]
    mov     [Op3], Limb0
    lahf

    add     Op1, 8
    add     Op2, 8
    add     Op3, 8
    mov     Limb0, Limb1

  .lSubShl1nEquTwo:

    test    Size, 2             ; a good R8 / R16 / R32 macro would help!
    je      .lSubShl1nEquFour

    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63

    sahf
    sbb     Limb0, [Op2]
    sbb     Limb1, [Op2+8]
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    lahf

    add     Op1, 16
    add     Op2, 16
    add     Op3, 16
    mov     Limb0, Limb2

  .lSubShl1nEquFour:

    test    Size, 4             ; a good R8 / R16 / R32 macro would help!
    je      .lSubShl1nEquTest   ; enter main loop =>

    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63
    shrd    Limb2, Limb3, 63
    shrd    Limb3, Limb4, 63

    sahf
    sbb     Limb0, [Op2]
    sbb     Limb1, [Op2+8]
    sbb     Limb2, [Op2+16]
    sbb     Limb3, [Op2+24]
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3
    lahf

    add     Op1, 32
    add     Op2, 32
    add     Op3, 32
    mov     Limb0, Limb4
    jmp     .lSubShl1nEquTest   ; enter main loop =>

    ; main loop: <1.3 cycles per limb in L1$
    ; combining elements in multiples of four prooved fastest on Skylake
    align   32
  .lSubShl1nEquLoop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
    prefetchnta [Op2+Offs]
  %endif

    mov     Limb1, [Op1]        ; prepare shifted oct-limb from Op1
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63
    shrd    Limb2, Limb3, 63
    shrd    Limb3, Limb4, 63
    mov     Limb5, [Op1+32]
    mov     Limb6, [Op1+40]
    mov     Limb7, [Op1+48]
    mov     Limb8, [Op1+56]
    shrd    Limb4, Limb5, 63
    shrd    Limb5, Limb6, 63
    shrd    Limb6, Limb7, 63
    shrd    Limb7, Limb8, 63

    sahf                        ; restore carry
    sbb     Limb0, [Op2]        ; sub Op2 from shifted Op1 with result in Op3
    sbb     Limb1, [Op2+8]
    sbb     Limb2, [Op2+16]
    sbb     Limb3, [Op2+24]
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3
    sbb     Limb4, [Op2+32]
    sbb     Limb5, [Op2+40]
    sbb     Limb6, [Op2+48]
    sbb     Limb7, [Op2+56]
    mov     [Op3+32], Limb4
    mov     [Op3+40], Limb5
    mov     [Op3+48], Limb6
    mov     [Op3+56], Limb7
    lahf                        ; remember carry for next round

    add     Op1, 64
    add     Op2, 64
    add     Op3, 64
    mov     Limb0, Limb8

  .lSubShl1nEquTest:

    sub     Size, 8
    jnc     .lSubShl1nEquLoop

    ; housekeeping - hand back total carry
    shr     Limb0, 63
    sahf
    sbb     Limb0, 0            ; Limb0=-1/0/1 depending on final carry and shift
    mov     RAX, Limb0

  .Exit:

  %ifdef USE_LINUX64
      mov   Limb0, [RSP]
      mov   Limb5, [RSP+8]
      mov   Limb6, [RSP+16]
      mov   Limb7, [RSP+24]
      mov   Limb8, [RSP+32]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+40]
      add   RSP, 48
    %else
      add   RSP, 40
    %endif
  %endif

  %ifdef USE_WIN64
      mov   Limb0, [RSP]
      mov   Limb1, [RSP+8]
      mov   Limb2, [RSP+16]
      mov   Limb5, [RSP+24]
      mov   Limb6, [RSP+32]
      mov   Limb7, [RSP+40]
      mov   Limb8, [RSP+48]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+56]
      sub   RSP, 64
    %else
      sub   RSP, 56
    %endif
  %endif

    ret

; ============================================================================
; lSubShl1rEqu( Op1, Op2: pLimb; const Size: tCounter; Op3: pLimb ):tBaseVal
; Linux         RDI  RSI               RDX             RCX         :RAX
; Win7          RCX  RDX               R8              R9          :RAX
;
; Description:
; The function shifts Op2 left one bit, subtracts it from Op1, stores the
; result in Op3 and hands back the total carry. There is a gain in execution
; speed compared to separate shift and subtract by interleaving the elementary
; operations and reducing memory access. The factor depends on the size of the
; operands (the cache level in which the operands can be handled) and the core
; used.
;
;  Op3 := Op1 - Op2<<1
;
; Caveats:
; - the total carry is in [0..2]!
;
; Comments:
; - Skaylake asm version implemented, tested & benched on 15.10.2015 by jn
; - on an i7 6700K per limb saving is 1 cycle in L1$, L2$ and L3$
; - includes LAHF / SAHF
; - includes prefetching

%ifdef USE_WIN64

  %define   Op1     RCX
  %define   Op2     RDX
  %define   Size    R8
  %define   Op3     R9
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   RDI         ; SAVE!
  %define   Limb2   RSI         ; SAVE!
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

%ifdef USE_LINUX64

  %define   Op1     RDI
  %define   Op2     RSI
  %define   Size    RDX
  %define   Op3     RCX
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   R8
  %define   Limb2   R9
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

    align   32
lSubShl1rEqu:

  %ifdef USE_WIN64
    %ifdef USE_PREFETCH
      sub   RSP, 64
      mov   [RSP+56], Offs
    %else
      sub   RSP, 56
    %endif
      mov   [RSP+48], Limb8
      mov   [RSP+40], Limb7
      mov   [RSP+32], Limb6
      mov   [RSP+24], Limb5
      mov   [RSP+16], Limb2
      mov   [RSP+8], Limb1
      mov   [RSP], Limb0
  %endif

  %ifdef USE_LINUX64
    %ifdef USE_PREFETCH
      sub   RSP, 48
      mov   [RSP+40], Offs
    %else
      sub   RSP, 40
    %endif
      mov   [RSP+32], Limb8
      mov   [RSP+24], Limb7
      mov   [RSP+16], Limb6
      mov   [RSP+8], Limb5
      mov   [RSP], Limb0
  %endif

  %ifdef USE_PREFETCH
    prefetchnta [Op1]
    prefetchnta [Op2]
    mov     EBP, 512            ; Attn: check if redefining Offs
  %endif

    ; prepare shift & subtraction with loop-unrolling 8
    xor     Limb0, Limb0
    lahf                        ; memorize clear carry (from "xor")

    test    Size, 1             ; a good R8 / R16 / R32 macro would help!
    je      .lSubShl1rEquTwo

    mov     Limb1, [Op2]
    shrd    Limb0, Limb1, 63

    sahf
    mov     RAX, [Op1]
    sbb     RAX, Limb0
    mov     [Op3], RAX
    lahf

    add     Op1, 8
    add     Op2, 8
    add     Op3, 8
    mov     Limb0, Limb1

  .lSubShl1rEquTwo:

    test    Size, 2             ; a good R8 / R16 / R32 macro would help!
    je      .lSubShl1rEquFour

    mov     Limb1, [Op2]
    mov     Limb2, [Op2+8]
    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63

    sahf
    mov     RAX, [Op1]
    sbb     RAX, Limb0
    mov     [Op3], RAX
    mov     RAX, [Op1+8]
    sbb     RAX, Limb1
    mov     [Op3+8], RAX
    lahf

    add     Op1, 16
    add     Op2, 16
    add     Op3, 16
    mov     Limb0, Limb2

  .lSubShl1rEquFour:

    test    Size, 4             ; a good R8 / R16 / R32 macro would help!
    je      .lSubShl1rEquTest   ; enter main loop =>

    mov     Limb1, [Op2]
    mov     Limb2, [Op2+8]
    mov     Limb3, [Op2+16]
    mov     Limb4, [Op2+24]
    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63
    shrd    Limb2, Limb3, 63
    shrd    Limb3, Limb4, 63

    sahf
    mov     RAX, [Op1]
    sbb     RAX, Limb0
    mov     [Op3], RAX
    mov     RAX, [Op1+8]
    sbb     RAX, Limb1
    mov     [Op3+8], RAX
    mov     RAX, [Op1+16]
    sbb     RAX, Limb2
    mov     [Op3+16], RAX
    mov     RAX, [Op1+24]
    sbb     RAX, Limb3
    mov     [Op3+24], RAX
    lahf

    add     Op1, 32
    add     Op2, 32
    add     Op3, 32
    mov     Limb0, Limb4
    jmp     .lSubShl1rEquTest   ; enter main loop =>

    ; main loop: <1.5 cycles per limb across all caches
    align   32
  .lSubShl1rEquLoop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
    prefetchnta [Op2+Offs]
  %endif

    mov     Limb1, [Op2]        ; prepare shifted oct-limb from Op2
    mov     Limb2, [Op2+8]
    mov     Limb3, [Op2+16]
    mov     Limb4, [Op2+24]
    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63
    shrd    Limb2, Limb3, 63
    shrd    Limb3, Limb4, 63
    mov     Limb5, [Op2+32]
    mov     Limb6, [Op2+40]
    mov     Limb7, [Op2+48]
    mov     Limb8, [Op2+56]
    shrd    Limb4, Limb5, 63
    shrd    Limb5, Limb6, 63
    shrd    Limb6, Limb7, 63
    shrd    Limb7, Limb8, 63

    sahf                        ; restore carry
    mov     RAX, [Op1]          ; sub shifted Op2 from Op1 with result in Op3
    sbb     RAX, Limb0
    mov     [Op3], RAX
    mov     RAX, [Op1+8]
    sbb     RAX, Limb1
    mov     [Op3+8], RAX
    mov     RAX, [Op1+16]
    sbb     RAX, Limb2
    mov     [Op3+16], RAX
    mov     RAX, [Op1+24]
    sbb     RAX, Limb3
    mov     [Op3+24], RAX
    mov     RAX, [Op1+32]
    sbb     RAX, Limb4
    mov     [Op3+32], RAX
    mov     RAX, [Op1+40]
    sbb     RAX, Limb5
    mov     [Op3+40], RAX
    mov     RAX, [Op1+48]
    sbb     RAX, Limb6
    mov     [Op3+48], RAX
    mov     RAX, [Op1+56]
    sbb     RAX, Limb7
    mov     [Op3+56], RAX
    lahf                        ; remember carry for next round

    add     Op1, 64
    add     Op2, 64
    add     Op3, 64
    mov     Limb0, Limb8

  .lSubShl1rEquTest:

    sub     Size, 8
    jnc     .lSubShl1rEquLoop

    ; housekeeping - hand back total carry
    shr     Limb0, 63
    sahf
    adc     Limb0, 0            ; Limb0=0/1/2 depending on final carry and shift
    mov     RAX, Limb0

  .Exit:

  %ifdef USE_LINUX64
      mov   Limb0, [RSP]
      mov   Limb5, [RSP+8]
      mov   Limb6, [RSP+16]
      mov   Limb7, [RSP+24]
      mov   Limb8, [RSP+32]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+40]
      add   RSP, 48
    %else
      add   RSP, 40
    %endif
  %endif

  %ifdef USE_WIN64
      mov   Limb0, [RSP]
      mov   Limb1, [RSP+8]
      mov   Limb2, [RSP+16]
      mov   Limb5, [RSP+24]
      mov   Limb6, [RSP+32]
      mov   Limb7, [RSP+40]
      mov   Limb8, [RSP+48]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+56]
      sub   RSP, 64
    %else
      sub   RSP, 56
    %endif
  %endif

    ret

; ============================================================================
; lShr1AddEqu( Op1, Op2: pLimb; const Size: tCounter; Op3: pLimb ):tBaseVal
; Linux        RDI  RSI               RDX             RCX         :RAX
; Win7         RCX  RDX               R8              R9          :RAX
;
; Description:
; The function adds Op1 to Op2, shifts this right one bit, stores the result
; in Op3 and hands back the total carry. Though in theory the carry is
; absorbed by the shift right it is still signalled to the upper layer to
; indicate an overflow has happened. There is a gain in execution speed
; compared to separate shift and addition by interleaving the elementary
; operations and reducing memory access. The factor depends on the size of the
; operands (the cache level in which the operands can be handled) and the core
; used.
;
;  Op3 := (Op1 + Op2)>>1
;
; Caveats:
; - the carry handed back must be handled outside this function!
;
; Comments:
; - Skylake asm version implemented, tested & benched on 16.10.2015 by jn
; - on an i7 6700K per limb saving is 1 cycle in L1$, L2$ and L3$
; - includes LAHF / SAHF
; - includes prefetching

%ifdef USE_WIN64

  %define   Op1     RCX
  %define   Op2     RDX
  %define   Size    R8
  %define   Op3     R9
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   RDI         ; SAVE!
  %define   Limb2   RSI         ; SAVE!
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

%ifdef USE_LINUX64

  %define   Op1     RDI
  %define   Op2     RSI
  %define   Size    RDX
  %define   Op3     RCX
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   R8
  %define   Limb2   R9
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

    align   32
lShr1AddEqu:

  %ifdef USE_WIN64
    %ifdef USE_PREFETCH
      sub   RSP, 64
      mov   [RSP+56], Offs
    %else
      sub   RSP, 56
    %endif
      mov   [RSP+48], Limb8
      mov   [RSP+40], Limb7
      mov   [RSP+32], Limb6
      mov   [RSP+24], Limb5
      mov   [RSP+16], Limb2
      mov   [RSP+8], Limb1
      mov   [RSP], Limb0
  %endif

  %ifdef USE_LINUX64
    %ifdef USE_PREFETCH
      sub   RSP, 48
      mov   [RSP+40], Offs
    %else
      sub   RSP, 40
    %endif
      mov   [RSP+32], Limb8
      mov   [RSP+24], Limb7
      mov   [RSP+16], Limb6
      mov   [RSP+8], Limb5
      mov   [RSP], Limb0
  %endif

  %ifdef USE_PREFETCH
    prefetchnta [Op1]
    prefetchnta [Op2]
    mov     EBP, 512            ; Attn: check if redefining Offs
  %endif

    ; prepare shift & addition with loop-unrolling 8
    mov     Limb0, [Op1]
    add     Limb0, [Op2]
    lahf                        ; memorize carry

    add     Op1, 8
    add     Op2, 8
    sub     Size, 1
    jc      .Exit

    test    Size, 1             ; a good R8 / R16 / R32 macro would help!
    je      .lShr1AddEquTwo

    sahf
    mov     Limb1, [Op1]
    adc     Limb1, [Op2]
    lahf

    shrd    Limb0, Limb1, 1
    mov     [Op3], Limb0

    add     Op1, 8
    add     Op2, 8
    add     Op3, 8
    mov     Limb0, Limb1

  .lShr1AddEquTwo:

    test    Size, 2             ; a good R8 / R16 / R32 macro would help!
    je      .lShr1AddEquFour

    sahf
    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    adc     Limb1, [Op2]
    adc     Limb2, [Op2+8]
    lahf

    shrd    Limb0, Limb1, 1
    shrd    Limb1, Limb2, 1
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1

    add     Op1, 16
    add     Op2, 16
    add     Op3, 16
    mov     Limb0, Limb2

  .lShr1AddEquFour:

    test    Size, 4             ; a good R8 / R16 / R32 macro would help!
    je      .lShr1AddEquCheck   ; enter main-loop =>

    sahf
    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    adc     Limb1, [Op2]
    adc     Limb2, [Op2+8]
    adc     Limb3, [Op2+16]
    adc     Limb4, [Op2+24]
    lahf

    shrd    Limb0, Limb1, 1
    shrd    Limb1, Limb2, 1
    shrd    Limb2, Limb3, 1
    shrd    Limb3, Limb4, 1
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3

    add     Op1, 32
    add     Op2, 32
    add     Op3, 32
    mov     Limb0, Limb4
    jmp     .lShr1AddEquCheck   ; enter main-loop =>

    ; main loop: <1.3 cycles per limb in L1$
    ; combining elements in multiples of four prooved fastest on Skylake
    align   32
  .lShr1AddEquLoop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
    prefetchnta [Op2+Offs]
  %endif

    sahf                        ; restore carry ...
    mov     Limb1, [Op1]        ; generate added oct-limb from Op1 and Op2
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    adc     Limb1, [Op2]
    adc     Limb2, [Op2+8]
    adc     Limb3, [Op2+16]
    adc     Limb4, [Op2+24]
    mov     Limb5, [Op1+32]
    mov     Limb6, [Op1+40]
    mov     Limb7, [Op1+48]
    mov     Limb8, [Op1+56]
    adc     Limb5, [Op2+32]
    adc     Limb6, [Op2+40]
    adc     Limb7, [Op2+48]
    adc     Limb8, [Op2+56]
    lahf                        ; ... and memorize carry again

    shrd    Limb0, Limb1, 1     ; shift oct-limbs and store in Op3
    shrd    Limb1, Limb2, 1
    shrd    Limb2, Limb3, 1
    shrd    Limb3, Limb4, 1
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3
    shrd    Limb4, Limb5, 1
    shrd    Limb5, Limb6, 1
    shrd    Limb6, Limb7, 1
    shrd    Limb7, Limb8, 1
    mov     [Op3+32], Limb4
    mov     [Op3+40], Limb5
    mov     [Op3+48], Limb6
    mov     [Op3+56], Limb7

    add     Op1, 64
    add     Op2, 64
    add     Op3, 64
    mov     Limb0, Limb8

  .lShr1AddEquCheck:

    sub     Size, 8
    jnc     .lShr1AddEquLoop

    ; housekeeping - set MSL and return the total carry
    shr     Limb0, 1
    mov     [Op3], Limb0

    xor     Limb0, Limb0
    sahf
    adc     Limb0, Limb0
    mov     RAX, Limb0

  .Exit:

  %ifdef USE_LINUX64
      mov   Limb0, [RSP]
      mov   Limb5, [RSP+8]
      mov   Limb6, [RSP+16]
      mov   Limb7, [RSP+24]
      mov   Limb8, [RSP+32]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+40]
      add   RSP, 48
    %else
      add   RSP, 40
    %endif
  %endif

  %ifdef USE_WIN64
      mov   Limb0, [RSP]
      mov   Limb1, [RSP+8]
      mov   Limb2, [RSP+16]
      mov   Limb5, [RSP+24]
      mov   Limb6, [RSP+32]
      mov   Limb7, [RSP+40]
      mov   Limb8, [RSP+48]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+56]
      sub   RSP, 64
    %else
      sub   RSP, 56
    %endif
  %endif

    ret

; ============================================================================
; lShr1SubEqu( Op1, Op2: pLimb; const Size: tCounter; Op3: pLimb ):tBaseVal
; Linux        RDI  RSI               RDX             RCX         :RAX
; Win7         RCX  RDX               R8              R9          :RAX
;
; Description:
; The function subtracts Op2 from Op1, shifts this right one bit, stores the
; result in Op3 and hands back the total carry. Though in theory the carry is
; absorbed by the shift right it is still signalled to the upper layer to
; indicate an overflow has happened. There is a gain in execution speed
; compared to separate shift and subtraction by interleaving the elementary
; operations and reducing memory access. The factor depends on the size of the
; operands (the cache level in which the operands can be handled) and the core
; used.
;
;  Op3 := (Op1 - Op2)>>1
;
; Caveats:
;
; Comments:
; - Skylake asm version implemented, tested & benched on 17.10.2015 by jn
; - on an i7 6700K per limb saving is 1 cycle in L1$, L2$ and L3$
; - includes LAHF / SAHF
; - includes prefetching

%ifdef USE_WIN64

  %define   Op1     RCX
  %define   Op2     RDX
  %define   Size    R8
  %define   Op3     R9
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   RDI         ; SAVE!
  %define   Limb2   RSI         ; SAVE!
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

%ifdef USE_LINUX64

  %define   Op1     RDI
  %define   Op2     RSI
  %define   Size    RDX
  %define   Op3     RCX
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   R8
  %define   Limb2   R9
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

    align   32
lShr1SubEqu:

  %ifdef USE_WIN64
    %ifdef USE_PREFETCH
      sub   RSP, 64
      mov   [RSP+56], Offs
    %else
      sub   RSP, 56
    %endif
      mov   [RSP+48], Limb8
      mov   [RSP+40], Limb7
      mov   [RSP+32], Limb6
      mov   [RSP+24], Limb5
      mov   [RSP+16], Limb2
      mov   [RSP+8], Limb1
      mov   [RSP], Limb0
  %endif

  %ifdef USE_LINUX64
    %ifdef USE_PREFETCH
      sub   RSP, 48
      mov   [RSP+40], Offs
    %else
      sub   RSP, 40
    %endif
      mov   [RSP+32], Limb8
      mov   [RSP+24], Limb7
      mov   [RSP+16], Limb6
      mov   [RSP+8], Limb5
      mov   [RSP], Limb0
  %endif

  %ifdef USE_PREFETCH
    prefetchnta [Op1]
    prefetchnta [Op2]
    mov     EBP, 512            ; Attn: check if redefining Offs
  %endif

    ; prepare shift & subtraction with loop-unrolling 8
    mov     Limb0, [Op1]
    sub     Limb0, [Op2]
    lahf                        ; memorize carry

    add     Op1, 8
    add     Op2, 8
    sub     Size, 1
    jc      .Exit

    test    Size, 1             ; a good R8 / R16 / R32 macro would help!
    je      .lShr1SubEquTwo

    sahf
    mov     Limb1, [Op1]
    sbb     Limb1, [Op2]
    lahf

    shrd    Limb0, Limb1, 1
    mov     [Op3], Limb0

    add     Op1, 8
    add     Op2, 8
    add     Op3, 8
    mov     Limb0, Limb1

  .lShr1SubEquTwo:

    test    Size, 2             ; a good R8 / R16 / R32 macro would help!
    je      .lShr1SubEquFour

    sahf
    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    sbb     Limb1, [Op2]
    sbb     Limb2, [Op2+8]
    lahf

    shrd    Limb0, Limb1, 1
    shrd    Limb1, Limb2, 1
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1

    add     Op1, 16
    add     Op2, 16
    add     Op3, 16
    mov     Limb0, Limb2

  .lShr1SubEquFour:

    test    Size, 4             ; a good R8 / R16 / R32 macro would help!
    je      .lShr1SubEquCheck   ; enter main-loop =>

    sahf
    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    sbb     Limb1, [Op2]
    sbb     Limb2, [Op2+8]
    sbb     Limb3, [Op2+16]
    sbb     Limb4, [Op2+24]
    lahf

    shrd    Limb0, Limb1, 1
    shrd    Limb1, Limb2, 1
    shrd    Limb2, Limb3, 1
    shrd    Limb3, Limb4, 1
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3

    add     Op1, 32
    add     Op2, 32
    add     Op3, 32
    mov     Limb0, Limb4
    jmp     .lShr1SubEquCheck   ; enter main-loop =>

    ; main loop: <1.3 cycles per limb in L1$
    ; combining elements in multiples of four prooved fastest on Skylake
    align   32
  .lShr1SubEquLoop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
    prefetchnta [Op2+Offs]
  %endif

    sahf                        ; restore carry ...
    mov     Limb1, [Op1]        ; generate subtracted oct-limb from Op1 and Op2
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    sbb     Limb1, [Op2]
    sbb     Limb2, [Op2+8]
    sbb     Limb3, [Op2+16]
    sbb     Limb4, [Op2+24]
    mov     Limb5, [Op1+32]
    mov     Limb6, [Op1+40]
    mov     Limb7, [Op1+48]
    mov     Limb8, [Op1+56]
    sbb     Limb5, [Op2+32]
    sbb     Limb6, [Op2+40]
    sbb     Limb7, [Op2+48]
    sbb     Limb8, [Op2+56]
    lahf                        ; ... and memorize carry again

    shrd    Limb0, Limb1, 1     ; shift oct-limbs and store in Op3
    shrd    Limb1, Limb2, 1
    shrd    Limb2, Limb3, 1
    shrd    Limb3, Limb4, 1
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3
    shrd    Limb4, Limb5, 1
    shrd    Limb5, Limb6, 1
    shrd    Limb6, Limb7, 1
    shrd    Limb7, Limb8, 1
    mov     [Op3+32], Limb4
    mov     [Op3+40], Limb5
    mov     [Op3+48], Limb6
    mov     [Op3+56], Limb7

    add     Op1, 64
    add     Op2, 64
    add     Op3, 64
    mov     Limb0, Limb8

  .lShr1SubEquCheck:

    sub     Size, 8
    jnc     .lShr1SubEquLoop

    ; housekeeping - set MSL and return the total carry
    shr     Limb0, 1
    mov     [Op3], Limb0

    xor     Limb0, Limb0
    sahf
    adc     Limb0, Limb0
    mov     RAX, Limb0

  .Exit:

  %ifdef USE_LINUX64
      mov   Limb0, [RSP]
      mov   Limb5, [RSP+8]
      mov   Limb6, [RSP+16]
      mov   Limb7, [RSP+24]
      mov   Limb8, [RSP+32]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+40]
      add   RSP, 48
    %else
      add   RSP, 40
    %endif
  %endif

  %ifdef USE_WIN64
      mov   Limb0, [RSP]
      mov   Limb1, [RSP+8]
      mov   Limb2, [RSP+16]
      mov   Limb5, [RSP+24]
      mov   Limb6, [RSP+32]
      mov   Limb7, [RSP+40]
      mov   Limb8, [RSP+48]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+56]
      sub   RSP, 64
    %else
      sub   RSP, 56
    %endif
  %endif

    ret

; ============================================================================
; lShl1AddEqu( Op1, Op2: pLimb; const Size: tCounter; Op3: pLimb ):tBaseVal
; Linux        RDI  RSI               RDX             RCX         :RAX
; Win7         RCX  RDX               R8              R9          :RAX
;
; Description:
; The function adds Op1 to Op2, shifts this left one bit, stores the result in
; Op3 and hands back the total carry. There is a gain in execution speed
; compared to separate shift and addition by interleaving the elementary
; operations and reducing memory access. The factor depends on the size of the
; operands (the cache level in which the operands can be handled) and the core
; used.
;
;  Op3 := (Op1 + Op2)<<1
;
; Caveats:
; - the total carry is in [0-2]!
;
; Comments:
; - Skylake asm version implemented, tested & benched on 18.10.2015 by jn
; - on an i7 6700K per limb saving is 1 cycle in L1$, L2$ and L3$
; - includes LAHF / SAHF
; - includes prefetching

%ifdef USE_WIN64

  %define   Op1     RCX
  %define   Op2     RDX
  %define   Size    R8
  %define   Op3     R9
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   RDI         ; SAVE!
  %define   Limb2   RSI         ; SAVE!
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

%ifdef USE_LINUX64

  %define   Op1     RDI
  %define   Op2     RSI
  %define   Size    RDX
  %define   Op3     RCX
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   R8
  %define   Limb2   R9
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

    align   32
lShl1AddEqu:

  %ifdef USE_WIN64
    %ifdef USE_PREFETCH
      sub   RSP, 64
      mov   [RSP+56], Offs
    %else
      sub   RSP, 56
    %endif
      mov   [RSP+48], Limb8
      mov   [RSP+40], Limb7
      mov   [RSP+32], Limb6
      mov   [RSP+24], Limb5
      mov   [RSP+16], Limb2
      mov   [RSP+8], Limb1
      mov   [RSP], Limb0
  %endif

  %ifdef USE_LINUX64
    %ifdef USE_PREFETCH
      sub   RSP, 48
      mov   [RSP+40], Offs
    %else
      sub   RSP, 40
    %endif
      mov   [RSP+32], Limb8
      mov   [RSP+24], Limb7
      mov   [RSP+16], Limb6
      mov   [RSP+8], Limb5
      mov   [RSP], Limb0
  %endif

  %ifdef USE_PREFETCH
    prefetchnta [Op1]
    prefetchnta [Op2]
    mov     EBP, 512            ; Attn: check if redefining Offs
  %endif

    ; prepare shift & addition with loop-unrolling 8
    xor     Limb0, Limb0
    lahf                        ; memorize clear carry (from "xor")

    test    Size, 1             ; a good R8 / R16 / R32 macro would help!
    je      .lShl1AddEquTwo

    sahf
    mov     Limb1, [Op1]
    adc     Limb1, [Op2]
    lahf

    shrd    Limb0, Limb1, 63
    mov     [Op3], Limb0

    add     Op1, 8
    add     Op2, 8
    add     Op3, 8
    mov     Limb0, Limb1

  .lShl1AddEquTwo:

    test    Size, 2             ; a good R8 / R16 / R32 macro would help!
    je      .lShl1AddEquFour

    sahf
    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    adc     Limb1, [Op2]
    adc     Limb2, [Op2+8]
    lahf

    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1

    add     Op1, 16
    add     Op2, 16
    add     Op3, 16
    mov     Limb0, Limb2

  .lShl1AddEquFour:

    test    Size, 4             ; a good R8 / R16 / R32 macro would help!
    je      .lShl1AddEquCheck   ; enter main loop =>

    sahf
    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    adc     Limb1, [Op2]
    adc     Limb2, [Op2+8]
    adc     Limb3, [Op2+16]
    adc     Limb4, [Op2+24]
    lahf

    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63
    shrd    Limb2, Limb3, 63
    shrd    Limb3, Limb4, 63
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3

    add     Op1, 32
    add     Op2, 32
    add     Op3, 32
    mov     Limb0, Limb4
    jmp     .lShl1AddEquCheck   ; enter main-loop =>

    ; main loop: <1.3 cycles per limb in L1$
    ; combining elements in multiples of four prooved fastest on Skylake
    align   32
  .lShl1AddEquLoop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
    prefetchnta [Op2+Offs]
  %endif

    sahf                        ; restore carry ...
    mov     Limb1, [Op1]        ; prepare added oct-limb from Op1 and Op2
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    adc     Limb1, [Op2]
    adc     Limb2, [Op2+8]
    adc     Limb3, [Op2+16]
    adc     Limb4, [Op2+24]
    mov     Limb5, [Op1+32]
    mov     Limb6, [Op1+40]
    mov     Limb7, [Op1+48]
    mov     Limb8, [Op1+56]
    adc     Limb5, [Op2+32]
    adc     Limb6, [Op2+40]
    adc     Limb7, [Op2+48]
    adc     Limb8, [Op2+56]
    lahf                        ; ... and memorize carry again

    shrd    Limb0, Limb1, 63    ; shift oct-limb and store in Op3
    shrd    Limb1, Limb2, 63
    shrd    Limb2, Limb3, 63
    shrd    Limb3, Limb4, 63
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3
    shrd    Limb4, Limb5, 63
    shrd    Limb5, Limb6, 63
    shrd    Limb6, Limb7, 63
    shrd    Limb7, Limb8, 63
    mov     [Op3+32], Limb4
    mov     [Op3+40], Limb5
    mov     [Op3+48], Limb6
    mov     [Op3+56], Limb7

    add     Op1, 64
    add     Op2, 64
    add     Op3, 64
    mov     Limb0, Limb8

  .lShl1AddEquCheck:

    sub     Size, 8
    jnc     .lShl1AddEquLoop;

    ; housekeeping - hand back total carry
    shr     Limb0, 63
    sahf
    adc     Limb0, 0            ; Limb0=0..2 depending on carry and shift!
    mov     RAX, Limb0

  .Exit:

  %ifdef USE_LINUX64
      mov   Limb0, [RSP]
      mov   Limb5, [RSP+8]
      mov   Limb6, [RSP+16]
      mov   Limb7, [RSP+24]
      mov   Limb8, [RSP+32]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+40]
      add   RSP, 48
    %else
      add   RSP, 40
    %endif
  %endif

  %ifdef USE_WIN64
      mov   Limb0, [RSP]
      mov   Limb1, [RSP+8]
      mov   Limb2, [RSP+16]
      mov   Limb5, [RSP+24]
      mov   Limb6, [RSP+32]
      mov   Limb7, [RSP+40]
      mov   Limb8, [RSP+48]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+56]
      sub   RSP, 64
    %else
      sub   RSP, 56
    %endif
  %endif

    ret

; ============================================================================
; lShl1SubEqu( Op1, Op2: pLimb; const Size: tCounter; Op3: pLimb ):tBaseVal
; Linux        RDI  RSI               RDX             RCX         :RAX
; Win7         RCX  RDX               R8              R9          :RAX
;
; Description:
; The function subtracts Op2 from Op1, shifts this left one bit, stores the
; result in Op3 and hands back the total carry. There is a gain in execution
; speed compared to separate shift and subtraction by interleaving the
; elementary operations and reducing memory access. The factor depends on the
; size of the operands (the cache level in which the operands can be handled)
; and the core used.
;
;  Op3 := (Op1 - Op2)<<1
;
; Caveats:
; - the total carry is in [-1..1]!
;
; Comments:
; - Skylake asm version implemented, tested & benched on 19.10.2015 by jn
; - the expected gain is depending on the memory bandwidth - which in turn
;   is a function of the cache level (plus some unknown hoopla - ask Intel).
; - on an i7 6700K per limb saving is 1 cycle in L1$, L2$ and L3$
; - includes LAHF / SAHF
; - includes prefetching

%ifdef USE_WIN64

  %define   Op1     RCX
  %define   Op2     RDX
  %define   Size    R8
  %define   Op3     R9
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   RDI         ; SAVE!
  %define   Limb2   RSI         ; SAVE!
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

%ifdef USE_LINUX64

  %define   Op1     RDI
  %define   Op2     RSI
  %define   Size    RDX
  %define   Op3     RCX
  %ifdef USE_PREFETCH
    %define Offs    RBP         ; SAVE!
  %endif

  %define   Limb0   RBX         ; SAVE!
  %define   Limb1   R8
  %define   Limb2   R9
  %define   Limb3   R10
  %define   Limb4   R11
  %define   Limb5   R12         ; SAVE!
  %define   Limb6   R13         ; SAVE!
  %define   Limb7   R14         ; SAVE!
  %define   Limb8   R15         ; SAVE!

%endif

    align   32
lShl1SubEqu:

  %ifdef USE_WIN64
    %ifdef USE_PREFETCH
      sub   RSP, 64
      mov   [RSP+56], Offs
    %else
      sub   RSP, 56
    %endif
      mov   [RSP+48], Limb8
      mov   [RSP+40], Limb7
      mov   [RSP+32], Limb6
      mov   [RSP+24], Limb5
      mov   [RSP+16], Limb2
      mov   [RSP+8], Limb1
      mov   [RSP], Limb0
  %endif

  %ifdef USE_LINUX64
    %ifdef USE_PREFETCH
      sub   RSP, 48
      mov   [RSP+40], Offs
    %else
      sub   RSP, 40
    %endif
      mov   [RSP+32], Limb8
      mov   [RSP+24], Limb7
      mov   [RSP+16], Limb6
      mov   [RSP+8], Limb5
      mov   [RSP], Limb0
  %endif

  %ifdef USE_PREFETCH
    prefetchnta [Op1]
    prefetchnta [Op2]
    mov     EBP, 512            ; Attn: check if redefining Offs
  %endif

    ; prepare shift & addition with loop-unrolling 8
    xor     Limb0, Limb0
    lahf                        ; memorize clear carry (from "xor")

    test    Size, 1             ; a good R8 / R16 / R32 macro would help!
    je      .lShl1SubEquTwo

    sahf
    mov     Limb1, [Op1]
    sbb     Limb1, [Op2]
    lahf

    shrd    Limb0, Limb1, 63
    mov     [Op3], Limb0

    add     Op1, 8
    add     Op2, 8
    add     Op3, 8
    mov     Limb0, Limb1

  .lShl1SubEquTwo:

    test    Size, 2             ; a good R8 / R16 / R32 macro would help!
    je      .lShl1SubEquFour

    sahf
    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    sbb     Limb1, [Op2]
    sbb     Limb2, [Op2+8]
    lahf

    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1

    add     Op1, 16
    add     Op2, 16
    add     Op3, 16
    mov     Limb0, Limb2

  .lShl1SubEquFour:

    test    Size, 4             ; a good R8 / R16 / R32 macro would help!
    je      .lShl1SubEquCheck   ; enter main loop =>

    sahf
    mov     Limb1, [Op1]
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    sbb     Limb1, [Op2]
    sbb     Limb2, [Op2+8]
    sbb     Limb3, [Op2+16]
    sbb     Limb4, [Op2+24]
    lahf

    shrd    Limb0, Limb1, 63
    shrd    Limb1, Limb2, 63
    shrd    Limb2, Limb3, 63
    shrd    Limb3, Limb4, 63
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3

    add     Op1, 32
    add     Op2, 32
    add     Op3, 32
    mov     Limb0, Limb4
    jmp     .lShl1SubEquCheck   ; enter main-loop =>

    ; main loop: <1.3 cycles per limb in L1$
    ; combining elements in multiples of four prooved fastest on Skylake
    align   32
  .lShl1SubEquLoop:

  %ifdef USE_PREFETCH
    prefetchnta [Op1+Offs]
    prefetchnta [Op2+Offs]
  %endif

    sahf                        ; restore carry ...
    mov     Limb1, [Op1]        ; prepare added oct-limb from Op1 and Op2
    mov     Limb2, [Op1+8]
    mov     Limb3, [Op1+16]
    mov     Limb4, [Op1+24]
    sbb     Limb1, [Op2]
    sbb     Limb2, [Op2+8]
    sbb     Limb3, [Op2+16]
    sbb     Limb4, [Op2+24]
    mov     Limb5, [Op1+32]
    mov     Limb6, [Op1+40]
    mov     Limb7, [Op1+48]
    mov     Limb8, [Op1+56]
    sbb     Limb5, [Op2+32]
    sbb     Limb6, [Op2+40]
    sbb     Limb7, [Op2+48]
    sbb     Limb8, [Op2+56]
    lahf                        ; ... and memorize carry again

    shrd    Limb0, Limb1, 63    ; shift oct-limb and store in Op3
    shrd    Limb1, Limb2, 63
    shrd    Limb2, Limb3, 63
    shrd    Limb3, Limb4, 63
    mov     [Op3], Limb0
    mov     [Op3+8], Limb1
    mov     [Op3+16], Limb2
    mov     [Op3+24], Limb3
    shrd    Limb4, Limb5, 63
    shrd    Limb5, Limb6, 63
    shrd    Limb6, Limb7, 63
    shrd    Limb7, Limb8, 63
    mov     [Op3+32], Limb4
    mov     [Op3+40], Limb5
    mov     [Op3+48], Limb6
    mov     [Op3+56], Limb7

    add     Op1, 64
    add     Op2, 64
    add     Op3, 64
    mov     Limb0, Limb8

  .lShl1SubEquCheck:

    sub     Size, 8
    jnc     .lShl1SubEquLoop;

    ; housekeeping - hand back total carry
    shr     Limb0, 63
    sahf
    sbb     Limb0, 0            ; Limb0=-1..1 depending on carry and shift!
    mov     RAX, Limb0

  .Exit:

  %ifdef USE_LINUX64
      mov   Limb0, [RSP]
      mov   Limb5, [RSP+8]
      mov   Limb6, [RSP+16]
      mov   Limb7, [RSP+24]
      mov   Limb8, [RSP+32]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+40]
      add   RSP, 48
    %else
      add   RSP, 40
    %endif
  %endif

  %ifdef USE_WIN64
      mov   Limb0, [RSP]
      mov   Limb1, [RSP+8]
      mov   Limb2, [RSP+16]
      mov   Limb5, [RSP+24]
      mov   Limb6, [RSP+32]
      mov   Limb7, [RSP+40]
      mov   Limb8, [RSP+48]
    %ifdef USE_PREFETCH
      mov   Offs, [RSP+56]
      sub   RSP, 64
    %else
      sub   RSP, 56
    %endif
  %endif

    ret


