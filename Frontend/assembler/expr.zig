const std = @import("std");
const Token = @import("token.zig");

pub const ExprError = error { 
	InvalidExpression
};

pub const ExprSize = enum { 
	U14, S9, S24, S19,
	U8, U16, U32
};

const TokenParser = struct {
	toks: []const Token.Token,
	i: usize,

	fn peekType(self: *TokenParser) Token.TokenType {
		if (self.i >= self.toks.len) return .UNKNOWN;
		return self.toks[self.i].tokType;
	}

	fn consumeType(self: *TokenParser, t: Token.TokenType) bool {
		if (self.i < self.toks.len and self.toks[self.i].tokType == t) {
			self.i += 1;
			return true;
		}
		return false;
	}

	fn parseExpr(self: *TokenParser) ExprError!u64 {
		return self.parseOr();
	}

	fn parseOr(self: *TokenParser) ExprError!u64 {
		var left = try self.parseXor();
		while (true) {
			if (self.consumeType(.BITWISE_OR)) {
				const right = try self.parseXor();
				left = left | right;
			} else break;
		}
		return left;
	}

	fn parseXor(self: *TokenParser) ExprError!u64 {
		var left = try self.parseAnd();
		while (true) {
			if (self.consumeType(.BITWISE_XOR)) {
				const right = try self.parseAnd();
				left = left ^ right;
			} else break;
		}
		return left;
	}

	fn parseAnd(self: *TokenParser) ExprError!u64 {
		var left = try self.parseShift();
		while (true) {
			if (self.consumeType(.BITWISE_AND)) {
				const right = try self.parseShift();
				left = left & right;
			} else break;
		}
		return left;
	}

	fn parseShift(self: *TokenParser) ExprError!u64 {
		var left = try self.parseAddSub();
		while (true) {
			if (self.consumeType(.SHIFT_LEFT)) {
				const right = try self.parseAddSub();
				if (right >= 64) { left = 0; }
				else {
					var res: u64 = left;
					const cnt = @as(usize, right);
					var j: usize = 0;
					while (j < cnt) {
						const mm = @mulWithOverflow(res, 2);
						res = mm[0];
						j += 1;
					}
					left = res;
				}
			} else if (self.consumeType(.SHIFT_RIGHT)) {
				const right = try self.parseAddSub();
				if (right >= 64) { left = 0; }
				else {
					var res: u64 = left;
					const cnt = @as(usize, right);
					var j: usize = 0;
					while (j < cnt) {
						res = res / 2;
						j += 1;
					}
					left = res;
				}
			} else break;
		}
		return left;
	}

	fn parseAddSub(self: *TokenParser) ExprError!u64 {
		var left = try self.parseMulDiv();
		while (true) {
			if (self.consumeType(.PLUS)) {
				const right = try self.parseMulDiv();
				const addres = @addWithOverflow(left, right);
				left = addres[0];
			} else if (self.consumeType(.MINUS)) {
				const right = try self.parseMulDiv();
				const subres = @subWithOverflow(left, right);
				left = subres[0];
			} else break;
		}
		return left;
	}

	fn parseMulDiv(self: *TokenParser) ExprError!u64 {
		var left = try self.parseUnary();
		while (true) {
			if (self.consumeType(.ASTERISK)) {
				const right = try self.parseUnary();
				const mulres = @mulWithOverflow(left, right);
				left = mulres[0];
			} else if (self.consumeType(.DIVIDE)) {
				const right = try self.parseUnary();
				if (right == 0) return ExprError.InvalidExpression;
				left = left / right;
			} else break;
		}
		return left;
	}

	fn parseUnary(self: *TokenParser) ExprError!u64 {
		if (self.consumeType(.PLUS)) return self.parseUnary();
		if (self.consumeType(.MINUS)) {
			const v = try self.parseUnary();
			const subres = @subWithOverflow(@as(u64, 0), v);
			return subres[0];
		}
		if (self.consumeType(.BITWISE_NOT)) {
			const v = try self.parseUnary();
			return v ^ 0xFFFFFFFFFFFFFFFF;
		}
		return self.parsePrimary();
	}

	fn parsePrimary(self: *TokenParser) ExprError!u64 {
		if (self.consumeType(.LPAREN)) {
			const v = try self.parseExpr();
			if (!self.consumeType(.RPAREN)) return ExprError.InvalidExpression;
			return v;
		}
		if (self.i >= self.toks.len) return ExprError.InvalidExpression;
		const tok = self.toks[self.i];
		if (tok.tokType == .INTEGER) {
			self.i += 1;
			return try parseLexNumber(tok.lexeme);
		}
		if (tok.tokType == .IMM) {
			self.i += 1;
			if (tok.lexeme.len > 0 and tok.lexeme[0] == '#') {
				return try parseLexNumber(tok.lexeme[1..]);
			}
			return ExprError.InvalidExpression;
		}
		return ExprError.InvalidExpression;
	}
};

