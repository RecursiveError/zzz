const std = @import("std");
const assert = std.debug.assert;

// The Pseudoslice will basically stitch together two different buffers, using
// a third provided buffer as the output.
pub const Pseudoslice = struct {
    first: []const u8,
    second: []const u8,
    shared: []u8,
    len: u32,

    pub fn init(first: []const u8, second: []const u8, shared: []u8) Pseudoslice {
        return Pseudoslice{
            .first = first,
            .second = second,
            .shared = shared,
            .len = @intCast(first.len + second.len),
        };
    }

    /// Operates like a slice. That means it does not capture the end.
    /// Start is an inclusive bound and end is an exclusive bound.
    pub fn get(self: *Pseudoslice, start: u32, end: u32) []const u8 {
        assert(end >= start);
        assert(self.shared.len >= end - start);

        const clamped_end = @min(end, self.len);

        if (start < self.first.len) {
            if (clamped_end <= self.first.len) {
                return self.first[start..clamped_end];
            } else {
                // Across both buffers
                const first_len = self.first.len - start;
                const second_len = clamped_end - self.first.len;
                std.mem.copyForwards(u8, self.shared[0..first_len], self.first[start..]);
                std.mem.copyForwards(u8, self.shared[first_len..], self.second[0..second_len]);
                return self.shared[0..(first_len + second_len)];
            }
        }

        if (start >= self.first.len) {
            const second_start = start - self.first.len;
            const second_end = end - self.first.len;
            return self.second[second_start..second_end];
        }

        unreachable;
    }
};

const testing = std.testing;

test "General" {
    var buffer = [_]u8{0} ** 1024;
    const value = "hello, my name is muki";
    var pseudo = Pseudoslice.init(value[0..6], value[6..], buffer[0..]);

    for (0..pseudo.len) |i| {
        for (0..i) |j| {
            try testing.expectEqualStrings(value[j..i], pseudo.get(@intCast(j), @intCast(i)));
        }
    }
}

test "Empty Second" {
    var buffer = [_]u8{0} ** 1024;
    const value = "hello, my name is muki";
    var pseudo = Pseudoslice.init(value[0..], &.{}, buffer[0..]);

    for (0..pseudo.len) |i| {
        try testing.expectEqualStrings(value[0..i], pseudo.get(@intCast(0), @intCast(i)));
    }
}