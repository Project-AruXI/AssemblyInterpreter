// zig fmt: off

const std = @import("std");
const Token = @import("token.zig");
const Instr = @import("instr.zig");
const Opcodes = Instr.Opcodes;
const Directive = @import("directive.zig");
const Expr = @import("expr.zig");


pub const ParserError = error{
	UnexpectedToken,
	InvalidSyntax,
	InvalidRegister,
};


fn createIInstruction(instrOp: Opcodes.Opcode, tokens: []const Token.Token, alias: ?Opcodes.Alias) !Instr.Instr {
	// Handle alias-specific syntaxes first
	if (alias) |a| {
		switch (a) {
			.NOP => {
				if (tokens.len != 0) return ParserError.InvalidSyntax;
				return Instr.Instr{ .I = .{ .instrOp = instrOp, .rd = .x0, .rs = .x0, .imm14 = 0 } };
			},
			.CMPI => {
				// cmpi <rs>, #<imm>
				if (tokens.len < 3) return ParserError.InvalidSyntax;
				const rs = Instr.Arch.IntReg.fromString(tokens[0].lexeme) orelse return ParserError.InvalidSyntax;
				if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
				const imm = try Expr.parseEval(tokens[2..], Expr.ExprSize.U14);
				if (imm > 0x3FFF) return ParserError.InvalidSyntax;
				const imm14: u16 = @intCast(imm);
				return Instr.Instr{ .I = .{ .instrOp = instrOp, .rd = .x30, .rs = rs, .imm14 = imm14 } };
			},
			.MVNI => {
				// mvni <rd>, #<imm>
				if (tokens.len < 3) return ParserError.InvalidSyntax;
				if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
				const rd = Instr.Arch.IntReg.fromString(tokens[0].lexeme) orelse return ParserError.InvalidSyntax;
				const imm = try Expr.parseEval(tokens[2..], Expr.ExprSize.U14);
				if (imm > 0x3FFF) return ParserError.InvalidSyntax;
				const imm14: u16 = @intCast(imm);
				return Instr.Instr{ .I = .{ .instrOp = instrOp, .rd = rd, .rs = .x30, .imm14 = imm14 } };
			},
			else => {}
		}
	}

	// std.debug.print("Creating I-type instruction with op {any} and tokens {any}\n", .{instrOp, tokens});
	// Most of I-type instruction follow the format of [op] <rd>, <rs>, #<imm>
	// Exceptions are NOT (not <xd>, #<imm>), MV/MVN (mv/mvn <rd>, #<imm>), and CMP (cmp <rs>, #<imm>)

	switch (instrOp) {
		.ADD, .ADDS, .SUB, .SUBS, .OR, .AND, .XOR, .LSL, .LSR, .ASR => {
			// Format: [op] <rd>, <rs>, #<imm>
			// Token length must be at least 5 (rd, comma, rs, comma, imm [at least one imm token])
			if (tokens.len < 5) return ParserError.InvalidSyntax;
			const rd = Instr.Arch.IntReg.fromString(tokens[0].lexeme) orelse return ParserError.InvalidSyntax;
			if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
			const rs = Instr.Arch.IntReg.fromString(tokens[2].lexeme) orelse return ParserError.InvalidSyntax;
			if (tokens[3].tokType != .COMMA) return ParserError.InvalidSyntax;
			// Parse immediate
			// The immediate can be an expression, which is composed by the rest of the tokens after the comma
			const imm = try Expr.parseEval(tokens[4..], Expr.ExprSize.U14);
			// To match with the .imm14 field typed as u16, `imm` must be casted to u16 then the upper 2 bits must be checked to be zero (since imm14 is unsigned)
			if (imm > 0x3FFF) return ParserError.InvalidSyntax;
			const imm14: u16 = @intCast(imm);

			return Instr.Instr{
				.I = .{
					.instrOp = instrOp,
					.rd = rd,
					.rs = rs,
					.imm14 = imm14
				}
			};
		},
		.NOT, .MVI => {
			// Format: op <rd>, #<imm>
			if (tokens.len < 3) return ParserError.InvalidSyntax;
			const rd = Instr.Arch.IntReg.fromString(tokens[0].lexeme) orelse return ParserError.InvalidSyntax;
			if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
			const imm = try Expr.parseEval(tokens[2..], Expr.ExprSize.U14);
			if (imm > 0x3FFF) return ParserError.InvalidSyntax;
			const imm14: u16 = @intCast(imm);

			return Instr.Instr{
				.I = .{
					.instrOp = instrOp,
					.rd = rd,
					.rs = .x30,
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

test "createIInstruction" {
	// Normal instruction (addi x5, x10, #20)
	const instr1 = try createIInstruction(.ADDI, &.{
		Token.Token{ .tokType = .IDENTIFIER, .lexeme = "x5" },
		Token.Token{ .tokType = .COMMA, .lexeme = "," },
		Token.Token{ .tokType = .IDENTIFIER, .lexeme = "x10" },
		Token.Token{ .tokType = .COMMA, .lexeme = "," },
		Token.Token{ .tokType = .NUMBER, .lexeme = "20" },
	}, null);
	try std.testing.expectEqual(Instr.Arch.IntReg.x5, instr1.I.rd);
	try std.testing.expectEqual(Instr.Arch.IntReg.x10, instr1.I.rs);
	try std.testing.expectEqual(20, instr1.I.imm14);


	// Aliased instruction (cmpi x0, #0)
	const instr2 = try createIInstruction(.CMPI, &.{
		Token.Token{ .tokType = .IDENTIFIER, .lexeme = "x0" },
		Token.Token{ .tokType = .COMMA, .lexeme = "," },
		Token.Token{ .tokType = .NUMBER, .lexeme = "0" },
	}, null);
	try std.testing.expectEqual(Instr.Arch.IntReg.x0, instr2.I.rd);
	try std.testing.expectEqual(0, instr2.I.imm14);
}

fn createRInstruction(instrOp: Opcodes.Opcode, tokens: []const Token.Token, alias: ?Opcodes.Alias) !Instr.Instr {
	// Handle alias-specific syntaxes first
	if (alias) |a| {
		switch (a) {
			.CMP => {
				// cmp <rs>, <rr>
				if (tokens.len != 3) return ParserError.InvalidSyntax;
				const rs = Instr.Arch.IntReg.fromString(tokens[0].lexeme) orelse return ParserError.InvalidSyntax;
				if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
				const rr = Instr.Arch.IntReg.fromString(tokens[2].lexeme) orelse return ParserError.InvalidSyntax;
				return Instr.Instr{ .R = .{ .instrOp = instrOp, .rd = .x30, .rs = rs, .rr = rr } };
			},
			.MV => {
				// mv <rd>, <rs>  (register form)
				if (tokens.len != 3) return ParserError.InvalidSyntax;
				if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
				const rd = Instr.Arch.IntReg.fromString(tokens[0].lexeme) orelse return ParserError.InvalidSyntax;
				const rs = Instr.Arch.IntReg.fromString(tokens[2].lexeme) orelse return ParserError.InvalidSyntax;
				return Instr.Instr{ .R = .{ .instrOp = instrOp, .rd = rd, .rs = rs, .rr = .x30 } };
			},
			.MVN => {
				// mvn <rd>, <rs>
				if (tokens.len != 3) return ParserError.InvalidSyntax;
				if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
				const rd = Instr.Arch.IntReg.fromString(tokens[0].lexeme) orelse return ParserError.InvalidSyntax;
				const rs = Instr.Arch.IntReg.fromString(tokens[2].lexeme) orelse return ParserError.InvalidSyntax;
				return Instr.Instr{ .R = .{ .instrOp = instrOp, .rd = rd, .rs = rs, .rr = .x30 } };
			},
			else => {}
		}
	}

	// std.debug.print("Creating R-type instruction with op {any} and tokens {any}\n", .{instrOp, tokens});
	// Most of R-type instructions follow the format of [op] <rd>, <rs>, <rr>
	// Exceptions are NOT (not <rd>, <rs>), MV/MVN (mv/mvn <rd>, <rs>), and CMP (cmp <rs>, <rr>)

	switch (instrOp) {
		.ADD, .ADDS, .SUB, .SUBS, .OR, .AND, 
		.XOR, .LSL, .LSR, .ASR, 
		.MUL, .SMUL, .DIV, .SDIV => {
			// Format: [op] <rd>, <rs>, <rr>
			if (tokens.len != 5) return ParserError.InvalidSyntax;
			const rd = Instr.Arch.IntReg.fromString(tokens[0].lexeme) orelse return ParserError.InvalidSyntax;
			if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
			const rs = Instr.Arch.IntReg.fromString(tokens[2].lexeme) orelse return ParserError.InvalidSyntax;
			if (tokens[3].tokType != .COMMA) return ParserError.InvalidSyntax;
			const rr = Instr.Arch.IntReg.fromString(tokens[4].lexeme) orelse return ParserError.InvalidSyntax;

			return Instr.Instr{
				.R = .{
					.instrOp = instrOp,
					.rd = rd,
					.rs = rs,
					.rr = rr
				}
			};
		},
		.NOT => {
			if (tokens.len != 3) return ParserError.InvalidSyntax;
			const rd = Instr.Arch.IntReg.fromString(tokens[0].lexeme) orelse return ParserError.InvalidSyntax;
			if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
			const rs = Instr.Arch.IntReg.fromString(tokens[2].lexeme) orelse return ParserError.InvalidSyntax;

			return Instr.Instr{
				.R = .{
					.instrOp = instrOp,
					.rd = rd,
					.rs = rs,
					.rr = .x30
				}
			};
		},
		else => {
			std.debug.print("Creating R-type instruction for op {any} not yet implemented\n", .{instrOp});
			return ParserError.UnexpectedToken;
		}
	}
}

fn createMInstruction(instrOp: Opcodes.Opcode, tokens: []const Token.Token) !Instr.Instr {
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
	const rd = Instr.Arch.IntReg.fromString(tokens[0].lexeme) orelse return ParserError.InvalidSyntax;
	if (tokens[1].tokType != .COMMA) return ParserError.InvalidSyntax;
	if (tokens[2].tokType != .LBRACKET) return ParserError.InvalidSyntax;
	const rs = Instr.Arch.IntReg.fromString(tokens[3].lexeme) orelse return ParserError.InvalidSyntax;
	var rr: Instr.Arch.IntReg = .x30;
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
			rr = Instr.Arch.IntReg.fromString(tokens[6].lexeme) orelse return ParserError.InvalidSyntax;
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

	return Instr.Instr{
		.M = .{
			.instrOp = instrOp,
			.rd = rd,
			.rs = rs,
			.rr = rr,
			.simm9 = simm9
		}
	};
}

fn createSInstruction(instrOp: Opcodes.SysSubOp, tokens: []const Token.Token) !Instr.Instr {
	_ = tokens;
	// std.debug.print("Creating system instruction with op {any} and tokens {any}\n", .{instrOp, tokens});
	// For now, only SYSCALL exists, and it takes no arguments
	return Instr.Instr{
		.S = .{
			.instrOp = instrOp,
			.rd = .x0,
			.rs = .x0
		}
	};
}

fn isLastOperandRegister(tokens: []const Token.Token) bool {
	if (tokens.len == 0) return false;
	
	var lastCommaIndex: ?usize = null;
	for (tokens, 0..) |tok, i| {
		if (tok.tokType == .COMMA) {
			lastCommaIndex = i;
		}
	}
	
	if (lastCommaIndex) |idx| {
		const lastOpTokens = tokens[idx + 1..];
		if (lastOpTokens.len == 1) {
			if (Instr.Arch.IntReg.fromString(lastOpTokens[0].lexeme)) |_| {
				return true;
			}
		}
	} else {
		if (tokens.len == 1) {
			if (Instr.Arch.IntReg.fromString(tokens[0].lexeme)) |_| {
				return true;
			}
		}
	}
	return false;
}

pub fn parseInstruction(tokens: []const Token.Token) !Instr.Instr {
	if (tokens[0].tokType != .IDENTIFIER) return ParserError.UnexpectedToken;
	// std.debug.print("Parsing identifier...\n", .{});

	const instrName = tokens[0].lexeme;

	const instrOp: Opcodes.AnyOpcode = Opcodes.stringToOpcode(instrName) orelse {
		std.debug.print("Unknown instruction: {any}\n", .{instrName});
		return ParserError.UnexpectedToken;
	};

	var instr: Instr.Instr = undefined;

	switch (instrOp) {
		.opcode => |op| {
			switch (op) {
				.ADDI, .ADDSI, .SUBI, .SUBSI, .ORI, .ANDI, 
				.XORI, .LSLI, .LSRI, .ASRI,
				.NOTI => {
					const args = tokens[1..];
					if (isLastOperandRegister(args)) {
						const rOp = @as(Opcodes.Opcode, @enumFromInt(@intFromEnum(op) + 1));
						instr = try createRInstruction(rOp, args, null);
					} else {
						instr = try createIInstruction(op, args, null);
					}
				},
				.MVI => {
					const args = tokens[1..];
					if (isLastOperandRegister(args)) {
						instr = try createRInstruction(.OR, args, .MV);
					} else {
						instr = try createIInstruction(op, args, null);
					}
				},
				.ADD, .ADDS, .SUB, .SUBS, .OR, .AND, 
				.XOR, .LSL, .LSR, .ASR,
				.NOT => {
					const args = tokens[1..];
					if (!isLastOperandRegister(args)) {
						const iOp = @as(Opcodes.Opcode, @enumFromInt(@intFromEnum(op) - 1));
						instr = try createIInstruction(iOp, args, null);
					} else {
						instr = try createRInstruction(op, args, null);
					}
				},
				.MUL, .SMUL, .DIV, .SDIV => {
					instr = try createRInstruction(op, tokens[1..], null);
				},
				.LD, .LDB, .LDBS, .LDBZ, .LDH, .LDHS, .LDHZ, .STR, .STRB, .STRH => {
					instr = try createMInstruction(op, tokens[1..]);
				},
				else => {
					std.debug.print("Parsing for instruction op {any} not yet implemented\n", .{op});
					return ParserError.UnexpectedToken;
				}
			}
		},
		.sys => |sysOp| {
			instr = try createSInstruction(sysOp, tokens[1..]);
		},
		.fusedf => |fusedfOp| {
			_ = fusedfOp;
			std.debug.print("Parsing for fused floating point instruction not yet implemented\n", .{});
			return ParserError.UnexpectedToken;
		},
		.alias => |aliasOp| {
			const args = tokens[1..];
			switch (aliasOp) {
				.NOP => {
					instr = try createIInstruction(.ADDI, args, .NOP);
				},
				.MV => {
					if (isLastOperandRegister(args)) {
						instr = try createRInstruction(.OR, args, .MV);
					} else {
						instr = try createIInstruction(.MVI, args, null);
					}
				},
				.CMP, .CMPI => {
					if (isLastOperandRegister(args)) {
						instr = try createRInstruction(.SUBS, args, .CMP);
					} else {
						instr = try createIInstruction(.SUBI, args, .CMPI);
					}
				},
				.MVN, .MVNI => {
					if (isLastOperandRegister(args)) {
						instr = try createRInstruction(.SUB, args, .MVN);
					} else {
						instr = try createIInstruction(.SUBI, args, .MVNI);
					}
				},
			}
		}
	}
	return instr;
}

pub fn parseDirective(tokens: []const Token.Token) !Directive.Directive {
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