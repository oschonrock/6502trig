

; VIC
vic		.namespace 
base		= $d000
sprpos		= base

spr0x           = base + 0
spr0y           = base + 1
spr1x           = base + 2
spr1y           = base + 3
spr2x           = base + 4
spr2y           = base + 5
spr3x           = base + 6
spr3y           = base + 7
spr4x           = base + 8
spr4y           = base + 9
spr5x           = base + 10
spr5y           = base + 11
spr6x           = base + 12
spr6y           = base + 13
spr7x           = base + 14
spr7y           = base + 15

sprxhibits	= $d010

screenctrl	= $d011   ; contains bit-7 of rasterline
rasterintline	= $d012
rasterline	= $d012

sprenable	= $d015

memsetup        = $d018
intstatus	= $d019
intctrl		= $d01a

borderclr	= $d020
bgclr		= $d021

sprcolors	= $d027

screenmem       = $0400  ; by default
colorram        = $d800

colors		.namespace
black		= 0
white		= 1
red		= 2
cyan            = 3 	
purple		= 4 	
green		= 5 	
blue		= 6 	
yellow		= 7 	
orange		= 8 	
brown		= 9 	
lightred	= 10 	
darkgrey	= 11	
grey		= 12	
lightgreen	= 13	
lightblue	= 14	
lightgrey       = 15	
                .endnamespace

; ##### macros #######

rasterint .macro  ; params: rasterline inthandler
          lda #<\1                            ; bits 0-7 of raster line int target
	  sta vic.rasterintline
	  lda vic.screenctrl
	  .if \1 > $ff
	      ora #%1000_0000
          .else 
	      and #%0111_1111
	 .endif
	 sta vic.screenctrl

         lda #<\2                            ; configure int handler
         sta kernal.isrvector                ; this assumes the kernal is still running
         lda #>\2                            ; so inthandler should jump to kernal.isrdefault when done
         sta kernal.isrvector+1


	 .endmacro

.endnamespace

