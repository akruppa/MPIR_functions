        .text
	.align	16, 0x90
	.globl	__gmpn_mul_basecase
	.type	__gmpn_mul_basecase,@function
__gmpn_mul_basecase:

	

	push	%rbx
	push	%rbp
	push	%r12
	push	%r13
	push	%r14
	mov	%rdx, %rbx		
	neg	%rbx

	mov	%rdx, %rbp		
	sar	$2, %rbp			

	test	$1, %r8b
	jz	.Ldo_mul_2 #ajs:notshortform
	mov	(%rcx), %rdx

.Ldo_mul_1:
	test	$1, %bl
	jnz	.Lm1x1

.Lm1x0:
	test	$2, %bl
	jnz	.Lm110

.Lm100:
	mulx 	(%rsi), %r14, %r12
	mulx 	8(%rsi), %r11, %r13
	lea	-24(%rdi), %rdi
	jmp     .Lm1l0 #ajs:notshortform

.Lm110:
	mulx 	(%rsi), %r13, %r9
	mulx 	8(%rsi), %r11, %r14
	lea	-8(%rdi), %rdi
	test	%rbp, %rbp
	jz	.Lcj2 #ajs:notshortform
	mulx 	16(%rsi), %r10, %r12
	lea	16(%rsi), %rsi
	jmp	.Lm1l2

.Lm1x1:
	test	$2, %bl
	jz	.Lm111

.Lm101:
	mulx 	(%rsi), %r9, %r14
	lea	-16(%rdi), %rdi
	test	%rbp, %rbp
	jz	.Lcj1 #ajs:notshortform
	mulx 	8(%rsi), %r10, %r12
	lea	8(%rsi), %rsi
	jmp	.Lm1l1

.Lm111:
	mulx 	(%rsi), %r12, %r13
	mulx 	8(%rsi), %r10, %r9
	mulx 	16(%rsi), %r11, %r14
	lea	24(%rsi), %rsi
	test	%rbp, %rbp
	jnz	.Lgt3
	add	%r10, %r13
	jmp	.Lcj3
.Lgt3:
		add	%r10, %r13
	jmp	.Lm1l3

	.align	32, 0x90
.Lm1tp:
	lea	32(%rdi), %rdi
.Lm1l3:
	mov	%r12, (%rdi)
	mulx 	(%rsi), %r10, %r12
.Lm1l2:
	mov	%r13, 8(%rdi)
	adc	%r11, %r9
.Lm1l1:
	adc	%r10, %r14
	mov	%r9, 16(%rdi)
	mulx 	8(%rsi), %r11, %r13
.Lm1l0:
	mov	%r14, 24(%rdi)
	mulx 	16(%rsi), %r10, %r9
	adc	%r11, %r12
	mulx 	24(%rsi), %r11, %r14
	adc	%r10, %r13
	lea	32(%rsi), %rsi
	dec	%rbp
	jnz	.Lm1tp

.Lm1ed:
	lea	32(%rdi), %rdi
.Lcj3:
		mov	%r12, (%rdi)
.Lcj2:
		mov	%r13, 8(%rdi)
	adc	%r11, %r9
.Lcj1:
		mov	%r9, 16(%rdi)
	adc	$0, %r14
	mov	%r14, 24(%rdi)

	dec	%r8d
	jz	.Lret5 #ajs:notshortform

	lea	8(%rcx), %rcx
	lea	32(%rdi), %rdi



	jmp	.Ldo_addmul #ajs:notshortform

.Ldo_mul_2:





	mov	(%rcx), %r9
	mov	8(%rcx), %r14

	lea	(%rbx), %rbp
	sar	$2, %rbp

	test	$1, %bl
	jnz	.Lm2x1

.Lm2x0:
	xor	%r10, %r10
	test	$2, %bl
	mov	(%rsi), %rdx
	mulx 	%r9, %r12, %r11
	jz	.Lm2l0

.Lm210:
	lea	-16(%rdi), %rdi
	lea	-16(%rsi), %rsi
	jmp	.Lm2l2 #ajs:notshortform

.Lm2x1:
	xor	%r12, %r12
	test	$2, %bl
	mov	(%rsi), %rdx
	mulx 	%r9, %r10, %r13
	jz	.Lm211

.Lm201:
	lea	-24(%rdi), %rdi
	lea	8(%rsi), %rsi
	jmp	.Lm2l1 #ajs:notshortform

.Lm211:
	lea	-8(%rdi), %rdi
	lea	-8(%rsi), %rsi
	jmp	.Lm2l3

	.align	16, 0x90
.Lm2tp:
	mulx 	%r14, %rax, %r10
	add	%rax, %r12
	mov	(%rsi), %rdx
	mulx 	%r9, %rax, %r11
	adc	$0, %r10
	add	%rax, %r12
	adc	$0, %r11
	add	%r13, %r12
.Lm2l0:
	mov	%r12, (%rdi)
	adc	$0, %r11
	mulx 	%r14, %rax, %r12
	add	%rax, %r10
	mov	8(%rsi), %rdx
	adc	$0, %r12
	mulx 	%r9, %rax, %r13
	add	%rax, %r10
	adc	$0, %r13
	add	%r11, %r10
.Lm2l3:
	mov	%r10, 8(%rdi)
	adc	$0, %r13
	mulx 	%r14, %rax, %r10
	add	%rax, %r12
	mov	16(%rsi), %rdx
	mulx 	%r9, %rax, %r11
	adc	$0, %r10
	add	%rax, %r12
	adc	$0, %r11
	add	%r13, %r12
.Lm2l2:
	mov	%r12, 16(%rdi)
	adc	$0, %r11
	mulx 	%r14, %rax, %r12
	add	%rax, %r10
	mov	24(%rsi), %rdx
	adc	$0, %r12
	mulx 	%r9, %rax, %r13
	add	%rax, %r10
	adc	$0, %r13
	add	%r11, %r10
	lea	32(%rsi), %rsi
