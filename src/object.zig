const std = @import("std");
const Value = @import("value.zig").Value;
const LoxContext = @import("context.zig").LoxContext;

pub const ObjType = enum {
    String,
};

pub const Obj = struct {
    obj_type: ObjType,
    next: ?*Obj,

    pub fn allocate(ctx: *LoxContext, comptime T: type, obj_type: ObjType) *Obj {
        const ptr = ctx.allocator.create(T) catch {
            std.debug.print("OOME: can not allocate object", .{});
            std.process.exit(200);
        };

        ptr.obj = Obj{ .obj_type = obj_type, .next = ctx.objects };

        ctx.objects = &ptr.obj;

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

    pub fn destroy(self: *Obj, ctx: *LoxContext) void {
        switch (self.obj_type) {
            .String => {
                self.asString().destroy(ctx);
            },
        }
    }
};

pub const ObjString = struct {
    obj: Obj,
    chars: []const u8,

    pub fn create(ctx: *LoxContext, str: []const u8) *ObjString {
        const obj = Obj.allocate(ctx, ObjString, .String);
        const ret = obj.asString();

        ret.* = ObjString{ .obj = obj.*, .chars = str };

        return ret;
    }

    pub fn copy(ctx: *LoxContext, source: []const u8) *ObjString {
        const buffer = ctx.allocator.alloc(u8, source.len) catch {
            std.debug.print("OOME: can not allocate string", .{});
            std.process.exit(200);
        };
        std.mem.copyForwards(u8, buffer, source);
        return ObjString.create(ctx, buffer);
    }

    pub fn take(ctx: *LoxContext, source: []const u8) *ObjString {
        return ObjString.create(ctx, source);
    }

    pub fn destroy(self: *ObjString, ctx: *LoxContext) void {
        ctx.allocator.free(self.chars);
        ctx.allocator.destroy(self);
    }
};
