ODIR = o
BGFXSRC = ../bgfx
BXSRC = ../bx
BIMGSRC = ../bimg
LUAINC = -I/usr/local/include
LUALIB = -L/usr/local/bin -llua53

CC= gcc
CXX = g++
CFLAGS = -O2 -Wall

# math3d

all : math3d.dll

math3d.dll : libmath.c
	$(CC) $(CFLAGS) --shared -DLUA_BUILD_AS_DLL -o $@ $^ $(LUAINC) $(LUALIB)

# bgfx
BGFXVER = Debug
#BGFXVER = Release
BGFXLIB = -L$(BGFXSRC)/.build/win64_mingw-gcc/bin -lbgfx$(BGFXVER) -lbimg$(BGFXVER) -lbx$(BGFXVER) -lstdc++ -lgdi32 -lpsapi -luuid
BGFXINC = -I$(BGFXSRC)/include -I$(BXSRC)/include/compat/mingw -I$(BXSRC)/include
BGFXUTILLIB = -lexample-common$(BGFXVER)
BGFX3RDINC = -I$(BGFXSRC)/3rdparty

$(ODIR)/ibcompress.o : ibcompress.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -std=c++11 -c -o $@ $^ $(BGFXINC) $(BGFX3RDINC)

$(ODIR)/luabgfx.o : luabgfx.c  | $(ODIR)
	$(CC) $(CFLAGS) -c -DLUA_BUILD_AS_DLL -o $@ $^ $(LUAINC) $(BGFXINC)

$(ODIR)/luabgfxutil.o : luabgfxutil.c  | $(ODIR)
	$(CC) $(CFLAGS) -c -DLUA_BUILD_AS_DLL -o $@ $^ $(LUAINC) $(BGFXINC)

bgfx.dll : $(ODIR)/luabgfx.o $(ODIR)/ibcompress.o $(ODIR)/luabgfxutil.o
	$(CC) $(CFLAGS) --shared -o $@ $^ $(LUALIB) $(BGFXUTILLIB) $(BIMGLIB) $(BGFXLIB)

all : bgfx.dll

# all

$(ODIR) :
	mkdir $@

clean :
	rm -rf $(ODIR) && rm -f *.dll
