# Makefile to create a release of the Fife/Drum book, code, slides, etc.

# ================================================================

RELEASE = $(HOME)/Git/Learn_Bluespec_and_RISCV_Design
TODAY   = `date -Idate`

.PHONY: help
help:
	@echo "This Makefile is for creating the BSV/Fife/Drum book release in:"
	@echo "    RELEASE = $(RELEASE)"
	@echo "    TODAY   = $(TODAY)"
	@echo "It copies items from this DEVEL dir to RELEASE."
	@echo ""
	@echo "Targets:"
	@echo "  Book       Copy  $(BOOK_PDF)  to  RELEASE/Book"
	@echo "  Code       In RELEASE move  Code/  to Code_TODAY;"
	@echo "             then copy code, Makefiles, etc. to  RELEASE/Code/"
	@echo "  TestRIG    In RELEASE move  TestRIG/  to  TestRIG_TODAY/;"
	@echo "             then copy code, Makefiles, etc.to  RELEASE/TestRIG/"
	@echo "  Slides     Copy slides PDFs from  $(BOOK)  to  ."
	@echo "  Exercises  Copy exercises from  $(BOOK)  to  ."
	@echo ""
	@echo "  clean       Remove temporary intermediate files"
	@echo "  full_clean  clean; and also remove .html"
	@echo ""
	@echo "Please rm any build-temporaries, including .o files"

# ================================================================
# Book

BOOK_PDF = ./Book/Book_BLang_RISCV.pdf

.PHONY: Book
Book:
	@echo "---------------- Copying book PDF"
	cp -p  $(BOOK_PDF)  $(RELEASE)/

# ================================================================
# Code, tools, etc.

# Code
FIFE_SRCS += src_Common
FIFE_SRCS += src_Drum
FIFE_SRCS += src_Fife
FIFE_SRCS += src_Top

# Tools
FIFE_SRCS += Tools

# Doc
FIFE_SRCS += Doc/Build_and_Run_Guide.adoc
FIFE_SRCS += Doc/Build_and_Run_Guide.html
FIFE_SRCS += Doc/Makefile

# Build
FIFE_SRCS += Build/Include.mk
FIFE_SRCS += Build/Drum/Makefile
FIFE_SRCS += Build/Drum/test.memhex32
FIFE_SRCS += Build/Fife/Makefile
FIFE_SRCS += Build/Fife/test.memhex32

# Vendor
FIFE_SRCS += vendor

.PHONY: Code
Code:
	@echo ""
	@echo "---------------- Copying Fife/Drum code to $(RELEASE)/Code/"
	@echo "---- Cleaning up .o files, in ./Code "
	rm -f Code/src_*/*.o
	rm -f Code/vendor/*/*.o
	@echo "---- tar up files to be copied, in ./Code "
	cd Code; tar -cvzf $(HOME)/foo.tar.gz  $(FIFE_SRCS)
	@echo ""
	@echo "---- Save  Code/  to  Code_$(TODAY)/, in $(RELEASE)"
	cd $(RELEASE); mv Code Code_$(TODAY)
	@echo ""
	@echo "---- Unpack tar file/, in $(RELEASE)/Code"
	cd $(RELEASE); mkdir -p Code; cd Code; tar -xvzf $(HOME)/foo.tar.gz; Strip_LaTeX.py  .
	@echo "Copied Fife/Drum code to $(RELEASE)/Code/"

# ================================================================
# TestRIG

TESTRIG_DIR = $(HOME)/Git/DEVEL_Learn_Bluespec_and_RISCV_Design/TestRIG

TESTRIG_SRCS  = Build

TESTRIG_SRCS += src_Top_TestRIG

TESTRIG_SRCS += Doc/Figs/RSN_2025-06-28.000.00_TestRIG_Fife.png
TESTRIG_SRCS += Doc/Figs/TestRIG_Setup.png
TESTRIG_SRCS += Doc/Makefile
TESTRIG_SRCS += Doc/TestRIG_Setup.adoc
TESTRIG_SRCS += Doc/TestRIG_Setup.html

TESTRIG_SRCS += vendor

.PHONY: TestRIG
TestRIG:
	@echo "---------------- Copying TestRIG code to $(RELEASE)/TestRIG/"
	@echo "---- Cleaning up .o files, in ./TestRIG "
	rm -f TestRIG/src_*/*.o
	rm -f TestRIG/vendor/*/*.o
	@echo "---- tar up files to be copied, in ./TestRIG "
	cd $(TESTRIG_DIR); tar -cvzf $(HOME)/foo.tar.gz  $(TESTRIG_SRCS)
	@echo ""
	@echo "---- Save  TestRIG/  to  TestRIG_$(TODAY)/, in $(RELEASE)"
	cd $(RELEASE); mv TestRIG TestRIG_$(TODAY)
	@echo ""
	@echo "---- Unpack tar file/, in $(RELEASE)/TestRIG"
	cd $(RELEASE); mkdir -p Testrig; cd TestRIG; tar -xvzf $(HOME)/foo.tar.gz; Strip_LaTeX.py  .
	@echo "Copied TestRIG code to $(RELEASE)/TestRIG/"

# ================================================================

.PHONY: Slides
Slides:
	mkdir -p Slides
	cp -p $(HOME)/Git/Book_BSV_RISCV/courseware/Slides*.pdf  Slides/

# ================================================================

.PHONY: Exercises
Exercises:
	@echo "Copying exercises in Exercises/"
	mkdir -p Exercises
	rm -r -f Exercises/*
	cd $(BOOK)/exercises; tar -cvzf $(HOME)/foo.tar.gz  *
	cd Exercises; tar -xvzf $(HOME)/foo.tar.gz
	@echo "Created exercises in Exercises/"

# ================================================================

.PHONY: clean
clean:
	rm -r -f  *~

.PHONY: full_clean
full_clean: clean
	rm -r -f  README.html
