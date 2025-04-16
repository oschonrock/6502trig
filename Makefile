
# always keep the .prg, even if subsequent tasks (like running vice) "fails" or in innterrupted
.PRECIOUS: %.prg

# always build %.prg, 64tass is so fast and dependencies are hard to work out, that this is easiest
FORCE:

%.prg: %.asm FORCE
	64tass -Wall -C -a -B -i --vice-labels -l build/$*.labels -L build/$*.lst $< -o build/$@

%.breaks : %.prg
	bash debug.sh build/$*.labels build/$*.breaks

%.run: %.prg %.breaks FORCE
	x64sc -autostartprgmode 1 -autostart-warp +cart -moncommands build/$*.breaks -nativemonitor -silent build/$<

%.d64: %.prg
	c1541 -format eight,1 d64 build/$*.d64 -write build/$*.prg eight

.PHONY: clean
clean:
	$(RM) build/*
