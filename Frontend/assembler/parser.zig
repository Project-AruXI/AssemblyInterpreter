// zig fmt: off

const std = @import("std");
const Token = @import("token.zig");
const _instr = @import("instr.zig");
const _directive = @import("directive.zig");
const Expr = @import("expr.zig");


pub const ParserError = error{
	UnexpectedToken,
	InvalidSyntax,
	InvalidRegister,
};


fn parseRegister(regStr: []const u8) !_instr.Reg {
	// "sp"|"SP" -> .SP
	// "ir"|"IR" -> .IR
	// "x0"|"X0" - "x30"| "X30" -> .X0 - .X30
	// "a0"|"A0" - "a9"|"A9" -> .X0 - .X9 (alias for x0-x9)
	// "xr"|"XR" -> .X0
	// "c0"|"C0" - "c4"|"C4" -> .X12 - .X16 (alias for x12-x16)
	// "s0"|"S0" - "s10"|"S10" -> .X17 - .X27 (alias for x17-x27)
	// "lr"|"LR" -> .X28 (alias for x28)
	// "xb"|"XB" -> .X29 (alias for x29)
	// "xz"|"XZ" -> .X30 (alias for x30)
	// "f0"|"F0" - "f15"|"F15" -> .F0 - .F15 (ignore for now)
	// "v0"|"V0" - "v5"|"V5" -> .V0 - .V5 (ignore for now)

	if (std.ascii.eqlIgnoreCase(regStr, "sp")) {
		return _instr.Reg.SP;
	} else if (std.ascii.eqlIgnoreCase(regStr, "ir")) {
		return _instr.Reg.IR;
	} else if (regStr.len >= 2 and (regStr[0] == 'x' or regStr[0] == 'X')) {
		const regNum = std.fmt.parseInt(u8, regStr[1..], 10) catch {
			return ParserError.InvalidRegister;
		};
		if (regNum <= 30) {
			return switch (regNum) {
				0 => _instr.Reg.X0,
				1 => _instr.Reg.X1,
				2 => _instr.Reg.X2,
				3 => _instr.Reg.X3,
				4 => _instr.Reg.X4,
				5 => _instr.Reg.X5,
				6 => _instr.Reg.X6,
				7 => _instr.Reg.X7,
				8 => _instr.Reg.X8,
				9 => _instr.Reg.X9,
				10 => _instr.Reg.X10,
				11 => _instr.Reg.X11,
				12 => _instr.Reg.X12,
				13 => _instr.Reg.X13,
				14 => _instr.Reg.X14,
				15 => _instr.Reg.X15,
				16 => _instr.Reg.X16,
				17 => _instr.Reg.X17,
				18 => _instr.Reg.X18,
				19 => _instr.Reg.X19,
				20 => _instr.Reg.X20,
				21 => _instr.Reg.X21,
				22 => _instr.Reg.X22,
				23 => _instr.Reg.X23,
				24 => _instr.Reg.X24,
				25 => _instr.Reg.X25,
				26 => _instr.Reg.X26,
				27 => _instr.Reg.X27,
				28 => _instr.Reg.X28,
				29 => _instr.Reg.X29,
				else => _instr.Reg.X30
			};
		} else {
			return ParserError.InvalidRegister;
		}
	} else if (regStr.len >= 2 and (regStr[0] == 'a' or regStr[0] == 'A')) {
		const regNum = std.fmt.parseInt(u8, regStr[1..], 10) catch {
			return ParserError.InvalidRegister;
		};
		if (regNum <= 9) {
			return switch (regNum) {
				0 => _instr.Reg.X0,
				1 => _instr.Reg.X1,
				2 => _instr.Reg.X2,
				3 => _instr.Reg.X3,
				4 => _instr.Reg.X4,
				5 => _instr.Reg.X5,
				6 => _instr.Reg.X6,
				7 => _instr.Reg.X7,
				8 => _instr.Reg.X8,
				else => _instr.Reg.X9
			};
		} else {
			return ParserError.InvalidRegister;
		}
	} else {
		return ParserError.InvalidRegister;
	}

}

test "Parse register" {
	try std.testing.expectEqual(_instr.Reg.X0, parseRegister("x0"));
	try std.testing.expectEqual(_instr.Reg.X1, parseRegister("X1"));
	try std.testing.expectEqual(_instr.Reg.X2, parseRegister("a2"));
	try std.testing.expectEqual(_instr.Reg.X3, parseRegister("A3"));
	try std.testing.expectEqual(_instr.Reg.SP, parseRegister("sp"));
	try std.testing.expectEqual(_instr.Reg.IR, parseRegister("IR"));
	try std.testing.expectEqual(ParserError.InvalidRegister, parseRegister("x31"));
	try std.testing.expectEqual(ParserError.InvalidRegister, parseRegister("y0"));
}


