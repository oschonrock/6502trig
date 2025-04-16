

scnkey        .block

lstx          = $c5      ; last matrix corodinate
ndx           = $c6      ; number of characters in keyboard buffer
sfdx          = $cb      ; matrix coordinate of current keypress
keytab        = $f5      ; and $f6 .. ptr to key map
mode1         = $eb81    ; default unshifted map
keyd          = $0277    ; keyboard buffer
rptflg        = $028a    ; repeat flag
xmax          = $0289    ; max keyboard buffer size
kount         = $028a    ; coutn for time between repeats
shflag        = $028d    ; shift/ctrl/logo
lstshf        = $028d    ; last shift combo
delay         = $028c
keylog        = $028f    ; vector to keyboard shift table routine
mode          = $0291    ; enable or disable charset switching

keycod        = $eb79    ; key decoding something

colm          = $dc00
rows          = $dc01

                           
              lda #$00
              sta shflag
              ldy #64         ;last key index
              sty sfdx        ;null key found
              sta colm        ;raise all lines
              ldx rows        ;check for a key down
              cpx #$ff        ;no keys down?
              beq scnrts      ;branch if none
              tay             ;.a=0 ldy #0
              lda #<mode1     
              sta keytab
              lda #>mode1     
              sta keytab+1
              lda #$fe        ;start with 1st column
              sta colm
scn20         ldx #8          ;8 row keyboard
              pha             ;save column output info
scn22         lda rows
              cmp rows        ;debounce keyboard
              bne scn22
scn30         lsr a           ;look for key down
              bcs ckit        ;none
              pha
              lda (keytab),y  ;get char code
              cmp #$05
              bcs spck2       ;if not special key go on
              cmp #$03        ;could it be a stop key?
              beq spck2       ;branch if so
              ora shflag
              sta shflag      ;put shift bit in flag byte
              bpl ckut
spck2
              sty sfdx        ;save key number
ckut          pla
ckit          iny
              cpy #65
              bcs ckit1       ;branch if finished
              dex
              bne scn30
              sec
              pla             ;reload column info
              rol a
              sta colm        ;next column on keyboard
              bne scn20       ;always branch
ckit1         pla             ;dump column output...all done
              jmp shflog      ;evaluate shift functions - commented out because it determines which shift mode to put in $f5
rekey         ldy sfdx        ;get key index
              lda (keytab),y  ;get char code
              tax             ;save the char
              jmp ckit2

ckit2
              ldy sfdx        ;get index of key
              sty lstx        ;save this index to key found
              ldy shflag      ;update shift status
              sty lstshf
ckit3         cpx #$ff        ;a null key or no key ?
              beq scnrts      ;branch if so
              txa             ;need x as index so...

putque
              pha
              ; sta keyd,x      ;put raw data here
              ; inx
              ; stx ndx         ;update key queue count
              lda #$7f        ;setup pb7 for stop key sense
              sta colm
              pla
              rts

scnrts        lda #$7f
              sta colm
              lda #0          ; no key found
              rts
;
; shift logic
;

shflog        lda shflag
              cmp #$03        ;commodore shift combination?
              bne keylg2      ;branch if not
              cmp lstshf      ;did i do this already
              beq scnrts      ;branch if so
              lda mode
              bmi shfout      ;dont shift if its minus
switch        lda vic.memsetup;**********************************:
              eor #$02        ;turn on other case
              sta vic.memsetup;point the vic there
              jmp shfout

keylg2        asl a
              cmp #$08        ;was it a control key
              bcc nctrl       ;branch if not
              lda #6          ;else use table #4

nctrl
notkat        tax
              lda keycod,x
              sta keytab
              lda keycod+1,x
              sta keytab+1
shfout
              jmp rekey

              .endblock
