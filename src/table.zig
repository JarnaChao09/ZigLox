const std = @import("std");

const Allocator = std.mem.Allocator;
const HashMap = std.hash_map.HashMap;
const ObjString = @import("object.zig").ObjString;
const Value = @import("value.zig").Value;

const max_table_load = 75;

pub const Table = struct {
    const Map = HashMap(*ObjString, Value, TableCtx, max_table_load);

    backing_map: Map,

    const TableCtx = struct {
        pub fn hash(_: TableCtx, key: *ObjString) u64 {
            return key.*.hash;
        }

        pub fn eql(_: TableCtx, key_a: *ObjString, key_b: *ObjString) bool {
            return key_a.*.hash == key_b.*.hash and std.mem.eql(u8, key_a.*.chars, key_b.*.chars);
        }
    };

    pub fn init(allocator: Allocator) Table {
        return Table{
            .backing_map = Map.init(allocator),
        };
    }

    pub fn deinit(self: *Table) void {
        self.backing_map.deinit();
    }

    const AdaptedCtx = struct {
        captured_chars: []const u8,
        captured_hash: u32,

        pub fn init(chars: []const u8, chars_hash: u32) AdaptedCtx {
            return AdaptedCtx{
                .captured_chars = chars,
                .captured_hash = chars_hash,
            };
        }

        pub fn hash(self: AdaptedCtx, _: @TypeOf(void)) u64 {
            return self.captured_hash;
        }

        pub fn eql(self: AdaptedCtx, _: @TypeOf(void), key: *ObjString) bool {
            return self.captured_hash == key.*.hash and std.mem.eql(u8, self.captured_chars, key.*.chars);
        }
    };

    pub fn findString(self: *Table, chars: []const u8, chars_hash: u32) ?*ObjString {
        return self.backing_map.getKeyAdapted(void, AdaptedCtx.init(chars, chars_hash));
    }

    pub fn set(self: *Table, key: *ObjString, value: Value) bool {
        return if (self.backing_map.fetchPut(key, value) catch {
            std.debug.print("Table: can't put key into table", .{});
            std.process.exit(205);
        }) |_| false else true;
    }

    pub fn get(self: *Table, key: *ObjString) ?Value {
        return self.backing_map.get(key);
    }

    pub fn delete(self: *Table, key: *ObjString) bool {
        return self.backing_map.remove(key);
    }
};
