;  AMD64 mpn_mul_basecase optimised for Intel Broadwell.

;  Copyright 2015 Free Software Foundation, Inc.

;  This file is part of the GNU MP Library.
;
;  The GNU MP Library is free software; you can redistribute it and/or modify
;  it under the terms of either:
;
;    * the GNU Lesser General Public License as published by the Free
;      Software Foundation; either version 3 of the License, or (at your
;      option) any later version.
;
;  or
;
;    * the GNU General Public License as published by the Free Software
;      Foundation; either version 2 of the License, or (at your option) any
;      later version.
;
;  or both in parallel, as here.
;
;  The GNU MP Library is distributed in the hope that it will be useful, but
;  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
;  for more details.
;
;  You should have received copies of the GNU General Public License and the
;  GNU Lesser General Public License along with the GNU MP Library.  If not,
;  see https://www.gnu.org/licenses/.

%include 'yasm_mac.inc'

; cycles/limb	mul_1		addmul_1
; AMD K8,K9	n/a		n/a
; AMD K10	n/a		n/a
; AMD bull	n/a		n/a
; AMD pile	n/a		n/a
; AMD steam	n/a		n/a
; AMD excavator	 ?		 ?
; AMD bobcat	n/a		n/a
; AMD jaguar	n/a		n/a
; Intel P4	n/a		n/a
; Intel core2	n/a		n/a
; Intel NHM	n/a		n/a
; Intel SBR	n/a		n/a
; Intel IBR	n/a		n/a
; Intel HWL	 1.68		n/a
; Intel BWL	 1.69	      1.8-1.9
; Intel atom	n/a		n/a
; Intel SLM	n/a		n/a
; VIA nano	n/a		n/a

; The inner loops of this code are the result of running a code generation and
; optimisation tool suite written by David Harvey and Torbjorn Granlund.

; TODO
;  * Do overlapped software pipelining.
;  * When changing this, make sure the code which falls into the inner loops
;    does not execute too many no-ops (for both PIC and non-PIC).

%define rp rdi
%define up rsi
%define un_param rdx
%define un_param32 edx
%define vp_param rcx
%define vn r8

%define n rcx
%define n_save rbp
%define vp r14
%define unneg rbx
%define v0 rdx
%define jaddr rax

%define w0 r12
%define w1 r9
%define w2 r10
%define w3 r11





	section .text
	align 16
	GLOBAL_FUNC mpn_mul_basecase
	
%ifdef USE_WIN64
	mov	r8d, [rsp + 56]
%endif
	cmp	un_param, 2
	ja	.Lgen
	mov	rdx, [vp_param]
	mulx 	r9, rax, [up]	; 0 1
	je	.Ls2x

.Ls11:	mov	[rp], rax
	mov	[rp + 8], r9
	
	ret

.Ls2x:	cmp	vn, 2
	mulx 	r10, r8, [up + 8]	; 1 2
	je	.Ls22

.Ls21:	add	r9, r8
	adc	r10, 0
	mov	[rp], rax
	mov	[rp + 8], r9
	mov	[rp + 16], r10
	
	ret

.Ls22:	add	r9, r8		; 1
	adc	r10, 0		; 2
	mov	rdx, [vp_param + 8]
	mov	[rp], rax
	mulx 	r11, r8, [up]	; 1 2
	mulx 	rdx, rax, [up + 8]	; 2 3
	add	rax, r11		; 2
	adc	rdx, 0		; 3
	add	r9, r8		; 1
	adc	r10, rax		; 2
	adc	rdx, 0		; 3
	mov	[rp + 8], r9
	mov	[rp + 16], r10
	mov	[rp + 24], rdx
	
	ret

	align 16
.Lgen:
	push	rbx
	push	rbp
	push	r12
	push	r14

	mov	vp, vp_param
	lea	unneg, [un_param + 1]
	mov	n_save, un_param
	mov	eax, un_param32
	and	unneg, -8
	shr	n_save, 3		; loop count
	neg	unneg
	and	eax, 7			; clear CF for adc as side-effect
					; note that rax lives very long
	mov	n, n_save
	mov	v0, [vp]
	lea	vp, [vp + 8]

	lea	r10, [rel .Lmtab]
