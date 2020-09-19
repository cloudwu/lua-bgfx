local LUA54DIR = "../lua/"
local BGFXDIR = "../bgfx/"
local BXDIR = "../bx/"

local BGFXINC = {
    BGFXDIR.."include",
    BGFXDIR.."3rdparty",
    BGFXDIR.."examples/common",
    BXDIR.."compat/msvc",
    BXDIR.."include",
    }

local BGFXLIBDIR = BGFXDIR..".build/win64_vs2019/bin/"

workspace "lua-bgfx"
    configurations { "Debug", "Release" }
    flags{"NoPCH","RelativeLinks"}
    location "./build"
    architecture "x64"

    filter "configurations:Debug"
        defines { "DEBUG" }
        symbols "On"

    filter "configurations:Release"
        defines { "NDEBUG" }
        optimize "On"
        symbols "On"

    filter {"system:windows"}
        characterset "MBCS"
        systemversion "latest"
        warnings "Extra"

    -- filter { "system:linux" }
    --     warnings "High"

    -- filter { "system:macosx" }
    --     warnings "High"

project "bgfx"
    location "build/bgfx"
    objdir "build/%{cfg.project.name}/%{cfg.buildcfg}"
    targetdir "bin/%{cfg.buildcfg}"
    kind "SharedLib"
    language "C++"
    includedirs {LUA54DIR,"./"}
    includedirs(BGFXINC)
    defines {"BGFX_STATIC_LINK"}
    files {
        "./luabgfx.c",
        "./luabgfxutil.c",
        "./luabgfximgui.cpp",
        "./bgfx_alloc.cpp"
        }
    libdirs{BGFXLIBDIR}
    links{"lua54"}
    filter "configurations:Debug"
        links{
            "bgfxDebug",
            "bimgDebug",
            "bxDebug",
            "example-commonDebug"
            }
    filter "configurations:Release"
        links{
            "bgfxRelease",
            "bimgRelease",
            "bxRelease",
            "example-commonRelease"
            }
    filter { "system:windows" }
        defines {"LUA_BUILD_AS_DLL"}

project "math3d"
    location "build/math3d"
    objdir "build/%{cfg.project.name}/%{cfg.buildcfg}"
    targetdir "bin/%{cfg.buildcfg}"
    kind "SharedLib"
    language "C++"
    includedirs {
        LUA54DIR,
        "math3d/glm/"
    }
    links{"lua54"}
    files {
        "./math3d/linalg.c",
        "./math3d/math3d.c",
        "./math3d/math3dfunc.cpp",
        "./math3d/mathadapter.c",
        "./math3d/testadapter.c"
        }
    filter { "system:windows" }
        defines {"LUA_BUILD_AS_DLL","M_PI=3.14159265358979323846"}

project "lua54"
    location "build/lua54"
    objdir "build/obj/%{cfg.project.name}/%{cfg.buildcfg}"
    targetdir "bin/%{cfg.buildcfg}"
    kind "SharedLib"
    language "C"
    includedirs {LUA54DIR}
    files { LUA54DIR.."onelua.c"}
    filter { "system:windows" }
        -- disablewarnings { "4244","4324","4702","4310" }
        defines {"LUA_BUILD_AS_DLL"}

project "lua"
    location "build/lua"
    objdir "build/obj/%{cfg.project.name}/%{cfg.buildcfg}"
    targetdir "bin/%{cfg.buildcfg}"
    kind "ConsoleApp"
    language "C"
    includedirs {LUA54DIR}
    files { LUA54DIR.."lua.c"}
    links{"lua54"}
    defines {"MAKE_LUA"}
    filter { "system:windows" }
        -- disablewarnings { "4244","4324","4702","4310" }
        defines {"LUA_BUILD_AS_DLL"}
