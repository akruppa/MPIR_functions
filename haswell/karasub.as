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

;%include 'yasm_mac.inc'

%define TP rsi
; LP covers blocks A, B
%define RP rdi
%define LP rdi
; HP covers blocks C, D
%define HP rbp

ASM_START()
GLOBAL_FUNC mpn_karasub
; requires n>=8
push rbx
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
xor rax, rax
xor rbx, rbx
; rax rbx are the carrys
lea LP, [RP + rdx*8 - 24]
lea TP, [TP + rdx*8 - 24]
lea HP, [HP + rdx*8 - 24]
mov ecx,3
sub rcx, rdx			; rcx = 3 - rdx = 3 - n/2
mov edx, 3
.align 16
.Lp:	bt 2, rbx
	mov r8, [LP + rdx*8]
	adc r8, [HP + rcx*8]
	mov r12, r8
	mov r9, [LP + rdx*8 + 8]
	adc r9, [HP + rcx*8 + 8]
	mov r10, [LP + rdx*8 + 16]
	adc r10, [HP + rcx*8 + 16]
	mov r11, [LP + rdx*8 + 24]
	adc r11, [HP + rcx*8 + 24]
	adc rbx, rbx
	bt 1, rax
	mov r15, r11
	adc r8, [LP + rcx*8]
	mov r13, r9
	adc r9, [LP + rcx*8 + 8]
	mov r14, r10
	adc r10, [LP + rcx*8 + 16]
	adc r11, [LP + rcx*8 + 24]
	adc rax, rax
	bt 2, rbx
	adc r12, [HP + rdx*8]
	adc r13, [HP + rdx*8 + 8]
	adc r14, [HP + rdx*8 + 16]
	adc r15, [HP + rdx*8 + 24]
	adc rbx, rbx
	bt 1, rax
	sbb r8, [TP + rcx*8]
	sbb r9, [TP + rcx*8 + 8]
	sbb r10, [TP + rcx*8 + 16]
	sbb r11, [TP + rcx*8 + 24]
	mov [LP + rdx*8 + 16], r10
	mov [LP + rdx*8 + 24], r11
	adc rax, rax
	bt 2, rbx
	mov [LP + rdx*8], r8
	mov [LP + rdx*8 + 8], r9
	sbb r12, [TP + rdx*8]
	sbb r13, [TP + rdx*8 + 8]
	sbb r14, [TP + rdx*8 + 16]
	sbb r15, [TP + rdx*8 + 24]
	adc rbx, rbx
	add rdx,4
	mov [HP + rcx*8], r12
	mov [HP + rcx*8 + 8], r13
	mov [HP + rcx*8 + 16], r14
	mov [HP + rcx*8 + 24], r15
	add rcx,4
	jnc .Lp
cmp rcx,2
jg	.Lcase0
jz	.Lcase1
jp	.Lcase2
.Lcase3:	;rcx=0
	bt 2, rbx
	mov r8, [LP + rdx*8]
	adc r8, [HP]
	mov r12, r8
	mov r9, [LP + rdx*8 + 8]
	adc r9, [HP + 8]
	mov r10, [LP + rdx*8 + 16]
	adc r10, [HP + 16]
	adc rbx, rbx
	bt 1, rax
	adc r8, [LP]
	mov r13, r9
	adc r9, [LP + 8]
	mov r14, r10
	adc r10, [LP + 16]
	adc rax, rax
	bt 2, rbx
	adc r12, [HP + rdx*8]
	adc r13, [HP + rdx*8 + 8]
	adc r14, [HP + rdx*8 + 16]
	adc rbx, rbx
	bt 1, rax
	sbb r8, [TP]
	sbb r9, [TP + 8]
	sbb r10, [TP + 16]
	mov [LP + rdx*8 + 16], r10
	adc rax, rax
	bt 2, rbx
	mov [LP + rdx*8], r8
	mov [LP + rdx*8 + 8], r9
	sbb r12, [TP + rdx*8]
	sbb r13, [TP + rdx*8 + 8]
	sbb r14, [TP + rdx*8 + 16]
	adc rbx, rbx
	add rdx,3
	mov [HP], r12
	mov [HP + 8], r13
	mov [HP + 16], r14
	jmp .Lfin
