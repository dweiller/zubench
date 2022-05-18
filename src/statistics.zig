const std = @import("std");

/// Sample mean
pub fn mean(samples: []u64) f32 {
    std.debug.assert(samples.len > 0);
    var acc: u128 = 0;
    for (samples) |sample| {
        acc += sample;
    }
    return @intToFloat(f32, acc) / @intToFloat(f32, samples.len);
}

fn totalSquaredError(samples: []u64, avg: f32) f32 {
    var acc: f32 = 0.0;
    for (samples) |sample| {
        const diff = avg - @intToFloat(f32, sample);
        acc += diff * diff;
    }
    return acc;
}
/// sample variance
pub fn variance(samples: []u64, avg: f32) f32 {
    return totalSquaredError(samples, avg) / @intToFloat(f32, samples.len - 1);
}

/// sample standard deviation
pub fn correctedSampleStdDev(samples: []u64, avg: f32) f32 {
    return std.math.sqrt(variance(samples, avg));
}
