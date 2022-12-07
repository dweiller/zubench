const std = @import("std");
const zubench = @import("zubench");
const fib = @import("fib.zig");

// uncomment this to explicitly specify which clocks to use
// pub const sample_spec = [_]zubench.Clock{ .real, .process, .thread };

fn fib10() u32 {
    return fib.fibFast(10);
}

pub const benchmarks = .{
    .@"fib()" = zubench.Spec(fib.fib){
        .args = .{35},
        .max_samples = 20,
        .opts = .{ .outlier_detection = .none }, // disable MAD-base outlier detection
    },
    // by default use MAD-based outlier detection
    .@"fibFast()" = zubench.Spec(fib.fibFast){ .args = .{35}, .max_samples = 1_000_000 },
    // 0-ary functions do not need .args field
    .@"fib10()" = zubench.Spec(fib10){ .max_samples = 1_000 },
};
