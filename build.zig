pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const liblsquic_dep = b.dependency("lsquic", .{
        .target = target,
        .optimize = optimize,
    });

    const mod_lsquic = b.addModule("lsquic", .{
        .root_source_file = b.path("src/lsquic.zig"),
        .optimize = optimize,
        .target = target,
    });

    const lib = b.addLibrary(.{
        .name = "lsquic",
        .linkage = .static,
        .root_module = mod_lsquic,
    });

    const liblsquic = liblsquic_dep.artifact("lsquic");

    lib.linkSystemLibrary("zlib");
    lib.linkLibrary(liblsquic);
    lib.step.dependOn(&liblsquic.step);
    lib.addIncludePath(liblsquic_dep.path("include"));

    const filters = b.option([]const []const u8, "filter", "filter based on name");
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/lsquic.zig"),
        .target = target,
        .optimize = optimize,
        .filters = filters orelse &.{},
    });
    lib_unit_tests.root_module.addIncludePath(liblsquic_dep.path("include"));
    lib_unit_tests.root_module.linkLibrary(liblsquic);
    lib_unit_tests.root_module.linkSystemLibrary("zlib", .{});
    b.installArtifact(lib);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const tutorial = b.addExecutable(.{
        .name = "tutorial",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });
    tutorial.root_module.addImport("lsquic", mod_lsquic);
    b.installArtifact(tutorial);
    const run_cmd = b.addRunArtifact(tutorial);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

const std = @import("std");
const Import = std.Build.Module.Import;
