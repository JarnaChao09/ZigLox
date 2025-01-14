const std = @import("std");
const Obj = @import("object.zig").Obj;
const ObjType = @import("object.zig").ObjType;

pub const Value = union(enum) {
    bool: bool,
    nil,
    number: f64,
    object: *Obj,

    pub inline fn fromBool(value: bool) Value {
        return Value{ .bool = value };
    }

    pub inline fn fromNumber(value: f64) Value {
        return Value{ .number = value };
    }

    pub inline fn fromObject(value: *Obj) Value {
        return Value{ .object = value };
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

    pub inline fn isObject(self: Value, objtype: ObjType) bool {
        return switch (self) {
            .object => self.object.*.is(objtype),
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
            .object => |l| switch (other) {
                .object => |r| blk: {
                    const a_string = l.asString().chars;
                    const b_string = r.asString().chars;

                    break :blk a_string.len == b_string.len and std.mem.eql(u8, a_string, b_string);
                },
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
        .object => |object| switch (object.obj_type) {
            .String => {
                std.debug.print("{s}", .{object.asString().chars});
            },
        },
    }
}
