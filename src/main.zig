const std = @import("std");
const chunk = @import("chunk.zig");
const vm = @import("vm.zig");

pub fn main() !void {
    var c = chunk.Chunk.init(std.heap.page_allocator);
    defer c.deinit();

    const constant1 = try c.addConstant(1.2);
    try c.writeOpCode(.op_constant, 123);
    try c.write(constant1, 123);

    const constant2 = try c.addConstant(3.4);
    try c.writeOpCode(.op_constant, 123);
    try c.write(constant2, 123);

    try c.writeOpCode(.op_add, 123);

    const constant3 = try c.addConstant(5.6);
    try c.writeOpCode(.op_constant, 123);
    try c.write(constant3, 123);

    try c.writeOpCode(.op_divide, 123);

    try c.writeOpCode(.op_negate, 123);

    try c.writeOpCode(.op_return, 123);

    c.disassemble("test chunk");

    var v = vm.VM.init();
    defer v.deinit();

    try v.interpret(&c);
}
