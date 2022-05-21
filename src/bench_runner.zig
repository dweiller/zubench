const std = @import("std");
const bench = @import("zubench");
const root = @import("@bench");
const builtin = @import("builtin");

pub const sample_spec = if (@hasDecl(root, "sample_spec"))
    root.sample_spec
else
    bench.default_sample_spec;

pub fn main() !void {
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
        var benchmark = try bench.Benchmark(spec.func).init(
            allocator,
            field.name,
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