fn createIInstruction(instrOp: _instr.InstrOp, tokens: []const Token.Token) !_instr.Instr {
	// std.debug.print("Creating I-type instruction with op {any} and tokens {any}\n", .{instrOp, tokens});
	// Most of I-type instruction follow the format of [op] <rd>, <rs>, #<imm>
	// Exceptions are NOT (not <xd>, #<imm>), MV/MVN (mv/mvn <rd>, #<imm>), and CMP (cmp <rs>, #<imm>)

	switch (instrOp) {
		.ADD, .ADDS, .SUB, .SUBS, .OR, .AND, 
		.XOR, .LSL, .LSR, .ASR => {
			// Format: [op] <rd>, <rs>, #<imm>
			// Token length must be at least 5 (rd, comma, rs, comma, imm [at least one imm token])
			if (tokens.len < 5) return ParserError.InvalidSyntax;

			const rd = try parseRegister(tokens[0].lexeme);
			if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
			const rs = try parseRegister(tokens[2].lexeme);
			if (tokens[3].tokType != .COMMA) return ParserError.InvalidSyntax;
			// Parse immediate
			// The immediate can be an expression, which is composed by the rest of the tokens after the comma
			const imm = try Expr.parseEval(tokens[4..], Expr.ExprSize.U14);
			// To match with the .imm14 field typed as u16, `imm` must be casted to u16 then the upper 2 bits must be checked to be zero (since imm14 is unsigned)
			if (imm > 0x3FFF) return ParserError.InvalidSyntax;
			const imm14: u16 = @intCast(imm);

			return _instr.Instr{
				.I = .{
					.instrOp = instrOp,
					.rd = rd,
					.rs = rs,
					.imm14 = imm14
				}
			};
		},
		.NOT, .MV, .MVN => {
			// Format: [op] <rd>, #<imm>
			if (tokens.len < 3) return ParserError.InvalidSyntax;

			const rd = try parseRegister(tokens[0].lexeme);
			if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
			const imm = try Expr.parseEval(tokens[2..], Expr.ExprSize.U14);
			if (imm > 0x3FFF) return ParserError.InvalidSyntax;
			const imm14: u16 = @intCast(imm);

			return _instr.Instr{
				.I = .{
					.instrOp = instrOp,
					.rd = rd,
					.rs = .X30,
					.imm14 = imm14
				}
			};
		},
		.CMP => {
			// Format: cmp <rs>, #<imm>
			if (tokens.len < 3) return ParserError.InvalidSyntax;

			const rs = try parseRegister(tokens[0].lexeme);
			if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
			const imm = try Expr.parseEval(tokens[2..], Expr.ExprSize.U14);
			if (imm > 0x3FFF) return ParserError.InvalidSyntax;
			const imm14: u16 = @intCast(imm);

			return _instr.Instr{
				.I = .{
					.instrOp = instrOp,
					.rd = .X30,
					.rs = rs,
					.imm14 = imm14
				}
			};
		},
		else => {
			std.debug.print("Creating I-type instruction for op {any} not yet implemented\n", .{instrOp});
			return ParserError.UnexpectedToken;
		}
	}
}

fn createRInstruction(instrOp: _instr.InstrOp, tokens: []const Token.Token) !_instr.Instr {
	// std.debug.print("Creating R-type instruction with op {any} and tokens {any}\n", .{instrOp, tokens});
	// Most of R-type instructions follow the format of [op] <rd>, <rs>, <rr>
	// Exceptions are NOT (not <rd>, <rs>), MV/MVN (mv/mvn <rd>, <rs>), and CMP (cmp <rs>, <rr>)

	switch (instrOp) {
		.ADD, .ADDS, .SUB, .SUBS, .OR, .AND, 
		.XOR, .LSL, .LSR, .ASR, 
		.MUL, .SMUL, .DIV, .SDIV => {
			// Format: [op] <rd>, <rs>, <rr>
			if (tokens.len != 5) return ParserError.InvalidSyntax;

			const rd = try parseRegister(tokens[0].lexeme);
			if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
			const rs = try parseRegister(tokens[2].lexeme);
			if (tokens[3].tokType != .COMMA) return ParserError.InvalidSyntax;
			const rr = try parseRegister(tokens[4].lexeme);

			return _instr.Instr{
				.R = .{
					.instrOp = instrOp,
					.rd = rd,
					.rs = rs,
					.rr = rr
				}
			};
		},
		.NOT, .MV, .MVN => {
			// Format: [op] <rd>, <rs>
			if (tokens.len != 3) return ParserError.InvalidSyntax;

			const rd = try parseRegister(tokens[0].lexeme);
			if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
			const rs = try parseRegister(tokens[2].lexeme);

			return _instr.Instr{
				.R = .{
					.instrOp = instrOp,
					.rd = rd,
					.rs = rs,
					.rr = .X30
				}
			};
		},
		.CMP => {
			// Format: cmp <rs>, <rr>
			if (tokens.len != 3) return ParserError.InvalidSyntax;

			const rs = try parseRegister(tokens[0].lexeme);
			if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
			const rr = try parseRegister(tokens[2].lexeme);

			return _instr.Instr{
				.R = .{
					.instrOp = instrOp,
					.rd = .X30,
					.rs = rs,
					.rr = rr
				}
			};
		},
		else => {
			std.debug.print("Creating R-type instruction for op {any} not yet implemented\n", .{instrOp});
			return ParserError.UnexpectedToken;
		}
	}
}

