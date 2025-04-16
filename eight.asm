.include "lib/utilmacros.asm"
.include "lib/kernal.asm"
.include "lib/vic.asm"
.include "lib/cia.asm"

                #basicstub start

; working area in zero page
zpb1            = $02
zpb2            = $03
zpb3            = $04
zpptr1          = $fb
zpptr2          = $fd

; sprites
sprptrs         = $07f8
sprdata         = $2000  ; 64 * 26 = 1664 bytes, computed at startup  
initraster      = 252

; config
debug = true
speed = 1
adjspeed = 1
spritesenabled = $ff

start       .block
            lda #vic.colors.darkgrey
            sta vic.borderclr
            lda #vic.colors.black
            sta vic.bgclr

            jsr makesprites
            jsr initsprites
            jsr initstatus
            jsr initinterrupts

mainloop    lda stopreq          ; have we been asked to stop?
            beq mainloop

stop        lda #0
            sta stopreq          ; clear stop request
            jsr kernal.restor    ; reset interrupt vectors
            jsr kernal.ioinit    ; reset CIA config
            jsr kernal.scinit    ; reset VIC and clear screen
            jmp (kernal.basicnmivector)          ; BASIC warm start - a plain rts leave the screen in funny state
            .endblock

; ===============================
initsprites .block
            lda #spritesenabled ; enable all sprites
            sta vic.sprenable

            ;set sprite pointers
            ldx # sprdata / 64
            ldy #0
-           txa
            sta sprptrs,y
            inx
            iny
            cpy #8
            bne -

            ;set sprite colours
            ldx #1
            ldy #0
-           txa
            sta vic.sprcolors,y
            inx
            iny
            cpy #8
            bne -

            ;sprite 0 is active
            lda #0
            sta spritenum
            rts
            .bend

; ===============================
initstatus .block
            jsr scr.clrscr
            #addr2ptr xradtxt, scr.tmpptr
            jsr scr.strout

            lda xradius
            jsr scr.bin8bcd
            #scr.hex12out scr.bcdtotal

            #scr.crsrnext

            #addr2ptr yradtxt, scr.tmpptr
            jsr scr.strout

            lda yradius
            jsr scr.bin8bcd
            #scr.hex12out scr.bcdtotal

            #scr.newline
            #addr2ptr pos0txt, scr.tmpptr
            jsr scr.strout 

            rts
            .bend

; ===============================
initinterrupts
         .block
                                             ; setup interrupts
         sei                                 ; disable interrupts for more accurate timing
         #vic.rasterint initraster, rasterstab

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

; ===============================
rasterstab  .block
            lda #vic.colors.cyan
            sta vic.borderclr

            ; acklowledge interrupt, must happen before readkeyboard
            ; which calls getin which invokes `cli`, if key pressed
            lda #1
            sta vic.intstatus     

            jsr scnkey
            jsr readkeyboard

kbdone      lda #vic.colors.red
            sta vic.borderclr

            jsr readjoystick

            lda #vic.colors.yellow
            sta vic.borderclr

            jsr positionsprites

            lda #vic.colors.lightgreen
            sta vic.borderclr

            jsr printsprpos

            ; lda #vic.colors.brown
            ; sta vic.borderclr
            ; jsr playsid  ; play the music

            lda #vic.colors.lightgrey
            sta vic.borderclr

            ; don't do rest of int routine, we only needed scnkeydefault 
            ; and have done that already
            jmp kernal.isrdefaultexit
            .endblock

; ===============================
readjoystick  .block

              ldx spritenum
              lda cia1.joystick2
              lsr a
              bcs chkdown
	      pha
	      jsr radius.incy
	      pla

chkdown       lsr a
              bcs chkleft
	      
	      pha
	      jsr radius.decy
	      pla

chkleft       lsr a
              bcs chkright
	      pha
	      jsr radius.decx
	      pla

chkright      lsr a
              bcs chkbutton
	      pha
	      jsr radius.incx
	      pla

chkbutton     lsr a
              bcs notpushed           
              ; state = 1
              lda lastbuttonstate     ; use state to do a "rising edge detect", ie state from 0 -> 1
              bne chkdone             ; was pushed last time alredy, ignore
              lda #1                  
              sta lastbuttonstate     ; remember that it was pushed on this cycle
              inc vic.sprcolors,x     ; change color
              rts

