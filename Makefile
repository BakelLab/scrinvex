# 1. Path Configuration
PREFIX ?= /usr/local

# Ensure the Conda include and lib paths are at the front
INCLUDE_DIRS = -I$(PREFIX)/include -Irnaseqc -Irnaseqc/src -Irnaseqc/SeqLib -Irnaseqc/SeqLib/htslib/
LIBRARY_PATHS = -L$(PREFIX)/lib

# 2. Build Flags
ABI ?= 1
CXX ?= g++
STDLIB = -std=c++14
CXXFLAGS += -Wall $(STDLIB) -D_GLIBCXX_USE_CXX11_ABI=$(ABI) -O3

# 3. Libraries
LIBS = -lboost_filesystem -lboost_regex -lboost_system -lcurl -lcrypto -ldeflate -lz -llzma -lbz2 -lpthread

# 4. Source Mapping
SOURCES = scrinvex.cpp
SRCDIR = src
OBJECTS = $(SOURCES:.cpp=.o)

# 5. Build Rules

# Final binary linking
scrinvex: $(foreach file,$(OBJECTS),$(SRCDIR)/$(file)) rnaseqc/rnaseqc.a rnaseqc/SeqLib/lib/libseqlib.a rnaseqc/SeqLib/lib/libhts.a
	$(CXX) $(CXXFLAGS) $(LIBRARY_PATHS) -o $@ $^ $(LIBS)

# Compilation of main source files
$(SRCDIR)/%.o: $(SRCDIR)/%.cpp
	$(CXX) $(CXXFLAGS) -I. $(INCLUDE_DIRS) -c -o $@ $<

# RNA-SeQC core build rule
rnaseqc/rnaseqc.a:
	cd rnaseqc && $(MAKE) lib \
		ABI=$(ABI) \
		PREFIX=$(PREFIX) \
		CXX="$(CXX)" \
		INCLUDE_DIRS="-I$(PREFIX)/include -ISeqLib -ISeqLib/htslib/" \
		CFLAGS="$(CXXFLAGS) -I$(PREFIX)/include -I."

# SeqLib build rule
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
