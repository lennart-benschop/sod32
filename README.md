# SOD 32, THE STACK ORIENTED DESIGN.

SOD 32 is an imaginary 32 bit processor that is optimized for the execution
of Forth. This package contains a software simulator in C plus a Forth that
can be run on the simulator. The speed of that forth is competitive with
some of the available Forth interpreters in C, but that was not the main
goal when I developed it. After all I wrote it just for the hack value.
It is released under the GNU General Public License version 2.

This Forth is almost as small as it can be. It is closely modeled after ANSI
Forth, but it is not a complete implementation. It is just big enough that
it can recompile itself with its own cross compiler. 

Because the Forth system and its cross compiler are small and well commented
they have a certain instructional value as well.

A glossary generator is provided and it produces a glossary of all Forth
words in the file forth.glo.

You can probably still find the draft proposed ANS Forth standard on
   ftp.uu.net:/vendor/minerva/x3j14/dpans6ps.zip

Technical documentation about the SOD 32 processor, its simulator and
its Forth can be found in the file sod32.doc and in the various source
files.

## GETTING STARTED

After you unpack the shar archives you will have the following files:
* Makefile
* README.md
* sod32.h
* main.c
* special.c
* engine.c
* engine.S
* kernel.img
* sod32.txt
* extend.4th
* cross.4th
* kernel.4th
* sod32.4th
* doglos.4th
* glosgen.4th

If your system is big-endian (680x0), then uncomment the -DBIG_ENDIAN flag
in the Makefile. Check that the UNS8 INT32 and UNS32 types in sod32.h are 
defined right for your system as unsigned 8 bit character, signed 32 bit
integer and unsigned 32 bit integer. Adjust MEMSIZE to a reasonable value.
Set the CC variable in the Makefile to the C compiler you will use. 
Now type 
```  
  touch kernel.img
  make
```

If everything goes well, you have an executable sod32, the file forth.img
and the glossary forth.glo.

Start Forth with

 ./sod32 forth.img

Now you can type Forth words. 

134 2 * .

will show 

268 OK

WORDS will show all available forth words.
You can load other files with

S" name" INCLUDED

This way you can load the cross compiler cross.4th, which will recompile
kernel.img You can also load the glossary generator or the sod32 simulator.

S" sod32.4th" INCLUDED
SOD32 forth.img

will bring up Forth in a simulator under Forth. It will be slow and you
cannot do file operations, but nearly everything else.

You leave SOD 32 Forth by typing

BYE

## PORTABILITY

The SOD 32 simulator is written in ANSI C. It should run on any platform
that provides:
  - 8 bit bytes.
  - An unsigned 32 bit integer type.
  - Two's complement integer representation.

It should run just fine with 32-bit C compilers on the 386, the 68000 and the
vast majority of Unix work stations. There is even a chance that it runs
with 16-bit DOS C compilers if you restrict the memory size to 64kB and you
use unsigned long for UNS32. The simulator uses no operating system specific
functions and therefore it is more portable than, say PFE.

It mimics a big-endian machine regardless of the endianness of the system
you run it on. 

A binary file kernel.img is included in the package. This is considered a
_bad thing_ on comp.sources.misc, but the inclusion is in my opinion
justified for the following reasons.
* the file is machine independent. The same file can be used on every
  machine that can run the SOD 32 simulator.
* the file in necessary to run SOD 32 Forth. The source for the file is
  included in the form of cross.4th and kernel.4th, but you need to be able
  to run Forth in order to compile kernel.img from it. If I did not 
  include it, you would first need to find a suitable other Forth.
* As this Forth is more easily portable than most other Forths, having
  to use another Forth system first before you can use this package,
  would seriously hinder its usefulness.

  
