const std = @import("std");
const library = @import("library.zig");
const Node = library.Node;
const Unit = library.Unit;
const Entry = library.Entry;

const Token = union(enum) {
    Literal: []const u8,
    Comma,
    Colon,
    OpenBracket,
    CloseBracket,
};

pub const Parser = struct {
    lexer: Lexer,
    allocator: std.mem.Allocator,
    tree: Node,

    pub fn parse(allocator: std.mem.Allocator, input: []const u8) !Parser {
        var parser = Parser{
            .lexer = try Lexer.tokenize(allocator, input),
            .allocator = allocator,
            .tree = undefined,
        };

        parser.tree = try parser.parseKV();

        return parser;
    }

    pub fn deinit_no_tree(parser: *Parser) void {
        parser.lexer.deinit();
    }

    pub fn deinit(parser: *Parser) void {
        parser.deinit_no_tree();

        parser.tree.deinit();
    }

    fn expect(parser: *Parser, token: Token) !void {
        const actual = parser.lexer.tokens.items[0];
        std.debug.assert(std.mem.startsWith(u8, @tagName(actual), @tagName(token)));
    }

    fn pop(parser: *Parser) Token {
        return parser.lexer.tokens.orderedRemove(0);
    }

    fn peek(parser: *Parser) Token {
        return parser.lexer.tokens.items[0];
    }

    fn parseKV(parser: *Parser) !Node {
        try parser.expect(Token{ .Literal = "" });

        const name = parser.pop();
        defer parser.allocator.free(name.Literal);

        try parser.expect(.Colon);
        _ = parser.pop();

        if (parser.peek() == .OpenBracket) {
            _ = parser.pop();

            var node = Node{
                .Unit = try Unit.init(parser.allocator, name.Literal),
            };

            while (true) {
                if (parser.peek() == .CloseBracket) {
                    _ = parser.pop();
                    break;
                }

                const child = try parser.parseKV();
                try node.Unit.children.append(child);
            }

            try parser.expect(.Comma);
            _ = parser.pop();

            return node;
        } else {
            try parser.expect(Token{ .Literal = "" });

            const value_string = parser.pop();
            defer parser.allocator.free(value_string.Literal);

            const value = try std.fmt.parseUnsigned(u64, value_string.Literal, 16);

            try parser.expect(.Comma);
            _ = parser.pop();

            return Node{
                .Entry = try Entry.init(parser.allocator, name.Literal, value),
            };
        }
    }
};

const Lexer = struct {
    allocator: std.mem.Allocator,
    tokens: std.ArrayList(Token),

    pub fn tokenize(allocator: std.mem.Allocator, input: []const u8) !Lexer {
        var tokens = std.ArrayList(Token).init(allocator);

        var i: usize = 0;
        while (i < input.len) {
            const ch = input[i];

            switch (ch) {
                '[' => {
                    try tokens.append(.OpenBracket);
                    i += 1;
                },
                ']' => {
                    try tokens.append(.CloseBracket);
                    i += 1;
                },
                ':' => {
                    try tokens.append(.Colon);
                    i += 1;
                },
                ',' => {
                    try tokens.append(.Comma);
                    i += 1;
                },
                else => {
                    const start = i;
                    while (i < input.len and input[i] != ':' and input[i] != ',' and input[i] != '[' and input[i] != ']') {
                        i += 1;
                    }

                    const literal = try allocator.dupe(u8, input[start..i]);
                    const token = Token{ .Literal = literal };

                    try tokens.append(token);
                },
            }
        }

        return .{
            .allocator = allocator,
            .tokens = tokens,
        };
    }

    pub fn deinit(self: *Lexer) void {
        for (self.tokens.items) |token| {
            switch (token) {
                .Literal => |literal| {
                    self.allocator.free(literal);
                },
                else => {},
            }
        }

        self.tokens.deinit();
    }
};

test "tokenizes correctly" {
    const allocator = std.testing.allocator;

    const input = "root:[a:1,b:2,],";
    const expected: [13]Token = .{
        Token{ .Literal = "root" },
        Token{ .Colon = {} },
        Token{ .OpenBracket = {} },
        Token{ .Literal = "a" },
        Token{ .Colon = {} },
        Token{ .Literal = "1" },
        Token{ .Comma = {} },
        Token{ .Literal = "b" },
        Token{ .Colon = {} },
        Token{ .Literal = "2" },
        Token{ .Comma = {} },
        Token{ .CloseBracket = {} },
        Token{ .Comma = {} },
    };

    var lexer = try Lexer.tokenize(allocator, input);
    defer lexer.deinit();
    const tokens = lexer.tokens;

    try std.testing.expectEqual(expected.len, tokens.items.len);

    for (expected, tokens.items) |exp_tok, actual_tok| {
        try std.testing.expectEqual(@tagName(exp_tok), @tagName(actual_tok));

        if (exp_tok == .Literal and actual_tok == .Literal) {
            try std.testing.expectEqualStrings(exp_tok.Literal, actual_tok.Literal);
        }
    }
}
