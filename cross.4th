\ CROSS COMPILER FOR SOD-32, THE STACK ORIENTED DESIGN PROCESSOR 
\ Copyright 1994 L.C. Benschop Vught, The Netherlands.
\ The program is released under the GNU General Public License version 2.
\ There is NO WARRANTY.
\ 
\ This serves as an introduction to Forth cross compiling, so it is excessively 
\ commented.  
\ 
\ This cross compiler can be run on any ANS Forth with the necessary 
\ extension wordset that is at least 32-bit, including SOD-32 Forth. 
\ 
\ It creates the memory image of a new Forth system that is to be run 
\ by the SOD-32 virtual processor. (or maybe a real SOD-32 processor if 
\ it will ever be made.) 
\ 
\ The cross compiler (or meta compiler or target compiler) is similar 
\ to a regular Forth compiler, except that it builds definitions in 
\ a dictionary in the memory image of a different Forth system. 
\ We call this the target dictionary in the target space of the 
\ target system.  
\ 
\ As the new definitions are for a different Forth system, the cross 
\ compiler cannot EXECUTE them. Neither can it easily find the new 
\ definitions in the target dictionary. Hence a shadow definition 
\ for each target definition is made in the normal Forth dictionary. 
\
\ The names of the new definitions overlap with the names of existing
\ elementary. Forth words. Therefore they need to be in a wordlist 
\ different from the normal Forth wordlist.

\ Change 2025-01-11: Fixed to cross compile on 64-bit target.

\ PART 1: THE VOCABULARIES.

\ We need the word VOCABULARY. It's not in the standard though it will
\ be in most actual implementations.
: VOCABULARY WORDLIST CREATE  ,  \ Make a new wordlist and store it in def.
  DOES> >R                      \ Replace last item in the search order.
  GET-ORDER SWAP DROP R> @ SWAP SET-ORDER ;


VOCABULARY TARGET
\ This vocabulary will hold shadow definitions for all words that are in
\ the target dictionary. When a shadow definition is executed, it 
\ performs the compile action in the target dictionary.

VOCABULARY TRANSIENT
\ This vocabulary will hold definitions that must be executed by the
\ host system ( the system on which the cross compiler runs) and that
\ compile to the target system.

\ Expl: The word IF occurs in all three vocabularies. The word IF in the
\       FORTH vocabulary is run by the host system and is used when
\       compiling host definitions. A different version is in the
\       TRANSIENT vocabulary. This one runs on the host system and
\       is used when compiling target definitions. The version in the
\       TARGET vocabulary is the version that will run on the target
\       system. 

\ : \D ; \ Uncomment one of these. If uncommented, display debug info.
: \D POSTPONE \ ; IMMEDIATE 

\ PART 2: THE TARGET DICTIONARY SPACE.

\ Next we need to define the target space and the words to access it.

20000 CONSTANT IMAGE_SIZE

CREATE IMAGE IMAGE_SIZE CHARS ALLOT \ This space contains the target image.
       IMAGE IMAGE_SIZE 0 FILL      \ Initialize it to zero.

\ Fetch and store characters in the target space.
: C@-T ( t-addr --- c) CHARS IMAGE + C@ ;
: C!-T ( c t-addr ---) CHARS IMAGE + C! ;

\ Fetch and store cells in the target space.
\ SOD32 is big endian 32 bit so store explicitly big-endian.
: @-T  ( t-addr --- x)
       CHARS IMAGE + DUP C@ 24 LSHIFT OVER 1 CHARS + C@ 16 LSHIFT +
       OVER 2 CHARS + C@ 8 LSHIFT + SWAP 3 CHARS + C@ + ;
: !-T  ( x t-addr ---)
       CHARS IMAGE + OVER 24 RSHIFT OVER C! OVER 16 RSHIFT OVER 1 CHARS + C!
       OVER 8 RSHIFT OVER 2 CHARS + C! 3 CHARS + C! ;


