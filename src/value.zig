const std = @import("std");
pub const Value = union(enum) {
    bool: bool,
    nil,
    number: f64,

    pub inline fn fromBool(value: bool) Value {
        return Value{ .bool = value };
    }

    pub inline fn fromNumber(value: f64) Value {
        return Value{ .number = value };
    }

    pub inline fn isBool(self: Value) bool {
        return switch (self) {
            .bool => true,
            else => false,
        };
    }

    pub inline fn isNil(self: Value) bool {
        return switch (self) {
            .nil => true,
            else => false,
        };
    }

    pub inline fn isNumber(self: Value) bool {
        return switch (self) {
            .number => true,
            else => false,
        };
    }

    pub inline fn isFalsey(self: Value) bool {
        return self.isNil() or (self.isBool() and !self.bool);
    }

    pub inline fn equals(self: Value, other: Value) bool {
        return switch (self) {
            .bool => |l| switch (other) {
                .bool => |r| l == r,
                else => false,
            },
            .nil => switch (other) {
                .nil => true,
                else => false,
            },
            .number => |l| switch (other) {
                .number => |r| l == r,
                else => false,
            },
        };
    }
};

pub fn printValue(value: Value) void {
    switch (value) {
        .bool => |val| {
            std.debug.print("{}", .{val});
        },
        .nil => {
            std.debug.print("nil", .{});
        },
        .number => |val| {
            std.debug.print("{d}", .{val});
        },
    }
}
