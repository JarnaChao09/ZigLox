const std = @import("std");
const Value = @import("value.zig").Value;
const VM = @import("vm.zig").VM;

pub const ObjType = enum {
    String,
};

pub const Obj = struct {
    obj_type: ObjType,
    next: ?*Obj,

    pub fn allocate(vm: *VM, comptime T: type, obj_type: ObjType) *Obj {
        const ptr = vm.allocator.create(T) catch {
            std.debug.print("OOME: can not allocate object", .{});
            std.process.exit(200);
        };

        ptr.obj = Obj{ .obj_type = obj_type, .next = vm.objects };

        vm.objects = &ptr.obj;

        return &ptr.obj;
    }

    pub inline fn is(self: Obj, objtype: ObjType) bool {
        return switch (self.obj_type) {
            objtype => true,
            // else => false, // more will exist
        };
    }

    pub fn asString(self: *Obj) *ObjString {
        return @alignCast(@fieldParentPtr("obj", self));
    }

    pub fn asValue(self: *Obj) Value {
        return Value.fromObject(self);
    }

    pub fn destroy(self: *Obj, vm: *VM) void {
        switch (self.obj_type) {
            .String => {
                self.asString().destroy(vm);
            },
        }
    }
};

pub const ObjString = struct {
    obj: Obj,
    chars: []const u8,

    pub fn create(vm: *VM, str: []const u8) *ObjString {
        const obj = Obj.allocate(vm, ObjString, .String);
        const ret = obj.asString();

        ret.* = ObjString{ .obj = obj.*, .chars = str };

        return ret;
    }

    pub fn copy(vm: *VM, source: []const u8) *ObjString {
        const buffer = vm.allocator.alloc(u8, source.len) catch {
            std.debug.print("OOME: can not allocate string", .{});
            std.process.exit(200);
        };
        std.mem.copyForwards(u8, buffer, source);
        return ObjString.create(vm, buffer);
    }

    pub fn destroy(self: *ObjString, vm: *VM) void {
        vm.allocator.free(self.chars);
        vm.allocator.destroy(self);
    }
};
