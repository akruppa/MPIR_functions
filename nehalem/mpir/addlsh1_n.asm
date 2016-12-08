; PROLOGUE(mpn_addlsh1_n)

;  Copyright 2008 Jason Moxham
;
;  This file is part of the MPIR Library.
;
;  Windows Conversion Copyright 2008 Brian Gladman
;
;  The MPIR Library is free software; you can redistribute it and/or modify
;  it under the terms of the GNU Lesser General Public License as published
;  by the Free Software Foundation; either version 2.1 of the License, or (at
;  your option) any later version.
;  The MPIR Library is distributed in the hope that it will be useful, but
;  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
;  License for more details.
;  You should have received a copy of the GNU Lesser General Public License
;  along with the MPIR Library; see the file COPYING.LIB.  If not, write
;  to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;  Boston, MA 02110-1301, USA.
;
;  mp_limb_t mpn_addlsh1_n(mp_ptr, mp_ptr, mp_ptr, mp_size_t)
;  rax                        rdi     rsi     rdx        rcx
;  rax                        rcx     rdx      r8         r9

%include "yasm_mac.inc"


    BITS 64

; Linux      RDI  RSI         RDX             RCX         :RAX
; Win7       RCX  RDX         R8              R9          :RAX

%ifdef Use_Win64

CPU  Core2

%define RP   rcx
%define S1P  rdx
%define S2P  r8
%define Size r9
%define T1   rsi
%define T2   rdi

%else

%define RP   rdi
%define S1P  rsi
%define S2P  rdx
%define Size rcx
%define T1   r8
%define T2   r9

%endif

%define T3   rbx
%define T4   r10
%define T5   r11
%define T6   rax

%ifdef Use_Win64
    %define reg_save_list rbx, rsi, rdi
    FRAME_PROC mpn_addlsh1_n, 0, reg_save_list
%else
    GLOBAL_FUNC mpn_addlsh1_n
    push    rbx
%endif

    lea     S1P, [S1P+Size*8]
    lea     S2P, [S2P+Size*8]
    lea     RP, [RP+Size*8]
    neg     Size
    xor     T1, T1
    xor     T6, T6
    test    Size, 3
    jz      .2
.1:	mov     T2, [S2P+Size*8]
    add     T1, 1
    adc     T2, T2
    sbb     T1, T1
    add     T6, 1
    adc     T2, [S1P+Size*8]
    sbb     T6, T6
    mov     [RP+Size*8], T2
    add     Size, 1           ; ***
    test    Size, 3
    jnz     .1
.2: cmp     Size, 0
    jz      .4

    align  16
.3: mov     T2, [S2P+Size*8]
    mov     T3, [S2P+Size*8+8]
    mov     T4, [S2P+Size*8+16]
    mov     T5, [S2P+Size*8+24]
    add     T1, 1
    adc     T2, T2
    adc     T3, T3
    adc     T4, T4
    adc     T5, T5
    sbb     T1, T1
    add     T6, 1
    adc     T2, [S1P+Size*8]
    adc     T3, [S1P+Size*8+8]
    adc     T4, [S1P+Size*8+16]
    adc     T5, [S1P+Size*8+24]
    sbb     T6, T6
    mov     [RP+Size*8], T2
    mov     [RP+Size*8+8], T3
    mov     [RP+Size*8+16], T4
    mov     [RP+Size*8+24], T5
    add     Size, 4
    jnz     .3
.4: add     T6, T1
    neg     T6
%ifdef Use_Win64
    END_PROC reg_save_list
%else
    pop     rbx
    ret
%endif

    end
