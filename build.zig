const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ── Dependência externa: Spider Web Framework ─────────────────────
    const spider_dep = b.dependency("spider", .{ .target = target });
    const spider_mod = spider_dep.module("spider");

    // ── core ──────────────────────────────────────────────────────────
    // Usado em main.zig via @import("core"):
    //   core.db.migrations  →  src/core/db/migrations.zig
    //   core.middleware      →  src/core/middleware/mod.zig
    const core_mod = b.createModule(.{
        .root_source_file = b.path("src/core/mod.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "spider", .module = spider_mod },
        },
    });

    // ── features ──────────────────────────────────────────────────────
    // Usado em main.zig via @import("features/mod.zig").
    // auth e home são resolvidos internamente por features via
    // @import relativo — não precisam ser módulos do build.
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
        .name = "basic",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // Apenas o que main.zig importa via @import("nome")
    exe.root_module.addImport("spider", spider_mod);
    exe.root_module.addImport("core", core_mod);
    exe.root_module.addImport("features", features_mod);

    // PostgreSQL via libpq (usado por spider.pg)
    exe.root_module.linkSystemLibrary("pq", .{});

    b.installArtifact(exe);

    // ── Run ───────────────────────────────────────────────────────────
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // ── Testes ────────────────────────────────────────────────────────
    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
