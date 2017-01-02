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
; LP covers blocks A, B
%define RP rdi
%define LP rdi
; HP covers blocks C, D
%define HP rbp

GLOBAL_FUNC mpn_karasub
; requires n>=8
push rbp
push r12
push r13
push r14
push r15
push rdx
;rp is rdi
;tp is rsi
;n is rdx and put it on the stack
shr rdx, 1
;n2 is rdx
lea rcx, [rdx + rdx]		; rcx = 2*n2 = 2*rdx
lea HP, [LP + rcx*8]
xor eax, eax
; eax contains the carrys
lea LP, [RP + rdx*8 - 24]
lea TP, [TP + rdx*8 - 24]
lea HP, [HP + rdx*8 - 24]
mov ecx,3
sub rcx, rdx			; rcx = 3 - rdx = 3 - n/2
mov edx, 3
align 16
.Lp:	bt eax, 4
	mov r8, [LP + rdx*8]		; r8 = B[i]
	adc r8, [HP + rcx*8]		; r8 = B[i] + C[i]
	mov r9, [LP + rdx*8 + 8]	; r9 = B[i+1]
	adc r9, [HP + rcx*8 + 8]	; r9 = B[i+1] + C[i+1]
	mov r10, [LP + rdx*8 + 16]	; r10 = B[i+2]
	adc r10, [HP + rcx*8 + 16]	; r10 = B[i+2] + C[i+2]
	mov r11, [LP + rdx*8 + 24]	; r11 = B[i+3]
	adc r11, [HP + rcx*8 + 24]	; r11 = B[i+3] + C[i+3]
	adc eax, eax
	bt eax, 4
	mov r12, r8			; r12 = B[i] + C[i]
	mov r13, r9			; r13 = B[i+1] + C[i+1]
	mov r14, r10			; r14 = B[i+2] + C[i+2]
	mov r15, r11			; r15 = B[i+3] + C[i+3]
	adc r8, [LP + rcx*8]		; r8 = B[i] + C[i] + A[i]
	adc r9, [LP + rcx*8 + 8]	; r9 = B[i+1] + C[i+1] + A[i+1]
	adc r10, [LP + rcx*8 + 16]	; r10 = B[i+2] + C[i+2] + A[i+2]
	adc r11, [LP + rcx*8 + 24]	; r11 = B[i+3] + C[i+3] + A[i+3]
	adc eax, eax
	bt eax, 4
	adc r12, [HP + rdx*8]		; r12 = B[i] + C[i] + D[i]
	adc r13, [HP + rdx*8 + 8]	; r13 = B[i+1] + C[i+1] + D[i+1]
	adc r14, [HP + rdx*8 + 16]	; r14 = B[i+2] + C[i+2] + D[i+2]
	adc r15, [HP + rdx*8 + 24]	; r15 = B[i+3] + C[i+3] + D[i+3]
	adc eax, eax
	bt eax, 4
	sbb r8, [TP + rcx*8]		; r8 = B[i] + C[i] + A[i] - E[i]
	sbb r9, [TP + rcx*8 + 8]	; r9 = B[i+1] + C[i+1] + A[i+1] - E[i+1]
	sbb r10, [TP + rcx*8 + 16]	; r10 = B[i+2] + C[i+2] + A[i+2] - E[i+2]
	sbb r11, [TP + rcx*8 + 24]	; r11 = B[i+3] + C[i+3] + A[i+3] - E[i+3]
	mov [LP + rdx*8], r8		; B[i] = B[i] + C[i] + A[i] - E[i]
	mov [LP + rdx*8 + 8], r9	; B[i+1] = B[i+1] + C[i+1] + A[i+1] - E[i+1]
	mov [LP + rdx*8 + 16], r10	; B[i+2] = B[i+2] + C[i+2] + A[i+2] - E[i+2]
	mov [LP + rdx*8 + 24], r11	; B[i+3] = B[i+3] + C[i+3] + A[i+3] - E[i+3]
	adc eax, eax
	bt eax, 4
	sbb r12, [TP + rdx*8]		; r12 = B[i] + C[i] + D[i] - F[i]
	sbb r13, [TP + rdx*8 + 8]	; r13 = B[i+1] + C[i+1] + D[i+1] - F[i+1]
	sbb r14, [TP + rdx*8 + 16]	; r14 = B[i+2] + C[i+2] + D[i+2] - F[i+2]
	sbb r15, [TP + rdx*8 + 24]	; r15 = B[i+3] + C[i+3] + D[i+3] - F[i+3]
	adc eax, eax
	add rdx,4
	mov [HP + rcx*8], r12		; C[i] = B[i] + C[i] + D[i] - F[i]
	mov [HP + rcx*8 + 8], r13	; C[i+1] = B[i+1] + C[i+1] + D[i+1] - F[i+1]
	mov [HP + rcx*8 + 16], r14	; C[i+2] = B[i+2] + C[i+2] + D[i+2] - F[i+2]
	mov [HP + rcx*8 + 24], r15	; C[i+3] = B[i+3] + C[i+3] + D[i+3] - F[i+3]
	add rcx,4
	jnc .Lp

; Previously,
; Bits of rbx contain carries of
; 0		1	2
; (B+C+D)-F	(B+C)+D	B+C
; Bits of rax contain carries of
; 0		1
; (B+C+A)-E	(B+C)+A

; Now bits of eax contain carries of:
; 0		1		2	3	4
; (B+C+D)-F	(B+C+A)-E	(B+C)+D	(B+C)+A	B+C

