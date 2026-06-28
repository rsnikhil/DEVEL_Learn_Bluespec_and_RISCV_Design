# Makefile to create a release of the Fife/Drum book, code, slides, etc.

# ================================================================

DEVEL   = $(HOME)/Git/DEVEL_Learn_Bluespec_and_RISCV_Design
RELEASE = $(HOME)/Git/Learn_Bluespec_and_RISCV_Design

.PHONY: help
help:
	@echo "This Makefile is for creating the BSV/Fife/Drum book release in:"
	@echo "    RELEASE = $(RELEASE)"
	@echo "It copies items from this DEVEL dir to RELEASE."
	@echo "    DEVEL   = $(DEVEL)"
	@echo ""
	@echo "Targets:"
	@echo "  Book        Copy  $(BOOK_PDF)  to  RELEASE/Book"
	@echo "  Code        Copy  DEVEL/Code/  to  RELEASE/Code_Candidate;"
	@echo "                strip LaTeX tags; ready for test and manual copy to Code"
	@echo "  TestRIG     In RELEASE move  TestRIG/  to  TestRIG_TODAY/;"
	@echo "                then copy code, Makefiles, etc.to  RELEASE/TestRIG/"
	@echo "  Slides      Copy slides PDFs from  $(BOOK)  to  ."
	@echo "  Exercises   Copy exercises from  $(BOOK)  to  ."
	@echo ""
	@echo "  vsdiff, diff  Shows VScode diff or diff between X in DEVEL and RELEASE"
	@echo "                (define X=path in 'make' invocation"
	@echo ""
	@echo "  clean       Remove temporary intermediate files"
	@echo "  full_clean  clean; and also remove .html"
	@echo ""
	@echo "Please rm any build-temporaries, including .o files"

# ================================================================
# TEMPORARY: delete after use

.PHONY: vsdiff
vsdiff:
	code --diff  $(DEVEL)/Code/$(X)  $(RELEASE)/Code/$(X)

.PHONY: diff
diff:
	diff  $(DEVEL)/Code/$(X)  $(RELEASE)/Code/$(X)

# ================================================================
# Book

BOOK_PDF = Book_BLang_RISCV.pdf

.PHONY: Book
Book:
	@echo "---------------- Copying book PDF"
	cp -p  $(DEVEL)/Book/(BOOK_PDF)  $(RELEASE)/

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
	@echo "---------------- Copying DEVEL/Code to to RELEASE/Code_Candidate/"
	@echo "---- Cleaning up .o files, in DEVEL/Code "
	rm -f $(DEVEL)/Code/src_*/*.o
	rm -f $(DEVEL)/Code/vendor/*/*.o
	@echo "---- tar up files to be copied, in DEVEL/Code "
	cd $(DEVEL)/Code; tar -cvzf $(HOME)/foo.tar.gz  $(FIFE_SRCS)
	@echo ""
	@echo "---- Unpack tar file into RELEASE/Code_Candidate/"
	cd $(RELEASE); rm -r -f Code_Candidate; mkdir -p Code_Candidate; cd Code_Candidate; tar -xvzf $(HOME)/foo.tar.gz; Strip_LaTeX.py  .
	@echo "Copied DEVEL/Code to to RELEASE/Code_Candidate/"
	@echo "    Please test RELEASE/Code_Candidate"
	@echo "    then replace RELEASE/Code <= RELEASE/Code_Candidate"

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
	rm -f $(DEVEL)/TestRIG/src_*/*.o
	rm -f $(DEVEL)/TestRIG/vendor/*/*.o
	@echo "---- tar up files to be copied, in ./TestRIG "
	cd $(TESTRIG_DIR); tar -cvzf $(HOME)/foo.tar.gz  $(TESTRIG_SRCS)
	@echo ""
	@echo "---- Unpack tar file into $(RELEASE)/TestRIG_Candidate/"
	cd $(RELEASE); rm -r -f TestRIG_Candidate; mkdir -p TestRIG_Candidate; cd TestRIG_Candidate; tar -xvzf $(HOME)/foo.tar.gz; Strip_LaTeX.py  .
	@echo "Copied TestRIG code to $(RELEASE)/TestRIG_Candidate/"

# ================================================================

.PHONY: Slides
Slides:
	mkdir -p Slides
	cp -p $(HOME)/Git/Book_BSV_RISCV/courseware/Slides*.pdf  Slides/

# ================================================================

.PHONY: Exercises
Exercises:
	@echo "---------------- Copying DEVEL/Exercises to RELEASE/Exercises_Candidate/"
	@echo "---- tar up files to be copied, from DEVEL/Code "
	cd $(DEVEL)/Exercises; tar -cvzf $(HOME)/foo.tar.gz  .
	@echo ""
	@echo "---- Unpack tar file into RELEASE/Exercises_Candidate/"
	cd $(RELEASE); rm -r -f Exercises_Candidate; mkdir -p Exercises_Candidate; cd Exercises_Candidate; tar -xvzf $(HOME)/foo.tar.gz
	rm -r -f $(RELEASE)/Exercises_Candidate/*/build*
	rm -r -f $(RELEASE)/Exercises_Candidate/*/exe_*
	@echo "Copied DEVEL/Exercises to RELEASE/Exercises_Candidate/"
	@echo "    Please test RELEASE/Exercises_Candidate"
	@echo "    then replace RELEASE/Exercises <= RELEASE/Exercises_Candidate"

# ================================================================

.PHONY: clean
clean:
	rm -r -f  *~

.PHONY: full_clean
full_clean: clean
	rm -r -f  README.html
