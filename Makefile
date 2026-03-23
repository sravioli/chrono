# chrono — Lua benchmarking engine
#
# Targets:
#   make              Build everything (native C timer)
#   make clock        Build the optional C high-resolution timer
#   make test         Run the test suite (busted)
#   make verify       Quick sanity check — prints detected timer sources
#   make clean        Remove build artifacts

LUA ?= lua

.PHONY: all clock test verify clean

all: clock

clock:
	$(MAKE) -C c

test:
	busted

verify:
	$(LUA) verify.lua

clean:
	$(MAKE) -C c clean
