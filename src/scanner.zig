const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;

pub const Scanner = struct {
    start: [*]const u8,
    current: [*]const u8,
    line: usize,

    pub fn init(source: []const u8) Scanner {
        return Scanner{
            .start = source.ptr,
            .current = source.ptr,
            .line = 1,
        };
    }

    pub fn deinit(_: *Scanner) void {}

    pub fn scanToken(self: *Scanner) Token {
        self.skipWhitespace();

        self.start = self.current;

        if (self.isAtEnd(0)) {
            return self.makeToken(.eof);
        }

        const c = self.advance();

        return switch (c) {
            '(' => self.makeToken(.left_paren),
            ')' => self.makeToken(.right_paren),
            '{' => self.makeToken(.left_brace),
            '}' => self.makeToken(.right_brace),
            ';' => self.makeToken(.semicolon),
            ',' => self.makeToken(.comma),
            '.' => self.makeToken(.dot),
            '-' => self.makeToken(.minus),
            '+' => self.makeToken(.plus),
            '/' => self.makeToken(.slash),
            '*' => self.makeToken(.star),
            '!' => self.makeToken(if (self.match('=')) .bang_equal else .bang),
            '=' => self.makeToken(if (self.match('=')) .equal_equal else .equal),
            '<' => self.makeToken(if (self.match('=')) .less_equal else .less),
            '>' => self.makeToken(if (self.match('=')) .greater_equal else .greater),
            '"' => self.string(),
            '0'...'9' => self.number(),
            'a'...'z', 'A'...'Z', '_' => self.identifier(),
            else => blk: {
                break :blk self.errorToken("Unexpected character.");
            },
        };
    }

    fn skipWhitespace(self: *Scanner) void {
        while (true) {
            switch (self.peek(0)) {
                ' ', '\r', '\t' => {
                    _ = self.advance();
                },
                '\n' => {
                    self.line += 1;
                    _ = self.advance();
                },
                '/' => {
                    if (self.peek(1) == '/') {
                        while (self.peek(0) != '\n' and !self.isAtEnd(0)) : (_ = self.advance()) {}
                    } else {
                        return;
                    }
                },
                else => return,
            }
        }
    }

    fn string(self: *Scanner) Token {
        while (self.peek(0) != '"' and !self.isAtEnd(0)) : (_ = self.advance()) {
            if (self.peek(0) == '\n') {
                self.line += 1;
            }
        }

        if (self.isAtEnd(0)) {
            return self.errorToken("Unterminated string.");
        }

        _ = self.advance();

        return self.makeToken(.string);
    }

    fn number(self: *Scanner) Token {
        while (isDigit(self.peek(0))) : (_ = self.advance()) {}

        if (self.peek(0) == '.' and isDigit(self.peek(1))) {
            _ = self.advance();

            while (isDigit(self.peek(0))) : (_ = self.advance()) {}
        }

        return self.makeToken(.number);
    }

    fn identifier(self: *Scanner) Token {
        while (isAlpha(self.peek(0)) or isDigit(self.peek(0))) : (_ = self.advance()) {}

        return self.makeToken(self.identifierType());
    }

    fn identifierType(self: *Scanner) TokenType {
        return switch (self.start[0]) {
            'a' => self.checkKeyword(1, "nd", .tk_and),
            'c' => self.checkKeyword(1, "lass", .class),
            'e' => self.checkKeyword(1, "lse", .tk_else),
            'i' => self.checkKeyword(1, "f", .tk_if),
            'n' => self.checkKeyword(1, "il", .nil),
            'o' => self.checkKeyword(1, "r", .tk_or),
            'p' => self.checkKeyword(1, "rint", .print),
            'r' => self.checkKeyword(1, "eturn", .tk_return),
            's' => self.checkKeyword(1, "uper", .super),
            'v' => self.checkKeyword(1, "ar", .tk_var),
            'w' => self.checkKeyword(2, "hile", .tk_while),
            'f' => blk: {
                if (@intFromPtr(self.current) - @intFromPtr(self.start) > 1) {
                    break :blk switch (self.start[1]) {
                        'a' => self.checkKeyword(2, "lse", .tk_false),
                        'o' => self.checkKeyword(2, "r", .tk_for),
                        'u' => self.checkKeyword(2, "n", .fun),
                        else => .identifier,
                    };
                } else {
                    break :blk .identifier;
                }
            },
            't' => blk: {
                if (@intFromPtr(self.current) - @intFromPtr(self.start) > 1) {
                    break :blk switch (self.start[1]) {
                        'h' => self.checkKeyword(2, "is", .this),
                        'r' => self.checkKeyword(2, "ue", .tk_true),
                        else => .identifier,
                    };
                } else {
                    break :blk .identifier;
                }
            },
            else => .identifier,
        };
    }

    fn checkKeyword(self: Scanner, start: usize, rest: []const u8, token_type: TokenType) TokenType {
        if ((@intFromPtr(self.current) - @intFromPtr(self.start) == start + rest.len) and std.mem.eql(u8, self.start[start .. rest.len + 1], rest)) {
            return token_type;
        }

        return .identifier;
    }

    fn isDigit(c: u8) bool {
        return switch (c) {
            '0'...'9' => true,
            else => false,
        };
    }

    fn isAlpha(c: u8) bool {
        return switch (c) {
            'a'...'z', 'A'...'Z', '_' => true,
            else => false,
        };
    }

    fn isAtEnd(self: Scanner, distance: usize) bool {
        return self.start[distance] == '\x00';
    }

    fn makeToken(self: Scanner, token_type: TokenType) Token {
        return Token{
            .start = self.start,
            .type = token_type,
            .len = @intFromPtr(self.current) - @intFromPtr(self.start),
            .line = self.line,
        };
    }

    fn errorToken(self: Scanner, message: []const u8) Token {
        return Token{
            .type = .tk_error,
            .start = message.ptr,
            .len = message.len,
            .line = self.line,
        };
    }

    fn advance(self: *Scanner) u8 {
        self.current += 1;
        return (self.current - 1)[0];
    }

    fn peek(self: *Scanner, distance: usize) u8 {
        if (self.isAtEnd(distance)) {
            return '\x00';
        }

        return self.current[distance];
    }

    fn match(self: *Scanner, expected: u8) bool {
        if (self.isAtEnd(0)) {
            return false;
        }

        if (self.current[0] != expected) {
            return false;
        }

        self.current += 1;
        return true;
    }
};
