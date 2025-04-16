
# always keep the .prg, even if subsequent tasks (like running vice) "fails" or in innterrupted
.PRECIOUS: %.prg

# always build %.prg, 64tass is so fast and dependencies are hard to work out, that this is easiest
FORCE:

%.prg: %.asm FORCE
	64tass -Wall -C -a -B -i --vice-labels -l $*.labels -L $*.lst $< -o $@

%.breaks : %.prg
	bash debug.sh $*.labels $*.breaks

%.run: %.prg %.breaks
	x64sc -autostartprgmode 1 -autostart-warp +cart -moncommands $*.breaks -nativemonitor -silent $<

%.d64: %.prg
	c1541 -format eight,1 d64 eight.d64 -write eight.prg eight

.PHONY: clean
clean:
	$(RM) *.prg *.labels *.breaks *.lst *.d64