notpushed     lda #0           ; state = 0
              sta lastbuttonstate
chkdone       rts
              .endblock

; ===============================
readkeyboard  .block
              ; jsr kernal.getin
              bne chkstop ; key found
              rts

chkstop       cmp #3 ; key "stop"
              bne num

              lda #1
              sta stopreq
              rts          ; request stop from mainline code

num           cmp #49 ; key 1
              bcc alpha ;invalid
              cmp #57 ; key 9 (valid is 1-8)
              bcs alpha
              ;key from 1 to 8
              sec
              sbc #49 ; set acc 0 to 7
              sta spritenum
              rts

alpha         cmp #65 ;A key
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

cursorup      cmp #145
              bne cursordown
	      jsr radius.incy
	      rts

cursordown    cmp #17
              bne cursorleft
	      jsr radius.decy
	      rts

cursorright   cmp #29
              bne space
	      jsr radius.incx
	      rts

cursorleft    cmp #157
              bne cursorright
	      jsr radius.decx
	      rts

space         cmp #32
              bne done
              lda #$ff
              eor vic.sprenable
              sta vic.sprenable
done          rts

             .endblock


; ============================
radius        .block

incx          lda xradius
              cmp #$100 - adjspeed
              bcs +
              inc xradius
              .if adjspeed == 2 
              inc xradius
              .endif
+             jmp updx

decx          lda xradius
              cmp #0 + adjspeed
              bcc +
              dec xradius
              .if adjspeed == 2 
              dec xradius
              .endif
+             jmp updx

incy          lda yradius
              cmp #$100 - adjspeed
              bcs +
              inc yradius
              .if adjspeed == 2 
              inc yradius 
              .endif
+             jmp updy

decy          lda yradius
              cmp #0 + adjspeed
              bcc +
              dec yradius
              .if adjspeed == 2 
              dec yradius
              .endif
+             jmp updy

updx          #scr.setpos 0, size(xradtxt)-1
              lda xradius
              jsr scr.bin8bcd
              #scr.hex12out scr.bcdtotal
              rts

updy          #scr.setpos 0, size(xradtxt) + 3 + size(yradtxt) - 1
              lda yradius
              jsr scr.bin8bcd
              #scr.hex12out scr.bcdtotal
              rts
	      .endblock


; ===============================
positionsprites   .block
                  inc angle 
                  .if speed == 2
                  inc angle 
                  .endif
                  ldx #0 ; sprite number

nextspr           txa
                  asl a
                  asl a
                  asl a
                  asl a
                  asl a ; multiply by 32 to get sprite angle offset
                  clc

                  adc angle
                  sta zpb2 ; sprite angle

                  and #%0011_1111  ; just always repeat maths of 1st quadrant
                  sta zpb3

                  lda zpb2
                  lsr a    
                  lsr a
                  lsr a
                  lsr a
                  lsr a  ; divide by 64
                  lsr a  ; this is the quadrant we are actually in
                  beq q0
                  cmp #1
                  beq q1
                  cmp #2
                  beq q2
                  cmp #3
                  beq q3

q0                #coord xradius, cos, zpb3
                  #shiftbycentrex add

                  #coord yradius, sin, zpb3
                  #shiftbycentrey add
                  jmp endjumpt

q1                #reverseflow zpb3
                  #coord xradius, cos, zpb3
                  #shiftbycentrex sub

                  #coord yradius, sin, zpb3
                  #shiftbycentrey add
                  jmp endjumpt

q2                #coord xradius, cos, zpb3
                  #shiftbycentrex sub

                  #coord yradius, sin, zpb3
                  #shiftbycentrey sub
                  jmp endjumpt

q3                #reverseflow zpb3
                  #coord xradius, cos, zpb3
                  #shiftbycentrex add

                  #coord yradius, sin, zpb3
                  #shiftbycentrey sub

endjumpt          inx
                  cpx #8
                  bne nextspr

                  lda #vic.colors.lightred
                  sta vic.borderclr

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
                  .endblock


