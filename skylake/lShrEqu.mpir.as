%line 1+1 lShrEqu.mpir.asm
































[bits 64]

[global lShrEqu:function (lShrEqu.end - lShrEqu)]

[segment .text]

%line 40+1 lShrEqu.mpir.asm

%line 50+1 lShrEqu.mpir.asm

%line 55+1 lShrEqu.mpir.asm

%line 65+1 lShrEqu.mpir.asm

%line 67+1 lShrEqu.mpir.asm

[align 32]
lShrEqu:

 xor EAX, EAX
 or RDX, RDX
 je .Exit		;ajs:notshortform

 mov R8, [RDI]
 shrd RAX, R8, CL

 sub RDX, 1
 je .lShrEquPost	;ajs:notshortform

%line 84+1 lShrEqu.mpir.asm

 cmp RDX, 8
 jc .lShrEquFour	;ajs:notshortform


 test RSI, 8
 je .lShrEquAlign16

 mov R9, [RDI+8]
 shrd R8, R9, CL
 mov [RSI], R8
 mov R8, R9

 add RDI, 8
 add RSI, 8
 sub RDX, 1

 .lShrEquAlign16:

 test RSI, 16
 je .lShrEquAVX

 mov R9, [RDI+8]
 shrd R8, R9, CL
 mov [RSI], R8
 mov R8, [RDI+16]
 shrd R9, R8, CL
 mov [RSI+8], R9

 add RDI, 16
 add RSI, 16
 sub RDX, 2

 .lShrEquAVX:


 vmovq XMM6, RCX
 neg RCX
 and RCX, 63
 vmovq XMM7, RCX
 neg RCX
 and RCX, 63
 vpbroadcastq YMM6, XMM6
 vpbroadcastq YMM7, XMM7


 vmovdqu YMM0, [RDI]
 vpsllvq YMM3, YMM0, YMM7

 add RDI, 32
 sub RDX, 4
 jmp .lShrEquAVXCheck





[align 16]
 .lShrEquAVXLoop:

%line 147+1 lShrEqu.mpir.asm

 vmovdqu YMM1, [RDI]
 vpsrlvq YMM2, YMM0, YMM6
 vmovdqu YMM0, [RDI+32]
 vpsllvq YMM5, YMM1, YMM7
 vpblendd YMM3, YMM3, YMM5, 3
 vpermq YMM3, YMM3, 57
 vpor YMM2, YMM2, YMM3
 vpsrlvq YMM4, YMM1, YMM6
 vpsllvq YMM3, YMM0, YMM7
 vpblendd YMM5, YMM5, YMM3, 3
 vpermq YMM5, YMM5, 57
 vmovdqa [RSI], YMM2
 vpor YMM4, YMM4, YMM5
 vmovdqa [RSI+32], YMM4

 add RDI, 64
 add RSI, 64

 .lShrEquAVXCheck:

 sub RDX, 8
 jnc .lShrEquAVXLoop




 mov R8, [RDI]
 xor R9, R9
 shrd R9, R8, CL
 vpsrlvq YMM2, YMM0, YMM6
 pinsrq XMM3, R9, 0
 vpermq YMM3, YMM3, 57
 vpor YMM2, YMM2, YMM3
 vmovdqa [RSI], YMM2

 add RSI, 32
 add RDX, 8


 .lShrEquFour:

 add RDI, 8
 test RDX, 4
 je .lShrEquTwo

 mov R9, [RDI]
 shrd R8, R9, CL
 mov [RSI], R8
 mov R8, [RDI+8]
 shrd R9, R8, CL
 mov [RSI+8], R9
 mov R9, [RDI+16]
 shrd R8, R9, CL
 mov [RSI+16], R8
 mov R8, [RDI+24]
 shrd R9, R8, CL
 mov [RSI+24], R9

 add RDI, 32
 add RSI, 32

 .lShrEquTwo:

 test RDX, 2
 je .lShrEquOne

 mov R9, [RDI]
 shrd R8, R9, CL
 mov [RSI], R8
 mov R8, [RDI+8]
 shrd R9, R8, CL
 mov [RSI+8], R9

 add RDI, 16
 add RSI, 16

 .lShrEquOne:

 test RDX, 1
 je .lShrEquPost

 mov R9, [RDI]
 shrd R8, R9, CL
 mov [RSI], R8
 mov R8, R9

 add RSI, 8


 .lShrEquPost:

 shr R8, CL
 mov [RSI], R8

 .Exit:

 ret
.end:
