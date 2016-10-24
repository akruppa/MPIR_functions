all: lCmp.o lCpyDec.o lCpyInc.o lShl1Equ.o lShlEqu.o lShr1Equ.o lShrEqu.o

%.as: %.asm
	yasm -e -D USE_LINUX64 -D USE_AVX -m amd64 -o $@ $^

%.o: %.as
	yasm -g dwarf2 -m amd64 -f elf64 -o $@ $^
