%line 1+1 rsh1add_n.mpir.asm























[bits 64]

[global rsh1add_n:function (rsh1add_n.end - rsh1add_n)]

[segment .text]

%line 58+1 rsh1add_n.mpir.asm

%line 60+1 rsh1add_n.mpir.asm

%line 68+1 rsh1add_n.mpir.asm

%line 78+1 rsh1add_n.mpir.asm

%line 87+1 rsh1add_n.mpir.asm

%line 89+1 rsh1add_n.mpir.asm

[align 32]
rsh1add_n:

%line 109+1 rsh1add_n.mpir.asm

%line 114+1 rsh1add_n.mpir.asm
 movq XMM0, RBX
 movq XMM1, R12
 movq XMM2, R13
 movq XMM3, R14
 movq XMM4, R15
%line 120+1 rsh1add_n.mpir.asm

%line 124+1 rsh1add_n.mpir.asm


 mov RBX, [RDI]
 add RBX, [RSI]
 lahf

 add RDI, 8
 add RSI, 8
 sub RCX, 1

 test RCX, 1
 je .rsh1add_n_two

 mov R8, [RDI]
 mov RAX, [RSI]
 adc R8, RAX
 lahf

 shrd RBX, R8, 1
 mov [RDX], RBX

 add RDI, 8
 add RSI, 8
 add RDX, 8
 mov RBX, R8

 .rsh1add_n_two:

 test RCX, 2
 je .rsh1add_n_four

 sahf
 mov R8, [RDI]
 mov RAX, [RSI]
 adc R8, RAX
 mov R9, [RDI+8]
 mov RAX, [RSI+8]
 adc R9, RAX
 lahf

 shrd RBX, R8, 1
 mov [RDX], RBX
 shrd R8, R9, 1
 mov [RDX+8], R8

 add RDI, 16
 add RSI, 16
 add RDX, 16
 mov RBX, R9

 .rsh1add_n_four:

 test RCX, 4
 je .rsh1add_n_test ;ajs:notshortform

 sahf
 mov R8, [RDI]
 mov RAX, [RSI]
 adc R8, RAX
 mov R9, [RDI+8]
 mov RAX, [RSI+8]
 adc R9, RAX
 mov R10, [RDI+16]
 mov RAX, [RSI+16]
 adc R10, RAX
 mov R11, [RDI+24]
 mov RAX, [RSI+24]
 adc R11, RAX
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
 jmp .rsh1add_n_test ;ajs:notshortform





[align 16]
 .rsh1add_n_loop:

%line 220+1 rsh1add_n.mpir.asm

 sahf
 mov R8, [RDI]
 mov RAX, [RSI]
 adc R8, RAX
 mov R9, [RDI+8]
 mov RAX, [RSI+8]
 adc R9, RAX
 mov R10, [RDI+16]
 mov RAX, [RSI+16]
 adc R10, RAX
 mov R11, [RDI+24]
 mov RAX, [RSI+24]
 adc R11, RAX
 mov R12, [RDI+32]
 mov RAX, [RSI+32]
 adc R12, RAX
 mov R13, [RDI+40]
 mov RAX, [RSI+40]
 adc R13, RAX
 mov R14, [RDI+48]
 mov RAX, [RSI+48]
 adc R14, RAX
 mov R15, [RDI+56]
 mov RAX, [RSI+56]
 adc R15, RAX
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

 .rsh1add_n_test:

 sub RCX, 8
 jnc .rsh1add_n_loop


 shr RBX, 1
 mov [RDX], RBX

 xor RCX, RCX
 sahf
 adc RCX, RCX
 mov RAX, RCX

 .Exit:

%line 287+1 rsh1add_n.mpir.asm
 movq R15, XMM4
 movq R14, XMM3
 movq R13, XMM2
 movq R12, XMM1
 movq RBX, XMM0
%line 296+1 rsh1add_n.mpir.asm

%line 313+1 rsh1add_n.mpir.asm

 ret
end:
