%line 1+1 sumdiff_n.mpir.asm




















[bits 64]

[global sumdiff_n:function (sumdiff_n.end - sumdiff_n)]

[segment .text]

%line 57+1 sumdiff_n.mpir.asm

%line 59+1 sumdiff_n.mpir.asm

%line 65+1 sumdiff_n.mpir.asm

%line 75+1 sumdiff_n.mpir.asm

%line 79+1 sumdiff_n.mpir.asm

%line 86+1 sumdiff_n.mpir.asm

%line 88+1 sumdiff_n.mpir.asm

[align 32]
sumdiff_n:

%line 104+1 sumdiff_n.mpir.asm

%line 106+1 sumdiff_n.mpir.asm
 movq XMM5, R15
 movq XMM4, R14
 movq XMM3, R13
 movq XMM2, R12
 movq XMM1, RBP
 movq XMM0, RBX
%line 113+1 sumdiff_n.mpir.asm

 xor EAX, EAX

 test R8, 1
 je .sumdiff_n_two

 mov RBX, [RDI]
 mov R12, [RSI]
 mov R9, RBX
 add R9, R12
 mov [RDX], R9

 sbb AL, AL

 sub RBX, R12
 mov [RCX], RBX

 sbb AH, AH

 add RDI, 8
 add RSI, 8
 add RDX, 8
 add RCX, 8

 .sumdiff_n_two:

 test R8, 2
 je .sumdiff_n_four

 mov RBX, [RDI]
 mov R9, [RDI+8]
 mov R12, [RSI]
 mov R13, [RSI+8]

 add AL, AL

 mov R10, RBX
 adc R10, R12
 mov [RDX], R10
 mov R11, R9
 adc R11, R13
 mov [RDX+8], R11

 sbb AL, AL
 add AH, AH

 sbb RBX, R12
 mov [RCX], RBX
 sbb R9, R13
 mov [RCX+8], R9

 sbb AH, AH

 add RDI, 16
 add RSI, 16
 add RDX, 16
 add RCX, 16

 .sumdiff_n_four:

 test R8, 4
 je .sumdiff_n_test ;ajs:notshortform

 add AL, AL



 mov RBX, [RDI]
 mov R12, [RSI]
 mov RBP, RBX
 adc RBP, R12
 mov [RDX], RBP
 mov R9, [RDI+8]
 mov R13, [RSI+8]
 mov RBP, R9
 adc RBP, R13
 mov [RDX+8], RBP
 mov R10, [RDI+16]
 mov R14, [RSI+16]
 mov RBP, R10
 adc RBP, R14
 mov [RDX+16], RBP
 mov R11, [RDI+24]
 mov R15, [RSI+24]
 mov RBP, R11
 adc RBP, R15
 mov [RDX+24], RBP

 sbb AL, AL
 add AH, AH

 sbb RBX, R12
 mov [RCX], RBX
 sbb R9, R13
 mov [RCX+8], R9
 sbb R10, R14
 mov [RCX+16], R10
 sbb R11, R15
 mov [RCX+24], R11

 sbb AH, AH

 add RDI, 32
 add RSI, 32
 add RDX, 32
 add RCX, 32
 jmp .sumdiff_n_test ;ajs:notshortform





[align 16]
 .sumdiff_n_loop:

%line 232+1 sumdiff_n.mpir.asm

 add AL, AL

 mov RBX, [RDI]
 mov R12, [RSI]
 mov RBP, RBX
 adc RBP, R12
 mov [RDX], RBP
 mov R9, [RDI+8]
 mov R13, [RSI+8]
 mov RBP, R9
 adc RBP, R13
 mov [RDX+8], RBP
 mov R10, [RDI+16]
 mov R14, [RSI+16]
 mov RBP, R10
 adc RBP, R14
 mov [RDX+16], RBP
 mov R11, [RDI+24]
 mov R15, [RSI+24]
 mov RBP, R11
 adc RBP, R15
 mov [RDX+24], RBP

 sbb AL, AL
 add AH, AH

 sbb RBX, R12
 mov [RCX], RBX
 sbb R9, R13
 mov [RCX+8], R9
 sbb R10, R14
 mov [RCX+16], R10
 sbb R11, R15
 mov [RCX+24], R11

 mov RBX, [RDI+32]
 mov R12, [RSI+32]
 mov RBP, RBX
 sbb RBP, R12
 mov [RCX+32], RBP
 mov R9, [RDI+40]
 mov R13, [RSI+40]
 mov RBP, R9
 sbb RBP, R13
 mov [RCX+40], RBP
 mov R10, [RDI+48]
 mov R14, [RSI+48]
 mov RBP, R10
 sbb RBP, R14
 mov [RCX+48], RBP
 mov R11, [RDI+56]
 mov R15, [RSI+56]
 mov RBP, R11
 sbb RBP, R15
 mov [RCX+56], RBP

 sbb AH, AH
 add AL, AL

 adc RBX, R12
 mov [RDX+32], RBX
 adc R9, R13
 mov [RDX+40], R9
 adc R10, R14
 mov [RDX+48], R10
 adc R11, R15
 mov [RDX+56], R11

 sbb AL, AL

 add RDI, 64
 add RSI, 64
 add RDX, 64
 add RCX, 64

 .sumdiff_n_test:

 sub R8, 8
 jnc .sumdiff_n_loop


 .sumdiff_n_post:

 add AL, AL
 rcl AL, 1
 add AH, AH
 rcl AL, 1
 and EAX, 3

 .Exit:

%line 336+1 sumdiff_n.mpir.asm

%line 338+1 sumdiff_n.mpir.asm
 movq R15, XMM5
 movq R14, XMM4
 movq R13, XMM3
 movq R12, XMM2
 movq RBP, XMM1
 movq RBX, XMM0
%line 345+1 sumdiff_n.mpir.asm

 ret
.end:
