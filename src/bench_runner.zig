const std = @import("std");
const bench = @import("zubench");
const root = @import("@bench");
const builtin = @import("builtin");

pub const sample_spec = if (!builtin.is_test and @hasDecl(root, "sample_spec"))
    root.sample_spec
else
    bench.default_sample_spec;

pub fn main() !void {
    if (builtin.is_test)
        try testRunner()
    else
        try standalone();
}

fn testRunner() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const options = bench.Options{};
    const max_samples = 100;

    const stderr = std.io.getStdErr().writer();
    try stderr.print("Running benchmarks ({s} mode)\n", .{@tagName(builtin.mode)});

    var progress = std.Progress{};
    var results = try std.ArrayList(bench.Report).initCapacity(allocator, builtin.test_functions.len);
    defer results.deinit();

    for (builtin.test_functions) |test_fn| {
        const bench_name = if (std.mem.indexOfScalar(u8, test_fn.name, '.')) |index|
            test_fn.name[index + 1 ..]
        else
            test_fn.name;
        var benchmark = try bench.Benchmark(std.meta.Child(@TypeOf(test_fn.func))).init(
            allocator,
            bench_name,
            test_fn.func,
            .{},
            options,
            max_samples,
            &progress,
        );
        defer benchmark.deinit();
        results.appendAssumeCapacity(try benchmark.run());
    }

    const stdout = std.io.getStdOut().writer();
    for (results.items) |report| {
        // write human-readable summary
        try stdout.print("{}", .{report});
    }
}

fn standalone() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stderr = std.io.getStdErr().writer();
    try stderr.print("Running benchmarks ({s} mode)\n", .{@tagName(builtin.mode)});

    var progress = std.Progress{};

    const benchmarks = @typeInfo(@TypeOf(root.benchmarks)).Struct.fields;
    var results = std.BoundedArray(bench.Report, benchmarks.len).init(0) catch unreachable;

    inline for (benchmarks) |field| {
        const spec = @field(root.benchmarks, field.name);
        var benchmark = try bench.Benchmark(@TypeOf(spec.func)).init(
            allocator,
            field.name,
            spec.func,
            spec.args,
            spec.opts,
            spec.max_samples,
            &progress,
        );
        defer benchmark.deinit();
        results.appendAssumeCapacity(try benchmark.run());
    }

    const stdout = std.io.getStdOut().writer();
    for (results.slice()) |report| {
        // write human-readable summary
        try stdout.print("{}", .{report});
    }
}