fn createIRInstruction(instrOp: _instr.InstrOp, tokens: []const Token.Token) !_instr.Instr {
	// This applies to both I and R type instructions
	// They are differentiated by whether an immediate exists, for the most part
	// std.debug.print("Creating IR-type instruction with op {any} and tokens {any}\n", .{instrOp, tokens});
	
	const lastToken = tokens[tokens.len - 1];
	// If last token is a register, then the instruction MAY be R-type
	// Otherwise it MAY be I-type, since the token is not guaranteed to be fitting of an expression

	_ = parseRegister(lastToken.lexeme) catch {
		// If the last token is not a register, then the instruction MAY be I-type
		return try createIInstruction(instrOp, tokens);
	};
	// If the last token is a register, then the instruction MAY be R-type
	return try createRInstruction(instrOp, tokens);
}

fn createMInstruction(instrOp: _instr.InstrOp, tokens: []const Token.Token) !_instr.Instr {
	// std.debug.print("Creating memory instruction with op {any} and tokens {any}\n", .{instrOp, tokens});
	// Formats are:
	// [op] <rd>, [<rs>, #<imm>]
	// [op] <rd>, [<rs>]
	// [op] <rd>, [<rs>], <rr>
	// Specials are:
	// ld <rd>, <label> (loads contents at address of label into rd as 4 bytes)
	// ld <rd>, =<imm> (moves the immediate directly into rd, aka a longer range of mv)
	// These instructions are pseudo, as they move potentially big numbers (up to 32 bits), which cannot be encoded
	// A normal assembler would expand these into multiple instructions (up to 7)
	// However, for now, ignore
	// Note: <imm> can be an expression
	
	if (tokens.len < 5) return ParserError.InvalidSyntax;

	const rd = parseRegister(tokens[0].lexeme) catch {
		// In the case that the first token is not a register, it means the syntax is wrong
		return ParserError.InvalidSyntax;
	};

	if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
	if (tokens[2].tokType != .LBRACKET) return ParserError.InvalidSyntax;

	const rs = parseRegister(tokens[3].lexeme) catch {
		return ParserError.InvalidSyntax;
	};

	var rr: _instr.Reg = .X30;
	var simm9: i9 = 0;

	// This is where the pattern changes
	// The next token after the register can either be ']' or ','
	if (tokens[4].tokType == .RBRACKET) {
		// Format: [op] <rd>, [<rs>] or [op] <rd>, [<rs>], <rr>
		if (tokens.len == 5) {
			// [op] <rd>, [<rs>]
			// Nothing to do since rr is already set, it was just a matter of closing the bracket
		} else if (tokens.len == 7) {
			// [op] <rd>, [<rs>], <rr>
			if (tokens[5].tokType != .COMMA) return ParserError.InvalidSyntax;
			rr = parseRegister(tokens[6].lexeme) catch {
				return ParserError.InvalidSyntax;
			};
		} else {
			return ParserError.InvalidSyntax;
		}
	} else if (tokens[4].tokType == .COMMA) {
		// Format: [op] <rd>, [<rs>, #<imm>]
		// The rest of the tokens compose the immediate, except the very last, that needs to be the closing bracket
		if (tokens[tokens.len - 1].tokType != .RBRACKET) return ParserError.InvalidSyntax;

		const imm = try Expr.parseEval(tokens[5..tokens.len - 1], Expr.ExprSize.S19);
		if (imm < -256 or imm > 255) return ParserError.InvalidSyntax;
		simm9 = @intCast(imm);
	} else {
		return ParserError.InvalidSyntax;
	}

	return _instr.Instr{
		.M = .{
			.instrOp = instrOp,
			.rd = rd,
			.rs = rs,
			.rr = rr,
			.simm9 = simm9
		}
	};
}

