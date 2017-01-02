;  mpn_karasub

;  Copyright 2011,2012 The Code Cavern

;  This file is part of the MPIR Library.

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

;  void mpn_karasub(mp_ptr, mp_ptr, mp_size_t)
;  rax                 rdi     rsi        rdx
;  rax                 rcx     rdx         r8
;
;  Karasuba Multiplication - split x and y into two equal length halves so
;  that x = xh.B + xl and y = yh.B + yl. Then their product is:
;
;  x.y = xh.yh.B^2 + (xh.yl + xl.yh).B + xl.yl
;      = xh.yh.B^2 + (xh.yh + xl.yl - {xh - xl}.{yh - yl}).B + xl.yl
;
; If the length of the elements is m (about n / 2), the output length is 4 * m 
; as illustrated below.  The middle two blocks involve three additions and one 
; subtraction: 
; 
;       -------------------- rp
;       |                  |-->
;       |   A:xl.yl[lo]    |   |
;       |                  |   |      (xh - xl).(yh - yl)
;       --------------------   |      -------------------- tp
;  <--  |                  |<--<  <-- |                  |
; |     |   B:xl.yl[hi]    |   |      |     E:[lo]       |
; |     |                  |   |      |                  |
; |     --------------------   |      --------------------
; >-->  |                  |-->   <-- |                  |
; |\___ |   C:xh.yh[lo]    | ____/    |     F:[hi]       |
; |     |                  |          |                  |
; |     --------------------          --------------------
;  <--  |                  |   
;       |   D:xh.yh[hi]    |
;       |                  |
;       --------------------
;
; To avoid overwriting B before it is used, we need to do two operations
; in parallel:
;
; (1)   B = B + C + A - E = (B + C) + A - E
; (2)   C = C + B + D - F = (B + C) + D - F
;
; The final carry from (1) has to be propagated into C and and, D the final
; carry from (2) has to be propagated into D. When the number of input limbs
; is odd, some extra operations have to be undertaken. 

%include 'yasm_mac.inc'

BITS 64

%define TP rsi
%define RP rdi

%define A_P rdi
%define B_P rbx
%define C_P rcx
%define D_P rdx
%define E_P rsi
%define F_P rbp

