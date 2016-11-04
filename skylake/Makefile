
TIMINGS=lShl1Equ.mpir.timing  lShlEqu.mpir.timing  lShr1Equ.mpir.timing  lShrEqu.mpir.timing
all: lCmp.o lCpyDec.o lCpyInc.o lShl1Equ.o lShlEqu.o lShr1Equ.o lShrEqu.o

%.as: %.asm
	yasm -e -D USE_LINUX64 -D USE_AVX -m amd64 $^ | tr "#" ";" > $@

%.o: %.as
	yasm -g dwarf2 -m amd64 -f elf64 -o $@ $^

%.timing: %.as %.sig
	../timing.sh -s `cat $*.sig` -i $< > $@

timing: $(TIMINGS)