%ifdef PIC
	movsxd	r11, DWORD [r10+rax*4]
	lea	r10, [r11+r10]
	jmp	r10
%else
	jmp	[r10+rax*8]
%endif

.Lmf0:	mulx 	w3, w2, [up]
	lea	up, [up + 56]
	lea	rp, [rp - 8]
	jmp	.Lmb0

.Lmf3:	mulx 	w1, w0, [up]
	lea	up, [up + 16]
	lea	rp, [rp + 16]
	inc	n
	jmp	.Lmb3

.Lmf4:	mulx 	w3, w2, [up]
	lea	up, [up + 24]
	lea	rp, [rp + 24]
	inc	n
	jmp	.Lmb4

.Lmf5:	mulx 	w1, w0, [up]
	lea	up, [up + 32]
	lea	rp, [rp + 32]
	inc	n
	jmp	short .Lmb5 ; Force YASM to issue a short jump

.Lmf6:	mulx 	w3, w2, [up]
	lea	up, [up + 40]
	lea	rp, [rp + 40]
	inc	n
	jmp	.Lmb6

.Lmf7:	mulx 	w1, w0, [up]
	lea	up, [up + 48]
	lea	rp, [rp + 48]
	inc	n
	jmp	.Lmb7

.Lmf1:	mulx 	w1, w0, [up]
	jmp	.Lmb1

.Lmf2:	mulx 	w3, w2, [up]
	lea	up, [up + 8]
	lea	rp, [rp + 8]
	mulx 	w1, w0, [up]

	; align 16 ; YASM, being a two-pass assembler, cannot determine
        ; that .Lm1top is already 16-aligned if the above "jmp .Lmb5"
	; is encoded as a short jump
.Lm1top:
	mov	[rp - 8], w2
	adc	w0, w3
.Lmb1:	mulx 	w3, w2, [up + 8]
	adc	w2, w1
	lea	up, [up + 64]
	mov	[rp], w0
.Lmb0:	mov	[rp + 8], w2
	mulx 	w1, w0, [up - 48]
	lea	rp, [rp + 64]
	adc	w0, w3
.Lmb7:	mulx 	w3, w2, [up - 40]
	mov	[rp - 48], w0
	adc	w2, w1
.Lmb6:	mov	[rp - 40], w2
	mulx 	w1, w0, [up - 32]
	adc	w0, w3
.Lmb5:	mulx 	w3, w2, [up - 24]
	mov	[rp - 32], w0
	adc	w2, w1
.Lmb4:	mulx 	w1, w0, [up - 16]
	mov	[rp - 24], w2
	adc	w0, w3
.Lmb3:	mulx 	w3, w2, [up - 8]
	adc	w2, w1
	mov	[rp - 16], w0
	dec	n
	mulx 	w1, w0, [up]
	jnz	.Lm1top

.Lm1end:
	mov	[rp - 8], w2
	adc	w0, w3
	mov	[rp], w0
	adc	w1, rcx			; relies on rcx = 0
	mov	[rp + 8], w1

	dec	vn
	jz	.Ldone

	lea	r10, [rel .Latab]
%ifdef PIC
	movsxd	rax, DWORD [r10+rax*4]
	lea	jaddr, [rax+r10]
%else
	mov	jaddr, [r10+rax*8]
%endif

.Louter:
	lea	up, [up+unneg*8]
	mov	n, n_save
	mov	v0, [vp]
	lea	vp, [vp + 8]
	jmp	jaddr

.Lf0:	mulx 	w3, w2, [up + 8]
	lea	rp, [rp + unneg*8 + 8]
	lea	n, [n - 1]
	jmp	.Lb0

.Lf3:	mulx 	w1, w0, [up - 16]
	lea	rp, [rp + unneg*8 - 56]
	jmp	.Lb3

.Lf4:	mulx 	w3, w2, [up - 24]
	lea	rp, [rp + unneg*8 - 56]
	jmp	.Lb4

