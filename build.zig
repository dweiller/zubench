const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zubench = b.addModule("zubench", .{
        .root_source_file = b.path("src/bench.zig"),
    });

    const fib2 = b.addExecutable(.{
        .name = "fib2",
        .root_source_file = b.path("examples/fib2.zig"),
        .target = target,
        .optimize = optimize,
    });
    fib2.root_module.addImport("zubench", zubench);

    const fib_build = addBenchInner(
        b,
        "examples/fib_build.zig",
        target,
        optimize,
        &.{},
        zubench,
        b.path("src/bench_runner.zig"),
    );

    const fib_test = addTestBenchInner(
        b,
        "examples/fib.zig",
        .ReleaseSafe,
        zubench,
        b.path("src/bench_runner.zig"),
    );
    fib_test.filters = &.{"bench"};

    const examples = [_]*std.Build.Step.Compile{
        fib2,
        fib_build,
        fib_test,
    };

    const examples_step = b.step("examples", "Build the examples");
    const bench_step = b.step("run", "Run the examples");

    for (examples) |example| {
        const install = b.addInstallArtifact(example, .{});
        const run_cmd = b.addRunArtifact(example);

        // NOTE: this works around Zig issue #15119 and should be removed when
        //       Zig PR #15120 or an equivalent is merged
        run_cmd.stdio = .infer_from_args;
        while (run_cmd.argv.items.len > 1) _ = run_cmd.argv.pop();

        run_cmd.step.dependOn(&install.step);

        examples_step.dependOn(&install.step);
        bench_step.dependOn(&run_cmd.step);
    }

    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/bench.zig"),
        .optimize = optimize,
    });
    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}

pub fn addBench(
    b: *std.Build,
    path: []const u8,
    target: std.Build.ResolvedTarget,
    mode: std.builtin.OptimizeMode,
    dependencies: []const std.Build.Module.Import,
) *std.Build.Step.Compile {
    const zubench_dep = b.dependencyFromBuildZig(@This(), .{});
    const zubench_mod = zubench_dep.module("zubench");
    const bench_runner_path: std.Build.LazyPath = .{
        .dependency = .{
            .dependency = zubench_dep,
            .sub_path = "src/bench_runner.zig",
        },
    };
    return addBenchInner(b, path, target, mode, dependencies, zubench_mod, bench_runner_path);
}

fn addBenchInner(
    b: *std.Build,
    path: []const u8,
    target: std.Build.ResolvedTarget,
    mode: std.builtin.OptimizeMode,
    dependencies: []const std.Build.Module.Import,
    zubench_mod: *std.Build.Module,
    bench_runner_path: std.Build.LazyPath,
) *std.Build.Step.Compile {
    const name = benchExeName(b.allocator, path, mode);
    var deps = b.allocator.alloc(std.Build.Module.Import, dependencies.len + 1) catch unreachable;
    @memcpy(deps[0..dependencies.len], dependencies);

    deps[deps.len - 1] = .{ .name = "zubench", .module = zubench_mod };
    const root = b.createModule(.{
        .root_source_file = b.path(path),
        .imports = deps,
    });

    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = bench_runner_path,
        .target = target,
        .optimize = mode,
    });
    exe.root_module.addImport("@bench", root);
    exe.root_module.addImport("zubench", zubench_mod);

    return exe;
}

pub fn addTestBench(
    b: *std.Build,
    path: []const u8,
    mode: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const zubench_dep = b.dependencyFromBuildZig(@This(), .{});
    const zubench_mod = zubench_dep.module("zubench");
    const bench_runner_path: std.Build.LazyPath = .{
        .dependency = zubench_dep,
        .sub_path = "src/bench_runner.zig",
    };
    return addTestBenchInner(b, path, mode, zubench_mod, bench_runner_path);
}

fn addTestBenchInner(
    b: *std.Build,
    path: []const u8,
    mode: std.builtin.OptimizeMode,
    zubench_mod: *std.Build.Module,
    bench_runner_path: std.Build.LazyPath,
) *std.Build.Step.Compile {
    const name = benchExeName(b.allocator, path, mode);

    const exe = b.addTest(.{
        .name = name,
        .root_source_file = b.path(path),
        .optimize = mode,
        .test_runner = bench_runner_path,
    });
    exe.root_module.addImport("zubench", zubench_mod);

    return exe;
}

fn benchExeName(allocator: std.mem.Allocator, path: []const u8, mode: std.builtin.Mode) []const u8 {
    const basename = std.fs.path.basename(path);
    const no_ext = if (std.mem.lastIndexOfScalar(u8, basename, '.')) |index|
        basename[0..index]
    else
        basename;

    const name = std.fmt.allocPrint(allocator, "zubench-{s}-{s}", .{
        no_ext,
        @tagName(mode),
    }) catch unreachable;
    return name;
}
