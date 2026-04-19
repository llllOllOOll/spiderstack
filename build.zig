const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ── Dependência externa: Spider Web Framework ─────────────────────
    const spider_dep = b.dependency("spider", .{ .target = target });
    const spider_mod = spider_dep.module("spider");

    // ── core ──────────────────────────────────────────────────────────
    const core_mod = b.createModule(.{
        .root_source_file = b.path("src/core/mod.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "spider", .module = spider_mod },
        },
    });

    // ── features ──────────────────────────────────────────────────────
    const features_mod = b.createModule(.{
        .root_source_file = b.path("src/features/mod.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "spider", .module = spider_mod },
            .{ .name = "core", .module = core_mod },
        },
    });

    // ── Executável ────────────────────────────────────────────────────
    const exe = b.addExecutable(.{
        .name = "spiderstack",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    exe.root_module.addImport("spider", spider_mod);
    exe.root_module.addImport("core", core_mod);
    exe.root_module.addImport("features", features_mod);
    exe.root_module.linkSystemLibrary("pq", .{});

    b.installArtifact(exe);

    const gen = b.addRunArtifact(spider_dep.artifact("generate-templates"));
    gen.addArg("src/");
    gen.addArg("src/embedded_templates.zig");
    exe.step.dependOn(&gen.step);

    // ── Run ───────────────────────────────────────────────────────────
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // ── Testes unitários (sem banco) ──────────────────────────────────
    // zig build test
    const unit_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // ── Testes de integração (requer banco no ar) ─────────────────────
    // zig build test-integration
    const integration_mod = b.createModule(.{
        .root_source_file = b.path("src/core/db/integration_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "spider", .module = spider_mod },
            .{ .name = "core", .module = core_mod },
        },
    });

    const integration_tests = b.addTest(.{ .root_module = integration_mod });
    integration_tests.root_module.linkSystemLibrary("pq", .{});

    const run_integration_tests = b.addRunArtifact(integration_tests);

    // Não falha o build se o banco não estiver disponível em CI
    run_integration_tests.has_side_effects = true;

    const integration_step = b.step("test-integration", "Run integration tests (requires DB)");
    integration_step.dependOn(&run_integration_tests.step);
}
