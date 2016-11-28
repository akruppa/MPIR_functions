%define OpS     RDI
%define OpD     RSI
%define OpA     RDX
%define OpB     RCX
%define Size1   R8
%define LimbB   R9
%define LimbA   R10
%define LimbNeg R11
%define Sum     R12
%define Tmp1    R13
%define Tmp2    R14
%define Tmp2    R15

%define VNeg	YMM2
%define XNeg	XMM2
%define Vones   YMM3
%define Xones   XMM3

BITS 64

global addsub_4

; for an n-bit integer x, 0 <= x < 2^n, -x = NOT_n(x) + 1,
; where NOT_n(x) is the length-n one's complement of x.

addsub_4:

xor rax, rax
dec rax
movq Xones, rax
vpbroadcastq Vones, Xones
xor rax, rax


stc			; Init carry chain to 1 to effect the "+ 1"
                        ; in -x = NOT_n(x) + 1

.avxloop:

vmovdqu VNeg, [OpB]
vpxor  VNeg, VNeg, Vones	; Vones = 0xFFFF...FFFF

mov LimbB, [OpB]
mov LimbA, [OpA]
vmovq LimbNeg, XNeg
adox LimbB, LimbA	; Sum
adcx LimbA, LimbNeg	; Difference
mov [OpS], LimbB
mov [OpD], LimbA
vpermq VNeg, VNeg, 57 ; = 0b00111001, rotate qwords right

mov LimbB, [OpB + 8]
mov LimbA, [OpA + 8]
vmovq LimbNeg, XNeg
adox LimbB, LimbA	; Sum
adcx LimbA, LimbNeg	; Difference
mov [OpS + 8], LimbB
mov [OpD + 8], LimbA
vpermq VNeg, VNeg, 57 ; = 0b00111001, rotate qwords right

mov LimbB, [OpB + 16]
mov LimbA, [OpA + 16]
vmovq LimbNeg, XNeg
adox LimbB, LimbA	; Sum
adcx LimbA, LimbNeg	; Difference
mov [OpS + 16], LimbB
mov [OpD + 16], LimbA
vpermq VNeg, VNeg, 57 ; = 0b00111001, rotate qwords right

mov LimbB, [OpB + 24]
mov LimbA, [OpA + 24]
vmovq LimbNeg, XNeg
adox LimbB, LimbA	; Sum
adcx LimbA, LimbNeg	; Difference
mov [OpS + 24], LimbB
mov [OpD + 24], LimbA
; vpermq VNeg, VNeg, 57 ; = 0b00111001, rotate qwords right

lea OpA, [OpA + 32]
lea OpB, [OpB + 32]
lea OpS, [OpS + 32]
lea OpD, [OpD + 32]
dec Size1
jnz .avxloop

ret

.three:
xor rax, rax
stc
mov LimbA, [OpA]
mov LimbB, [OpB]
mov LimbNeg, [OpA + 8]
mov Tmp1, [OpB + 8]
mov Tmp2, [OpA + 16]
mov Tmp3, [OpB + 16]
mov Sum, LimbA
adox Sum, LimbB
adcx 