GLOBAL_FUNC mpn_karasub
; requires n>=8
push rbp
push rbx
push r12
push r13
push r14
push r15
push rdx
; n is rdx and put it on the stack
and rdx, -1			; rdx = 2*floor(n/2)
shl rdx, 2			; rdx = 8*floor(n/2)
; eax contains the carrys
; A_P = RP
; B_P = RP + (n/2)*8
; C_P = RP + 2*(n/2)*8
; D_P = RP + 3*(n/2)*8
; E_P = TP
; F_P = TP + (n/2)*8
lea B_P, [RP + rdx]
lea C_P, [RP + rdx*2]
lea F_P, [RP + rdx]
lea D_P, [RP + rdx*2 + rdx]	; overwrites rdx
lea rax, [B_P - 3*8]
mov [rsp], rax			; for testing end of main loop
xor eax, eax
align 16
.Lp:	bt eax, 4
	mov r8, [B_P]		; r8 = B[i]
	adc r8, [C_P]		; r8 = B[i] + C[i]
	mov r9, [B_P + 8]	; r9 = B[i+1]
	adc r9, [C_P + 8]	; r9 = B[i+1] + C[i+1]
	mov r10, [B_P + 16]	; r10 = B[i+2]
	adc r10, [C_P + 16]	; r10 = B[i+2] + C[i+2]
	mov r11, [B_P + 24]	; r11 = B[i+3]
	adc r11, [C_P + 24]	; r11 = B[i+3] + C[i+3]
	adc eax, eax
	bt eax, 4
	mov r12, r8		; r12 = B[i] + C[i]
	mov r13, r9		; r13 = B[i+1] + C[i+1]
	mov r14, r10		; r14 = B[i+2] + C[i+2]
	mov r15, r11		; r15 = B[i+3] + C[i+3]
	adc r8, [A_P]		; r8 = B[i] + C[i] + A[i]
	adc r9, [A_P + 8]	; r9 = B[i+1] + C[i+1] + A[i+1]
	adc r10, [A_P + 16]	; r10 = B[i+2] + C[i+2] + A[i+2]
	adc r11, [A_P + 24]	; r11 = B[i+3] + C[i+3] + A[i+3]
	adc eax, eax
	bt eax, 4
	adc r12, [D_P]		; r12 = B[i] + C[i] + D[i]
	adc r13, [D_P + 8]	; r13 = B[i+1] + C[i+1] + D[i+1]
	adc r14, [D_P + 16]	; r14 = B[i+2] + C[i+2] + D[i+2]
	adc r15, [D_P + 24]	; r15 = B[i+3] + C[i+3] + D[i+3]
	adc eax, eax
	bt eax, 4
	sbb r8, [E_P]		; r8 = B[i] + C[i] + A[i] - E[i]
	sbb r9, [E_P + 8]	; r9 = B[i+1] + C[i+1] + A[i+1] - E[i+1]
	sbb r10, [E_P + 16]	; r10 = B[i+2] + C[i+2] + A[i+2] - E[i+2]
	sbb r11, [E_P + 24]	; r11 = B[i+3] + C[i+3] + A[i+3] - E[i+3]
	mov [B_P], r8		; B[i] = B[i] + C[i] + A[i] - E[i]
	mov [B_P + 8], r9	; B[i+1] = B[i+1] + C[i+1] + A[i+1] - E[i+1]
	mov [B_P + 16], r10	; B[i+2] = B[i+2] + C[i+2] + A[i+2] - E[i+2]
	mov [B_P + 24], r11	; B[i+3] = B[i+3] + C[i+3] + A[i+3] - E[i+3]
	adc eax, eax
	bt eax, 4
	sbb r12, [F_P]		; r12 = B[i] + C[i] + D[i] - F[i]
	sbb r13, [F_P + 8]	; r13 = B[i+1] + C[i+1] + D[i+1] - F[i+1]
	sbb r14, [F_P + 16]	; r14 = B[i+2] + C[i+2] + D[i+2] - F[i+2]
	sbb r15, [F_P + 24]	; r15 = B[i+3] + C[i+3] + D[i+3] - F[i+3]
	adc eax, eax
	mov [C_P], r12		; C[i] = B[i] + C[i] + D[i] - F[i]
	mov [C_P + 8], r13	; C[i+1] = B[i+1] + C[i+1] + D[i+1] - F[i+1]
	mov [C_P + 16], r14	; C[i+2] = B[i+2] + C[i+2] + D[i+2] - F[i+2]
	mov [C_P + 24], r15	; C[i+3] = B[i+3] + C[i+3] + D[i+3] - F[i+3]
	lea A_P, [A_P + 4*8]
	lea B_P, [B_P + 4*8]
	lea C_P, [C_P + 4*8]
	lea D_P, [D_P + 4*8]
	lea E_P, [E_P + 4*8]
	lea F_P, [F_P + 4*8]
	cmp A_P, [rsp]
	jc .Lp

; Bits of eax contain carries of:
; 0		1		2	3	4
; (B+C+D)-F	(B+C+A)-E	(B+C)+D	(B+C)+A	B+C

	mov r8, [rsp]		; FIXME: improve this
	add r8, 3*8		; original value of B_P
	sub r8, B_P
	shr r8, 3
	cmp r8, 2
	jg	.Lcase0
	jz	.Lcase1
	jp	.Lcase2
.Lcase3:	;rcx=0
	bt eax, 4
	mov r8, [B_P]
	adc r8, [C_P]
	mov r9, [B_P + 8]
	adc r9, [C_P + 8]
	mov r10, [B_P + 16]
	adc r10, [C_P + 16]
	adc eax, eax
	bt eax, 4
	mov r12, r8
	mov r13, r9
	mov r14, r10
	adc r8, [A_P]
	adc r9, [A_P + 8]
	adc r10, [A_P + 16]
	adc eax, eax
	bt eax, 4
	adc r12, [D_P]
	adc r13, [D_P + 8]
	adc r14, [D_P + 16]
	adc eax, eax
	bt eax, 4
	sbb r8, [E_P]
	sbb r9, [E_P + 8]
	sbb r10, [E_P + 16]
	adc eax, eax
	bt eax, 4
	mov [B_P], r8
	mov [B_P + 8], r9
	mov [B_P + 16], r10
	sbb r12, [F_P]
	sbb r13, [F_P + 8]
	sbb r14, [F_P + 16]
	adc eax, eax
	mov [C_P], r12
	mov [C_P + 8], r13
	mov [C_P + 16], r14
	lea A_P, [A_P + 3*8]
	lea B_P, [B_P + 3*8]
	lea C_P, [C_P + 3*8]
	lea D_P, [D_P + 3*8]
	lea E_P, [E_P + 3*8]
	lea F_P, [F_P + 3*8]
	jmp .Lfin