fn createSInstruction(instrOp: _instr.InstrOp, tokens: []const Token.Token) !_instr.Instr {
	_ = tokens;
	// std.debug.print("Creating system instruction with op {any} and tokens {any}\n", .{instrOp, tokens});
	// For now, only SYSCALL exists, and it takes no arguments
	return _instr.Instr{
		.S = .{
			.instrOp = instrOp,
			.rd = .X0,
			.rs = .X0
		}
	};
}


inline fn getInstrOp(instrName: []const u8) !_instr.InstrOp {
	var instrOp: _instr.InstrOp = undefined;

	if (std.ascii.eqlIgnoreCase(instrName, "ADD")) {
		instrOp = _instr.InstrOp.ADD;
	} else if (std.ascii.eqlIgnoreCase(instrName, "ADDS")) {
		instrOp = _instr.InstrOp.ADDS;
	} else if (std.ascii.eqlIgnoreCase(instrName, "SUB")) {
		instrOp = _instr.InstrOp.SUB;
	} else if (std.ascii.eqlIgnoreCase(instrName, "SUBS")) {
		instrOp = _instr.InstrOp.SUBS;
	} else if (std.ascii.eqlIgnoreCase(instrName, "MUL")) {
		instrOp = _instr.InstrOp.MUL;
	} else if (std.ascii.eqlIgnoreCase(instrName, "SMUL")) {
		instrOp = _instr.InstrOp.SMUL;
	} else if (std.ascii.eqlIgnoreCase(instrName, "DIV")) {
		instrOp = _instr.InstrOp.DIV;
	} else if (std.ascii.eqlIgnoreCase(instrName, "SDIV")) {
		instrOp = _instr.InstrOp.SDIV;
	} else if (std.ascii.eqlIgnoreCase(instrName, "OR")) {
		instrOp = _instr.InstrOp.OR;
	} else if (std.ascii.eqlIgnoreCase(instrName, "AND")) {
		instrOp = _instr.InstrOp.AND;
	} else if (std.ascii.eqlIgnoreCase(instrName, "XOR")) {
		instrOp = _instr.InstrOp.XOR;
	} else if (std.ascii.eqlIgnoreCase(instrName, "NOT")) {
		instrOp = _instr.InstrOp.NOT;
	} else if (std.ascii.eqlIgnoreCase(instrName, "LSL")) {
		instrOp = _instr.InstrOp.LSL;
	} else if (std.ascii.eqlIgnoreCase(instrName, "LSR")) {
		instrOp = _instr.InstrOp.LSR;
	} else if (std.ascii.eqlIgnoreCase(instrName, "ASR")) {
		instrOp = _instr.InstrOp.ASR;
	} else if (std.ascii.eqlIgnoreCase(instrName, "CMP")) {
		instrOp = _instr.InstrOp.CMP;
	} else if (std.ascii.eqlIgnoreCase(instrName, "MV")) {
		instrOp = _instr.InstrOp.MV;
	} else if (std.ascii.eqlIgnoreCase(instrName, "MVN")) {
		instrOp = _instr.InstrOp.MVN;
	} else if (std.ascii.eqlIgnoreCase(instrName, "SXB")) {
		instrOp = _instr.InstrOp.SXB;
	} else if (std.ascii.eqlIgnoreCase(instrName, "SXH")) {
		instrOp = _instr.InstrOp.SXH;
	} else if (std.ascii.eqlIgnoreCase(instrName, "UXB")) {
		instrOp = _instr.InstrOp.UXB;
	} else if (std.ascii.eqlIgnoreCase(instrName, "UXH")) {
		instrOp = _instr.InstrOp.UXH;
	} else if (std.ascii.eqlIgnoreCase(instrName, "LD")) {
		instrOp = _instr.InstrOp.LD;
	} else if (std.ascii.eqlIgnoreCase(instrName, "LDB")) {
		instrOp = _instr.InstrOp.LDB;
	} else if (std.ascii.eqlIgnoreCase(instrName, "LDBS")) {
		instrOp = _instr.InstrOp.LDBS;
	} else if (std.ascii.eqlIgnoreCase(instrName, "LDBZ")) {
		instrOp = _instr.InstrOp.LDBZ;
	} else if (std.ascii.eqlIgnoreCase(instrName, "LDH")) {
		instrOp = _instr.InstrOp.LDH;
	} else if (std.ascii.eqlIgnoreCase(instrName, "LDHS")) {
		instrOp = _instr.InstrOp.LDHS;
	} else if (std.ascii.eqlIgnoreCase(instrName, "LDHZ")) {
		instrOp = _instr.InstrOp.LDHZ;
	} else if (std.ascii.eqlIgnoreCase(instrName, "STR")) {
		instrOp = _instr.InstrOp.STR;
	} else if (std.ascii.eqlIgnoreCase(instrName, "STRB")) {
		instrOp = _instr.InstrOp.STRB;
	} else if (std.ascii.eqlIgnoreCase(instrName, "STRH")) {
		instrOp = _instr.InstrOp.STRH;
	} else if (std.ascii.eqlIgnoreCase(instrName, "UB")) {
		instrOp = _instr.InstrOp.UB;
	} else if (std.ascii.eqlIgnoreCase(instrName, "UBR")) {
		instrOp = _instr.InstrOp.UBR;
	} else if (std.ascii.startsWithIgnoreCase(instrName, "B")) {
		instrOp = _instr.InstrOp.B;
	} else if (std.ascii.eqlIgnoreCase(instrName, "CALL")) {
		instrOp = _instr.InstrOp.CALL;
	} else if (std.ascii.eqlIgnoreCase(instrName, "RET")) {
		instrOp = _instr.InstrOp.RET;
	} else if (std.ascii.eqlIgnoreCase(instrName, "NOP")) {
		instrOp = _instr.InstrOp.NOP;
	} else if (std.ascii.eqlIgnoreCase(instrName, "SYSCALL")) {
		instrOp = _instr.InstrOp.SYSCALL;
	} else {
		std.debug.print("Instruction name {s} not recognized\n", .{instrName});
		return ParserError.UnexpectedToken;
	}

	return instrOp;
}

