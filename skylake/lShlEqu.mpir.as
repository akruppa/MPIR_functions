%line 1+1 lShlEqu.mpir.asm
































[bits 64]

[global lShlEqu:function (lShlEqu.end - lShlEqu)]

[segment .text]

%line 40+1 lShlEqu.mpir.asm

%line 50+1 lShlEqu.mpir.asm

%line 55+1 lShlEqu.mpir.asm

%line 65+1 lShlEqu.mpir.asm

%line 67+1 lShlEqu.mpir.asm

[align 32]
lShlEqu:

 xor EAX, EAX
 sub RDX, 1
 jc .Exit		;ajs:notshortform

 lea RDI, [RDI+8*RDX]
 lea RSI, [RSI+8*RDX]

 mov R8, [RDI]
 shld RAX, R8, CL

 or RDX, RDX
 je .lShlEquPost	;ajs:notshortform

%line 87+1 lShlEqu.mpir.asm

 cmp RDX, 8
 jc .lShlEquFour	;ajs:notshortform


 test RSI, 8
 jne .lShlEquA16

 mov R9, [RDI-8]
 shld R8, R9, CL
 mov [RSI], R8
 mov R8, R9

 sub RDI, 8
 sub RSI, 8
 sub RDX, 1

 .lShlEquA16:

 test RSI, 16
 jne .lShlEquAVX

 mov R9, [RDI-8]
 shld R8, R9, CL
 mov [RSI], R8
 mov R8, [RDI-16]
 shld R9, R8, CL
 mov [RSI-8], R9

 sub RDI, 16
 sub RSI, 16
 sub RDX, 2

 .lShlEquAVX:


 vmovq XMM6, RCX
 neg RCX
 and RCX, 63
 vmovq XMM7, RCX
 neg RCX
 and RCX, 63
 vpbroadcastq YMM6, XMM6
 vpbroadcastq YMM7, XMM7


 vmovdqu YMM0, [RDI-24]
 vpsrlvq YMM3, YMM0, YMM7
 vpermq YMM3, YMM3, 147

 sub RDI, 32
 sub RDX, 4
 jmp .lShlEquAVXCheck





[align 16]
 .lShlEquAVXLoop:

%line 151+1 lShlEqu.mpir.asm

 vmovdqu YMM1, [RDI-24]
 vpsllvq YMM2, YMM0, YMM6
 vmovdqu YMM0, [RDI-56]
 vpsrlvq YMM5, YMM1, YMM7
 vpermq YMM5, YMM5, 147
 vpblendd YMM3, YMM3, YMM5, 3
 vpor YMM2, YMM2, YMM3
 vpsllvq YMM4, YMM1, YMM6
 vpsrlvq YMM3, YMM0, YMM7
 vpermq YMM3, YMM3, 147
 vpblendd YMM5, YMM5, YMM3, 3
 vmovdqa [RSI-24], YMM2
 vpor YMM4, YMM4, YMM5
 vmovdqa [RSI-56], YMM4

 sub RDI, 64
 sub RSI, 64

 .lShlEquAVXCheck:

 sub RDX, 8
 jnc .lShlEquAVXLoop




 mov R8, [RDI]
 xor R9, R9
 shld R9, R8, CL
 vpsllvq YMM2, YMM0, YMM6
 pinsrq XMM3, R9, 0
 vpor YMM2, YMM2, YMM3
 vmovdqa [RSI-24], YMM2

 sub RSI, 32
 add RDX, 8


 .lShlEquFour:

 sub RDI, 8
 test RDX, 4
 je .lShlEquTwo

 mov R9, [RDI]
 shld R8, R9, CL
 mov [RSI], R8
 mov R8, [RDI-8]
 shld R9, R8, CL
 mov [RSI-8], R9
 mov R9, [RDI-16]
 shld R8, R9, CL
 mov [RSI-16], R8
 mov R8, [RDI-24]
 shld R9, R8, CL
 mov [RSI-24], R9

 sub RDI, 32
 sub RSI, 32

 .lShlEquTwo:

 test RDX, 2
 je .lShlEquOne

 mov R9, [RDI]
 shld R8, R9, CL
 mov [RSI], R8
 mov R8, [RDI-8]
 shld R9, R8, CL
 mov [RSI-8], R9

 sub RDI, 16
 sub RSI, 16

 .lShlEquOne:

 test RDX, 1
 je .lShlEquPost

 mov R9, [RDI]
 shld R8, R9, CL
 mov [RSI], R8
 mov R8, R9

 sub RSI, 8

 .lShlEquPost:

 shl R8, CL
 mov [RSI], R8

 .Exit:

 ret
.end:
