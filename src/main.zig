const std = @import("std");
const chunk = @import("chunk.zig");

pub fn main() !void {
    var c = chunk.Chunk.init(std.heap.page_allocator);
    defer c.deinit();

    const constant = try c.addConstant(1.2);
    try c.writeOpCode(.op_constant, 123);
    try c.write(constant, 123);

    try c.writeOpCode(.op_return, 123);

    c.disassemble("test chunk");
}
