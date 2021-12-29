const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;
const CrossTarget = std.zig.CrossTarget;
const Mode = std.builtin.Mode;
const sokol = @import("third-party/sokol-zig/build.zig");
const buildLua = @import("third-party/lua-build.zig").buildLua;
const print = @import("std").debug.print;

var raw = std.heap.GeneralPurposeAllocator(.{}){};
pub const ALLOCATOR = &raw.allocator;

const c_args = [_][]const u8{
    "-std=c11",
    "-fno-sanitize=undefined",
    "-DSOKOL_ZIG_BINDINGS",
};

const cpp_args = [_][]const u8{
    "-std=c++17",
    "-fno-sanitize=undefined",
    "-DSOKOL_ZIG_BINDINGS",
};

const fonts = [_][]const u8{
    "DroidSansJapanese.ttf",
    "DroidSerif-Bold.ttf",
    "DroidSerif-Italic.ttf",
    "DroidSerif-Regular.ttf",
    "hauer-12.png",
    "hauer-12.font.json",
    "robot-18.png",
    "robot-18.font.json",
};

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    const buildSokol = sokol.buildSokol(b, target, mode, "third-party/sokol-zig/");
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
        exe_LabCart.linkLibrary(buildSokol);
        exe_LabCart.linkLibrary(lua);
        exe_LabCart.linkLibrary(lib_LabFont);
        exe_LabCart.linkLibC();
        exe_LabCart.install();
    }

    for (fonts) |font| {
        var path = std.fs.path.join(b.allocator, &.{"./third-party/LabFont/resources", font}) catch unreachable;

        var dst_path: []u8 = std.fs.path.join(b.allocator, &.{ "LabCart-rsrc", font }) catch unreachable;

        const font_install = b.addInstallBinFile(
            .{ .path = path }, dst_path);

        b.getInstallStep().dependOn(&font_install.step);
    }

    const font_install = b.addInstallBinFile(
        .{ .path = "./third-party/LabFont/resources/hauer-12.png" }, "LabCart-rsrc/hauer-12.png");
    b.getInstallStep().dependOn(&font_install.step);

    const run = exe_LabCart.run();
    run.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run");
    run_step.dependOn(&run.step);
}

