const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Value = @import("value.zig").Value;
const printValue = @import("value.zig").printValue;

pub const OpCode = enum(u8) {
    op_constant,
    op_nil,
    op_true,
    op_false,
    op_equal,
    op_greater,
    op_less,
    op_add,
    op_subtract,
    op_multiply,
    op_divide,
    op_not,
    op_negate,
    op_return,

    // TODO: update to format method
    pub fn asString(self: OpCode) []const u8 {
        return switch (self) {
            .op_constant => "OP_CONSTANT",
            .op_nil => "OP_NIL",
            .op_true => "OP_TRUE",
            .op_false => "OP_FALSE",
            .op_equal => "OP_EQUAL",
            .op_greater => "OP_GREATER",
            .op_less => "OP_LESS",
            .op_add => "OP_ADD",
            .op_subtract => "OP_SUBTRACT",
            .op_multiply => "OP_MULTIPLY",
            .op_divide => "OP_DIVIDE",
            .op_not => "OP_NOT",
            .op_negate => "OP_NEGATE",
            .op_return => "OP_RETURN",
        };
    }
};

pub const Chunk = struct {
    code: ArrayList(u8),
    constants: ArrayList(Value),
    lines: ArrayList(usize),

    pub fn init(allocator: Allocator) Chunk {
        return Chunk{
            .code = ArrayList(u8).init(allocator),
            .constants = ArrayList(Value).init(allocator),
            .lines = ArrayList(usize).init(allocator),
        };
    }

    pub fn deinit(self: *Chunk) void {
        self.code.deinit();
        self.constants.deinit();
        self.lines.deinit();
    }

    pub fn write(self: *Chunk, byte: u8, line: usize) !void {
        try self.code.append(byte);
        try self.lines.append(line);
    }

    pub fn writeOpCode(self: *Chunk, op: OpCode, line: usize) !void {
        try self.write(@intFromEnum(op), line);
    }

    pub fn addConstant(self: *Chunk, value: Value) !usize {
        try self.constants.append(value);
        return self.constants.items.len - 1;
    }

    pub fn disassemble(self: *Chunk, name: []const u8) void {
        // TODO: figure out how to hold Writer types in structs
        std.debug.print("=== {s} ===\n", .{name});

        var offset: usize = 0;
        while (offset < self.code.items.len) : (offset = self.disassembleInstruction(offset)) {}
    }

    pub fn disassembleInstruction(self: *Chunk, offset: usize) usize {
        // TODO: figure out how to hold Writer types in structs
        std.debug.print("{d:0>4} ", .{offset});

        const current_line = self.lines.items[offset];
        if (offset > 0 and current_line == self.lines.items[offset - 1]) {
            // TODO: figure out how to hold Writer types in structs
            std.debug.print("   | ", .{});
        } else {
            // TODO: figure out how to hold Writer types in structs
            std.debug.print("{d: >4} ", .{current_line});
        }

        const instruction = @as(OpCode, @enumFromInt(self.code.items[offset]));
        return switch (instruction) {
            .op_constant => blk: {
                const constant = self.code.items[offset + 1];
                // TODO: figure out how to hold Writer types in structs
                std.debug.print("{s: <16} {d: >4} ", .{ instruction.asString(), constant });
                printValue(self.constants.items[constant]);
                // TODO: figure out how to hold Writer types in structs
                std.debug.print("\n", .{});

                break :blk offset + 2;
            },
            .op_nil, .op_true, .op_false, .op_equal, .op_greater, .op_less, .op_add, .op_subtract, .op_multiply, .op_divide, .op_not, .op_negate, .op_return => blk: {
                // TODO: figure out how to hold Writer types in structs
                std.debug.print("{s}\n", .{instruction.asString()});

                break :blk offset + 1;
            },
        };
    }
};
