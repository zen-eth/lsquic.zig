pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("lsquic", .{
        .target = target,
        .optimize = optimize,
    });

    const mod_lsquic = b.addModule("lsquic", .{
        .root_source_file = b.path("src/lsquic.zig"),
        .optimize = optimize,
        .target = target,
    });

    const liblsquic = upstream.artifact("lsquic");
    mod_lsquic.addIncludePath(upstream.path("include"));
    mod_lsquic.linkLibrary(liblsquic);

    const lsquic = b.addLibrary(.{
        .name = "lsquic",
        .linkage = .static,
        .root_module = mod_lsquic,
    });

    const filters = b.option([]const []const u8, "filter", "filter based on name");

    const test_module = b.createModule(.{
        .root_source_file = b.path("src/lsquic.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_module.addIncludePath(upstream.path("include"));
    test_module.linkLibrary(liblsquic);

    const lib_unit_tests = b.addTest(.{
        .root_module = test_module,
        .filters = filters orelse &.{},
    });
    b.installArtifact(lsquic);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const xev = b.dependency("libxev", .{ .target = target, .optimize = optimize });
    const mod_xev = xev.module("xev");

    const duck_client_mod = b.createModule(.{
        .root_source_file = b.path("src/duck_client.zig"),
        .optimize = optimize,
        .target = target,
    });
    duck_client_mod.addImport("lsquic", mod_lsquic);
    duck_client_mod.addImport("xev", mod_xev);
    const duck_client = b.addExecutable(.{ .name = "duck_client", .root_module = duck_client_mod });

    const duck_server_mod = b.createModule(.{
        .root_source_file = b.path("src/duck_server.zig"),
        .optimize = optimize,
        .target = target,
    });
    duck_server_mod.addImport("lsquic", mod_lsquic);
    duck_server_mod.addImport("xev", mod_xev);
    const duck_server = b.addExecutable(.{ .name = "duck_server", .root_module = duck_server_mod });

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