fn parseIdentifier(tokens: []const Token.Token) !_instr.Instr {
	// std.debug.print("Parsing identifier...\n", .{});

	const instrName = tokens[0].lexeme;

	const instrOp = try getInstrOp(instrName);
	var instr: _instr.Instr = undefined;

	switch (instrOp) {
		.ADD, .ADDS, .SUB, .SUBS, .OR, .AND, 
		.XOR, .NOT, .LSL, .LSR, .ASR, .CMP, .MV, .MVN, => {
			instr = try createIRInstruction(instrOp, tokens[1..]);
		},
		.NOP => {
			instr = _instr.Instr{
				.I = .{
					.instrOp = instrOp,
					.rd = .X30, // Ignored
					.rs = .X30, // Ignored
					.imm14 = 0 // Ignored
				}
			};
		},
		.MUL, .SMUL, .DIV, .SDIV, .SXB, .SXH, .UXB, .UXH, => {
			instr = try createRInstruction(instrOp, tokens[1..]);
		},
		.LD, .LDB, .LDBS, .LDBZ, .LDH, .LDHS, .LDHZ, .STR, .STRB, .STRH => {
			instr = try createMInstruction(instrOp, tokens[1..]);
		},
		.SYSCALL => {
			instr = try createSInstruction(instrOp, tokens[1..]);
		},
		else => {
			std.debug.print("Parsing for instruction op {any} not yet implemented\n", .{instrOp});
			return ParserError.UnexpectedToken;
		}
	}

	return instr;
}


pub fn parseInstruction(tokens: []const Token.Token) !_instr.Instr {
	switch (tokens[0].tokType) {
		.IDENTIFIER => {
			return parseIdentifier(tokens) catch |err| {
				std.debug.print("Error parsing identifier: {any}\n", .{err});
				return err;
			};
		},
		else => return ParserError.UnexpectedToken
	}
}



pub fn parseDirective(tokens: []const Token.Token) !_directive.Directive {
	switch (tokens[0].tokType) {
		.DIRECTIVE => {
			// For now, assume only directive is SET, format is: `.set symbol, expr`
			if (tokens.len < 4) return ParserError.InvalidSyntax;
			if (tokens[1].tokType != .IDENTIFIER) return ParserError.InvalidSyntax;
			if (tokens[2].tokType != .COMMA) return ParserError.InvalidSyntax;

			const exprVal = try Expr.parseEval(tokens[3..], Expr.ExprSize.U32);

			return .{
				.directiveType = .Set,
				.symbol = tokens[1].lexeme,
				.exprNum = @intCast(exprVal)
			};
		},
		else => return ParserError.UnexpectedToken
	}
}