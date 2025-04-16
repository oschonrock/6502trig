tk_sys          = $9e

*               = $0801
                .word (basic_end), 10                                   ;pointer, line number
                .null tk_sys, format("%4d", start)

basic_end       .word 0                                         ;basic line end

; working area in zero page
zpb1            = $02
zpb2            = $03
zpptr1          = $fb
zpptr2          = $fd

; sprites
sprptrs         = $07f8

; simple basic stub to start machine language code

sprdata         = $2000  ; can't be $1000 - $1fff due to VIC addressing limitations

debug = true

.include "lib/kernal.asm"
.include "lib/vic.asm"
.include "lib/cia.asm"
.include "lib/utilmacros.asm"


start    
         lda #vic.colors.black
         sta vic.borderclr
         sta vic.bgclr

         jsr kernal.clrscr
         jsr makesprites
         jsr initsprites
         jsr initsid
         ; jsr positionsprites ; call once from main code
         jsr initinterrupts

         clc ; just once here is enough, only the adc affects it and that can never overflow
         ldx vic.colors.black
mainloop
	 lda #1
-        ldy #250
-        dey
         sta vic.screenmem,y
	 sta vic.screenmem + 250,y
	 sta vic.screenmem + 500,y
	 sta vic.screenmem + 750,y
         bne -
         adc #1
         cmp #27
         bne --
         txa
         ldy #250
-        dey
         sta vic.colorram,y
	 sta vic.colorram + 250,y
	 sta vic.colorram + 500,y
	 sta vic.colorram + 750,y
         bne -
         inx

         ; have we been asked to stop?
         lda stopreq
         beq mainloop

stop            
	 lda #0
	 sta stopreq                          ; clear stop request
	 jsr kernal.ioinit                    ; reset CIA config
	 jsr kernal.restor                    ; reset interrupt vectors
	 jsr kernal.scinit                    ; reset VIC and clear screen
         jsr initsid
         rts                                  ; return to basic


initsprites
            .block
            lda #$ff ; enable all sprites
            sta vic.sprenable

            ;set sprite pointers
            ldx # sprdata / 64
            ldy #0
loop1       txa
            sta sprptrs,y
            inx
            iny
            cpy #8
            bne loop1

            ;set sprite colours
            ldx #1
            ldy #0
loop2       txa
            sta vic.sprcolors,y
            inx
            iny
            cpy #8
            bne loop2

            ;sprite 0 is active
            lda #0
            sta spritenum

            rts
            .bend

initinterrupts
         .block
                                             ; setup interrupts
         sei                                 ; disable interrupts for more accurate timing
         #vic.rasterint 84, rasterstab

         lda #84
         sta startraster
         
         lda #%0000_0001
         sta vic.intctrl                     ; enable raster interrupts
         inc vic.intstatus                   ; ack any previously pending raster interrupts

         lda #%0111_1111                     ; disable all CIA1 interrupts
         sta cia1.intctrl
         sta cia2.intctrl                    ; disable all CIA2 interrupts

         lda cia1.intctrl                    ; acknowledge any pending CIA interrupts
         lda cia2.intctrl

         cli
         rts
         .bend

* = $0900 ; new page to avoid cross page branches mucking up timing
rasterstab  
            sei
            lda #<inthandler                    ; configure 2nd int handler
            sta kernal.isrvector                ; 
            lda #>inthandler                    ;
            sta kernal.isrvector+1
            #delay 12                           ; wait until the end of the raster line
            inc vic.rasterintline               ; we are already on the next rasterline so set irw for one the next one
            lda #1
            sta vic.intstatus                   ; acklowledge interrupt
            cli
            #delay 46
            nop           ; The second interrupt will occur while executing these
            nop           ; two-cycle instructions.
            nop
            nop
            nop
            jmp kernal.isrdefault

inthandler
            lda #<rasterstab                    ; back to 1st int handler
            sta kernal.isrvector                ; 
            lda #>rasterstab                    ;
            sta kernal.isrvector+1
            ldx vic.rasterintline
            #delay 5
            cpx vic.rasterline
            beq *+2                             ; 3 cycles if we are there, 2 if not
            ; dex
            ; dex
	    #delay 8
	    
            ; ldx startraster           ; make this modifiable rather than relative (same cycle count as 2 x dex)
            ; stx vic.rasterintline     ; restore original raster interrupt position   
            ldx #1
            stx vic.intstatus         ; acknowledge the raster interrupt         

            ; we are now stably synced to the raster beam

            lda zpb2
            clc
nrasters    adc #160      ; self modified from keyboard control
            sta maxclr+1  ; self modify the cmp below
            #delay 23
loop        
            inc zpb2
            ldx zpb2
            stx vic.borderclr
            stx vic.bgclr
	    lda vic.screenctrl     ; bit7 contains bit8 of rasterline
	    asl a
	    bcs nextgt255          ; beyond start of border for sure, cannot be a badline
            lda vic.rasterline     ; check for badline
            cmp #51
            bcc nextlt50
            cmp #251
            bcs nextgt251
            and #7		   ; if rasterline modulo 8 == 3
            cmp #3		   ; then badline!
            bne next
            #delay 3 ; extra badline delay to make it 2 lines
