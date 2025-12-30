# 1. Path Configuration
# Allow Conda to pass in the prefix, default to /usr/local for manual builds
PREFIX ?= /usr/local

# Set inclusion paths - Ensure $(PREFIX)/include is prioritized for Conda/Boost
INCLUDE_DIRS = -I$(PREFIX)/include -Irnaseqc -Irnaseqc/src -Irnaseqc/SeqLib -Irnaseqc/SeqLib/htslib/

# Set library paths
LIBRARY_PATHS = -L$(PREFIX)/lib

# 2. Build Flags
# Set to 1 for modern systems; set to 0 for older compatibility
ABI ?= 1

# Use CXX to ensure the C++ compiler/linker is used (fixes DSO missing errors)
CXX ?= g++
STDLIB = -std=c++14
# Use += to append Conda environment flags
CXXFLAGS += -Wall $(STDLIB) -D_GLIBCXX_USE_CXX11_ABI=$(ABI) -O3

# 3. Dependencies and Libraries
STATIC_LIBS = 
LIBS = -lboost_filesystem -lboost_regex -lboost_system -lz -llzma -lbz2 -lpthread

# 4. Source and Object Mapping
SOURCES = scrinvex.cpp
SRCDIR = src
OBJECTS = $(SOURCES:.cpp=.o)

# 5. Build Rules

# Final binary linking step
scrinvex: $(foreach file,$(OBJECTS),$(SRCDIR)/$(file)) rnaseqc/rnaseqc.a rnaseqc/SeqLib/lib/libseqlib.a rnaseqc/SeqLib/lib/libhts.a
	$(CXX) $(CXXFLAGS) $(LIBRARY_PATHS) -o $@ $^ $(STATIC_LIBS) $(LIBS)

# Compilation of main source files
$(SRCDIR)/%.o: $(SRCDIR)/%.cpp
	$(CXX) $(CXXFLAGS) -I. $(INCLUDE_DIRS) -c -o $@ $<

# RNA-SeQC core build rule (RECURSIVE MAKE FIX)
# We explicitly pass PREFIX, CXX, and CXXFLAGS down to the submodule
rnaseqc/rnaseqc.a:
	cd rnaseqc && $(MAKE) lib \
		ABI=$(ABI) \
		PREFIX=$(PREFIX) \
		CXX="$(CXX)" \
		CXXFLAGS="$(CXXFLAGS) -I$(PREFIX)/include"

# SeqLib build rule
# Configures and installs SeqLib and HTSlib into the Conda prefix
rnaseqc/SeqLib/lib/libseqlib.a rnaseqc/SeqLib/lib/libhts.a:
	cd rnaseqc/SeqLib && \
	./configure --prefix=$(PREFIX) CPPFLAGS="-I$(PREFIX)/include" LDFLAGS="-L$(PREFIX)/lib" --with-bzip2 --with-lzma && \
	$(MAKE) -j1 CXXFLAGS="$(CXXFLAGS) -I$(PREFIX)/include" && \
	$(MAKE) install

.PHONY: clean

clean:
	rm -f $(SRCDIR)/*.o scrinvex
	cd rnaseqc && $(MAKE) clean || true
	cd rnaseqc/SeqLib && $(MAKE) clean || true
