all: lCmp.o

%.as: %.asm
	yasm -e -D USE_LINUX64 -m amd64 -o $@ $^

%.o: %.as
	yasm -g dwarf2 -m amd64 -f elf64 -o $@ $^
