const std = @import("std");
const zubench = @import("zubench");
const fib = @import("fib.zig");

pub const sample_spec = [_]zubench.Clock{ .real, .process, .thread };

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var progress = std.Progress{};

    var bm = try zubench.Benchmark(@TypeOf(fib.fib)).init(
        allocator,
        "fib()",
        &fib.fib,
        .{35},
        .{ .outlier_detection = .none }, //disable MAD-base outlier detection
        20,
        &progress,
    );
    const report = try bm.run();
    bm.deinit();

    var bm_fast = try zubench.Benchmark(@TypeOf(fib.fibFast)).init(
        allocator,
        "fibFast()",
        &fib.fibFast,
        .{35},
        .{},
        1_000_000,
        &progress,
    );
    const report_fast = try bm_fast.run();
    bm_fast.deinit();

    const stdout = std.io.getStdOut().writer();
    // write human-readable summary
    try stdout.print("{}", .{report});
    // write report as json
    try std.json.stringify(report_fast, .{}, stdout);
    try stdout.writeByte('\n');
}