; ===============================
printsprpos .block
            #scr.setpos 1, size(pos0txt)-1 

            lda xposlo
            ldy xposhi
            jsr scr.bin9bcd
            #scr.hex12out scr.bcdtotal

            #scr.crsrnext ; leave a space

            lda ypos
            jsr scr.bin8bcd
            #scr.hex12out scr.bcdtotal
            rts
            .endblock

; =============================================
; variables, string constants and lookup tables
; =============================================

                 .enc "screen"
xradtxt          .null "xrad="
yradtxt          .null "yrad="
pos0txt          .null "pos0="
                 .enc "none"

spritenum        .byte 0
lastbuttonstate  .byte 0

xposlo           .byte 50,80,110,140
                 .byte 170,200,230,5
xposhi           .byte 0,0,0,0,0,0,0,1
ypos             .byte 55,55,55,55
                 .byte 55,55,55,55
stopreq          .byte 0

centrexlo        .byte 170
centrexhi        .byte 0
centrey          .byte 140
angle            .byte 0

xradius          .byte 100
yradius          .byte 80


byterad     = 128/pi
sinb        .sfunction binangle, sin(binangle/byterad)
cosb        .sfunction binangle, cos(binangle/byterad)
log2        .sfunction val, log(val)/log(2)

l2sinb      .sfunction binangle, log2(sinb(binangle))
l2cosb      .sfunction binangle, log2(cosb(binangle))

.align $100 
thetaq1     = [0.01] .. range(1, 64)   ; fudge zero to prevent log errros
logcoslo    .byte <sint(round(l2cosb(thetaq1) * 2**11))
logcoshi    .byte >sint(round(l2cosb(thetaq1) * 2**11))
logsinlo    .byte <sint(round(l2sinb(thetaq1) * 2**11))
logsinhi    .byte >sint(round(l2sinb(thetaq1) * 2**11))

.align $100
rvals       = [0.01] .. range(1,256)   ; fudge zero to prevent log errros
loglo       .byte <round(log2(rvals) * 2**11)
loghi       .byte >round(log2(rvals) * 2**11)

.align $100 ; align to page
log2lovals    = range(256)
antilog
        .for log2hi := 0, log2hi != 8, log2hi += 1
             .byte round(2 ** ((256.0 * log2hi + log2lovals) / 2**8))
        .endfor

; =======================
; take antilog
; =======================

takeantilog .macro 
        lda zpb2
        bpl positive
        lda #0
        jmp done
positive
        ; first divide the log by 8 (because that is how our antilog table is set up)
        lsr zpb2
        ror zpb1
        lsr zpb2
        ror zpb1
        lsr zpb2
        ror zpb1

        ; calculate the page of the antilog lookup table based on the high byte
        lda zpb2
        clc
        adc #>antilog
        sta alogld + 2 ; modfiy code to select page by hi-byte of log value
        ldy zpb1       ; index by low-byte
alogld  lda antilog, y ; self modified
done
        .endmacro


coord   .macro radius, trigf, angle
        ldy \angle
        lda log\{trigf}lo, y
        clc
        ldy \radius
        adc loglo, y
        sta zpb1

        ldy \angle
        lda log\{trigf}hi, y
        ldy \radius
        adc loghi, y
        sta zpb2

        ; zpb1 + zpb2 now contain the log2 of the resilt of r * cos(theta)
        ; now take the anti log
        #takeantilog
        ; now have the coord value in accumulator
        .endmacro

add     = 1
sub     = -1

shiftbycentrex .macro addorsub
        .if \addorsub == add
            clc
            adc centrexlo
        .else
            sta zpb1
            lda centrexlo
            sec
            sbc zpb1
        .endif

        sta xposlo,x

        lda #0
        .if \addorsub == add
            adc #0 
        .else
            sbc #0
        .endif
        sta xposhi,x
        .endmacro


shiftbycentrey .macro addorsub
        .if \addorsub == add
            clc
            adc centrey
        .else
            sta zpb1
            lda centrey
            sec
            sbc zpb1
        .endif
        sta ypos,x
        .endmacro


reverseflow .macro angle
        lda #63
        sec
        sbc \angle
        sta \angle
        .endmacro


; libraries that produce actual memory content (ie not pure macros)
.include "lib/scr.asm"
.include "lib/alphasprites.asm"
.include "lib/scnkey.asm"
