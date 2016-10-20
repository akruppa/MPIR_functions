%line 1+1 addlsh1_n.mpir.asm

























[bits 64]

[global addlsh1_n:function (addlsh1_n.end - addlsh1_n)]

[segment .text]

%line 60+1 addlsh1_n.mpir.asm

%line 62+1 addlsh1_n.mpir.asm

%line 70+1 addlsh1_n.mpir.asm

%line 80+1 addlsh1_n.mpir.asm

%line 89+1 addlsh1_n.mpir.asm

%line 91+1 addlsh1_n.mpir.asm

[align 32]
addlsh1_n:

%line 111+1 addlsh1_n.mpir.asm

%line 116+1 addlsh1_n.mpir.asm
 movq XMM0, RBX
 movq XMM1, R12
 movq XMM2, R13
 movq XMM3, R14
 movq XMM4, R15
%line 122+1 addlsh1_n.mpir.asm

%line 126+1 addlsh1_n.mpir.asm


 xor RBX, RBX
 lahf

 test RCX, 1
 je .addlsh1_n_two

 mov R8, [RDI]
 shrd RBX, R8, 63

 sahf
 mov RAX, [RSI]
 adc RBX, RAX
 mov [RDX], RBX
 lahf

 add RDI, 8
 add RSI, 8
 add RDX, 8
 mov RBX, R8

 .addlsh1_n_two:

 test RCX, 2
 je .addlsh1_n_four

 mov R8, [RDI]
 mov R9, [RDI+8]
 shrd RBX, R8, 63
 shrd R8, R9, 63

 sahf
 mov RAX, [RSI]
 adc RBX, RAX
 mov [RDX], RBX
 mov RAX, [RSI+8]
 adc R8, RAX
 mov [RDX+8], R8
 lahf

 add RDI, 16
 add RSI, 16
 add RDX, 16
 mov RBX, R9

 .addlsh1_n_four:

 test RCX, 4
 je .addlsh1_n_test ;ajs:notshortform

 mov R8, [RDI]
 mov R9, [RDI+8]
 shrd RBX, R8, 63
 shrd R8, R9, 63
 mov R10, [RDI+16]
 mov R11, [RDI+24]
 shrd R9, R10, 63
 shrd R10, R11, 63

 sahf
 mov RAX, [RSI]
 adc RBX, RAX
 mov [RDX], RBX
 mov RAX, [RSI+8]
 adc R8, RAX
 mov [RDX+8], R8
 mov RAX, [RSI+16]
 adc R9, RAX
 mov [RDX+16], R9
 mov RAX, [RSI+24]
 adc R10, RAX
 mov [RDX+24], R10
 lahf

 add RDI, 32
 add RSI, 32
 add RDX, 32
 mov RBX, R11
 jmp .addlsh1_n_test ;ajs:notshortform





[align 16]
 .addlsh1_n_loop:

%line 218+1 addlsh1_n.mpir.asm

 mov R8, [RDI]
 mov R9, [RDI+8]
 mov R10, [RDI+16]
 shrd RBX, R8, 63
 shrd R8, R9, 63
 shrd R9, R10, 63
 mov R11, [RDI+24]
 mov R12, [RDI+32]
 mov R13, [RDI+40]
 shrd R10, R11, 63
 shrd R11, R12, 63
 shrd R12, R13, 63
 mov R14, [RDI+48]
 mov R15, [RDI+56]
 shrd R13, R14, 63
 shrd R14, R15, 63

 sahf
 mov RAX, [RSI]
 adc RBX, RAX
 mov [RDX], RBX
 mov RAX, [RSI+8]
 adc R8, RAX
 mov [RDX+8], R8
 mov RAX, [RSI+16]
 adc R9, RAX
 mov [RDX+16], R9
 mov RAX, [RSI+24]
 adc R10, RAX
 mov [RDX+24], R10
 mov RAX, [RSI+32]
 adc R11, RAX
 mov [RDX+32], R11
 mov RAX, [RSI+40]
 adc R12, RAX
 mov [RDX+40], R12
 mov RAX, [RSI+48]
 adc R13, RAX
 mov [RDX+48], R13
 mov RAX, [RSI+56]
 adc R14, RAX
 mov [RDX+56], R14
 lahf

 add RDI, 64
 add RSI, 64
 add RDX, 64
 mov RBX, R15

 .addlsh1_n_test:

 sub RCX, 8
 jnc .addlsh1_n_loop


 shr RBX, 63
 sahf
 adc RBX, 0
 mov RAX, RBX

 .Exit:

%line 282+1 addlsh1_n.mpir.asm
 movq R15, XMM4
 movq R14, XMM3
 movq R13, XMM2
 movq R12, XMM1
 movq RBX, XMM0
%line 291+1 addlsh1_n.mpir.asm

%line 308+1 addlsh1_n.mpir.asm

 ret
.end:
