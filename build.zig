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

    const duck_client = b.addExecutable(.{
        .name = "duck_client",
        .root_source_file = b.path("src/duck_client.zig"),
        .optimize = optimize,
        .target = target,
    });
    const duck_server = b.addExecutable(.{
        .name = "duck_server",
        .root_source_file = b.path("src/duck_server.zig"),
        .optimize = optimize,
        .target = target,
    });

    const xev = b.dependency("libxev", .{ .target = target, .optimize = optimize });
    const mod_xev = xev.module("xev");

    duck_client.root_module.addImport("lsquic", mod_lsquic);
    duck_client.root_module.addImport("xev", mod_xev);

    duck_server.root_module.addImport("lsquic", mod_lsquic);
    duck_server.root_module.addImport("xev", mod_xev);
    b.installArtifact(duck_client);
    b.installArtifact(duck_server);
    const run_duck_client_cmd = b.addRunArtifact(duck_client);
    const run_duck_server_cmd = b.addRunArtifact(duck_server);
    run_duck_client_cmd.step.dependOn(b.getInstallStep());
    run_duck_server_cmd.step.dependOn(b.getInstallStep());

    const run_duck_client_step = b.step("run-client", "Run duck client");
    const run_duck_server_step = b.step("run-server", "Run duck server");
    run_duck_client_step.dependOn(&run_duck_client_cmd.step);
    run_duck_server_step.dependOn(&run_duck_server_cmd.step);
}

const std = @import("std");
const Import = std.Build.Module.Import;
