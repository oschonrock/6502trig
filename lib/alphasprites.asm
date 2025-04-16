

; =========================
; make 26 3x magnified high resolution sprites from the ROM Charset alpah characters
;
; this quite CPU intensive, takes about 200ms
;
; set: 
;    sprdata = ????  ; in calling code to position the output, 1664 bytes will be used
;
; uses all resgisters plus:
; 
; zpb1            = $02
; zpb2            = $03
; zpptr1          = $fb
; zpptr2          = $fd
; ========================

makesprites   .block

              ;enable char rom
              sei
              lda 1
              and #~$04
              sta 1

               ;init source to A
              .enc "screen"
              lda #<$d000 + 8 * "a" 
              sta zpptr1
              lda #>$d000 + 8 * "a"
              sta zpptr1+1
              .enc "none"

              ;init dest to sprites
              lda #<sprdata   ; should be initialised in calling code
              sta zpptr2
              lda #>sprdata
              sta zpptr2+1

              lda #26
              sta chrcount

chrloop
              ;init counters
              lda #0
              sta srccount
              sta zpb2

              ;erase sprite
              lda #0
              ldy #63
clrloop       sta (zpptr2),y
              dey
              bpl clrloop

              ;get src char byte
rowloop       ldy srccount
              lda (zpptr1),y
              sta zpb1 ;save it - this is "srcbyte", using zero page for speed

              ldy zpb2

              ; test each bit in character, by shifting it left into carry
              ; and apply triplicated bit pattern to sprite, for 3x horizontal scaling
              ; all unrolled as the logic is messy anyway. this is clearer and 5x faster
bit7          asl zpb1
              bcc bit6
              lda #%11100000
              sta (zpptr2),y

bit6          asl zpb1
              bcc bit5
              lda (zpptr2),y
              ora #%00011100
              sta (zpptr2),y

bit5          asl zpb1
              bcc bit4
              lda (zpptr2),y
              ora #%00000011
              sta (zpptr2),y
              iny
              lda #%10000000
              sta (zpptr2),y
              dey         ; re-inc is below
   
bit4          iny
              asl zpb1
              bcc bit3
              lda (zpptr2),y
              ora #%01110000
              sta (zpptr2),y

bit3          asl zpb1
              bcc bit2
              lda (zpptr2),y
              ora #%00001110
              sta (zpptr2),y

bit2          asl zpb1
              bcc bit1
              lda (zpptr2),y
              ora #%00000001
              sta (zpptr2),y
              iny
              lda #%11000000
              sta (zpptr2),y
              dey       ; re-inc is below

bit1          iny
              asl zpb1
              bcc bit0
              lda (zpptr2),y
              ora #%00111000
              sta (zpptr2),y

bit0          asl zpb1
              bcc endrow
              lda (zpptr2),y
              ora #%00000111
              sta (zpptr2),y

endrow        ; done one row of character pixels

              ; make 2 copies of this row for vertical scaling
              ldx #3
              ldy zpb2

              ; set up self modifying code
              lda zpptr2+1    ; high byte 
              sta sta1+2   ; same for src and both destinations
              sta sta2+2   ; because sprites never cross page boundaries

              lda zpptr2
              clc
              adc #3       ; there cannot be any wrap around
              sta sta1+1
              adc #3       ; no need to clc either
              sta sta2+1
   
copyloop      lda (zpptr2),y
sta1          sta $0000,y  ; dummy adr for self modifying code
sta2          sta $0000,y  ; dummy adr for self modifying code
              iny
              dex
              bne copyloop

              ;done full row, go to next
              inc srccount
              lda zpb2
              clc
              adc #9
              sta zpb2
              cmp #(9*21) ;done?
              bne rowloop

              ; done full character
              ; goto next character
              lda zpptr1
              clc
              adc #8
              sta zpptr1
              lda zpptr1+1
              adc #0
              sta zpptr1+1

              ; next destination sprite
              lda zpptr2
              clc
              adc #64
              sta zpptr2
              lda zpptr2+1
              adc #0
              sta zpptr2+1

              dec chrcount
              beq done
              jmp chrloop

done          ;hide char rom
              lda 1
              ora #4
              sta 1
              cli
              rts

srccount      .byte 0  ; count of which character from the ROM are we translating
sprbyte       .byte 0  ; current destination byte in the sprite
chrcount      .byte 0 

              .endblock
