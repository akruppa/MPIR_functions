%line 1+1 lShl1Equ.mpir.asm



























[bits 64]

[global lShl1Equ:function (lShl1Equ.end - lShl1Equ)]

[segment .text]

%line 53+1 lShl1Equ.mpir.asm

%line 55+1 lShl1Equ.mpir.asm

%line 62+1 lShl1Equ.mpir.asm

%line 64+1 lShl1Equ.mpir.asm

%line 71+1 lShl1Equ.mpir.asm

%line 73+1 lShl1Equ.mpir.asm

[align 32]
lShl1Equ:

 xor EAX, EAX
 sub RDX, 1
 jc .Exit ;ajs:notshortform

 lea RDI, [RDI+8*RDX]
 lea RSI, [RSI+8*RDX]

 mov R8, [RDI]
 shld RAX, R8, 1

 or RDX, RDX
 je .lShl1EquPost ;ajs:notshortform

 cmp RDX, 8
 jc .lShl1EquFour ;ajs:notshortform


 test RSI, 8
 jne .lShl1EquA16

 mov R9, [RDI-8]
 shld R8, R9, 1
 mov [RSI], R8
 mov R8, R9

 sub RDI, 8
 sub RSI, 8
 sub RDX, 1

 .lShl1EquA16:

 test RSI, 16
 jne .lShl1EquAVX

 mov R9, [RDI-8]
 shld R8, R9, 1
 mov [RSI], R8
 mov R8, [RDI-16]
 shld R9, R8, 1
 mov [RSI-8], R9

 sub RDI, 16
 sub RSI, 16
 sub RDX, 2

 .lShl1EquAVX:


 vmovdqu YMM0, [RDI-24]
 vpsrlq YMM3, YMM0, 63
 vpermq YMM3, YMM3, 147

 sub RDI, 32
 sub RDX, 4
 jmp .lShl1EquAVXCheck





[align 16]
 .lShl1EquAVXLoop:

%line 143+1 lShl1Equ.mpir.asm

 vmovdqu YMM1, [RDI-24]
 vpsllq YMM2, YMM0, 1
 vmovdqu YMM0, [RDI-56]
 vpsrlq YMM5, YMM1, 63
 vpermq YMM5, YMM5, 147
 vpblendd YMM3, YMM3, YMM5, 3
 vpor YMM2, YMM2, YMM3
 vpsllq YMM4, YMM1, 1
 vpsrlq YMM3, YMM0, 63
 vpermq YMM3, YMM3, 147
 vpblendd YMM5, YMM5, YMM3, 3
 vmovdqa [RSI-24], YMM2
 vpor YMM4, YMM4, YMM5
 vmovdqa [RSI-56], YMM4

 sub RDI, 64
 sub RSI, 64

 .lShl1EquAVXCheck:

 sub RDX, 8
 jnc .lShl1EquAVXLoop




 mov R9, [RDI]
 mov R8, R9
 shr R9, 63
 vpsllq YMM2, YMM0, 1
 pinsrq XMM3, R9, 0
 vpor YMM2, YMM2, YMM3
 vmovdqa [RSI-24], YMM2

 sub RSI, 32
 add RDX, 8


 .lShl1EquFour:

 sub RDI, 8
 test RDX, 4
 je .lShl1EquTwo

 mov R9, [RDI]
 shld R8, R9, 1
 mov [RSI], R8
 mov R8, [RDI-8]
 shld R9, R8, 1
 mov [RSI-8], R9
 mov R9, [RDI-16]
 shld R8, R9, 1
 mov [RSI-16], R8
 mov R8, [RDI-24]
 shld R9, R8, 1
 mov [RSI-24], R9

 sub RDI, 32
 sub RSI, 32

 .lShl1EquTwo:

 test RDX, 2
 je .lShl1EquOne

 mov R9, [RDI]
 shld R8, R9, 1
 mov [RSI], R8
 mov R8, [RDI-8]
 shld R9, R8, 1
 mov [RSI-8], R9

 sub RDI, 16
 sub RSI, 16

 .lShl1EquOne:

 test RDX, 1
 je .lShl1EquPost

 mov R9, [RDI]
 shld R8, R9, 1
 mov [RSI], R8
 mov R8, R9

 sub RSI, 8

 .lShl1EquPost:

 shl R8, 1
 mov [RSI], R8

 .Exit:

 ret
.end:
