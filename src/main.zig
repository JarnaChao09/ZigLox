const std = @import("std");
const builtin = @import("builtin");
const chunk = @import("chunk.zig");
const vm = @import("vm.zig");

const DELIMITER = if (builtin.os.tag == .windows) '\r' else '\n';

fn repl(v: *vm.VM, stdin: anytype, stdout: anytype, allocator: std.mem.Allocator) !void {
    var input = std.ArrayList(u8).init(allocator);
    defer input.deinit();

    while (true) {
        try stdout.print("> ", .{});

        stdin.streamUntilDelimiter(input.writer(), DELIMITER, null) catch |e| switch (e) {
            error.EndOfStream => break,
            else => {
                try stdout.print("Error: {}", .{e});
                std.process.exit(74);
            },
        };

        // must state that slice is sentinel terminated, or else allocator.free will
        // report unequal free sizes
        const line: [:0]const u8 = if (builtin.os.tag == .windows) blk: {
            break :blk std.mem.trimLeft(u8, input.toOwnedSliceSentinel(0), '\n');
        } else blk: {
            break :blk try input.toOwnedSliceSentinel(0);
        };
        defer allocator.free(line);

        if (std.mem.eql(u8, line, ":q")) {
            break;
        }

        _ = v.interpret(line, stdout) catch |e| switch (e) {
            error.CompilerError => std.process.exit(65),
            error.RuntimeError => std.process.exit(75),
            else => return e,
        };
    }
}

fn runFile(path: []u8, v: *vm.VM, stdout: anytype, allocator: std.mem.Allocator) !void {
    const file = std.fs.cwd().openFile(path, .{}) catch |e| {
        try stdout.print("Error for file {s}: {}", .{ path, e });
        std.process.exit(74);
    };
    defer file.close();

    const file_size = (file.stat() catch |e| {
        try stdout.print("Unable to retrieve stats for file {s}: {}", .{ path, e });
        std.process.exit(74);
    }).size;
    const buffer = allocator.alloc(u8, file_size) catch |e| switch (e) {
        error.OutOfMemory => {
            try stdout.print("Error, failed to allocate buffer size {d}", .{file_size});
            std.process.exit(74);
        },
    };

    _ = file.readAll(buffer) catch |e| {
        try stdout.print("Error when reading file {s}: {}", .{ path, e });
        std.process.exit(74);
    };

    _ = v.interpret(buffer, stdout) catch |e| switch (e) {
        error.CompilerError => std.process.exit(65),
        error.RuntimeError => std.process.exit(75),
        else => return e,
    };
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var v = vm.VM.init();
    defer v.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status != .ok) {
            std.debug.print("allocation deinit failure with {}\n", .{deinit_status});
        }
    }

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try switch (args.len) {
        1 => repl(&v, stdin, stdout, allocator),
        2 => runFile(args[1], &v, stdout, allocator),
        else => {
            try stdout.print("Usage: ziglox [path]\n", .{});
            std.process.exit(64);
        },
    };
}
