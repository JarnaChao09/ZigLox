const std = @import("std");
const Allocator = std.mem.Allocator;
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const printValue = @import("value.zig").printValue;

const debug_trace_execution = false;
const stack_max = 256;

pub const InterpreterResult = error{
    CompilerError,
    RuntimeError,
};

pub const VM = struct {
    chunk: *Chunk,
    ip: [*]u8,
    stack: [stack_max]Value,
    stack_top: [*]Value,

    pub fn init() VM {
        const static = struct {
            var stack: [stack_max]Value = [_]Value{0.0} ** stack_max;
        };
        return VM{
            .chunk = undefined,
            .ip = undefined,
            .stack = static.stack,
            .stack_top = &static.stack,
        };
    }

    pub fn deinit(_: *VM) void {}

    pub fn interpret(self: *VM, chunk: *Chunk) InterpreterResult!void {
        self.chunk = chunk;
        self.ip = chunk.code.items.ptr;

        try self.run();
    }

    fn run(self: *VM) InterpreterResult!void {
        while (true) {
            if (comptime debug_trace_execution) {
                std.debug.print("          ", .{});

                var slot = &self.stack;

                while (slot < self.stack_top) : (slot += 1) {
                    std.debug.print("[ ", .{});
                    printValue(slot.*);
                    std.debug.print(" ]", .{});
                }

                self.chunk.disassembleInstruction(self.ip - &self.chunk.code.items);
            }

            const instruction = @as(OpCode, @enumFromInt(self.readByte()));

            switch (instruction) {
                .op_constant => {
                    const constant = self.readConstant();
                    self.push(constant);
                },
                .op_negate => {
                    self.push(-self.pop());
                },
                .op_add => {
                    (self.stack_top - 2)[0] += self.pop();
                },
                .op_subtract => {
                    (self.stack_top - 2)[0] -= self.pop();
                },
                .op_multiply => {
                    (self.stack_top - 2)[0] *= self.pop();
                },
                .op_divide => {
                    (self.stack_top - 2)[0] /= self.pop();
                },
                .op_return => {
                    printValue(self.pop());
                    std.debug.print("\n", .{});
                    return;
                },
            }
        }
    }

    inline fn readByte(self: *VM) u8 {
        const instruction = self.ip[0];
        self.ip += 1;

        return instruction;
    }

    inline fn readConstant(self: *VM) Value {
        const index = self.readByte();

        return self.chunk.constants.items[index];
    }

    fn resetStack(self: *VM) void {
        self.stack_top = &self.stack;
    }

    fn push(self: *VM, value: Value) void {
        self.stack_top[0] = value;
        self.stack_top += 1;
    }

    fn pop(self: *VM) Value {
        self.stack_top -= 1;
        return self.stack_top[0];
    }
};
