# clock — optional native high-resolution timer for chrono
#
# Targets:
#   make              Build for current platform
#   make clean        Remove build artifacts
#
# Override these if your Lua headers / libs are elsewhere:
#   make LUA_INCDIR=/usr/include/lua5.1 LUA_LIBDIR=/usr/lib
#
# On Windows with zig:
#   make CC="zig cc"

ifeq ($(OS),Windows_NT)
  UNAME := Windows
else
  UNAME := $(shell uname -s)
endif

CC       ?= cc
CFLAGS   ?= -O2 -Wall -g0

# ---------- Lua paths (override as needed) ----------
ifeq ($(UNAME),Windows)
  LUA_INCDIR ?= $(shell luarocks config variables.LUA_INCDIR 2>NUL)
  LUA_LIBDIR ?= $(shell luarocks config variables.LUA_LIBDIR 2>NUL)/../lib
else
  LUA_INCDIR ?= $(shell pkg-config --variable=includedir lua5.1 2>/dev/null || \
                 pkg-config --variable=includedir lua51  2>/dev/null || \
                 pkg-config --variable=includedir luajit  2>/dev/null || \
                 echo /usr/include/lua5.1)
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

TARGET = chrono/clock.$(EXT)

OUTDIR = chrono

.PHONY: all clean

all: $(TARGET)

$(TARGET): clock.c | $(OUTDIR)
	$(CC) $(CFLAGS) $(SHARED) -I$(LUA_INCDIR) -o $@ $< $(LDFLAGS)

$(OUTDIR):
ifeq ($(UNAME),Windows)
	if not exist $(OUTDIR) mkdir $(OUTDIR)
else
	mkdir -p $(OUTDIR)
endif

clean:
ifeq ($(UNAME),Windows)
	-cmd /c del /f /q chrono\\clock.dll chrono\\clock.so chrono\\clock.lib chrono\\clock.pdb chrono\\clock.exp clock.o 2>NUL
	-cmd /c if exist $(OUTDIR) rmdir /q $(OUTDIR) 2>NUL
else
	$(RM) $(TARGET) clock.o
	-rmdir $(OUTDIR) 2>/dev/null
endif
