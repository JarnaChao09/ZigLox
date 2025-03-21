const std = @import("std");

const Allocator = std.mem.Allocator;
const Obj = @import("object.zig").Obj;

pub const LoxContext = struct {
    allocator: Allocator,
    objects: ?*Obj,

    pub fn init(allocator: Allocator) LoxContext {
        return LoxContext{
            .allocator = allocator,
            .objects = null,
        };
    }

    pub fn deinit(_: *LoxContext) void {}

    pub fn freeObjects(self: *LoxContext) void {
        var object = self.objects;

        while (object) |obj| {
            const next = obj.*.next;
            obj.destroy(self);
            object = next;
        }
    }
};