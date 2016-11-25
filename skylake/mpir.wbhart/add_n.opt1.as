# This file was produced by ajs, the MPIR assembly superoptimiser
# 285.000000 cycles/204 limbs

L0:
L1:
	mov	%rcx,%rax
	and	$3,%rax
	shr	$2,%rcx
	cmp	$0,%rcx
	jnz	L2
	mov	(%rsi),%r11
	add	(%rdx),%r11
	mov	%r11,(%rdi)
	dec	%rax
	jz	L3
	mov	8(%rsi),%r11
	adc	8(%rdx),%r11
	mov	%r11,8(%rdi)
	dec	%rax
	jz	L3
	mov	16(%rsi),%r11
	adc	16(%rdx),%r11
	mov	%r11,16(%rdi)
	dec	%rax
L3:
	adc	%rax,%rax
	ret
	.align 8
L2:
	mov	(%rsi),%r11
	mov	8(%rsi),%r8
	adc	(%rdx),%r11
	lea	32(%rsi),%rsi
	adc	8(%rdx),%r8
	lea	32(%rdx),%rdx
	mov	%r8,8(%rdi)
	mov	%r11,(%rdi)
	mov	-16(%rsi),%r9
	mov	-8(%rsi),%r10
	adc	-16(%rdx),%r9
	lea	32(%rdi),%rdi
	adc	-8(%rdx),%r10
	mov	%r10,-8(%rdi)
	mov	%r9,-16(%rdi)
	dec	%rcx
	jnz	L2
	inc	%rax
	dec	%rax
	jz	L4
	mov	(%rsi),%r11
	adc	(%rdx),%r11
	mov	%r11,(%rdi)
	dec	%rax
	jz	L4
	mov	8(%rsi),%r11
	adc	8(%rdx),%r11
	mov	%r11,8(%rdi)
	dec	%rax
	jz	L4
	mov	16(%rsi),%r11
	adc	16(%rdx),%r11
	mov	%r11,16(%rdi)
	dec	%rax
L4:
	adc	%rax,%rax
	ret

