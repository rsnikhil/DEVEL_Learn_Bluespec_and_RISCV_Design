.PHONY: run_no_hazard
run_no_hazard:
	ln -s -f no_hazard.memhex32 test.memhex32
	./exe_Fife_RV32_bsim +log
	../../Tools/Log_Processing/Log_to_CSV.py log.txt 0 50
	mv log.txt.csv  no_hazard.csv
	rm -f log.txt.data

.PHONY: run_hazard
run_hazard:
	ln -s -f hazard.memhex32 test.memhex32
	./exe_Fife_RV32_bsim +log
	../../Tools/Log_Processing/Log_to_CSV.py log.txt 0 50
	mv log.txt.csv  hazard.csv
	rm -f log.txt.data

.PHONY: build
build:
	make b_compile b_link

.PHONY: gen
gen:
	Gen_Instrs.py | tee foo.log
