
TIMINGS=lShl1Equ.mpir.timing  lShlEqu.mpir.timing  lShr1Equ.mpir.timing  lShrEqu.mpir.timing
all: lCmp.o lCpyDec.o lCpyInc.o lShl1Equ.o lShlEqu.o lShr1Equ.o lShrEqu.o lShl1Equ.asm

%.as: %.annotated
	yasm -I./ -e -D USE_LINUX64 -D USE_AVX -m amd64 $^ | tr "#" ";" > $@

%.as: %.asm
	yasm -I./ -e -D USE_LINUX64 -D USE_AVX -m amd64 $^ > $@

%.asm: %.annotated
	tr "#" ";" < $^ > $@

%.o: %.as
	yasm -g dwarf2 -m amd64 -f elf64 -o $@ $^

%.timing: %.as %.sig
	../timing.sh -s `cat $*.sig` -i $< > $@

%.timing: %.s %.sig
	../timing.sh -s `cat $*.sig` $< > $@

timing: $(TIMINGS)
