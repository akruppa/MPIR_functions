%line 1+1 rsh1sub_n.mpir.asm
























[bits 64]

[global rsh1sub_n:function (rsh1sub_n.end - rsh1sub_n)]

[segment .text]

%line 59+1 rsh1sub_n.mpir.asm

%line 61+1 rsh1sub_n.mpir.asm

%line 69+1 rsh1sub_n.mpir.asm

%line 79+1 rsh1sub_n.mpir.asm

%line 88+1 rsh1sub_n.mpir.asm

%line 90+1 rsh1sub_n.mpir.asm

[align 32]
shr1sub_n:

%line 110+1 rsh1sub_n.mpir.asm

%line 115+1 rsh1sub_n.mpir.asm
 movq XMM0, RBX
 movq XMM1, R12
 movq XMM2, R13
 movq XMM3, R14
 movq XMM4, R15
%line 121+1 rsh1sub_n.mpir.asm

%line 125+1 rsh1sub_n.mpir.asm


 mov RBX, [RDI]
 sub RBX, [RSI]
 lahf

 add RDI, 8
 add RSI, 8
 sub RCX, 1

 test RCX, 1
 je .shr1sub_n_two

 sahf
 mov R8, [RDI]
 mov RAX, [RSI]
 sbb R8, RAX
 lahf

 shrd RBX, R8, 1
 mov [RDX], RBX

 add RDI, 8
 add RSI, 8
 add RDX, 8
 mov RBX, R8

 .shr1sub_n_two:

 test RCX, 2
 je .shr1sub_n_four

 sahf
 mov R8, [RDI]
 mov RAX, [RSI]
 sbb R8, RAX
 mov R9, [RDI+8]
 mov RAX, [RSI+8]
 sbb R9, RAX
 lahf

 shrd RBX, R8, 1
 mov [RDX], RBX
 shrd R8, R9, 1
 mov [RDX+8], R8

 add RDI, 16
 add RSI, 16
 add RDX, 16
 mov RBX, R9

 .shr1sub_n_four:

 test RCX, 4
 je .shr1sub_n_test ;ajs:notshortform

 mov R8, [RDI]
 mov RAX, [RSI]
 sbb R8, RAX
 mov R9, [RDI+8]
 mov RAX, [RSI+8]
 sbb R9, RAX
 mov R10, [RDI+16]
 mov RAX, [RSI+16]
 sbb R10, RAX
 mov R11, [RDI+24]
 mov RAX, [RSI+24]
 sbb R11, RAX
 lahf

 shrd RBX, R8, 1
 mov [RDX], RBX
 shrd R8, R9, 1
 mov [RDX+8], R8
 shrd R9, R10, 1
 mov [RDX+16], R9
 shrd R10, R11, 1
 mov [RDX+24], R10

 add RDI, 32
 add RSI, 32
 add RDX, 32
 mov RBX, R11
 jmp .shr1sub_n_test ;ajs:notshortform





[align 16]
 .shr1sub_n_loop:

%line 221+1 rsh1sub_n.mpir.asm

 sahf
 mov R8, [RDI]
 mov RAX, [RSI]
 sbb R8, RAX
 mov R9, [RDI+8]
 mov RAX, [RSI+8]
 sbb R9, RAX
 mov R10, [RDI+16]
 mov RAX, [RSI+16]
 sbb R10, RAX
 mov R11, [RDI+24]
 mov RAX, [RSI+24]
 sbb R11, RAX
 mov R12, [RDI+32]
 mov RAX, [RSI+32]
 sbb R12, RAX
 mov R13, [RDI+40]
 mov RAX, [RSI+40]
 sbb R13, RAX
 mov R14, [RDI+48]
 mov RAX, [RSI+48]
 sbb R14, RAX
 mov R15, [RDI+56]
 mov RAX, [RSI+56]
 sbb R15, RAX
 lahf

 shrd RBX, R8, 1
 mov [RDX], RBX
 shrd R8, R9, 1
 mov [RDX+8], R8
 shrd R9, R10, 1
 mov [RDX+16], R9
 shrd R10, R11, 1
 mov [RDX+24], R10
 shrd R11, R12, 1
 mov [RDX+32], R11
 shrd R12, R13, 1
 mov [RDX+40], R12
 shrd R13, R14, 1
 mov [RDX+48], R13
 shrd R14, R15, 1
 mov [RDX+56], R14

 add RDI, 64
 add RSI, 64
 add RDX, 64
 mov RBX, R15

 .shr1sub_n_test:

 sub RCX, 8
 jnc .shr1sub_n_loop


 shr RBX, 1
 mov [RDX], RBX

 xor RCX, RCX
 sahf
 adc RCX, RCX
 mov RAX, RCX

 .Exit:

%line 288+1 rsh1sub_n.mpir.asm
 movq R15, XMM4
 movq R14, XMM3
 movq R13, XMM2
 movq R12, XMM1
 movq RBX, XMM0
%line 297+1 rsh1sub_n.mpir.asm

%line 314+1 rsh1sub_n.mpir.asm

 ret
.end:
