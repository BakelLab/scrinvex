# Allow Conda to pass in the prefix, default to /usr/local if not set
PREFIX ?= /usr/local

# --- THE FIX: Force inclusion of the Conda/System prefix ---
INCLUDE_DIRS = -I$(PREFIX)/include -Irnaseqc -Irnaseqc/src -Irnaseqc/SeqLib -Irnaseqc/SeqLib/htslib/
LIBRARY_PATHS = -L$(PREFIX)/lib

# Standard library and flags
ABI ?= 1
CXX ?= g++
STDLIB = -std=c++14
# Use += to append to any flags passed from the environment
CXXFLAGS += -Wall $(STDLIB) -D_GLIBCXX_USE_CXX11_ABI=$(ABI) -O3

LIBS = -lboost_filesystem -lboost_regex -lboost_system -lz -llzma -lbz2 -lpthread

SOURCES = scrinvex.cpp
SRCDIR = src
OBJECTS = $(SOURCES:.cpp=.o)

# Final binary linking step
scrinvex: $(foreach file,$(OBJECTS),$(SRCDIR)/$(file)) rnaseqc/rnaseqc.a rnaseqc/SeqLib/lib/libseqlib.a rnaseqc/SeqLib/lib/libhts.a
	$(CXX) $(CXXFLAGS) $(LIBRARY_PATHS) -o $@ $^ $(LIBS)

# Compilation of source files to object files
$(SRCDIR)/%.o: $(SRCDIR)/%.cpp
	$(CXX) $(CXXFLAGS) -I. $(INCLUDE_DIRS) -c -o $@ $<

# SeqLib build rule
rnaseqc/SeqLib/lib/libseqlib.a rnaseqc/SeqLib/lib/libhts.a:
	cd rnaseqc/SeqLib && \
	./configure --prefix=$(PREFIX) CPPFLAGS="-I$(PREFIX)/include" LDFLAGS="-L$(PREFIX)/lib" --with-bzip2 --with-lzma && \
	make -j1 CXXFLAGS="$(CXXFLAGS) -I$(PREFIX)/include" && \
	make install

rnaseqc/rnaseqc.a:
	cd rnaseqc && make lib ABI=$(ABI)

.PHONY: clean
clean:
	rm -f $(SRCDIR)/*.o scrinvex || echo "Nothing to clean in scrinvex"
	cd rnaseqc && make clean || echo "Nothing to clean in RNA-SeQC"
	cd rnaseqc/SeqLib && make clean || echo "Nothing to clean in SeqLib"
