

kernal		.namespace 

basicnmivector	= $a002        ; doing a jmp($a002) does a "BASIC warm start" and this is called during run/stop+restore

clrscr		= $e544

scinit		= $ff81        ; Initialize VIC; restore default input/output to keyboard/screen; clear screen; set PAL/NTSC switch and interrupt timer.
ioinit		= $ff84	       ; Initialize CIA's, SID volume; setup memory configuration; set and start interrupt timer.
restor		= $ff8a        ; Fill vector table at memory addresses $0314-$0333 with default values.
scnkey		= $ff9f	       ; Query keyboard put current matrix code into memory address $00CB, current status of shift keys into memory address $028D and PETSCII code into keyboard buffer.
scnkeydefault   = $ea87        ; default 

chrin           = $ffcf        ; Read byte from default input (for keyboard, read a line from the screen). (If not keyboard, must call OPEN and CHKIN beforehands.)
chrout          = $ffd2        ; CHROUT. Write byte to default output.

getin           = $ffe4        ; Read byte from default input. (If not keyboard, must call OPEN and CHKIN beforehands.)

plot            = $fff0        ; PLOT. Save or restore cursor position.
                               ; Input: Carry: 0 = Restore from input, 1 = Save to output; 
                               ; Output: X = Cursor column (if Carry = 1); Y = Cursor row (if Carry = 1).
                               ; Used registers: X, Y.
                               ; Real address: $E50A.

isrvector       = $0314
isrdefault      = $ea31
isrdefaultexit  = $ea81
                .endnamespace

