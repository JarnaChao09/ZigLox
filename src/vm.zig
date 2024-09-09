const std = @import("std");
const Allocator = std.mem.Allocator;
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const printValue = @import("value.zig").printValue;
const compile = @import("compiler.zig").compile;
const ParserError = @import("compiler.zig").Parser.ParserError;

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
            var stack: [stack_max]Value = [_]Value{.nil} ** stack_max;
        };
        return VM{
            .chunk = undefined,
            .ip = undefined,
            .stack = static.stack,
            .stack_top = &static.stack,
        };
    }

    pub fn deinit(_: *VM) void {}

    pub fn interpret(self: *VM, source: []const u8, allocator: Allocator, stdout: anytype) (@TypeOf(stdout).Error || InterpreterResult || Allocator.Error || ParserError)!void {
        var chunk = Chunk.init(allocator);
        defer chunk.deinit();

        if (!(compile(source, &chunk, stdout) catch |err| blk: {
            try stdout.print("Error during compilation {}\n", .{err});
            break :blk false;
        })) {
            return InterpreterResult.CompilerError;
        }

        self.chunk = &chunk;
        self.ip = self.chunk.code.items.ptr;

        try self.run();
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

                const len = (@intFromPtr(self.stack_top) - @intFromPtr(&slot[0])) / @sizeOf(Value);

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
                .op_nil => {
                    self.push(Value{ .nil = undefined });
                },
                .op_true => {
                    self.push(Value.fromBool(true));
                },
                .op_false => {
                    self.push(Value.fromBool(false));
                },
                .op_equal => {
                    const b = self.pop();
                    (self.stack_top - 1)[0] = Value.fromBool(self.peek(0).equals(b));
                },
                .op_greater => {
                    if (!self.peek(0).isNumber() or !self.peek(1).isNumber()) {
                        self.runtimeErr("Operands must be numbers.", .{});
                        return InterpreterResult.RuntimeError;
                    }

                    const b = self.pop().number;
                    const a = self.pop().number;
                    self.push(Value.fromBool(a > b));
                },
                .op_less => {
                    if (!self.peek(0).isNumber() or !self.peek(1).isNumber()) {
                        self.runtimeErr("Operands must be numbers.", .{});
                        return InterpreterResult.RuntimeError;
                    }

                    const b = self.pop().number;
                    const a = self.pop().number;
                    self.push(Value.fromBool(a < b));
                },
                .op_add => {
                    if (!self.peek(0).isNumber() or !self.peek(1).isNumber()) {
                        self.runtimeErr("Operands must be numbers.", .{});
                        return InterpreterResult.RuntimeError;
                    }

                    (self.stack_top - 2)[0].number += self.pop().number;
                },
                .op_subtract => {
                    if (!self.peek(0).isNumber() or !self.peek(1).isNumber()) {
                        self.runtimeErr("Operands must be numbers.", .{});
                        return InterpreterResult.RuntimeError;
                    }

                    (self.stack_top - 2)[0].number -= self.pop().number;
                },
                .op_multiply => {
                    if (!self.peek(0).isNumber() or !self.peek(1).isNumber()) {
                        self.runtimeErr("Operands must be numbers.", .{});
                        return InterpreterResult.RuntimeError;
                    }

                    (self.stack_top - 2)[0].number *= self.pop().number;
                },
                .op_divide => {
                    if (!self.peek(0).isNumber() or !self.peek(1).isNumber()) {
                        self.runtimeErr("Operands must be numbers.", .{});
                        return InterpreterResult.RuntimeError;
                    }

                    (self.stack_top - 2)[0].number /= self.pop().number;
                },
                .op_not => {
                    (self.stack_top - 1)[0] = Value.fromBool(self.peek(0).isFalsey());
                },
                .op_negate => {
                    switch (self.peek(0)) {
                        .number => |val| (self.stack_top - 1)[0].number = -val,
                        else => {
                            self.runtimeErr("Operand must be a number.", .{});
                            return InterpreterResult.RuntimeError;
                        },
                    }
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

    fn runtimeErr(self: *VM, comptime fmt: []const u8, args: anytype) void {
        // TODO: figure out how to hold Writer types in structs

        std.debug.print(fmt, args);

        const instruction = @intFromPtr(self.ip) - @intFromPtr(self.chunk.code.items.ptr) - 1;
        std.debug.print("\n[line {d}] in script\n", .{self.chunk.lines.items[instruction]});
        self.resetStack();
    }

    fn push(self: *VM, value: Value) void {
        self.stack_top[0] = value;
        self.stack_top += 1;
    }

    fn pop(self: *VM) Value {
        self.stack_top -= 1;
        return self.stack_top[0];
    }

    fn peek(self: *VM, distance: usize) Value {
        return (self.stack_top - 1 - distance)[0];
    }

    // fn printStackDetails(self: VM) void {
    //     std.debug.print("stack_top {d}\n", .{@intFromPtr(&self.stack_top[0])});
    //     std.debug.print("stack bottom {d}\n", .{@intFromPtr(&self.stack[0])});
    // }
};
