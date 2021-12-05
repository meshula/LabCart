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

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    const sokol = buildSokol(b, target, mode, "third-party/sokol-zig/");
    const lua = buildLua(b, target, mode, "third-party/lua/");
    const options = b.addOptions();
    //-------------------------------------------------------------------------

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
        exe_LabCart.addIncludeDir("./third-party/microui/demo"); // for atlas.ini
        exe_LabCart.addCSourceFile("./third-party/microui/src/microui.c", &c_args);
        exe_LabCart.addCSourceFile("./third-party/sgl-microui.c", &c_args);
        exe_LabCart.linkLibrary(sokol);
        exe_LabCart.linkLibrary(lua);
        exe_LabCart.linkLibC();
        exe_LabCart.install();
    }

    const run = exe_LabCart.run();
    run.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run");
    run_step.dependOn(&run.step);
}