fn parseLexNumber(lex: []const u8) ExprError!u64 {
	if (lex.len == 0) return ExprError.InvalidExpression;
	// hex
	if (lex.len >= 2 and lex[0] == '0' and (lex[1] == 'x' or lex[1] == 'X')) {
		var v: u64 = 0;
		var any = false;
		var i: usize = 2;
		while (i < lex.len) {
			const c = lex[i];
			var digit: u8 = 0;
			if (c >= '0' and c <= '9') {
				digit = @as(u8, c - '0');
			} else if (c >= 'a' and c <= 'f') {
				digit = @as(u8, 10 + (c - 'a'));
			} else if (c >= 'A' and c <= 'F') {
				digit = @as(u8, 10 + (c - 'A'));
			} else break;
			any = true;
			const mulr = @mulWithOverflow(v, 16);
			const addr = @addWithOverflow(mulr[0], @as(u64, digit));
			v = addr[0];
			i += 1;
		}
		if (!any) return ExprError.InvalidExpression;
		return v;
	}
	// binary
	if (lex.len >= 2 and lex[0] == '0' and (lex[1] == 'b' or lex[1] == 'B')) {
		var v: u64 = 0;
		var any = false;
		var i: usize = 2;
		while (i < lex.len) {
			const c = lex[i];
			if (c == '0' or c == '1') {
				any = true;
				const mulr = @mulWithOverflow(v, 2);
				const addr = @addWithOverflow(mulr[0], @as(u64, c - '0'));
				v = addr[0];
				i += 1;
			} else break;
		}
		if (!any) return ExprError.InvalidExpression;
		return v;
	}
	// decimal
	var v: u64 = 0;
	var any = false;
	var i: usize = 0;
	while (i < lex.len) {
		const c = lex[i];
		if (c >= '0' and c <= '9') {
			any = true;
			const mulr = @mulWithOverflow(v, 10);
			const addr = @addWithOverflow(mulr[0], @as(u64, c - '0'));
			v = addr[0];
			i += 1;
		} else break;
	}
	if (!any) return ExprError.InvalidExpression;
	return v;
}

fn applySize(v: u64, size: ExprSize) u64 {
	switch (size) {
		.U14 => return v & ((@as(u64, 1) << 14) - 1),
		.S9 => {
			const bits: u64 = 9;
			const mask: u64 = (@as(u64, 1) << bits) - 1;
			const r = v & mask;
			const sign = (@as(u64, 1) << (bits - 1));
			if ((r & sign) != 0) return r | (~mask);
			return r;
		},
		.S24 => {
			const bits: u64 = 24;
			const mask: u64 = (@as(u64, 1) << bits) - 1;
			const r = v & mask;
			const sign = (@as(u64, 1) << (bits - 1));
			if ((r & sign) != 0) return r | (~mask);
			return r;
		},
		.S19 => {
			const bits: u64 = 19;
			const mask: u64 = (@as(u64, 1) << bits) - 1;
			const r = v & mask;
			const sign = (@as(u64, 1) << (bits - 1));
			if ((r & sign) != 0) return r | (~mask);
			return r;
		},
		.U8 => return v & 0xFF,
		.U16 => return v & 0xFFFF,
		.U32 => return v & 0xFFFFFFFF,
	}
}

pub fn parseEval(exprToks: []const Token.Token, size: ExprSize) ExprError!u64 {
	var p = TokenParser{ .toks = exprToks, .i = 0 };
	const v = try p.parseExpr();
	if (p.i != p.toks.len) return ExprError.InvalidExpression;
	return applySize(v, size);
}