.Lcase2:
	bt eax, 4
	mov r8, [B_P]
	adc r8, [C_P]
	mov r9, [B_P + 8]
	adc r9, [C_P + 8]
	adc eax, eax
	mov r12, r8
	mov r13, r9
	bt eax, 4
	adc r8, [A_P]
	adc r9, [A_P + 8]
	adc eax, eax
	bt eax, 4
	adc r12, [D_P]
	adc r13, [D_P + 8]
	adc eax, eax
	bt eax, 4
	sbb r8, [E_P]
	sbb r9, [E_P + 8]
	adc eax, eax
	bt eax, 4
	mov [B_P], r8
	mov [B_P + 8], r9
	sbb r12, [F_P]
	sbb r13, [F_P + 8]
	adc eax, eax
	add rdx,2
	mov [C_P], r12
	mov [C_P + 8], r13
	lea A_P, [A_P + 2*8]
	lea B_P, [B_P + 2*8]
	lea C_P, [C_P + 2*8]
	lea D_P, [D_P + 2*8]
	lea E_P, [E_P + 2*8]
	lea F_P, [F_P + 2*8]
	jmp .Lfin
.Lcase1:
	bt eax, 4
	mov r8, [B_P]
	adc r8, [C_P]
	mov r12, r8
	adc eax, eax
	bt eax, 4
	adc r8, [A_P + 16]
	adc eax, eax
	bt eax, 4
	adc r12, [D_P]
	adc eax, eax
	bt eax, 4
	sbb r8, [E_P]
	adc eax, eax
	bt eax, 4
	mov [B_P], r8
	sbb r12, [F_P]
	adc eax, eax
	mov [C_P], r12
	lea A_P, [A_P + 1*8]
	lea B_P, [B_P + 1*8]
	lea C_P, [C_P + 1*8]
	lea D_P, [D_P + 1*8]
	lea E_P, [E_P + 1*8]
	lea F_P, [F_P + 1*8]
.Lfin:
.Lcase0:
	; store top two words of H as carrys could change them
	pop r15
	bt r15, 0
	jnc .Lskipload
	mov r12, [D_P FIXME: what is correct offset here]
        mov r13, [D_P + 8 FIXME]
	; the two carrys from 2nd to 3rd
.Lskipload:
	xor r8, r8
	bt eax, 4 ; carry of B+C
	adc r8, r8
	mov r9, r8
	bt eax, 3 ; carry of (B+C)+A
	mov r10, B_P
	adc [B_P], r8
.L2:	adc qword [r10 + 8], 0
	lea r10, [r10 + 8]
	jc .L2
	; the two carrys from 3rd to 4th
	bt eax, 2 ; carry of (B+C)+D
	mov r10, C_P
	adc [C_P], r9
.L3:	adc qword [r10 + 8], 0
	lea r10, [r10 + 8]
	jc .L3
	; now the borrow from 2nd to 3rd
	mov r10, B_P
	bt eax, 1 ; carry of (B+C+A)-E
.L1:	sbb qword [r10], 0
	lea r10, [r10 + 8]
	jc .L1
	; borrow from 3rd to 4th
	bt eax, 0 ; carry of (B+C+D)-F
	mov r10, C_P
.L4:	sbb qword [r10], 0
	lea r10, [r10 + 8]
	jc .L4

	; if odd then do next two
	bt r15, 0
	jnc .Lnotodd

	sub r12, [F_P]
	sbb r13, [F_P + 8]
	sbb rax, rax
	add [C_P], r12
	adc [C_P + 8], r13
	adc rax, 0		; rax is -1, 0, or 1
.L7:	add [C_P], rax
	adc rax, 0
	lea C_P, [C_P + 8]
	sar rax, 1
	jnz .L7
.Lnotodd:
pop r15
pop r14
pop r13
pop r12
pop rbx
pop rbp
ret
