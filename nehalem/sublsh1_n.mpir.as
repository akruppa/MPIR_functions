%line 1+1 sublsh1_n.mpir.asm

























[bits 64]

[global sublsh1_n:function (sublsh1_n.end - sublsh1_n)]

[segment .text]

%line 60+1 sublsh1_n.mpir.asm

%line 62+1 sublsh1_n.mpir.asm

%line 70+1 sublsh1_n.mpir.asm

%line 80+1 sublsh1_n.mpir.asm

%line 89+1 sublsh1_n.mpir.asm

%line 91+1 sublsh1_n.mpir.asm

[align 32]
sublsh1_n:

%line 111+1 sublsh1_n.mpir.asm

%line 116+1 sublsh1_n.mpir.asm
 movq XMM0, RBX
 movq XMM1, R12
 movq XMM2, R13
 movq XMM3, R14
 movq XMM4, R15
%line 122+1 sublsh1_n.mpir.asm

%line 126+1 sublsh1_n.mpir.asm


 xor RBX, RBX
 lahf

 test RCX, 1
 je .sublsh1_n_two

 mov R8, [RSI]
 shrd RBX, R8, 63

 sahf
 mov RAX, [RDI]
 sbb RAX, RBX
 mov [RDX], RAX
 lahf

 add RDI, 8
 add RSI, 8
 add RDX, 8
 mov RBX, R8

 .sublsh1_n_two:

 test RCX, 2
 je .sublsh1_n_four

 mov R8, [RSI]
 mov R9, [RSI+8]
 shrd RBX, R8, 63
 shrd R8, R9, 63

 sahf
 mov RAX, [RDI]
 sbb RAX, RBX
 mov [RDX], RAX
 mov RAX, [RDI+8]
 sbb RAX, R8
 mov [RDX+8], RAX
 lahf

 add RDI, 16
 add RSI, 16
 add RDX, 16
 mov RBX, R9

 .sublsh1_n_four:

 test RCX, 4
 je .sublsh1_n_test ;ajs:notshortform

 mov R8, [RSI]
 mov R9, [RSI+8]
 shrd RBX, R8, 63
 shrd R8, R9, 63
 mov R10, [RSI+16]
 mov R11, [RSI+24]
 shrd R9, R10, 63
 shrd R10, R11, 63

 sahf
 mov RAX, [RDI]
 sbb RAX, RBX
 mov [RDX], RAX
 mov RAX, [RDI+8]
 sbb RAX, R8
 mov [RDX+8], RAX
 mov RAX, [RDI+16]
 sbb RAX, R9
 mov [RDX+16], RAX
 mov RAX, [RDI+24]
 sbb RAX, R10
 mov [RDX+24], RAX
 lahf

 add RDI, 32
 add RSI, 32
 add RDX, 32
 mov RBX, R11
 jmp .sublsh1_n_test ;ajs:notshortform





[align 16]
 .sublsh1_n_loop:

%line 218+1 sublsh1_n.mpir.asm

 mov R8, [RSI]
 mov R9, [RSI+8]
 mov R10, [RSI+16]
 shrd RBX, R8, 63
 shrd R8, R9, 63
 shrd R9, R10, 63
 mov R11, [RSI+24]
 mov R12, [RSI+32]
 mov R13, [RSI+40]
 shrd R10, R11, 63
 shrd R11, R12, 63
 shrd R12, R13, 63
 mov R14, [RSI+48]
 mov R15, [RSI+56]
 shrd R13, R14, 63
 shrd R14, R15, 63

 sahf
 mov RAX, [RDI]
 sbb RAX, RBX
 mov [RDX], RAX
 mov RAX, [RDI+8]
 sbb RAX, R8
 mov [RDX+8], RAX
 mov RAX, [RDI+16]
 sbb RAX, R9
 mov [RDX+16], RAX
 mov RAX, [RDI+24]
 sbb RAX, R10
 mov [RDX+24], RAX
 mov RAX, [RDI+32]
 sbb RAX, R11
 mov [RDX+32], RAX
 mov RAX, [RDI+40]
 sbb RAX, R12
 mov [RDX+40], RAX
 mov RAX, [RDI+48]
 sbb RAX, R13
 mov [RDX+48], RAX
 mov RAX, [RDI+56]
 sbb RAX, R14
 mov [RDX+56], RAX
 lahf

 add RDI, 64
 add RSI, 64
 add RDX, 64
 mov RBX, R15

 .sublsh1_n_test:

 sub RCX, 8
 jnc .sublsh1_n_loop


 shr RBX, 63
 sahf
 adc RBX, 0
 mov RAX, RBX

 .Exit:

%line 282+1 sublsh1_n.mpir.asm
 movq R15, XMM4
 movq R14, XMM3
 movq R13, XMM2
 movq R12, XMM1
 movq RBX, XMM0
%line 291+1 sublsh1_n.mpir.asm

%line 308+1 sublsh1_n.mpir.asm

 ret
.end:
