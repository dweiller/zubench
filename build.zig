const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardOptimizeOption(.{});

    const zubench = b.addModule("zubench", .{
        .source_file = .{ .path = "src/bench.zig" },
    });

    const fib2 = b.addExecutable(.{
        .name = "fib2",
        .root_source_file = .{ .path = "examples/fib2.zig" },
        .optimize = mode,
    });
    fib2.addModule("zubench", zubench);

    const fib_build = addBench(
        b,
        "examples/fib_build.zig",
        .ReleaseSafe,
        zubench,
        &.{},
    );

    const fib_test = addTestBench(b, "examples/fib.zig", .ReleaseSafe, zubench);
    fib_test.filter = "fib";

    const examples = [_]*std.Build.CompileStep{
        fib2,
        fib_build,
        fib_test,
    };

    const examples_step = b.step("examples", "Build the examples");
    const bench_step = b.step("run", "Run the examples");

    for (examples) |example| {
        const install = b.addInstallArtifact(example);
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
        .root_source_file = .{ .path = "src/bench.zig" },
        .optimize = mode,
    });
    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}

fn rootDir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

const bench_runner_path = rootDir() ++ "/src/bench_runner.zig";

pub fn addBench(
    b: *std.Build,
    path: []const u8,
    mode: std.builtin.OptimizeMode,
    zubench_mod: *std.Build.Module,
    dependencies: []const std.Build.ModuleDependency,
) *std.Build.CompileStep {
    const name = benchExeName(b.allocator, path, mode);
    var deps = b.allocator.alloc(std.build.ModuleDependency, dependencies.len + 1) catch unreachable;
    std.mem.copy(std.build.ModuleDependency, deps, dependencies);

    deps[deps.len - 1] = .{ .name = "zubench", .module = zubench_mod };
    const root = b.createModule(.{
        .source_file = .{ .path = path },
        .dependencies = deps,
    });

    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = .{ .path = bench_runner_path },
        .optimize = mode,
    });
    exe.addModule("@bench", root);
    exe.addModule("zubench", zubench_mod);

    return exe;
}

pub fn addTestBench(
    b: *std.Build,
    path: []const u8,
    mode: std.builtin.OptimizeMode,
    zubench_mod: *std.Build.Module,
) *std.Build.CompileStep {
    const name = benchExeName(b.allocator, path, mode);

    const exe = b.addTest(.{
        .name = name,
        .root_source_file = .{ .path = path },
        .optimize = mode,
        .test_runner = bench_runner_path,
    });
    exe.addModule("zubench", zubench_mod);

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