.Lm2l1:
	mov	%r10, 24(%rdi)
	adc	$0, %r13
	inc	%rbp
	lea	32(%rdi), %rdi
	jnz	.Lm2tp

.Lm2ed:
	mulx 	%r14, %rdx, %rax
	add	%rdx, %r12
	adc	$0, %rax
	add	%r13, %r12
	mov	%r12, (%rdi)
	adc	$0, %rax
	mov	%rax, 8(%rdi)

	add	$-2, %r8d
	jz	.Lret5 #ajs:notshortform
	lea	16(%rcx), %rcx
	lea	16(%rdi), %rdi


.Ldo_addmul:
	push	%r15
	push	%r8			





	lea	(%rdi,%rbx,8), %rdi
	lea	(%rsi,%rbx,8), %rsi

.Louter:
	mov	(%rcx), %r9
	mov	8(%rcx), %r8

	lea	2(%rbx), %rbp
	sar	$2, %rbp

	mov	(%rsi), %rdx
	test	$1, %bl
	jnz	.Lbx1

.Lbx0:
		mov	(%rdi), %r14
	mov	8(%rdi), %r15
	mulx 	%r9, %rax, %r11
	add	%rax, %r14
	mulx 	%r8, %rax, %r12
	adc	$0, %r11
	mov	%r14, (%rdi)
	add	%rax, %r15
	adc	$0, %r12
	mov	8(%rsi), %rdx
	test	$2, %bl
	jnz	.Lb10

.Lb00:
		lea	16(%rsi), %rsi
	lea	16(%rdi), %rdi
	jmp	.Llo0 #ajs:notshortform

.Lb10:
		mov	16(%rdi), %r14
	lea	32(%rsi), %rsi
	mulx 	%r9, %rax, %r13
	jmp	.Llo2

.Lbx1:
		mov	(%rdi), %r15
	mov	8(%rdi), %r14
	mulx 	%r9, %rax, %r13
	add	%rax, %r15
	adc	$0, %r13
	mulx 	%r8, %rax, %r10
	add	%rax, %r14
	adc	$0, %r10
	mov	8(%rsi), %rdx
	mov	%r15, (%rdi)
	mulx 	%r9, %rax, %r11
	test	$2, %bl
	jz	.Lb11

.Lb01:
		mov	16(%rdi), %r15
	lea	24(%rdi), %rdi
	lea	24(%rsi), %rsi
	jmp	.Llo1

.Lb11:
		lea	8(%rdi), %rdi
	lea	8(%rsi), %rsi
	jmp	.Llo3 #ajs:notshortform

	.align	16, 0x90
.Ltop:
		mulx 	%r9, %rax, %r13
	add	%r10, %r15
	adc	$0, %r12
.Llo2:
		add	%rax, %r15
	adc	$0, %r13
	mulx 	%r8, %rax, %r10
	add	%rax, %r14
	adc	$0, %r10
	lea	32(%rdi), %rdi
	add	%r11, %r15
	mov	-16(%rsi), %rdx
	mov	%r15, -24(%rdi)
	adc	$0, %r13
	add	%r12, %r14
	mov	-8(%rdi), %r15
	mulx 	%r9, %rax, %r11
	adc	$0, %r10
.Llo1:
		add	%rax, %r14
	mulx 	%r8, %rax, %r12
	adc	$0, %r11
	add	%r13, %r14
	mov	%r14, -16(%rdi)
	adc	$0, %r11
	add	%rax, %r15
	adc	$0, %r12
	add	%r10, %r15
	mov	-8(%rsi), %rdx
	adc	$0, %r12
.Llo0:
		mulx 	%r9, %rax, %r13
	add	%rax, %r15
	adc	$0, %r13
	mov	(%rdi), %r14
	mulx 	%r8, %rax, %r10
	add	%rax, %r14
	adc	$0, %r10
	add	%r11, %r15
	mov	%r15, -8(%rdi)
	adc	$0, %r13
	mov	(%rsi), %rdx
	add	%r12, %r14
	mulx 	%r9, %rax, %r11
	adc	$0, %r10
.Llo3:
		add	%rax, %r14
	adc	$0, %r11
	mulx 	%r8, %rax, %r12
	add	%r13, %r14
	mov	8(%rdi), %r15
	mov	%r14, (%rdi)
	mov	16(%rdi), %r14
	adc	$0, %r11
	add	%rax, %r15
	adc	$0, %r12
	mov	8(%rsi), %rdx
	lea	32(%rsi), %rsi
	inc	%rbp
	jnz	.Ltop

.Lend:
		mulx 	%r9, %rax, %r13
	add	%r10, %r15
	adc	$0, %r12
	add	%rax, %r15
	adc	$0, %r13
	mulx 	%r8, %rdx, %rax
	add	%r11, %r15
	mov	%r15, 8(%rdi)
	adc	$0, %r13
	add	%r12, %rdx
	adc	$0, %rax
	add	%r13, %rdx
	mov	%rdx, 16(%rdi)
	adc	$0, %rax
	mov	%rax, 24(%rdi)

	addl	$-2, (%rsp)
	lea	16(%rcx), %rcx
	lea	-16(%rsi,%rbx,8), %rsi
	lea	32(%rdi,%rbx,8), %rdi
	jnz	.Louter

	pop	%rax		
	pop	%r15
.Lret5:
	pop	%r14
.Lret4:
	pop	%r13
.Lret3:
	pop	%r12
.Lret2:
	pop	%rbp
	pop	%rbx
	
	ret
	.size	__gmpn_mul_basecase,.-__gmpn_mul_basecase
