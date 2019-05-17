ODIR = o
BGFXSRC = ../bgfx
BXSRC = ../bx
BIMGSRC = ../bimg
LUAINC = -I/usr/local/include
LUALIB = -L/usr/local/bin -llua53

CC= gcc
CXX = g++
CFLAGS = -g -Wall

all :

# bgfx
#BGFXVER = Debug
BGFXVER = Release
BGFXLIB = -L$(BGFXSRC)/.build/win64_mingw-gcc/bin -lbgfx$(BGFXVER) -lbimg$(BGFXVER) -lbx$(BGFXVER) -lstdc++ -lgdi32 -lpsapi -luuid
BGFXINC = -I$(BGFXSRC)/include -I$(BXSRC)/include/compat/mingw -I$(BXSRC)/include
BGFX3RDINC = -I$(BGFXSRC)/3rdparty
BGFXUTILLIB = -lexample-common$(BGFXVER)
BGFXUTILINC = $(BGFX3RDINC) -I$(BGFXSRC)/examples/common

$(ODIR)/luabgfx.o : luabgfx.c  | $(ODIR)
	$(CC) $(CFLAGS) -c -DBGFX_STATIC_LINK -DLUA_BUILD_AS_DLL -o $@ $^ $(LUAINC) $(BGFXINC)

$(ODIR)/luabgfxutil.o : luabgfxutil.c  | $(ODIR)
	$(CC) $(CFLAGS) -c -DLUA_BUILD_AS_DLL -o $@ $^ $(LUAINC) $(BGFXINC)

$(ODIR)/luabgfximgui.o : luabgfximgui.cpp  | $(ODIR)
	$(CXX) $(CFLAGS) -c -DLUA_BUILD_AS_DLL -o $@ $^ $(LUAINC) $(BGFXINC) $(BGFXUTILINC)

bin :
	mkdir $@

bin/bgfx.dll : $(ODIR)/luabgfx.o $(ODIR)/luabgfxutil.o $(ODIR)/luabgfximgui.o | bin
	$(CC) $(CFLAGS) --shared -o $@ $^ $(LUALIB) $(BGFXUTILLIB) $(BIMGLIB) $(BGFXLIB)

bin/math3d.dll : | bin
	cd math3d && $(MAKE) OUTPUT=../bin/

all : bin/bgfx.dll bin/math3d.dll

# all

$(ODIR) :
	mkdir $@

clean :
	rm -rf $(ODIR) && rm -f bin/bgfx.dll bin/math3d.dll
