const std = @import("std");

pub const Token = struct {
    type: TokenType,
    start: [*]const u8,
    len: usize,
    line: usize,

    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{} {s}", .{ self.type, self.start[0..self.len] });
    }
};

pub const TokenType = enum(u8) {
    left_paren,
    right_paren,
    left_brace,
    right_brace,
    comma,
    dot,
    minus,
    plus,
    semicolon,
    slash,
    star,

    bang,
    bang_equal,
    equal,
    equal_equal,
    greater,
    greater_equal,
    less,
    less_equal,

    identifier,
    string,
    number,

    tk_and,
    class,
    tk_else,
    tk_false,
    tk_for,
    fun,
    tk_if,
    nil,
    tk_or,
    print,
    tk_return,
    super,
    this,
    tk_true,
    tk_var,
    tk_while,

    tk_error,
    eof,
};
