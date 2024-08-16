const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;

pub fn compile(source: []u8, stdout: anytype) @TypeOf(stdout).Error!void {
    var scanner = Scanner.init(source);
    var line: usize = std.math.maxInt(usize);

    while (true) {
        const token = scanner.scanToken();

        if (token.line != line) {
            try stdout.print("{d:0>4} ", .{token.line});
            line = token.line;
        } else {
            try stdout.print("   | ", .{});
        }

        try stdout.print("{}\n", .{token});

        if (token.type == .eof) break;
    }
}