cmp rcx,2
jg	.Lcase0
jz	.Lcase1
jp	.Lcase2
.Lcase3:	;rcx=0
	bt eax, 4
	mov r8, [LP + rdx*8]
	adc r8, [HP]
	mov r12, r8
	mov r9, [LP + rdx*8 + 8]
	adc r9, [HP + 8]
	mov r10, [LP + rdx*8 + 16]
	adc r10, [HP + 16]
	adc eax, eax
	bt eax, 4
	adc r8, [LP]
	mov r13, r9
	adc r9, [LP + 8]
	mov r14, r10
	adc r10, [LP + 16]
	adc eax, eax
	bt eax, 4
	adc r12, [HP + rdx*8]
	adc r13, [HP + rdx*8 + 8]
	adc r14, [HP + rdx*8 + 16]
	adc eax, eax
	bt eax, 4
	sbb r8, [TP]
	sbb r9, [TP + 8]
	sbb r10, [TP + 16]
	mov [LP + rdx*8 + 16], r10
	adc eax, eax
	bt eax, 4
	mov [LP + rdx*8], r8
	mov [LP + rdx*8 + 8], r9
	sbb r12, [TP + rdx*8]
	sbb r13, [TP + rdx*8 + 8]
	sbb r14, [TP + rdx*8 + 16]
	adc eax, eax
	add rdx,3
	mov [HP], r12
	mov [HP + 8], r13
	mov [HP + 16], r14
	jmp .Lfin
.Lcase2:	;rcx=1
	bt eax, 4
	mov r8, [LP + rdx*8]
	adc r8, [HP + 8]
	mov r12, r8
	mov r9, [LP + rdx*8 + 8]
	adc r9, [HP + 16]
	adc eax, eax
	bt eax, 4
	adc r8, [LP + 8]
	mov r13, r9
	adc r9, [LP + 16]
	adc eax, eax
	bt eax, 4
	adc r12, [HP + rdx*8]
	adc r13, [HP + rdx*8 + 8]
	adc eax, eax
	bt eax, 4
	sbb r8, [TP + 8]
	sbb r9, [TP + 16]
	adc eax, eax
	bt eax, 4
	mov [LP + rdx*8], r8
	mov [LP + rdx*8 + 8], r9
	sbb r12, [TP + rdx*8]
	sbb r13, [TP + rdx*8 + 8]
	adc eax, eax
	add rdx,2
	mov [HP + 8], r12
	mov [HP + 16], r13
	jmp .Lfin
.Lcase1:	;rcx=2
	bt eax, 4
	mov r8, [LP + rdx*8]
	adc r8, [HP + 16]
	mov r12, r8
	adc eax, eax
	bt eax, 4
	adc r8, [LP + 16]
	adc eax, eax
	bt eax, 4
	adc r12, [HP + rdx*8]
	adc eax, eax
	bt eax, 4
	sbb r8, [TP + 16]
	adc eax, eax
	bt eax, 4
	mov [LP + rdx*8], r8
	sbb r12, [TP + rdx*8]
	adc eax, eax
	add rdx, 1
	mov [HP + rcx*8], r12
.Lfin:	mov rcx,3
.Lcase0: 	;rcx=3
	; store top two words of H as carrys could change them
	; eax is read-only past this point
	pop r15
	bt r15, 0
	jnc .Lskipload
	mov r12, [HP + rdx*8]
        mov r13, [HP + rdx*8 + 8]
	; the two carrys from 2nd to 3rd
.Lskipload:
	mov r11, rdx
	xor r8, r8
; was	bt rax, 1 ; carry of (B+C)+A
	bt eax, 3 ; carry of (B+C)+A
	adc r8, r8
; was	bt rbx, 2 ; carry of B+C
	bt eax, 4 ; carry of B+C
	adc r8,0
	add [LP + rdx*8], r8
.L2:	adc qword [LP + rdx*8 + 8], 0
	lea rdx, [rdx + 1]
	jc .L2
	; the two carrys from 3rd to 4th
	xor r8, r8
; was	bt rbx, 1 ; carry of (B+C)+D
	bt eax, 2 ; carry of (B+C)+D
	adc r8, r8
; was	bt rbx, 2 ; carry of B+C
	bt eax, 4 ; carry of B+C
	adc r8,0
	add [HP + rcx*8], r8
.L3:	adc qword [HP + rcx*8 + 8], 0
	lea rcx, [rcx + 1]
	jc .L3
	; now the borrow from 2nd to 3rd
	mov rdx, r11
; was	bt rax, 0 ; carry of (B+C+A)-E
	bt eax, 1 ; carry of (B+C+A)-E
.L1:	sbb qword [LP + rdx*8], 0
	lea rdx, [rdx + 1]
	jc .L1
	; borrow from 3rd to 4th
	mov rcx,3
; was	bt rbx, 0 ; carry of (B+C+D)-F
	bt eax, 0 ; carry of (B+C+D)-F
.L4:	sbb qword [HP + rcx*8], 0
	lea rcx, [rcx + 1]
	jc .L4
	; if odd the do next two
	mov rcx,3
	mov rdx, r11
	bt r15, 0
	jnc .Lnotodd
	xor r10, r10
	sub r12, [TP + rdx*8]
	sbb r13, [TP + rdx*8 + 8]
	rcl r10, 1
	add [HP + 24], r12
	adc [HP + 32], r13
	mov r8,0
	adc r8, r8
	bt r10, 0
	sbb r8,0
.L7:	add [HP + rcx*8 + 16], r8
	adc r8,0
	add rcx, 1
	sar r8, 1
	jnz .L7
.Lnotodd:
pop r15
pop r14
pop r13
pop r12
pop rbp
ret
