const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});
    const libdoom = b.addStaticLibrary(.{
        .name = "doom",
        .target = target,
        .optimize = optimize,
    });
    libdoom.addCSourceFile(.{
        .file = .{ .path = "src/main_doom.c" },
        .flags = cFlags,
    });
    const libwolf = b.addStaticLibrary(.{
        .name = "wolf",
        .target = target,
        .optimize = optimize,
    });

    libdoom.addIncludePath(.{ .path = "/opt/homebrew/opt/sdl2/include" });
    libdoom.addLibraryPath(.{ .path = "/opt/homebrew/opt/sdl2/lib" });
    libdoom.linkLibC();
    libdoom.linkSystemLibrary("SDL2");

    libwolf.addIncludePath(.{ .path = "/opt/homebrew/opt/sdl2/include" });
    libwolf.addLibraryPath(.{ .path = "/opt/homebrew/opt/sdl2/lib" });
    libwolf.linkLibC();
    libwolf.linkSystemLibrary("SDL2");

    b.installArtifact(libdoom);
    b.installArtifact(libwolf);
    const doom_step = b.step("doom", "Build the doom renderer");
    doom_step.dependOn(&libdoom.step);
    const wolf_step = b.step("wolf", "Build the wolfenstein renderer");
    wolf_step.dependOn(&libdoom.step);

    const l = b.addStaticLibrary(.{
        .name = "test",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/main.zig" },
    });
    l.addIncludePath(.{ .path = "/opt/homebrew/opt/sdl2/include" });
    l.addLibraryPath(.{ .path = "/opt/homebrew/opt/sdl2/lib" });
    l.linkLibC();
    l.linkSystemLibrary("SDL2");

    b.installArtifact(l);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.addIncludePath(.{ .path = "/opt/homebrew/opt/sdl2/include" });
    main_tests.addLibraryPath(.{ .path = "/opt/homebrew/opt/sdl2/lib" });
    main_tests.linkLibC();
    main_tests.linkSystemLibrary("SDL2");
    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}

const cFlags = &.{
    "-std=c2x",
    "-O2",
    "-g",
    "-fbracket-depth=1024",
    "-fmacro-backtrace-limit=0",
    "-Wall",
    "-Wextra",
    "-Wpedantic",
    "-Wfloat-equal",
    "-Wstrict-aliasing",
    "-Wswitch-default",
    "-Wformat=2",
    "-Wno-newline-eof",
    "-Wno-unused-parameter",
    "-Wno-strict-prototypes",
    "-Wno-fixed-enum-extension",
    "-Wno-int-to-void-pointer-cast",
    "-Wno-gnu-statement-expression",
    "-Wno-gnu-compound-literal-initialize",
    "-Wno-gnu-zero-variadic-macro-argumen",
    "-Wno-gnu-empty-struct",
    "-Wno-gnu-auto-type",
    "-Wno-gnu-empty-initializer",
    "-Wno-gnu-pointer-arith",
    "-Wno-c99-extensions",
    "-Wno-c11-extensions",
};
