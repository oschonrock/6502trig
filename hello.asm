; simple basic stub to start machine language code
tk_sys 		= $9e

*       	= $0801
		.word (basic_end), 10                              	;pointer, line number
		.null tk_sys, format("%4d", start)

basic_end	.word 0						;basic line end
		  
; constants		  
black		= 0
white		= 1
blue		= 6
yellow		= 8
ltblue  	= 14

; memory locations
char 		= $02

screen_mem	= $0400
border_color	= $d020


isr_vector      = $0314
isr_default     = $ea31
isr_default_exit	= $ea81

screen_ctrl_reg	= $d011
raster_line_int = $d012
vic_int_status	= $d019
vic_int_ctrl	= $d01a
bg_color	= $d021

cia1_int_ctrl	= $dc0d
cia2_int_ctrl	= $dd0d

kb_buf_len	= $c6


; kernal routines
scnkey		= $ff9f
getin           = $ffe4
chrout		= $ffd2
clrscr		= $e544
scinit		= $ff81	; Initialize VIC; restore default input/output to keyboard/screen; clear screen; set PAL/NTSC switch and interrupt timer.
ioinit		= $ff84	; Initialize CIA's, SID volume; setup memory configuration; set and start interrupt timer.
restor		= $ff8a ; Fill vector table at memory addresses $0314-$0333 with default values.

start
		; setup interrupts
		sei					; disable interrupts for more accurate timing

		lda #255				; bits 0-7 of raster line int target
		sta raster_line_int
		lda screen_ctrl_reg
		and #%0111_1111				; clear bit #8 of raster line int target
		sta screen_ctrl_reg

		
		lda #<int_handler 			; configure int handler
		sta isr_vector
		lda #>int_handler
		sta isr_vector+1

		lda #%0000_0001
		sta vic_int_ctrl
		inc vic_int_status			; ack any previously pending raster interrupts

		lda #%0111_1111                         ; disable all CIA1 interrupts
		sta cia1_int_ctrl
		lda #%0111_1111				; disable all CIA2 interrupts
		sta cia2_int_ctrl

		lda cia1_int_ctrl 			; clear any pending CIA interrupts
		lda cia2_int_ctrl

		lda #1					; screen code for 'A'
		sta char				; store as default character

		cli

		; running program: infinite loop to scnkey and update `char`
get 		jsr getin       			; get character
       		cmp #0          			; is it null?
       		beq get         			; yes... scan again
       		cmp #3          			; is it "stop" ?
       		beq stop         			; yes... exit to basic
		jsr petscii_to_sc			; convert to screencode
		sta char				; use this screen code from now on

		jmp get					; infinite busy wait

stop		
		jsr ioinit				; reset CIA config
		jsr restor				; reset interrupt vectors
		jsr scinit				; reset VIC and clear screen

		rts 					; return to basic

int_handler	; interrupt handler, triggger on specific raster line
		; registers already saved in Kernal ISR entry point

		lda vic_int_status
		and #1
		beq exit_handler

		lda #yellow				; color the border yellow while we fill the screen
		sta border_color

begin		ldy #250                		; 250 [0-249] postions per page
		lda char			 	; load selected char

loop		dey
		sta screen_mem + 0,y                    ; no overlap, no redundant filling, exactly 250*4
		sta screen_mem + 250,y
		sta screen_mem + 500,y
		sta screen_mem + 750,y

		bne loop

end		lda #ltblue
		sta border_color			; change border back to ltblue when done

ack_int		dec vic_int_status 			; acklowledge interrupt

exit_handler	jmp isr_default


petscii_to_sc
	; A = *SCII-code

		cmp #$20		; if A<32 then...
		bcc ddRev

		cmp #$60		; if A<96 then...
		bcc dd1

		cmp #$80		; if A<128 then...
		bcc dd2

		cmp #$a0		; if A<160 then...
		bcc dd3

		cmp #$c0		; if A<192 then...
		bcc dd4

		cmp #$ff		; if A<255 then...
		bcc ddRev

		lda #$7e		; A=255, then A=126
		bne ddEnd

	dd2:	and #$5f		; if A=96..127 then strip bits 5 and 7
		bne ddEnd

	dd3:	ora #$40		; if A=128..159, then set bit 6
		bne ddEnd

	dd4:	eor #$c0		; if A=160..191 then flip bits 6 and 7
		bne ddEnd

	dd1:	and #$3f		; if A=32..95 then strip bits 6 and 7
		bpl ddEnd		; <- you could also do .byte $0c here

	ddRev:	eor #$80		; flip bit 7 (reverse on when off and vice versa)
	ddEnd:
		; screencode is now in accumulator
		rts