.Lf5:	mulx 	w1, w0, [up - 32]
	lea	rp, [rp + unneg*8 - 56]
	jmp	.Lb5

.Lf6:	mulx 	w3, w2, [up - 40]
	lea	rp, [rp + unneg*8 - 56]
	jmp	.Lb6

.Lf7:	mulx 	w1, w0, [up + 16]
	lea	rp, [rp + unneg*8 + 8]
	jmp	.Lb7

.Lf1:	mulx 	w1, w0, [up]
	lea	rp, [rp + unneg*8 + 8]
	jmp	.Lb1

.Lam1end:
	adox 	w0, [rp]
	adox 	w1, rcx			; relies on rcx = 0
	mov	[rp], w0
	adc	w1, rcx			; relies on rcx = 0
	mov	[rp + 8], w1

	dec	vn			; clear CF and OF as side-effect
	jnz	.Louter
.Ldone:
	pop	r14
	pop	r12
	pop	rbp
	pop	rbx
	
	ret

.Lf2:
	mulx 	w3, w2, [up - 8]
	lea	rp, [rp + unneg*8 + 8]
	mulx 	w1, w0, [up]

	align 16
.Lam1top:
	adox 	w2, [rp - 8]
	adcx 	w0, w3
	mov	[rp - 8], w2
	jrcxz	.Lam1end
.Lb1:	mulx 	w3, w2, [up + 8]
	adox 	w0, [rp]
	lea	n, [n - 1]
	mov	[rp], w0
	adcx 	w2, w1
.Lb0:	mulx 	w1, w0, [up + 16]
	adcx 	w0, w3
	adox 	w2, [rp + 8]
	mov	[rp + 8], w2
.Lb7:	mulx 	w3, w2, [up + 24]
	lea	up, [up + 64]
	adcx 	w2, w1
	adox 	w0, [rp + 16]
	mov	[rp + 16], w0
.Lb6:	mulx 	w1, w0, [up - 32]
	adox 	w2, [rp + 24]
	adcx 	w0, w3
	mov	[rp + 24], w2
.Lb5:	mulx 	w3, w2, [up - 24]
	adcx 	w2, w1
	adox 	w0, [rp + 32]
	mov	[rp + 32], w0
.Lb4:	mulx 	w1, w0, [up - 16]
	adox 	w2, [rp + 40]
	adcx 	w0, w3
	mov	[rp + 40], w2
.Lb3:	adox 	w0, [rp + 48]
	mulx 	w3, w2, [up - 8]
	mov	[rp + 48], w0
	lea	rp, [rp + 64]
	adcx 	w2, w1
	mulx 	w1, w0, [up]
	jmp	.Lam1top

	section .data
	align 8
%ifdef PIC
.Lmtab:	
	DD	.Lmf0 - .Lmtab
	DD	.Lmf1 - .Lmtab
	DD	.Lmf2 - .Lmtab
	DD	.Lmf3 - .Lmtab
	DD	.Lmf4 - .Lmtab
	DD	.Lmf5 - .Lmtab
	DD	.Lmf6 - .Lmtab
	DD	.Lmf7 - .Lmtab
.Latab:
 	DD	.Lf0 - .Latab
	DD	.Lf1 - .Latab
	DD	.Lf2 - .Latab
	DD	.Lf3 - .Latab
	DD	.Lf4 - .Latab
	DD	.Lf5 - .Latab
	DD	.Lf6 - .Latab
	DD	.Lf7 - .Latab
%else
.Lmtab:
	DQ	.Lmf0
	DQ	.Lmf1
	DQ	.Lmf2
	DQ	.Lmf3
	DQ	.Lmf4
	DQ	.Lmf5
	DQ	.Lmf6
	DQ	.Lmf7
.Latab:
	DQ	.Lf0
	DQ	.Lf1
	DQ	.Lf2
	DQ	.Lf3
	DQ	.Lf4
	DQ	.Lf5
	DQ	.Lf6
	DQ	.Lf7
%endif
	section .text