test "expr basic examples" {
	// #2
	const toks1 = [_]Token.Token{
		Token.Token{ .lexeme = "#2", .tokType = .IMM }
	};
	try std.testing.expectEqual(2, try parseEval(toks1[0..], .U14));

	// 0x2 >> 1
	const toks2 = [_]Token.Token{
		Token.Token{ .lexeme = "0x2", .tokType = .INTEGER },
		Token.Token{ .lexeme = ">>", .tokType = .SHIFT_RIGHT },
		Token.Token{ .lexeme = "1", .tokType = .INTEGER },
	};
	try std.testing.expectEqual(1, try parseEval(toks2[0..], .U14));

	// 0x1 << 4
	const toks3 = [_]Token.Token{
		Token.Token{ .lexeme = "0x1", .tokType = .INTEGER },
		Token.Token{ .lexeme = "<<", .tokType = .SHIFT_LEFT },
		Token.Token{ .lexeme = "4", .tokType = .INTEGER },
	};
	try std.testing.expectEqual(16, try parseEval(toks3[0..], .U14));

	// 0xff + (2 ^ 1) / (2| 2)
	const toks4 = [_]Token.Token{
		Token.Token{ .lexeme = "0xff", .tokType = .INTEGER },
		Token.Token{ .lexeme = "+", .tokType = .PLUS },
		Token.Token{ .lexeme = "(", .tokType = .LPAREN },
		Token.Token{ .lexeme = "2", .tokType = .INTEGER },
		Token.Token{ .lexeme = "^", .tokType = .BITWISE_XOR },
		Token.Token{ .lexeme = "1", .tokType = .INTEGER },
		Token.Token{ .lexeme = ")", .tokType = .RPAREN },
		Token.Token{ .lexeme = "/", .tokType = .DIVIDE },
		Token.Token{ .lexeme = "(", .tokType = .LPAREN },
		Token.Token{ .lexeme = "2", .tokType = .INTEGER },
		Token.Token{ .lexeme = "|", .tokType = .BITWISE_OR },
		Token.Token{ .lexeme = "2", .tokType = .INTEGER },
		Token.Token{ .lexeme = ")", .tokType = .RPAREN },
	};
	try std.testing.expectEqual(0x100, try parseEval(toks4[0..], .U14));

	// 0b10
	const toks5 = [_]Token.Token{ Token.Token{ .lexeme = "0b10", .tokType = .INTEGER } };
	try std.testing.expectEqual(2, try parseEval(toks5[0..], .U14));

	// ~0xFFFFFFFFFFFFFFFF
	const toks6 = [_]Token.Token{
		Token.Token{ .lexeme = "~", .tokType = .BITWISE_NOT },
		Token.Token{ .lexeme = "0xFFFFFFFFFFFFFFFF", .tokType = .INTEGER },
	};
	try std.testing.expectEqual(0, try parseEval(toks6[0..], .U14));

	// -3 + 8
	const toks7 = [_]Token.Token{
		Token.Token{ .lexeme = "-", .tokType = .MINUS },
		Token.Token{ .lexeme = "3", .tokType = .INTEGER },
		Token.Token{ .lexeme = "+", .tokType = .PLUS },
		Token.Token{ .lexeme = "8", .tokType = .INTEGER },
	};
	try std.testing.expectEqual(5, try parseEval(toks7[0..], .U14));

	// #2 + #4
	const toks8 = [_]Token.Token{
		Token.Token{ .lexeme = "#2", .tokType = .IMM },
		Token.Token{ .lexeme = "+", .tokType = .PLUS },
		Token.Token{ .lexeme = "#4", .tokType = .IMM },
	};
	try std.testing.expectEqual(6, try parseEval(toks8[0..], .U14));

	// Precedence: 1 + 2 * 3 = 7
	const toks9 = [_]Token.Token{
		Token.Token{ .lexeme = "1", .tokType = .INTEGER },
		Token.Token{ .lexeme = "+", .tokType = .PLUS },
		Token.Token{ .lexeme = "2", .tokType = .INTEGER },
		Token.Token{ .lexeme = "*", .tokType = .ASTERISK },
		Token.Token{ .lexeme = "3", .tokType = .INTEGER },
	};
	try std.testing.expectEqual(7, try parseEval(toks9[0..], .U14));

	// Shift vs plus precedence: (1 + 2) << 3 = 24
	const toks10 = [_]Token.Token{
		Token.Token{ .lexeme = "1", .tokType = .INTEGER },
		Token.Token{ .lexeme = "+", .tokType = .PLUS },
		Token.Token{ .lexeme = "2", .tokType = .INTEGER },
		Token.Token{ .lexeme = "<<", .tokType = .SHIFT_LEFT },
		Token.Token{ .lexeme = "3", .tokType = .INTEGER },
	};
	try std.testing.expectEqual(24, try parseEval(toks10[0..], .U14));

	// Bitwise precedence: & before ^ -> (0xFF & 0x0F) ^ 0xF0 = 0xFF
	const toks11 = [_]Token.Token{
		Token.Token{ .lexeme = "0xFF", .tokType = .INTEGER },
		Token.Token{ .lexeme = "&", .tokType = .BITWISE_AND },
		Token.Token{ .lexeme = "0x0F", .tokType = .INTEGER },
		Token.Token{ .lexeme = "^", .tokType = .BITWISE_XOR },
		Token.Token{ .lexeme = "0xF0", .tokType = .INTEGER },
	};
	try std.testing.expectEqual(0xFF, try parseEval(toks11[0..], .U14));

	// U14 mask: 0x4000 -> masked to 0
	const toks12 = [_]Token.Token{ Token.Token{ .lexeme = "0x4000", .tokType = .INTEGER } };
	try std.testing.expectEqual(0, try parseEval(toks12[0..], .U14));
}

