; =============================================================================
; Elementary Arithmetic Assembler Routines using AVX
; for Intel Architectures Haswell, Broadwell and Skylake
;
; (c) Jens Nurmann - 2016
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
; ----------------------------------------------------------------------------
; History:
;
; Date       Author Version Action
; ---------- ------ ------- --------------------------------------------------
; 28.03.2016 jn     0.00.01 generated excerpt for MPIR containing
;                           - lCmp
;                           - lCpyInc
;                           - lCpyDec
;                           - lShr1Equ
;                           - lShl1Equ
;                           - lShrEqu
;                           - lShlEqu
; ============================================================================

%define     USE_LINUX64
;%define     USE_WIN64
;%define     USE_PREFETCH

segment     .text

