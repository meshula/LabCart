

#define SOKOL_ZIG_BINDINGS

// match Sokol-zig's defaults
#if defined(_WIN32)
    #define SOKOL_WIN32_FORCE_MAIN
    #define SOKOL_D3D11
    #define SOKOL_LOG(msg) OutputDebugStringA(msg)
#elif defined(__APPLE__)
    #define SOKOL_METAL
#else
    #define SOKOL_GLCORE33
#endif

#include "sokol_gfx.h"
#include "sokol_gl.h"
#define FONTSTASH_IMPLEMENTATION 
#include "fontstash.h"
#define SOKOL_FONTSTASH_IMPL
#include "sokol_fontstash.h"
#define SOKOL_GLUE_IMPL
#include "sokol_glue.h"

