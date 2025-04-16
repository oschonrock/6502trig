


; =========================
; standard print routines for binary byte an word value as decimal numbers
;
; these use a diffeent technique (repeated subtraction of powers of ten)
; and directly print out as they go
; 
; this is functionally replaced by the BCD conversion routines in scr.asm 
; those are slightly faster and more composable
; these are a better alternative if you don't want to store the intermediate BCD value
; ============================

byte8out   .block
    ; on entry, a = value to be printed

    ldx #2              ; number of digits to print, minus 1
; removeleading0s
;     cmp powers,x        ; if the value is >= 10^x...
;     bcs loop1           ; go ahead and start to print the value
;     dex                 ; otherwise decrease the digit count
;     bne removeleading0s
	
loop1                  ; loop for each digit to be printed
    ldy #0              ; count = 0
loop2
    cmp powers,x        ; see if subtracting 10^n would take us below 0
    bcc nomore          ; if so, we don't try to subtract any more
    iny                 ; increment count
    sbc powers,x        ; subtract 10^n from value
    bcs loop2           ; unconditionally reloop (c will always be set here)

nomore
    pha                 ; preserve accumulator
    tya                 ; get count into accumulator
    adc #48             ; add ascii code for digit 0 (c will always be clear)
    #chrout
    pla
    
    dex                 ; go to next digit to be printed
    bpl loop1           ; reloop
    rts
	
powers
    .byte 1              ; table containing one entry per power of 10
    .byte 10
    .byte 100
    .endblock



;********************************************************************
; Decimal number printing example
; by ccr/TNSP^PWP <ccr@tnsp.org>
;********************************************************************

;====================================================================
; Prints a 9bit value in decimal
; A = low byte of value
; Y = high byte
;====================================================================

word9out   .block
	   ; Store value to a temporary location
	   sty tmpptr+1
	   sta tmpptr

	   ; special handling to ignore negatives
	   tya
	   and #$80 ; test top bit, for negatives
	   beq positive
	   #crsrnext ; move the cursor along 3 digits as expected
    	   rts ; ignore the whole process        

	   ; Set Y register, indexing the division table, to 2
	   ; as the max divisor for 8-bit value is 100
positive   ldy #2
	   jmp qdivloop

;====================================================================
; Prints a 16bit value in decimal
; A = low byte of value
; Y = high byte
;====================================================================
word16out
	; Store value to a temporary location
	sty tmpptr+1
	sta tmpptr

	; Set Y register, indexing the division table, to 0
	ldy #0

	; Division loop for each digit
qdivloop 

	; Setup self-modifying code
	lda qdivtab_hi, y
	sta qp_hi+1
	sta qd_hi+1

	lda qdivtab_lo, y
	sta qp_lo+1
	sta qd_lo+1

	ldx #0

qcheck 
	; Check if value is larger or equal than divisor
	lda tmpptr+1
qp_hi 	cmp #0
	bcc qsmaller
	bne qbigger

	lda tmpptr
qp_lo 	cmp #0
	bcc qsmaller

	; It is larger or equal, substract divisor from it
	sec
qbigger 
	lda tmpptr
qd_lo 	sbc #0
	sta tmpptr

	lda tmpptr+1
qd_hi 	sbc #0
	sta tmpptr+1

	; Increase X
	inx
	jmp qcheck

qsmaller 
	; Now we have the count of how many times the divisor "fit"
	; into the divident in X register, so we can print it

	; save registers uisng elf modifying code during printing
	sta qsav_a+1
	; stx qsav_x+1
	sty qsav_y+1

	; Add '0' (=$30 PETSCII) to convert to PETSCII numeric digit
	; and our direct to screenmem macro to poke it 
	txa
	clc
	adc #$30
	#chrout 

	; restore resgitsers using seelf modified code
qsav_a  lda #0
; qsav_x  ldx #0
qsav_y  ldy #0

	; Then continue to next digit until we have gone through 5
	; which is the max for 16bit number
	iny
	cpy #5
	bcc qdivloop
	rts

; Tables for the divisor values: 10000, 1000, 100, 10, 1
qdivtab_hi 	.byte >10000, >1000, 0, 0, 0
qdivtab_lo 	.byte <10000, <1000, 100, 10, 1

    .endblock

; example usage
; 	lda xposlo
; 	ldy xposhi
; 	jsr scr.word9out

; 	#scr.crsrnext ; leave a space
; 	lda ypos
; 	jsr scr.byte8out

