const std = @import("std");
const zubench = @import("zubench");

pub const sample_spec = [_]zubench.Clock{ .real, .process, .thread };
// pray to the stack-overflow gods 🙏
fn fib(n: u32) u32 {
    return if (n == 0)
        0
    else if (n == 1)
        1
    else
        fib(n - 1) + fib(n - 2);
}

fn fibFast(n: u32) u32 {
    const phi = (1.0 + @sqrt(5.0)) / 2.0;
    const psi = (1.0 - @sqrt(5.0)) / 2.0;
    const float_n = @intToFloat(f32, n);
    const phi_n = std.math.pow(f32, phi, float_n);
    const psi_n = std.math.pow(f32, psi, float_n);
    return @floatToInt(u32, (phi_n - psi_n) / @sqrt(5.0));
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var progress = std.Progress{};

    var bm = try zubench.Benchmark(fib).init(allocator, "fib()", .{35}, 20, &progress);
    const report = bm.run();
    bm.deinit();

    var bm_fast = try zubench.Benchmark(fibFast).init(allocator, "fibFast()", .{35}, 1_000_000, &progress);
    const report_fast = bm_fast.run();
    bm_fast.deinit();

    const stdout = std.io.getStdOut().writer();
    // write human-readable summary
    try stdout.print("{}", .{report});
    // write report as json
    try std.json.stringify(report_fast, .{}, stdout);
    try stdout.writeByte('\n');
}
