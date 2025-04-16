
basicstub       .macro startadr
tk_sys          = $9e ; token for BASIC `SYS` command

*               = $0801                                         ; standard BASIC start/load address
                .word (basicend), 2025                            ; pointer, line number
                .null tk_sys, format("%4d", \startadr)
basicend        .word 0                                         ; basic line end
                .endmacro

addr2ptr .macro  addr, ptr  ;
        lda #<(\addr)
        sta \ptr
        lda #>(\addr)
        sta \ptr+1
        .endmacro

roln16  .macro addr, n ; `roll left` 16-bit unsigned int at `addr` by `n` bits => equiv to multiply by 2^n
        .for i := 0, i != \n, i += 1
        asl \addr
        rol \addr+1
        .endfor
        .endmacro

add16  .macro addr1, addr2  ; add 16 bit value at addr2 to addr1 and store back in addr1
        lda \addr1
        clc 
        adc \addr2
        sta \addr1
        lda \addr1+1
        adc \addr2+1
        sta \addr1+1
        .endmacro

add24  .macro addr1, addr2  ; add 16 bit value at addr2 to addr1 and store back in addr1
        add16 \addr1, \addr2 
        lda \addr1+2
        adc \addr2+2
        sta \addr1+2
        .endmacro

add16c  .macro addr1, const  ; add 16 bit value at addr2 to addr1 and store back in addr1
        lda \addr1
        clc 
        adc #<\const
        sta \addr1
        lda \addr1+1
        adc #>\const
        sta \addr1+1
        .endmacro

sub16  .macro addr1, addr2  ; subtract 16 bit value at addr2 from addr1 and store back in addr1
        lda \addr1
        sec
        sbc \addr2
        sta \addr1
        lda \addr1+1
        sbc \addr2+1
        sta \addr1+1
        .endmacro


delay   .macro cycles ; works for 2,3,4,5... etc cycles, but not for 1!
	cycles := \cycles               ; make it a variable
        .if cycles > 12
            n := (cycles - 6) / 5 + 1
            cycles -= 5 * (n-1) + 6
            .if cycles == 1             ; can't delay a remainder of one
               n -= 1                   ; so do one less iteration 
               cycles += 5              ; and recalc remainder
            .endif

            ldy #n
-           dey
            bne -

        .endif

        .for j := 0, j != (cycles / 2 - cycles % 2) , j += 1
        nop
        .endfor

        ; deal with odd number of cycles
        .if cycles % 2 == 1
        bit $02
        .endif

        .endmacro
