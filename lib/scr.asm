
scr		.namespace 

tmpidx = $16  
tmpptr = $18  ; and $19

crsrrowptr    = $d1   ; and $18, points to first byte in screen row - used by kernal, we are stealing it
crsrcol       = $d3   ; current column of cursor relative to start of row in $17/£18 - used by kernal, we are stealing it

currcrsrclr   = $0286  ; under control of kernal, good default


homerow .macro 
	; set up top left corner
        #addr2ptr vic.screenmem, crsrrowptr
	.endmacro

setpos  .macro row, col  ; different to plot routine belo, because this is a compile time macro, faster but more code
        #addr2ptr vic.screenmem + 40*\row, scr.crsrrowptr
	lda #\col
	sta scr.crsrcol
	.endmacro

plot 	.block ; a= row,  y = col
	sty crsrcol ; save y as column

	tay
	lda rowslo, y
	sta crsrrowptr
	lda rowshi, y
	sta crsrrowptr+1
	rts

rows    := vic.screenmem + range(0, 1000, 40)
rowslo  .byte <rows
rowshi  .byte >rows

	.endblock


fillchr  .block   ; A = screencode for fill byte
         ldy #250
-        dey
         sta vic.screenmem,y
	 sta vic.screenmem + 250,y
	 sta vic.screenmem + 500,y
	 sta vic.screenmem + 750,y
         bne -
	 rts
	 .endblock

fillclr  .block   ; A = colorcode for fill
	 ldy #250
-        dey
         sta vic.colorram,y
	 sta vic.colorram + 250,y
	 sta vic.colorram + 500,y
	 sta vic.colorram + 750,y
         bne -
	 rts
	 .endblock

clrscr  .block
	lda #32
	jsr fillchr
	lda currcrsrclr
	jsr fillclr
        #homerow
	lda #0
	sta crsrcol
	rts
	.endblock

crsrnext .macro ; advances the cursor by one chr
	inc scr.crsrcol ; leave a space
	.endmacro

newline .macro ; advances the cursor by one row and back to col0 => newline
	#add16c scr.crsrrowptr, 40 
	lda #0
	sta scr.crsrcol
	.endmacro

chrout  .macro
	ldy crsrcol
	sta (crsrrowptr),y
	#crsrnext
	.endmacro

strout  .block ; print out the string pointed to by scr.tmp
	ldy #0
	sty tmpidx
-	ldy tmpidx    
	lda (tmpptr),y
	beq done
	inc tmpidx
	#chrout
	bne - ; always branch for strings < 255, which would break anyway
done
	rts
	.endblock

; ===================
; hex printing rountines
; ===================


hex4out     .block  ; nibble in lower A
	    cmp #10
	    bcs letter
	    .enc "screen"
	    adc #"0"             ; '0' screencode
	    bne out
letter	    sbc #(10 - "a")      ; 10 we had minus 'a' screencode, carry is already set
	    .enc "none"
out         #chrout
	    rts
	    .endblock

hex8out     .block  ; byte in A
	    pha
	    lsr a
	    lsr a
	    lsr a
	    lsr a
	    jsr hex4out
	    pla
	    and #$0f
	    jsr hex4out
	    rts
           .endblock

hex12out    .macro addr
	    lda \addr+1
	    and #$0f
	    jsr scr.hex4out
	    lda \addr
	    jsr scr.hex8out
            .endmacro

hex16out    .macro addr
	    lda \addr+1
	    jsr scr.hex8out
	    lda \addr
	    jsr scr.hex8out
            .endmacro

hex20out    .macro addr
	    lda \addr+2
	    and #$0f
	    jsr scr.hex4out
	    #scr.hex16out \addr
            .endmacro

hex24out    .macro addr
	    lda \addr+2
	    jsr scr.hex8out
	    #scr.hex16out \addr
            .endmacro


; these are kernal string stack bytes in the zero page
bininput   = $19     ; 8 or 16 bit value
bcdtotal   = $1b     ; 16 or 24 bit value: accumulating bcd total 

; =================== 
; byte wise bin2bcd routine
; ===================

bin8bcd    .block ; binary in A
	    sta bininput

	    lda #0
	    sta bcdtotal
	    sta bcdtotal+1

	    ldy #0
	    sei   ; don't want interrupts running with decimal flag
	    sed   ; decimal for core of loop
nextbindig  lsr bininput
	    bcc skipadding
	    lda bcdtotal
	    clc
	    adc bindigvallow,y
	    sta bcdtotal
	    lda bcdtotal+1
	    adc bindigvalmid,y
	    sta bcdtotal+1
	    
skipadding  iny 
	    cpy #8
	    bne nextbindig
	    cld
	    cli
	    rts
            .endblock
	   

; =================== 
; word wise bin2bcd routine, selectable bit width
; ===================

bin9bcd     ; low byte in A, high byte in Y
	    sta bininput
	    lda #9
	    sta tmpidx
	    bne binXbcd  ; always branch

bin16bcd    ; low byte in A, high byte in Y
	    sta bininput
	    lda #16
	    sta tmpidx

binXbcd    .block ; low byte in A, high byte in Y, number of binary to examine in tmpidx
	    sty bininput+1

	    lda #0          ; clear total
	    sta bcdtotal
	    sta bcdtotal+1
	    sta bcdtotal+2

	    ldy #0
	    sei   ; don't want interrupts running with decimal flag
	    sed   ; decimal for core of loop

nextbindig  lsr bininput+1      ; rotate right the 16-bit input
	    ror bininput
	    bcc skipadding      ; if lowest bit was not set, then next digit

	    lda bcdtotal        ; lookup the value of this binary digit
	    clc
	    adc bindigvallow,y  ; as a 3-byte BCD value
	    sta bcdtotal
	    lda bcdtotal+1
	    adc bindigvalmid,y  ; and add to total 
	    sta bcdtotal+1
	    lda bcdtotal+2
	    adc bindigvalhi,y
	    sta bcdtotal+2
	    
skipadding  iny 
	    cpy tmpidx
	    bne nextbindig
	    cld
	    cli
	    rts
            .endblock

; storing the folowing "-byte BCD (ie 6 BCD digits) values in 3 split arrays low/mid/hi
; they represent the first 16 powers of 2 in BCD
; $000001, $000002, $000004, $000008, 
; $000016, $000032, $000064, $000128, 
; $000256, $000512, $001024, $002048, 
; $004096, $008192, $016384, $032768, 
bindigvallow  .byte $01, $02, $04, $08, $16, $32, $64, $28, $56, $12, $24, $48, $96, $92, $84, $68
bindigvalmid  .byte $00, $00, $00, $00, $00, $00, $00, $01, $02, $05, $10, $20, $40, $81, $63, $27
bindigvalhi   .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $03


.endnamespace

