const std = @import("std");
const Allocator = std.mem.Allocator;
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const printValue = @import("value.zig").printValue;
const compile = @import("compiler.zig").compile;

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

    pub fn interpret(_: *VM, source: []const u8, stdout: anytype) (@TypeOf(stdout).Error || InterpreterResult)!void {
        try compile(source, stdout);
    }

    fn run(self: *VM) InterpreterResult!void {
        // required to make debug tracing work
        // &self.stack[0] != self.stack_top for some reason unless we call reset stack here
        // potentially this is because arrays are copied...?
        // resetting the stack inside the init function also leads to different pointer values
        // so resetting the stack in init does not seem to be an option
        self.resetStack();

        while (true) {
            if (comptime debug_trace_execution) {
                std.debug.print("        > ", .{});

                var slot: [*]Value = &self.stack;

                const len = (@intFromPtr(self.stack_top) - @intFromPtr(&slot[0])) / @sizeOf(f64);

                var count: usize = 0;
                while (count < len) : ({
                    slot += 1;
                    count += 1;
                }) {
                    std.debug.print("[ ", .{});
                    printValue(slot[0]);
                    std.debug.print(" ]", .{});
                }
                std.debug.print("\n", .{});

                _ = self.chunk.disassembleInstruction(@intFromPtr(self.ip) - @intFromPtr(self.chunk.code.items.ptr));
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

    // fn printStackDetails(self: VM) void {
    //     std.debug.print("stack_top {d}\n", .{@intFromPtr(&self.stack_top[0])});
    //     std.debug.print("stack bottom {d}\n", .{@intFromPtr(&self.stack[0])});
    // }
};