test "imm literal" {
	const toks1 = [_]Token.Token{
		Token.Token{ .lexeme = "#2", .tokType = .IMM },
	};
	try std.testing.expectEqual(2, try parseEval(toks1[0..], .U14));
}

test "shift right" {
	const toks2 = [_]Token.Token{
		Token.Token{ .lexeme = "0x2", .tokType = .INTEGER },
		Token.Token{ .lexeme = ">>", .tokType = .SHIFT_RIGHT },
		Token.Token{ .lexeme = "1", .tokType = .INTEGER },
	};
	try std.testing.expectEqual(1, try parseEval(toks2[0..], .U14));
}

test "shift left" {
	const toks3 = [_]Token.Token{
		Token.Token{ .lexeme = "0x1", .tokType = .INTEGER },
		Token.Token{ .lexeme = "<<", .tokType = .SHIFT_LEFT },
		Token.Token{ .lexeme = "4", .tokType = .INTEGER },
	};
	try std.testing.expectEqual(16, try parseEval(toks3[0..], .U14));
}

test "complex expression" {
	const toks4 = [_]Token.Token{
		Token.Token{ .lexeme = "0xff", .tokType = .INTEGER },
		Token.Token{ .lexeme = "+", .tokType = .PLUS },
		Token.Token{ .lexeme = "(", .tokType = .LPAREN },
		Token.Token{ .lexeme = "2", .tokType = .INTEGER },
		Token.Token{ .lexeme = "^", .tokType = .BITWISE_XOR },
		Token.Token{ .lexeme = "1", .tokType = .INTEGER },
		Token.Token{ .lexeme = ")", .tokType = .RPAREN },
		Token.Token{ .lexeme = "/", .tokType = .DIVIDE },
		Token.Token{ .lexeme = "(", .tokType = .LPAREN },
		Token.Token{ .lexeme = "2", .tokType = .INTEGER },
		Token.Token{ .lexeme = "|", .tokType = .BITWISE_OR },
		Token.Token{ .lexeme = "2", .tokType = .INTEGER },
		Token.Token{ .lexeme = ")", .tokType = .RPAREN },
	};
	try std.testing.expectEqual(0x100, try parseEval(toks4[0..], .U14));
}

test "binary literal" {
	const toks5 = [_]Token.Token{ Token.Token{ .lexeme = "0b10", .tokType = .INTEGER } };
	try std.testing.expectEqual(2, try parseEval(toks5[0..], .U14));
}

