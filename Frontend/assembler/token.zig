// zig fmt: off

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
	tokType: TokenType
};