nextgt255   #delay 8  ; delay for skipping lda vic.rasterline, cmp # 51
nextlt50    #delay 4  ; delay for skipping cmp #251, bcs netxgt251
nextgt251   #delay 6  ; delay for skipping and #7, cmp #3, bne next

next        #delay 15
maxclr      cpx #$ff   ; self modifying
            bne loop

            #delay 7
	    ; finished with time critical rasterbars

            lda #vic.colors.black
            sta vic.borderclr
            sta vic.bgclr


	    ; non time critical, but regular tasks
            lda #vic.colors.grey
            sta vic.borderclr
            jsr readjoystick
            jsr readkeyboard
            jsr positionsprites

            lda #vic.colors.red
            sta vic.borderclr
	    jsr playsid  ; play the music

            ldx startraster           ; make this modifiable rather than relative (same cycle count as 2 x dex)
            stx vic.rasterintline     ; restore original raster interrupt position   

            lda #vic.colors.black
            sta vic.borderclr
	    jmp kernal.isrdefaultexit        ; return to rasterstab irq


readjoystick
         .block

         ldx spritenum
         lda cia1.joystick2
         lsr a
         bcs chkdown
         dec ypos,x

chkdown  lsr a
         bcs chkleft
         inc ypos,x

chkleft  lsr a
         bcs chkright
         dec xposlo,x
         ldy xposlo,x
         cpy #$ff
         bne chkright
         dec xposhi,x

chkright lsr a
         bcs chkbutton
         inc xposlo,x
         bne chkbutton
         inc xposhi,x

chkbutton lsr a
        bcs notpushed           
        ; state = 1
        lda lastbuttonstate     ; use state to do a "rising edge detect", ie state from 0 -> 1
        bne chkdone             ; was pushed last time alredy, ignore
        lda #1                  
        sta lastbuttonstate         ; remember that it was pushed on this cycle
        inc vic.sprcolors,x         ; change color
        rts

notpushed 
        lda #0           ; state = 0
        sta lastbuttonstate
chkdone
        rts
        .bend

readkeyboard
         .block
         jsr kernal.getin
         beq done ;no key

         cmp #3 ; key "stop"
         bne num

         lda #1
         sta stopreq
         rts          ; request stop from mainline code

num cmp #49 ; key 1
        bcc alpha ;invalid
        cmp #57 ; key 9 (valid is 1-8)
        bcs alpha
        ;key from 1 to 8
        sec
        sbc #49 ; set acc 0 to 7
        sta spritenum
        rts

alpha
        cmp #65 ;A key
        bcc cursorup
        cmp #91 ;one more than Zz
        bcs cursorup

        sec 
        sbc #65           ; make 0-based index
        clc
        adc #sprdata / 64 ; add base sprite pointer
        ldx spritenum
        sta sprptrs,x
        rts

cursorup
        cmp #145
        bne cursordown
        inc nrasters+1 ; increases the number of raster lines painted by self modifying code and visual "beat frequency sliding up and down screen"
        rts

cursordown
        cmp #17
        bne cursorleft
        dec nrasters+1 ; similar to above, but decreases
        rts

cursorleft
        cmp #157
        bne cursorright
	lda startraster
	sec
	sbc #8
	sta startraster
        rts
cursorright
        cmp #29
        bne space
	lda startraster
	clc
	adc #8
	sta startraster
        rts

space
        cmp #32
	lda #$ff
	eor vic.sprenable
	sta vic.sprenable
	bne done
done	rts
        .bend


positionsprites
        .block

        lda #0  ; clear sprx high bits, 
        sta zpb1 ; zero page tmp storage to reduce glitching if raster passes

        ; unrolled for 25% speed gain
        .for i := 0, i != 8, i += 1
            lda xposlo + i
            sta vic.sprpos + i * 2

            lda ypos + i
            sta vic.sprpos + i * 2 + 1

            lda xposhi + i
            lsr a
            ror zpb1
        .endfor

        lda zpb1
        sta vic.sprxhibits

        rts
        .bend


spritenum        .byte 0
lastbuttonstate  .byte 0

xposlo           .byte 50,80,110,140
                 .byte 170,200,230,5
xposhi           .byte 0,0,0,0,0,0,0,1
ypos             .byte 55,55,55,55
                 .byte 55,55,55,55
stopreq          .byte 0
startraster      .byte 84

.include "lib/alphasprites.asm"


; $1000 - $1fff
sid        = binary("assets/Axel_Foley.sid"); read in the SID file as bytes
offs       := sid[[$7, $6]]     ; data offset (big endian)
load       := sid[[$9, $8]]     ; load address (big endian)
initsid    = sid[[$b, $a]]      ; init address (big endian)
playsid    = sid[[$d, $c]]      ; play address (big endian)

; if load address is zero then it's the first 2 bytes of data
        .if load == 0
load    := sid[offs:offs+2]  ; load address (little endian)
offs    += 2                 ; skip load address bytes
        .endif

*       = load               ; set pc to load address
        .text sid[offs:]     ; dump music data
