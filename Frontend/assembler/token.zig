// zig fmt: off

const Writer = @import("std").Io.Writer;
const eql = @import("std").mem.eql;

pub const TokenType = enum {
	EOL,
	NL, // \n
	FLOAT, // <float>
	COMMA, // ,
	STRING, // "<string>"
	CHAR, // '<char>'
	PLUS, // +
	MINUS, // -
	ASTERISK, // *
	DIVIDE, // /
	LPAREN, // (
	RPAREN, // )
	LSQBRACKET, // [
	RSQBRACKET, // ]
	LBRACKET, // {
	RBRACKET, // }
	IMM, // #<num>
	BITWISE_AND, // &
	BITWISE_OR, // |
	BITWISE_XOR, // ^
	BITWISE_NOT, // ~
	SHIFT_LEFT, // <<
	SHIFT_RIGHT, // >>
	REGISTER, // <reg>
	IDENTIFIER, // <identifier>
	LABEL, // <label>:
	INTEGER, // <num>
	LP, // @
	DIRECTIVE, // .<directive>
	UNKNOWN
};

pub const Token = struct {
	lexeme: []const u8,
	tokType: TokenType,

	pub fn format(self: *const Token, writer: *Writer) !void {
		try writer.writeAll("Token{ ");
		inline for (@typeInfo(Token).@"struct".fields) |field| {
			const value = @field(self, field.name);

			if (comptime eql(u8, field.name, "lexeme")) {
				try writer.print("{s}: \"{s}\", ", .{field.name, value});
			} else {
				try writer.print("{s}: {any} ", .{field.name, value});
			}
		}
		try writer.writeAll("}");
	}
};