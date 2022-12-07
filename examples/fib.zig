const std = @import("std");

// pray to the stack-overflow gods 🙏
pub fn fib(n: u32) u32 {
    return if (n == 0)
        0
    else if (n == 1)
        1
    else
        fib(n - 1) + fib(n - 2);
}

pub fn fibFast(n: u32) u32 {
    const phi = (1.0 + @sqrt(5.0)) / 2.0;
    const psi = (1.0 - @sqrt(5.0)) / 2.0;
    const float_n = @intToFloat(f32, n);
    const phi_n = std.math.pow(f32, phi, float_n);
    const psi_n = std.math.pow(f32, psi, float_n);
    return @floatToInt(u32, (phi_n - psi_n) / @sqrt(5.0));
}
