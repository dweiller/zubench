const std = @import("std");

/// Sample mean
pub fn mean(samples: []const u64) f32 {
    std.debug.assert(samples.len > 0);
    var acc: u128 = 0;
    for (samples) |sample| {
        acc += sample;
    }
    return @as(f32, @floatFromInt(acc)) / @as(f32, @floatFromInt(samples.len));
}

fn totalSquaredError(samples: []const u64, avg: f32) f32 {
    var acc: f32 = 0.0;
    for (samples) |sample| {
        const diff = avg - @as(f32, @floatFromInt(sample));
        acc += diff * diff;
    }
    return acc;
}
/// sample variance
pub fn variance(samples: []const u64, avg: f32) f32 {
    return totalSquaredError(samples, avg) / @as(f32, @floatFromInt(samples.len - 1));
}

/// sample standard deviation
pub fn correctedSampleStdDev(samples: []const u64, avg: f32) f32 {
    return std.math.sqrt(variance(samples, avg));
}

/// returns the median
/// modifies `samples`, make a copy if you need to keep the original data
// PERF: better to use randomize quick select?
pub fn median(samples: []u64) f32 {
    std.sort.heap(u64, samples, {}, comptime std.sort.asc(u64));
    return if (samples.len % 2 == 0)
        @floatFromInt((samples[samples.len / 2 - 1] + samples[samples.len / 2]) / 2)
    else
        @floatFromInt(samples[samples.len / 2]);
}

/// median absolute deviation central tendency
/// modifies `samples`, make a copy if you need to keep the original data
pub fn medianAbsDev(samples: []u64, centre: f32) f32 {
    for (samples) |*sample| {
        const val: f32 = @floatFromInt(sample.*);
        // WARNING: cast will bias result
        sample.* = if (val > centre)
            @intFromFloat(val - centre)
        else
            @intFromFloat(centre - val);
    }
    return median(samples);
}

/// calculate the z-score
/// For the actual z-score, call as zScore(stddev, mean, val).
pub fn zScore(dispersion: f32, centre: f32, val: u64) f32 {
    const diff = @as(f32, @floatFromInt(val)) - centre;
    return diff / dispersion;
}

const SortContext = struct {
    centre: f32,
    dispersion: f32,
};

fn ascByZScore(context: SortContext, a: u64, b: u64) bool {
    const zscore_a = zScore(context.dispersion, context.centre, a);
    const zscore_b = zScore(context.dispersion, context.centre, b);
    return std.sort.asc(f32, zscore_a, zscore_b);
}

const IndexSortContext = struct {
    samples: []const u64,
    centre: f32,
    dispersion: f32,
};

fn ascIndexByZScore(context: SortContext, a: u16, b: u16) bool {
    const zscore_a = zScore(context.dispersion, context.centre, context.samples[a]);
    const zscore_b = zScore(context.dispersion, context.centre, context.samples[b]);
    return std.sort.asc(f32, zscore_a, zscore_b);
}

/// removes outliers from `samples`, copying data to `buf`
/// and returning a subslice of `buf` containing non-outliers
///
/// `cutoff` is the cutoff of MAD (median absolute deviation from the median)
/// to use. For examples, if you want to remove everything outside on `n` standard
/// deviations (assuming a normal distribution), `cutoff` should be set to
/// approximately `1.4826 * n`.
pub fn removeOutliers(buf: []u64, samples: []const u64, cutoff: f32) []u64 {
    std.mem.copy(u64, buf, samples);
    const centre = median(buf);
    const mad = medianAbsDev(buf, centre);
    const ctx = SortContext{ .centre = centre, .dispersion = mad };

    std.mem.copy(u64, buf, samples);
    std.sort.sort(u64, buf, ctx, ascByZScore);

    var i: usize = buf.len;
    while (zScore(mad, centre, buf[i - 1]) > cutoff) : (i -= 1) {}
    return buf[0..i];
}

pub fn removeOutliersIndices(buf: []u64, indices: []u16, samples: []const u64, cutoff: f32) []u64 {
    std.debug.assert(indices.len == samples.len and buf.len == samples.len);
    std.mem.copy(u64, buf, samples);
    const centre = median(buf);
    const mad = medianAbsDev(buf, centre);
    const ctx = SortContext{ .samples = samples, .centre = centre, .dispersion = mad };

    std.sort.sort(u64, indices, ctx, ascIndexByZScore);

    var i: usize = buf.len;
    while (zScore(mad, centre, samples[indices[i - 1]]) > cutoff * mad) : (i -= 1) {}
    return buf[0..i];
}
