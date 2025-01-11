CFLAGS= -O2 # -DBIG_ENDIAN
# Uncomment -DBIG_ENDIAN for big-endian processors (m68k etc)
CC=gcc

all: sod32 forth.img forth.glo

sod32: engine.o special.o term.o main.o 
	$(CC) -o sod32 engine.o special.o term.o main.o

engine.o: engine.c sod32.h

special.o: special.c sod32.h

main.o: main.c sod32.h

forth.img: extend.4th kernel.img 
	echo 'S" extend.4th" INCLUDED '|./sod32 kernel.img 

kernel.img: kernel.4th cross.4th
	echo 'S" cross.4th" INCLUDED '|./sod32 forth.img

forth.glo: kernel.4th extend.4th
	./sod32 forth.img < doglos.4th

clean:
	rm sod32 *.o forth.img forth.glo
