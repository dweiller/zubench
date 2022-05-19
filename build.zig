const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const bench = std.build.Pkg{
        .name = "bench",
        .path = .{ .path = "src/bench.zig" },
    };

    const fib2 = b.addExecutable("fib2", "examples/fib2.zig");
    fib2.addPackage(bench);
    fib2.setBuildMode(mode);
    fib2.install();

    const examples_step = b.step("examples", "Build the examples");
    examples_step.dependOn(&fib2.step);

    const main_tests = b.addTest("src/bench.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
