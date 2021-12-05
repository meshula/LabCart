
// forked from https://github.com/tiehuis/zig-lua
// where it has the MIT license

const std = @import("std");
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;
const LibExeObjStep = std.build.LibExeObjStep;
const Mode = std.builtin.Mode;

pub fn buildLua(b: *Builder, target: CrossTarget, mode: Mode,
                comptime prefix_path: []const u8) *LibExeObjStep {
    const lib = b.addStaticLibrary("lua", null);
    lib.setBuildMode(mode);
    lib.setTarget(target);
    lib.linkLibC();
    lib.linkSystemLibrary("c");
    lib.addIncludeDir(prefix_path ++ "lua");

    const lua_c_files = [_][]const u8{
        "lapi.c",
        "lauxlib.c",
        "lbaselib.c",
        "lcode.c",
        "lcorolib.c",
        "lctype.c",
        "ldblib.c",
        "ldebug.c",
        "ldo.c",
        "ldump.c",
        "lfunc.c",
        "lgc.c",
        "linit.c",
        "liolib.c",
        "llex.c",
        "lmathlib.c",
        "lmem.c",
        "loadlib.c",
        "lobject.c",
        "lopcodes.c",
        "loslib.c",
        "lparser.c",
        "lstate.c",
        "lstring.c",
        "lstrlib.c",
        "ltable.c",
        "ltablib.c",
        "ltm.c",
        "lundump.c",
        "lutf8lib.c",
        "lvm.c",
        "lzio.c",
    };

    const c_flags = [_][]const u8{
        "-std=c99",
        "-O2",
    };

    inline for (lua_c_files) |c_file| {
        lib.addCSourceFile(prefix_path ++ c_file, &c_flags);
    }

    return lib;
}