.Lcase2:	;rcx=1
	bt 2, rbx
	mov r8, [LP + rdx*8]
	adc r8, [HP + 8]
	mov r12, r8
	mov r9, [LP + rdx*8 + 8]
	adc r9, [HP + 16]
	adc rbx, rbx
	bt 1, rax
	adc r8, [LP + 8]
	mov r13, r9
	adc r9, [LP + 16]
	adc rax, rax
	bt 2, rbx
	adc r12, [HP + rdx*8]
	adc r13, [HP + rdx*8 + 8]
	adc rbx, rbx
	bt 1, rax
	sbb r8, [TP + 8]
	sbb r9, [TP + 16]
	adc rax, rax
	bt 2, rbx
	mov [LP + rdx*8], r8
	mov [LP + rdx*8 + 8], r9
	sbb r12, [TP + rdx*8]
	sbb r13, [TP + rdx*8 + 8]
	adc rbx, rbx
	add rdx,2
	mov [HP + 8], r12
	mov [HP + 16], r13
	jmp .Lfin
.Lcase1:	;rcx=2
	bt 2, rbx
	mov r8, [LP + rdx*8]
	adc r8, [HP + 16]
	mov r12, r8
	adc rbx, rbx
	bt 1, rax
	adc r8, [LP + 16]
	adc rax, rax
	bt 2, rbx
	adc r12, [HP + rdx*8]
	adc rbx, rbx
	bt 1, rax
	sbb r8, [TP + 16]
	adc rax, rax
	bt 2, rbx
	mov [LP + rdx*8], r8
	sbb r12, [TP + rdx*8]
	adc rbx, rbx
	add rdx, 1
	mov [HP + rcx*8], r12
.Lfin:	mov rcx,3
.Lcase0: 	;rcx=3
	;// store top two words of H as carrys could change them
	pop r15
	bt 0, r15
	jnc .Lskipload
	mov r12, [HP + rdx*8]
        mov r13, [HP + rdx*8 + 8]
	;// the two carrys from 2nd to 3rd
.Lskipload:	mov r11, rdx
	xor r8, r8
	bt 1, rax
	adc r8, r8
	bt 2, rbx
	adc r8,0
	add [LP + rdx*8], r8
.L2:	adc [LP + rdx*8 + 8],0
	lea rdx, [rdx + 1]
	jc .L2
	; //the two carrys from 3rd to 4th
	xor r8, r8
	bt 1, rbx
	adc r8, r8
	bt 2, rbx
	adc r8,0
	add [HP + rcx*8], r8
.L3:	adc [HP + rcx*8 + 8],0
	lea rcx, [rcx + 1]
	jc .L3
	;// now the borrow from 2nd to 3rd
	mov rdx, r11
	bt 0, rax
.L1:	sbb [LP + rdx*8],0
	lea rdx, [rdx + 1]
	jc .L1
	;// borrow from 3rd to 4th
	mov rcx,3
	bt 0, rbx
.L4:	sbb [HP + rcx*8],0
	lea rcx, [rcx + 1]
	jc .L4
	;// if odd the do next two
	mov rcx,3
	mov rdx, r11
	bt 0, r15
	jnc .Lnotodd
	xor r10, r10
	sub r12, [TP + rdx*8]
	sbb r13, [TP + rdx*8 + 8]
	rcl 1, r10
	add [HP + 24], r12
	adc [HP + 32], r13
	mov r8,0
	adc r8, r8
	bt 0, r10
	sbb r8,0
.L7:	add [HP + rcx*8 + 16], r8
	adc r8,0
	add rcx, 1
	sar 1, r8
	jnz .L7
.Lnotodd:
pop r15
pop r14
pop r13
pop r12
pop rbp
pop rbx
ret
EPILOGUE()
