const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;
const CrossTarget = std.zig.CrossTarget;
const Mode = std.builtin.Mode;
const buildSokol = @import("third-party/sokol-zig/build.zig").buildSokol;
const buildLua = @import("third-party/lua-build.zig").buildLua;

var raw = std.heap.GeneralPurposeAllocator(.{}){};
pub const ALLOCATOR = &raw.allocator;

const c_args = [_][]const u8{
    "-std=c11",
    "-fno-sanitize=undefined",
};

const cpp_args = [_][]const u8{
    "-std=c++17",
    "-fno-sanitize=undefined",
};

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    const sokol = buildSokol(b, target, mode, "third-party/sokol-zig/");
    const lua = buildLua(b, target, mode, "third-party/lua/");
    const options = b.addOptions();
    //-------------------------------------------------------------------------

    const lib_LabFont = b.addStaticLibrary("LabFont", null);
    {
        lib_LabFont.addOptions("build_options", options);
        lib_LabFont.setTarget(target);
        lib_LabFont.setBuildMode(mode);
        lib_LabFont.linkLibCpp();
        lib_LabFont.linkSystemLibrary("c");
        lib_LabFont.addIncludeDir("./");
        lib_LabFont.addIncludeDir("./third-party/rapidjson/include");
        lib_LabFont.addIncludeDir("./third-party/LabFont");
        lib_LabFont.addIncludeDir("./third-party/LabFont/src");
        lib_LabFont.addIncludeDir("./third-party/sokol-zig/src/sokol/c");
        lib_LabFont.addCSourceFile("./third-party/LabFont/src/LabFont.cpp", &cpp_args);
        lib_LabFont.addCSourceFile("./third-party/LabFont/src/quadplay_font.cpp", &cpp_args);
        lib_LabFont.addCSourceFile("./LabSokolAux.c", &c_args);
    }


    const exe_LabCart = b.addExecutable("LabCart", "LabCart.zig");
    {
        exe_LabCart.addOptions("build_options", options);
        exe_LabCart.setTarget(target);
        exe_LabCart.setBuildMode(mode);
        exe_LabCart.addPackagePath("sokol", "third-party/sokol-zig/src/sokol/sokol.zig");
        exe_LabCart.addIncludeDir("./third-party/sokol-zig/src/sokol/c");
        exe_LabCart.addIncludeDir("./third-party/microui/src");
        exe_LabCart.addIncludeDir("./third-party/lua");
        exe_LabCart.addIncludeDir("./third-party");
        exe_LabCart.addIncludeDir("./third-party/LabFont");
        exe_LabCart.addIncludeDir("./third-party/microui/demo"); // for atlas.ini
        exe_LabCart.addCSourceFile("./third-party/microui/src/microui.c", &c_args);
        exe_LabCart.addCSourceFile("./third-party/sgl-microui.c", &c_args);
        exe_LabCart.linkLibrary(sokol);
        exe_LabCart.linkLibrary(lua);
        exe_LabCart.linkLibrary(lib_LabFont);
        exe_LabCart.linkLibC();
        exe_LabCart.install();
    }

    const run = exe_LabCart.run();
    run.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run");
    run_step.dependOn(&run.step);
}

