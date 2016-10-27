%line 1+1 lShr1Equ.mpir.asm



























[bits 64]

[global lShr1Equ:function (lShr1Equ.end - lShr1Equ)]

[segment .text]

%line 53+1 lShr1Equ.mpir.asm

%line 55+1 lShr1Equ.mpir.asm

%line 62+1 lShr1Equ.mpir.asm

%line 64+1 lShr1Equ.mpir.asm

%line 71+1 lShr1Equ.mpir.asm

%line 73+1 lShr1Equ.mpir.asm

[align 32]
lShr1Equ:

 xor EAX, EAX
 or RDX, RDX
 je .Exit		;ajs:notshortform

 mov RAX, [RDI]
 mov R8, RAX
 shl RAX, 63

 sub RDX, 1
 je .lShr1EquPost	;ajs:notshortform

 cmp RDX, 8
 jc .lShr1EquFour	;ajs:notshortform


 test RSI, 8
 je .lShr1EquAlign16

 mov R9, [RDI+8]
 shrd R8, R9, 1
 mov [RSI], R8
 mov R8, R9

 add RDI, 8
 add RSI, 8
 sub RDX, 1

 .lShr1EquAlign16:

 test RSI, 16
 je .lShr1EquAVX

 mov R9, [RDI+8]
 shrd R8, R9, 1
 mov [RSI], R8
 mov R8, [RDI+16]
 shrd R9, R8, 1
 mov [RSI+8], R9

 add RDI, 16
 add RSI, 16
 sub RDX, 2

 .lShr1EquAVX:


 vmovdqu YMM0, [RDI]
 vpsllq YMM3, YMM0, 63

 add RDI, 32
 sub RDX, 4
 jmp .lShr1EquAVXCheck





[align 16]
 .lShr1EquAVXLoop:

%line 140+1 lShr1Equ.mpir.asm

 vmovdqu YMM1, [RDI]
 vpsrlq YMM2, YMM0, 1
 vmovdqu YMM0, [RDI+32]
 vpsllq YMM5, YMM1, 63
 vpblendd YMM3, YMM3, YMM5, 3
 vpermq YMM3, YMM3, 57
 vpor YMM2, YMM2, YMM3
 vpsrlq YMM4, YMM1, 1
 vpsllq YMM3, YMM0, 63
 vpblendd YMM5, YMM5, YMM3, 3
 vpermq YMM5, YMM5, 57
 vmovdqa [RSI], YMM2
 vpor YMM4, YMM4, YMM5
 vmovdqa [RSI+32], YMM4

 add RDI, 64
 add RSI, 64

 .lShr1EquAVXCheck:

 sub RDX, 8
 jnc .lShr1EquAVXLoop




 mov R9, [RDI]
 mov R8, R9
 shl R9, 63
 vpsrlq YMM2, YMM0, 1
 pinsrq XMM3, R9, 0
 vpermq YMM3, YMM3, 57
 vpor YMM2, YMM2, YMM3
 vmovdqa [RSI], YMM2

 add RSI, 32
 add RDX, 8


 .lShr1EquFour:

 add RDI, 8
 test RDX, 4
 je .lShr1EquTwo

 mov R9, [RDI]
 shrd R8, R9, 1
 mov [RSI], R8
 mov R8, [RDI+8]
 shrd R9, R8, 1
 mov [RSI+8], R9
 mov R9, [RDI+16]
 shrd R8, R9, 1
 mov [RSI+16], R8
 mov R8, [RDI+24]
 shrd R9, R8, 1
 mov [RSI+24], R9

 add RDI, 32
 add RSI, 32

 .lShr1EquTwo:

 test RDX, 2
 je .lShr1EquOne

 mov R9, [RDI]
 shrd R8, R9, 1
 mov [RSI], R8
 mov R8, [RDI+8]
 shrd R9, R8, 1
 mov [RSI+8], R9

 add RDI, 16
 add RSI, 16

 .lShr1EquOne:

 test RDX, 1
 je .lShr1EquPost

 mov R9, [RDI]
 shrd R8, R9, 1
 mov [RSI], R8
 mov R8, R9

 add RSI, 8

 .lShr1EquPost:

 shr R8, 1
 mov [RSI], R8

 .Exit:

 ret
.end:
