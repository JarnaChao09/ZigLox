const std = @import("std");
const Allocator = std.mem.Allocator;
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Scanner = @import("scanner.zig").Scanner;
const Value = @import("value.zig").Value;

const debug_print_code = false;

const Precedence = enum(u8) {
    prec_none,
    prec_assignment,
    prec_or,
    prec_and,
    prec_equality,
    prec_comparison,
    prec_term,
    prec_factor,
    prec_unary,
    prec_call,
    prec_primary,
};

const ParseRule = struct { prefix: ?*const fn (*Parser) Parser.ParserError!void, infix: ?*const fn (*Parser) Parser.ParserError!void, precedence: Precedence };

pub const Parser = struct {
    pub const ParserError = (std.mem.Allocator.Error || std.fmt.ParseFloatError);

    const rules = std.EnumArray(TokenType, ParseRule).init(.{
        .left_paren = ParseRule{ .prefix = &Parser.grouping, .infix = null, .precedence = .prec_none },
        .right_paren = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .left_brace = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .right_brace = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .comma = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .dot = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .minus = ParseRule{ .prefix = &Parser.unary, .infix = &Parser.binary, .precedence = .prec_term },
        .plus = ParseRule{ .prefix = null, .infix = &Parser.binary, .precedence = .prec_term },
        .semicolon = ParseRule{ .prefix = null, .infix = undefined, .precedence = .prec_none },
        .slash = ParseRule{ .prefix = null, .infix = &Parser.binary, .precedence = .prec_factor },
        .star = ParseRule{ .prefix = null, .infix = &Parser.binary, .precedence = .prec_factor },
        .bang = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .bang_equal = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .equal = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .equal_equal = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .greater = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .greater_equal = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .less = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .less_equal = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .identifier = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .string = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .number = ParseRule{ .prefix = &Parser.number, .infix = null, .precedence = .prec_none },
        .tk_and = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .class = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .tk_else = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .tk_false = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .tk_for = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .fun = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .tk_if = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .nil = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .tk_or = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .print = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .tk_return = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .super = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .this = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .tk_true = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .tk_var = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .tk_while = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .tk_error = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
        .eof = ParseRule{ .prefix = null, .infix = null, .precedence = .prec_none },
    });

    current: Token,
    previous: Token,
    hadError: bool,
    panicMode: bool,
    chunk: *Chunk,
    scanner: *Scanner,
    // TODO: figure out how to hold Writer types in structs
    // errorWriter: std.io.AnyWriter,

    pub fn init(scanner: *Scanner, chunk: *Chunk) Parser {
        return Parser{
            .current = undefined,
            .previous = undefined,
            .hadError = false,
            .panicMode = false,
            .chunk = chunk,
            .scanner = scanner,
        };
    }

    fn advance(self: *Parser) void {
        self.previous = self.current;

        while (true) {
            self.current = self.scanner.scanToken();

            if (self.current.type != .tk_error) {
                break;
            }

            self.errorAtCurrent(self.current.start[0..self.current.len]);
        }
    }

    fn errorAtCurrent(self: *Parser, message: []const u8) void {
        self.errorAt(self.current, message);
    }

    // error is a taken keyword
    fn err(self: *Parser, message: []const u8) void {
        self.errorAt(self.previous, message);
    }

    fn errorAt(self: *Parser, token: Token, message: []const u8) void {
        if (self.panicMode) {
            return;
        }
        self.panicMode = true;

        // TODO: figure out how to hold Writer types in structs
        // try self.errorWriter.print("[line {d}] Error", .{token.line});
        std.debug.print("[line {d}] Error", .{token.line});

        if (token.type == .eof) {
            // TODO: figure out how to hold Writer types in structs
            // try self.errorWriter.print(" at end", .{});
            std.debug.print(" at end", .{});
        } else if (token.type == .tk_error) {
            // nothing
        } else {
            // TODO: figure out how to hold Writer types in structs
            // try self.errorWriter.print(" at '{s}'", .{token.start[0..token.len]});
            std.debug.print(" at '{s}'", .{token.start[0..token.len]});
        }

        // TODO: figure out how to hold Writer types in structs
        // try self.errorWriter.print(": {s}\n", .{message});
        std.debug.print(": {s}\n", .{message});
        self.hadError = true;
    }

    fn consume(self: *Parser, ttype: TokenType, message: []const u8) void {
        if (self.current.type == ttype) {
            self.advance();
            return;
        }

        self.errorAtCurrent(message);
    }

    fn emitByte(self: *Parser, byte: u8) ParserError!void {
        try self.chunk.write(byte, self.previous.line);
    }

    fn emitBytes(self: *Parser, byte1: u8, byte2: u8) ParserError!void {
        try self.emitByte(byte1);
        try self.emitByte(byte2);
    }

    fn emitOpCode(self: *Parser, op: OpCode) ParserError!void {
        try self.chunk.writeOpCode(op, self.previous.line);
    }

    fn emitReturn(self: *Parser) ParserError!void {
        try self.emitOpCode(.op_return);
    }

    fn makeConstant(self: *Parser, value: Value) ParserError!u8 {
        const constant = try self.chunk.addConstant(value);
        if (constant > std.math.maxInt(u8)) {
            self.err("Too many constants in one chunk.");
            return 0;
        }

        return @intCast(constant);
    }

    fn emitConstant(self: *Parser, value: Value) ParserError!void {
        try self.emitBytes(@intFromEnum(OpCode.op_constant), try self.makeConstant(value));
    }

    fn endCompiler(self: *Parser) ParserError!void {
        try self.emitReturn();

        if (comptime debug_print_code) {
            if (!self.hadError) {
                self.chunk.disassemble("code");
            }
        }
    }

    fn grouping(self: *Parser) ParserError!void {
        try self.expression();
        self.consume(.right_paren, "Expect ')' after expression.");
    }

    fn expression(self: *Parser) ParserError!void {
        try self.parsePrecedence(@intFromEnum(Precedence.prec_assignment));
    }

    fn number(self: *Parser) ParserError!void {
        const value: Value = try std.fmt.parseFloat(Value, self.previous.start[0..self.previous.len]);
        try self.emitConstant(value);
    }

    fn unary(self: *Parser) ParserError!void {
        const operator_type = self.previous.type;

        try self.parsePrecedence(@intFromEnum(Precedence.prec_unary));

        try switch (operator_type) {
            .minus => self.emitOpCode(.op_negate),
            else => unreachable,
        };
    }

    fn binary(self: *Parser) ParserError!void {
        const operator_type = self.previous.type;
        const rule = getRule(operator_type);
        try self.parsePrecedence(@intFromEnum(rule.precedence) + 1);

        try switch (operator_type) {
            .plus => self.emitOpCode(.op_add),
            .minus => self.emitOpCode(.op_subtract),
            .star => self.emitOpCode(.op_multiply),
            .slash => self.emitOpCode(.op_divide),
            else => unreachable,
        };
    }

    fn parsePrecedence(self: *Parser, precedence: u8) !void {
        self.advance();

        const prefixRule = getRule(self.previous.type).prefix;

        if (prefixRule == null) {
            self.err("Expect expression.");
            return;
        }

        try prefixRule.?(self);

        while (precedence <= @intFromEnum(getRule(self.current.type).precedence)) {
            self.advance();

            const infixRule = getRule(self.previous.type).infix;
            try infixRule.?(self);
        }
    }

    fn getRule(ttype: TokenType) ParseRule {
        return rules.get(ttype);
    }
};

pub fn compile(source: []const u8, chunk: *Chunk, stdout: anytype) (@TypeOf(stdout).Error || Parser.ParserError)!bool {
    var scanner = Scanner.init(source);

    var parser = Parser.init(&scanner, chunk);

    parser.advance();
    try parser.expression();
    parser.consume(.eof, "Expected end of expression.");
    try parser.endCompiler();

    return !parser.hadError;
}