\ A dictionary is constructed in the target space. Here are the primitives
\ to maintain the dictionary pointer and to reserve space.

VARIABLE DP-T                       \ Dictionary pointer for target dictionary.
0 DP-T !                            \ Initialize it to zero, SOD starts at 0.
: THERE ( --- t-addr) DP-T @ ;      \ Equivalent of HERE in target space.                                
: ALLOT-T ( n --- ) DP-T +! ;       \ Reserve n bytes in the dictionary.
: CHARS-T ( n1 --- n2 ) ;      
: CELLS-T ( n1 --- n2 ) 2 LSHIFT ;  \ Cells are 4 chars.
: ALIGN-T                           \ SOD only accesses cells at aligned 
                                    \ addresses.
  BEGIN THERE 3 AND WHILE 1 ALLOT-T REPEAT ;
: ALIGNED-T ( n1 --- n2 ) 3 + -4 AND ; 
: C,-T  ( c --- )  THERE C!-T 1 CHARS ALLOT-T ;
: ,-T   ( x --- )  THERE !-T  1 CELLS-T ALLOT-T ;

: PLACE-T ( c-addr len t-addr --- ) \ Move counted string to target space.
  OVER OVER C!-T 1+ CHARS IMAGE + SWAP CHARS CMOVE ;      

\ After the Forth system is constructed, its image must be saved.
: SAVE-IMAGE ( "name" --- )
  32 WORD COUNT W/O BIN CREATE-FILE ABORT" Can't open file" >R
  IMAGE THERE R@ WRITE-FILE ABORT" Can't write file" 
  R> CLOSE-FILE ABORT" Can't close file" ;

\ PART 3: CREATING NEW DEFINITIONS IN THE TARGET SYSTEM.

\ These words create new target definitions, both the shadow definition
\ and the header in the target dictionary. The layout of target headers
\ can be changed but FIND in the target system must be changed accordingly. 

\ All definitions are linked together in a number of threads. Each word
\ is linked in only one thread. Which thread the word is linked to, can be
\ determined from the name by a 'hash' code. To find a word, one can compute
\ the hash code and then one can search just one thread that contains a 
\ small fraction of the words. 

32 CONSTANT #THREADS \ Number of threads 

CREATE TLINKS #THREADS CELLS ALLOT   \ This array points to the names
                           \ of the last definition in each thread.
TLINKS #THREADS CELLS 0 FILL 

VARIABLE LAST-T          \ Address of last definition.

