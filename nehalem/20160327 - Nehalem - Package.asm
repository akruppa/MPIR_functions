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
