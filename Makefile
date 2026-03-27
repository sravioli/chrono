# chrono — Lua benchmarking engine
#
# Targets:
#   make              Build everything (native C timer)
#   make build        Build the optional C high-resolution timer
#   make rebuild      Clean and rebuild the native timer
#   make test         Run the test suite (busted)
#   make verify       Quick sanity check — prints detected timer sources
#   make clean        Remove build artifacts
#
# Override these if your Lua headers / libs are elsewhere:
#   make LUA_INCDIR=/usr/include/lua5.1 LUA_LIBDIR=/usr/lib
#
# On Windows with zig:
#   make CC="zig cc"

#
# Step 1: Detect Operating System
OS ?= $(shell echo %OS% 2>/dev/null)
ifeq ($(OS),Windows_NT)
  IS_WINDOWS := 1
else
  UNAME_S := $(shell uname -s 2>/dev/null)
  ifeq ($(UNAME_S),Linux)
    IS_UNIX := 1
  else ifeq ($(UNAME_S),Darwin)
    IS_UNIX := 1
  else ifneq ($(filter MINGW%,$(UNAME_S)),)
    IS_WINDOWS := 1
  else ifneq ($(filter CYGWIN%,$(UNAME_S)),)
    IS_WINDOWS := 1
  else
    IS_UNIX := 1
  endif
endif


# Step 2: OS-specific commands
ifeq ($(IS_WINDOWS),1)
  RM      := del /f /q
  RMDIR   := rd /s /q
  MKDIR   := mkdir
  fixpath  = $(subst /,\,$1)
else
  RM      := rm -f
  RMDIR   := rm -rf
  MKDIR   := mkdir -p
  fixpath  = $1
endif


# Step 3: Tools
LUA    ?= lua
CC     ?= cc
CFLAGS ?= -O2 -Wall -g0


# Step 4: Lua paths (override as needed)
ifeq ($(IS_WINDOWS),1)
  LUA_INCDIR ?= $(shell luarocks config variables.LUA_INCDIR 2>NUL)
  LUA_LIBDIR ?= $(shell luarocks config variables.LUA_LIBDIR 2>NUL)/../lib
else
  LUA_INCDIR ?= $(shell \
    inc="$$(luarocks config variables.LUA_INCDIR 2>/dev/null)"; \
    if [ -z "$$inc" ]; then \
      inc="$$(pkg-config --cflags-only-I lua5.1 2>/dev/null | awk '{print $$1}' | sed 's/^-I//')"; \
    fi; \
    if [ -z "$$inc" ]; then \
      inc="$$(pkg-config --cflags-only-I lua51 2>/dev/null | awk '{print $$1}' | sed 's/^-I//')"; \
    fi; \
    if [ -z "$$inc" ]; then \
      inc="$$(pkg-config --cflags-only-I luajit 2>/dev/null | awk '{print $$1}' | sed 's/^-I//')"; \
    fi; \
    if [ -z "$$inc" ] && [ -d /usr/include/lua5.1 ]; then \
      inc=/usr/include/lua5.1; \
    fi; \
    if [ -z "$$inc" ] && [ -d /usr/include/luajit-2.1 ]; then \
      inc=/usr/include/luajit-2.1; \
    fi; \
    if [ -z "$$inc" ]; then \
      inc=/usr/include; \
    fi; \
    echo $$inc)
  LUA_LIBDIR ?=
endif


# Step 5: Platform-specific compiler flags
ifeq ($(UNAME_S),Darwin)
  SHARED  = -bundle -undefined dynamic_lookup
  EXT     = so
  LDFLAGS =
else ifeq ($(UNAME_S),Linux)
  SHARED  = -shared -fPIC
  EXT     = so
  LDFLAGS = -lrt
else
  # Windows (MinGW / MSYS2 / zig cc)
  SHARED  = -shared
  EXT     = dll
  LUA_LIB ?= lua54
  LDFLAGS = $(if $(LUA_LIBDIR),-L$(LUA_LIBDIR)) -l$(LUA_LIB)
endif


# Step 6: Paths
SRC    = c/clock.c
OUTDIR = c/chrono
TARGET = $(OUTDIR)/clock.$(EXT)

# Step 7: Targets
.PHONY: all build rebuild test verify clean

all: build

rebuild: clean build

build: $(TARGET)

$(TARGET): $(SRC) | $(OUTDIR)
	$(CC) $(CFLAGS) $(SHARED) -I$(LUA_INCDIR) -o $@ $< $(LDFLAGS)

$(OUTDIR):
	$(MKDIR) $(call fixpath,$(OUTDIR))

test:
	busted

verify:
	$(LUA) verify.lua

clean:
ifeq ($(IS_WINDOWS),1)
	@if exist $(call fixpath,$(OUTDIR)) ($(RMDIR) $(call fixpath,$(OUTDIR))) else (echo Already clean)
else
	@if [ -d $(OUTDIR) ]; then $(RMDIR) $(OUTDIR); else echo "Already clean"; fi
endif