test "bitwise not" {
	const toks6 = [_]Token.Token{
		Token.Token{ .lexeme = "~", .tokType = .BITWISE_NOT },
		Token.Token{ .lexeme = "0xFFFFFFFFFFFFFFFF", .tokType = .INTEGER },
	};
	try std.testing.expectEqual(0, try parseEval(toks6[0..], .U14));
}

test "unary minus plus" {
	const toks7 = [_]Token.Token{
		Token.Token{ .lexeme = "-", .tokType = .MINUS },
		Token.Token{ .lexeme = "3", .tokType = .INTEGER },
		Token.Token{ .lexeme = "+", .tokType = .PLUS },
		Token.Token{ .lexeme = "8", .tokType = .INTEGER },
	};
	try std.testing.expectEqual(5, try parseEval(toks7[0..], .U14));
}

test "imm add" {
	const toks8 = [_]Token.Token{
		Token.Token{ .lexeme = "#2", .tokType = .IMM },
		Token.Token{ .lexeme = "+", .tokType = .PLUS },
		Token.Token{ .lexeme = "#4", .tokType = .IMM },
	};
	try std.testing.expectEqual(6, try parseEval(toks8[0..], .U14));
}

test "precedence mul over add" {
	const toks9 = [_]Token.Token{
		Token.Token{ .lexeme = "1", .tokType = .INTEGER },
		Token.Token{ .lexeme = "+", .tokType = .PLUS },
		Token.Token{ .lexeme = "2", .tokType = .INTEGER },
		Token.Token{ .lexeme = "*", .tokType = .ASTERISK },
		Token.Token{ .lexeme = "3", .tokType = .INTEGER },
	};
	try std.testing.expectEqual(7, try parseEval(toks9[0..], .U14));
}

test "shift and add precedence" {
	const toks10 = [_]Token.Token{
		Token.Token{ .lexeme = "1", .tokType = .INTEGER },
		Token.Token{ .lexeme = "+", .tokType = .PLUS },
		Token.Token{ .lexeme = "2", .tokType = .INTEGER },
		Token.Token{ .lexeme = "<<", .tokType = .SHIFT_LEFT },
		Token.Token{ .lexeme = "3", .tokType = .INTEGER },
	};
	try std.testing.expectEqual(24, try parseEval(toks10[0..], .U14));
}

test "bitwise precedence" {
	const toks11 = [_]Token.Token{
		Token.Token{ .lexeme = "0xFF", .tokType = .INTEGER },
		Token.Token{ .lexeme = "&", .tokType = .BITWISE_AND },
		Token.Token{ .lexeme = "0x0F", .tokType = .INTEGER },
		Token.Token{ .lexeme = "^", .tokType = .BITWISE_XOR },
		Token.Token{ .lexeme = "0xF0", .tokType = .INTEGER },
	};
	try std.testing.expectEqual(0xFF, try parseEval(toks11[0..], .U14));
}

test "u14 masking" {
	const toks12 = [_]Token.Token{ Token.Token{ .lexeme = "0x4000", .tokType = .INTEGER } };
	try std.testing.expectEqual(0, try parseEval(toks12[0..], .U14));
}

test "s9 negative one" {
	const toks13 = [_]Token.Token{ Token.Token{ .lexeme = "0x1FF", .tokType = .INTEGER } };
	const expected: u64 = ~(@as(u64, 0)); // Hack to get -1 as unsigned, because zig is dumb for this
	try std.testing.expectEqual(expected, try parseEval(toks13[0..], .S9));
}

test "s9 sign extend" {
	const toks14 = [_]Token.Token{ Token.Token{ .lexeme = "0x100", .tokType = .INTEGER } };
	try std.testing.expectEqual(0xFFFFFFFFFFFFFF00, try parseEval(toks14[0..], .S9));
}

test "s24 sign extend" {
	const toks15 = [_]Token.Token{ Token.Token{ .lexeme = "0x800000", .tokType = .INTEGER } };
	try std.testing.expectEqual(0xFFFFFFFFFF800000, try parseEval(toks15[0..], .S24));
}

test "s19 sign extend" {
	const toks16 = [_]Token.Token{ Token.Token{ .lexeme = "0x40000", .tokType = .INTEGER } };
	try std.testing.expectEqual(0xFFFFFFFFFFFC0000, try parseEval(toks16[0..], .S19));
}