: HASH ( c-addr u #threads --- n)
  >R OVER C@ 1 LSHIFT OVER 1 > IF ROT CHAR+ C@ 2 LSHIFT XOR ELSE ROT DROP 
   THEN XOR 
  R> 1- AND 
;  

: "HEADER >IN @ CREATE >IN ! \ Create the shadow definition.
  BL WORD
  DUP COUNT #THREADS HASH >R \ Compute the hash code.                            
  ALIGN-T TLINKS R@ CELLS + @ ,-T        \ Lay out the link field.   
\D  DUP COUNT CR ." Creating: " TYPE ."  Hash:" R@ . 
  COUNT DUP >R THERE PLACE-T  \ Place name in target dictionary. 
  THERE TLINKS R> R> SWAP >R CELLS + !
  THERE LAST-T !               
  THERE C@-T 128 OR THERE C!-T R> 1+ ALLOT-T ALIGN-T ; 
      \ Set bit 7 of count byte as a marker.

\ : "HEADER CREATE ALIGN-T ;  \ Alternative for "HEADER in case the target system
                      \ is just an application without headers.

: MACRO LAST-T @ DUP C@-T 32 OR SWAP C!-T ; 
   \ Set the MACRO bit of last name. This indicates to the compiler in the
   \ target Forth system that this def may be expanded.

ALSO TRANSIENT DEFINITIONS 
: IMMEDIATE LAST-T @ DUP C@-T 64 OR SWAP C!-T ; 
            \ Set the IMMEDIATE bit of last name.
PREVIOUS DEFINITIONS

\ PART 4: CODE GENERATION

\ SOD-32 Forth is a native code Forth for an unusual machine, the SOD32.
\ Instructions are 32 bit cells. They are either calls to other definitions
\ (if bit 0 and 1 are zero) or conditional jumps (if bit 1 is 1 and bit
\ 0 is 0, or packs of six 5-bit opcodes (bit 0 is 1). In that case bit 31
\ indicates subroutine return. 

\ Forth primitives such as + and R> are single opcodes. The compiler 
\ compiles them as opcodes rather than calls to a definition. Other
\ definitions such as - and ! consist of only a few opcodes and are
\ expanded by the compiler into the constituent opcodes.

VARIABLE STATE-T 0 STATE-T ! \ State variable for cross compiler.
: T] 1 STATE-T ! ;
: T[ 0 STATE-T ! ;

VARIABLE CSP   \ Stack pointer checking between : and ;
: !CSP DEPTH CSP ! ;
: ?CSP DEPTH CSP @ - ABORT" Incomplete control structure" ;

HEX 80000000 DECIMAL CONSTANT RET-CODE \ Return bit.

VARIABLE OPLOC 0 OPLOC !  \ Target address where opcodes are appended.
VARIABLE OPSHIFT 31 OPSHIFT ! \ NUmber of bits to shift next opcode.

: CODEFLUSH 32 OPSHIFT ! ; \ Indicate that no more opcodes 
                            \ may be filled in at current location.
                            \ The unused opcodes are left 0 (noop).

: INSERT-OPCODE ( i --- ) \ Insert opcode i (0..31) into definition.
   OPSHIFT @ 30 > IF                                            
      THERE OPLOC ! 1 ,-T  \ Create a new 'sixpack' instruction
      1 OPSHIFT !          \ where opcodes may be inserted.
   THEN   
 \D  DUP CR ."  OPCODE " .  
   OPSHIFT @ LSHIFT OPLOC @ @-T + OPLOC @ !-T \ Add the shifted opcode.
   5 OPSHIFT +!            \ Next opcode must be shifted 5 more.
;

: LITERAL-T ( n --- ) 
\D DUP ."  Literal:" . CR  
  31 INSERT-OPCODE ,-T ;

TRANSIENT DEFINITIONS FORTH
\ Now define the words that do compile code. 

: OPCODE ( c --- )
  "HEADER DUP C, 2* RET-CODE 1+ OR ,-T MACRO \ Create an executable
                                             \ target definition.
  DOES> C@ INSERT-OPCODE 
;

: : !CSP "HEADER THERE , T]
    DOES> @ CODEFLUSH ,-T ;

: M: "HEADER THERE , MACRO \ M: makes a definition identical to that made by :
  T]                       \ but with macro bit set. If executed it copies 
                           \ all opcodes from the macro definition to the 
                           \ current definition. The macro itself is just
                           \ a target definition that can be executed.
   DOES> @ BEGIN
            DUP @-T         \ Get next instruction.
            DUP 1 AND 0= ABORT" Instruction not allowed in macro" 2/
            SWAP 4 + SWAP   \ Increment source address.
            6 0 DO \ Pick apart the six opcodes.
              DUP 31 AND ?DUP IF \ Skip opcode 0 (noop)
               DUP INSERT-OPCODE
               31 = IF \ Copy the literal for opcode 31 (lit) 
                      OVER @-T 
\D                         DUP . 
                      ,-T SWAP 4 + SWAP 
                    THEN
              THEN
              5 RSHIFT    
            LOOP
            1 AND \ Repeat until return bit encountered.  
           UNTIL
           DROP
;

: ; RET-CODE OPSHIFT @ 32 = IF \ If no current opcode location then 
        1 + ,-T              \ Make new instruction with six noops and return.
    ELSE 
        OPLOC @ @-T + OPLOC @ !-T \ else set return bit of current instruction.
    THEN CODEFLUSH T[ ?CSP \ Quit compilation state.
  ;

FORTH DEFINITIONS

\ PART 5: FORWARD REFERENCES 

\ Some definitions are referenced before they are defined. A definition
\ in the TRANSIENT voc is created for each forward referenced definition.
\ This links all addresses together where the forward reference is used.
\ The word RESOLVE stores the real address everywhere it is needed.    

: FORWARD  
  CREATE $FFFFFFFF ,              \ Store head of list in the definition.
  DOES> CODEFLUSH 
        DUP @ ,-T THERE 1 CELLS-T - SWAP ! \ Reserve a cell in the dictionary
                  \ where the call to the forward definition must come.
	          \ As the call address is unknown, store link to next 
                  \ reference instead.                                
;

: RESOLVE
  ALSO TARGET >IN @ ' >BODY @ >R >IN ! \ Find the resolving word in the 
                          \ target voc. and take the CFA out of the definition.
\D >IN @ BL WORD COUNT CR ." Resolving: " TYPE >IN !
  TRANSIENT ' >BODY  @                 \ Find the forward ref word in the
                                       \ TRANSIENT VOC and take list head.   
  BEGIN
   DUP $FFFFFFFF -                     \ Traverse all the links until end.
  WHILE
   DUP @-T                             \ Take address of next link from dict.
   R@ ROT !-T                           \ Set resolved address in dict.
  REPEAT DROP R> DROP PREVIOUS
;

\ PART 6: DEFINING WORDS.

TRANSIENT DEFINITIONS FORTH
 
FORWARD DOVAR \ Dovar is the runtime part of a variable.

: VARIABLE "HEADER THERE , [ TRANSIENT ] DOVAR [ FORTH ]  0 ,-T
\ Create a variable.
DOES> @ 4 + LITERAL-T  \ Compile var address as a literal for speed.  
; 

: CONSTANT "HEADER THERE ,
  RET-CODE 1 + 31 2* + ,-T  \ Assemble the instruction LIT with RETURN.
  ,-T
  DOES> @ 4 + @-T LITERAL-T \ Compile const as a literal for speed.
;

FORTH DEFINITIONS

: T' ( --- t-addr) \ Find the execution token of a target definition.
  ALSO TARGET ' >BODY @ \ Get the address from the shadow definition.
  PREVIOUS
;

: >BODY-T ( t-addr1 --- t-addr2 ) \ Convert executing token to param address.
  1 CELLS-T + ;

\ PART 7: COMPILING WORDS 

TRANSIENT DEFINITIONS FORTH

\ The TRANSIENT definitions for IF, THEN etc. compile the conditional
\ branch instructions of SOD-32. This is the address with bit 1 set,
\ this is the address + 2. SOD has no unconditional branch. It is 
\ composed of opcode 28 (which pushes 0 onto the stack) and the
\ conditional branch. 

: BEGIN CODEFLUSH THERE ;
: UNTIL CODEFLUSH 2 + ,-T ; 
: IF CODEFLUSH THERE 1 CELLS-T ALLOT-T ;
: THEN CODEFLUSH THERE 2 + SWAP !-T ; TARGET
: ELSE 28 INSERT-OPCODE [ TRANSIENT ] IF SWAP THEN [ FORTH ] ; 
: WHILE [ TRANSIENT ] IF [ FORTH ] SWAP ; TARGET
: REPEAT 28 INSERT-OPCODE [ TRANSIENT ] UNTIL THEN [ FORTH ] ; 

FORWARD (DO)
FORWARD (LOOP)
FORWARD (.")
FORWARD (POSTPONE)

: DO [ TRANSIENT ] (DO) [ FORTH ] THERE ;
: LOOP [ TRANSIENT ] (LOOP) [ FORTH ] ,-T ;
: ." [ TRANSIENT ] (.") [ FORTH ] 34 WORD COUNT DUP 1+ >R 
      THERE PLACE-T R> ALLOT-T ALIGN-T ;
: POSTPONE [ TRANSIENT ] (POSTPONE) [ FORTH ] T' ,-T ;

: \ POSTPONE \ ; IMMEDIATE
: \G POSTPONE \ ; IMMEDIATE
: ( POSTPONE ( ; IMMEDIATE \ Move duplicates of comment words to TRANSIENT
: CHARS-T CHARS-T ; \ Also words that must be executed while cross compiling.
: CELLS-T CELLS-T ;
: ALLOT-T ALLOT-T ;
: ['] T' LITERAL-T ;

FORTH DEFINITIONS

\ PART 8: THE CROSS COMPILER ITSELF.

VARIABLE DPL
: NUMBER? ( c-addr ---- d f)
  -1 DPL !
  BASE @ >R
  COUNT   
  OVER C@ 45 = DUP >R IF 1 - SWAP 1 + SWAP THEN \ Get any - sign 
  OVER C@ 36 = IF 16 BASE ! 1 - SWAP 1 + SWAP THEN   \ $ sign for hex.
  OVER C@ 35 = IF 10 BASE ! 1 - SWAP 1 + SWAP THEN   \ # sign for decimal
  DUP  0 > 0= IF  R> DROP R> BASE ! 0 EXIT THEN   \ Length 0 or less?
  >R >R 0 0 R> R>
  BEGIN  
   >NUMBER  
   DUP IF OVER C@ 46 = IF 1 - DUP DPL ! SWAP 1 + SWAP ELSE \ handle point. 
         R> DROP R> BASE ! 0 EXIT THEN   \ Error if anything but point  
       THEN    
  DUP 0= UNTIL DROP DROP R> IF DNEGATE THEN    
  R> BASE ! -1  
;


: CROSS-COMPILE
  ONLY TARGET DEFINITIONS ALSO TRANSIENT \ Restrict search order.
  BEGIN 
   BL WORD 
 \D CR DUP COUNT TYPE 
   DUP C@ 0= IF \ Get new word
    DROP REFILL DROP                      \ If empty, get new line.
   ELSE
    DUP COUNT S" END-CROSS" COMPARE 0=    \ Exit cross compiler on END-CROSS
    IF
     ONLY FORTH ALSO DEFINITIONS          \ Normal search order again.
     DROP EXIT
    THEN
    FIND IF                               \ Execute if found.
     EXECUTE
    ELSE
     NUMBER? 0= ABORT" Undefined word" DROP 
     STATE-T @ IF \ Parse it as a number.
      LITERAL-T   \ If compiling then compile as a literal. 
     THEN  
    THEN
   THEN
  0 UNTIL
;

\ PART 9: CROSS COMPILING THE KERNEL 

\ Up till now not a single byte of the new Forth kernel has actually been 
\ compiled. 

TRANSIENT DEFINITIONS
FORWARD COLD
FORWARD WARM
FORWARD DIV-EX
FORWARD BREAK-EX
FORWARD TIMER-EX
FORWARD THROW
FORTH DEFINITIONS

S" kernel.4th" INCLUDED

\ PART 10: FINISHING AND SAVING THE TARGET IMAGE.

\ Resolve the forward references created by the cross compiler.
RESOLVE (DO) RESOLVE DOVAR
RESOLVE (LOOP) RESOLVE (.") 
RESOLVE COLD   RESOLVE WARM
RESOLVE DIV-EX RESOLVE BREAK-EX
RESOLVE TIMER-EX RESOLVE THROW
RESOLVE (POSTPONE)

\ Store appropriate values into some of the new Forth's variables.
: CELLS>TARGET
  0 DO OVER I CELLS + @ OVER I CELLS-T + !-T LOOP 2DROP ;

#THREADS T' FORTH-WORDLIST >BODY-T !-T
TLINKS T' FORTH-WORDLIST >BODY-T 4 + #THREADS CELLS>TARGET 
THERE   T' DP             >BODY-T !-T 

SAVE-IMAGE kernel.img \ Save the newly constructed Forth system to disk.
 
BYE \ All's been done. 
