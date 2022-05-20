const std = @import("std");
const bench = @import("bench");

// uncomment this to explicitly specify which clocks to use
// pub const sample_spec = [_]bench.Clock{ .real, .process, .thread };

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


pub const benchmarks = .{
    .@"fib()" = bench.Spec(fib){ .args = .{35}, .max_samples = 20 },
    .@"fibFast()" = bench.Spec(fibFast){ .args = .{35}, .max_samples = 1_000_000 },
};
