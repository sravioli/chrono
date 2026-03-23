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

# ---------- Platform detection ----------
ifeq ($(OS),Windows_NT)
  UNAME := Windows
else
  UNAME := $(shell uname -s)
endif

# ---------- Tools ----------
LUA      ?= lua
CC       ?= cc
CFLAGS   ?= -O2 -Wall -g0

# ---------- Lua paths (override as needed) ----------
ifeq ($(UNAME),Windows)
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

# ---------- Platform-specific flags ----------
ifeq ($(UNAME),Darwin)
  SHARED   = -bundle -undefined dynamic_lookup
  EXT      = so
  LDFLAGS  =
else ifeq ($(UNAME),Linux)
  SHARED   = -shared -fPIC
  EXT      = so
  LDFLAGS  = -lrt
else
  # Windows (MinGW / MSYS2 / zig cc)
  SHARED   = -shared
  EXT      = dll
  LUA_LIB ?= lua54
  LDFLAGS  = $(if $(LUA_LIBDIR),-L$(LUA_LIBDIR)) -l$(LUA_LIB)
endif

ifeq ($(UNAME),Windows)
  RM = cmd /c del /f /q
else
  RM = rm -f
endif

# ---------- Paths ----------
SRC    = c/clock.c
OUTDIR = c/chrono
TARGET = $(OUTDIR)/clock.$(EXT)

# ---------- Targets ----------
.PHONY: all build rebuild test verify clean

all: build

rebuild: clean build

build: $(TARGET)

$(TARGET): $(SRC) | $(OUTDIR)
	$(CC) $(CFLAGS) $(SHARED) -I$(LUA_INCDIR) -o $@ $< $(LDFLAGS)

$(OUTDIR):
ifeq ($(UNAME),Windows)
	if not exist $(OUTDIR) mkdir $(OUTDIR)
else
	mkdir -p $(OUTDIR)
endif

test:
	busted

verify:
	$(LUA) verify.lua

clean:
ifeq ($(UNAME),Windows)
	-cmd /c del /f /q c\\chrono\\clock.dll c\\chrono\\clock.so c\\chrono\\clock.lib c\\chrono\\clock.pdb c\\chrono\\clock.exp c\\clock.o 2>NUL
	-cmd /c if exist $(OUTDIR) rmdir /q $(OUTDIR) 2>NUL
else
	$(RM) $(TARGET) c/clock.o
	-rmdir $(OUTDIR) 2>/dev/null
endif
