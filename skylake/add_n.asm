%include 'yasm_mac.inc'

BITS 64

%ifdef USE_WIN64
    %define Op3     RCX
    %define Op2     RDX
    %define Op1     R8
    %define Size1   R9
    %define Limb1   R10
    %define Offs    R11
%else
    ; RDI, RSI, RDX, RCX, R8, R9
    %define Op3     RDI
    %define Op2     RSI
    %define Op1     RDX
    %define Size1   RCX
    %define Limb1   R8
    %define Offs    R9
    %define Limb2   R10
    %define Limb3   R8
    %define Limb4   R10
%endif

    align   32

GLOBAL_FUNC mpn_add_n
    push   r12
    xor    rax, rax
    xor    Offs, Offs
    shr	   Size1, 1
    jnc   .even

    ; Size1 parameter was odd
    mov	   Limb1, [Op1]
    add    Limb1, [Op2]
    mov    [Op3], Limb1
    lea    Offs, [Offs + 8]
    setc   al

.even:
    shr    Size1, 1
    jnc    .preloop
    shr    al, 1
    mov	   Limb1, [Op1 + Offs]
    adc    Limb1, [Op2 + Offs]
    mov    [Op3 + Offs], Limb1
    mov	   Limb2, [Op1 + Offs + 8]
    adc    Limb2, [Op2 + Offs + 8]
    mov    [Op3 + Offs + 8], Limb2
    lea    Offs, [Offs + 16]
    setc   al

.preloop:
    test   Size1, Size1
    jz     .end
    shr    al, 1
align 32
.loop:
    mov	   Limb1, [Op1 + Offs]		; 1,1 p23
    adc    Limb1, [Op2 + Offs]		; 2,3 2p0156 p23
    mov	   Limb2, [Op1 + Offs + 8]	; 1,1 p23
    adc    Limb2, [Op2 + Offs + 8]	; 2,3 2p0156 p23
    mov    [Op3 + Offs], Limb1		; 1,2 p237 p4
    mov    [Op3 + Offs + 8], Limb2	; 1,2 p237 p4

    mov	   Limb3, [Op1 + Offs + 16]	; 1,1 p23
    mov	   Limb4, [Op1 + Offs + 24]	; 1,1 p23
    adc    Limb3, [Op2 + Offs + 16]	; 2,3 2p0156 p23
    adc    Limb4, [Op2 + Offs + 24]	; 2,3 2p0156 p23
    mov    [Op3 + Offs + 16], Limb3	; 1,2 p237 p4
    mov    [Op3 + Offs + 24], Limb4	; 1,2 p237 p4

    lea    Offs, [Offs + 32]		; 1,1 p15
    dec    Size1			; 1,1 p0156
    jnz    .loop			; 1,1 p6

    setc   al
.end:
    pop r12
    ret
