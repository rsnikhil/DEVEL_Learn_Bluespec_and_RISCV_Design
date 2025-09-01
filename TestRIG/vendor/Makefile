.PHONY: help
help:
	@echo "Targets:"
	@echo "  $(TARGETS)"
	@echo "  all           All targets"
	@echo "  clean         Delete temporary files"
	@echo "  full_clean    Restore to pristine state"
	@echo "See each <target>.vendor.hjson for details of remote repos etc."

.PHONY: all
all:
	make  $(TARGETS)

# ================================================================
VENDOR_PY = ./vendor.py

TARGETS += BSV-RVFI-DII
LOCKS   += BSV-RVFI-DII.lock.hjson
.PHONY: BSV-RVFI-DII
BSV-RVFI-DII:
	$(VENDOR_PY)  BSV-RVFI-DII.vendor.hjson

TARGETS += SocketPacketUtils
LOCKS   += SocketPacketUtils.lock.hjson
.PHONY: SocketPacketUtils
SocketPacketUtils:
	$(VENDOR_PY)  SocketPacketUtils.vendor.hjson

# ================================================================

.PHONY: clean
clean:
	rm -r -f  *~

.PHONY: full_clean
full_clean: clean
	rm -r -f  $(TARGETS)  $(LOCKS)
