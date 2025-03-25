const std = @import("std");

const Allocator = std.mem.Allocator;
const Table = @import("table.zig").Table;
const Obj = @import("object.zig").Obj;

pub const LoxContext = struct {
    allocator: Allocator,
    objects: ?*Obj,
    strings: Table,

    pub fn init(allocator: Allocator) LoxContext {
        return LoxContext{
            .allocator = allocator,
            .objects = null,
            .strings = Table.init(allocator),
        };
    }

    pub fn deinit(self: *LoxContext) void {
        self.strings.deinit();
    }

    pub fn freeObjects(self: *LoxContext) void {
        var object = self.objects;

        while (object) |obj| {
            const next = obj.*.next;
            obj.destroy(self);
            object = next;
        }
    }
};