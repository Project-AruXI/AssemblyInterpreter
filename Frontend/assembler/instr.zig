// zig fmt: off

const std = @import("std");


pub const InstrOp = enum {
	ADD,
	ADDS,
	SUB,
	SUBS,
	MUL,
	SMUL,
	DIV,
	SDIV,
	OR,
	AND,
	XOR,
	NOT,
	LSL,
	LSR,
	ASR,
	CMP,
	MV,
	MVN,
	SXB,
	SXH,
	UXB,
	UXH,
	LD,
	LDB,
	LDBS,
	LDBZ,
	LDH,
	LDHS,
	LDHZ,
	STR,
	STRB,
	STRH,
	UB,
	UBR,
	B,
	CALL,
	RET,
	NOP,
	SYSCALL,
};

pub const Reg = enum {
	X0, X1, X2, X3, X4, X5, X6, X7, X8, X9, X10, X11, X12, X13, X14, X15,
	X16, X17, X18, X19, X20, X21, X22, X23, X24, X25, X26, X27, X28, X29, X30, 
	SP, IR
};

pub const InstrError = error {
	UnimplementedInstructionEncoding,
	InstructionEncodingError,
	UnreachableInstructionEncoding,
};

pub const I_Instr = struct {
	instrOp: InstrOp,
	rd: Reg,
	rs: Reg,
	imm14: u16,

	pub fn encode(this: I_Instr) !u32 {
		var opcode: u8 = 0b00000000;

		switch (this.instrOp) {
			.ADD, .NOP => opcode = 0b10000000,
			.ADDS => opcode = 0b10001000,
			.SUB, .MVN => opcode = 0b10010000,
			.SUBS, .CMP => opcode = 0b10011000,
			.OR => opcode = 0b01000000,
			.AND => opcode = 0b01000010,
			.XOR => opcode = 0b01000100,
			.NOT => opcode = 0b01000110,
			.LSL => opcode = 0b01001000,
			.LSR => opcode = 0b01001010,
			.ASR => opcode = 0b01001100,
			.MV => opcode = 0b10000100,
			else => return InstrError.UnimplementedInstructionEncoding
		}

		// By using intFromEnum, it is assumed that .rd and .rs are assigned the proper registers
		// For example, some instructions may use XZ as a default/preset register, and the parser should assign .rd or .rs to XZ accordingly
		// If no register is used and according to the ISA, the register should be 0s (encoded as X0)
		const rd: u8 = @intFromEnum(this.rd);
		const rs: u8 = @intFromEnum(this.rs);
		// Make sure the immediate has the upper unused bits cleared to avoid encoding errors
		const imm14: u16 = this.imm14 & 0x3FFF;

		const encoding: u32 = (@as(u32, opcode) << 24) | (@as(u32, imm14) << 10) | (@as(u32, rs) << 5) | @as(u32, rd);

		return encoding;
	}
};

pub const R_Instr = struct {
	instrOp: InstrOp,
	rd: Reg,
	rs: Reg,
	rr: Reg,

	pub fn encode(this: R_Instr) !u32 {
		var opcode: u8 = 0b00000000;

		switch (this.instrOp) {
			.ADD => opcode = 0b10000001,
			.ADDS => opcode = 0b10001001,
			.SUB => opcode = 0b10010001,
			.SUBS, .CMP => opcode = 0b10011001,
			.MUL => opcode = 0b10100000,
			.SMUL => opcode = 0b10100010,
			.DIV => opcode = 0b10101000,
			.SDIV => opcode = 0b10101010,
			.OR, .MV => opcode = 0b01000001,
			.AND => opcode = 0b01000011,
			.XOR => opcode = 0b01000101,
			.NOT => opcode = 0b01000111,
			.LSL => opcode = 0b01001001,
			.LSR => opcode = 0b01001011,
			.ASR => opcode = 0b01001101,
			else => return InstrError.UnimplementedInstructionEncoding
		}

		const rd: u8 = @intFromEnum(this.rd);
		const rs: u8 = @intFromEnum(this.rs);
		const rr: u8 = @intFromEnum(this.rr);

		const encoding: u32 = (@as(u32, opcode) << 24) | (@as(u32, rs) << 10) | (@as(u32, rr) << 5) | @as(u32, rd);

		return encoding;
	}
};

test "R Instr Encoding" {
	// add x5, x10, x15
	const addInstr = R_Instr{
		.instrOp = .ADD,
		.rd = .X5,
		.rs = .X10,
		.rr = .X15,
	};

	const encoding = try addInstr.encode();
	const expectedEncoding = 0b1000000_0_000000000_01010_01111_00101;
	try std.testing.expectEqual(expectedEncoding, encoding);


	// TODO
}


pub const M_Instr = struct {
	instrOp: InstrOp,
	rd: Reg,
	rs: Reg,
	rr: Reg,
	simm9: i9,

	pub fn encode(this: M_Instr) !u32 {
		var opcode: u8 = 0b00000000;

		switch (this.instrOp) {
			.LD => opcode = 0b00010100,
			.LDB => opcode = 0b00110100,
			.LDBS => opcode = 0b01010100,
			.LDBZ => opcode = 0b01110100,
			.LDH => opcode = 0b10010100,
			.LDHS => opcode = 0b10110100,
			.LDHZ => opcode = 0b11010100,
			.STR => opcode = 0b00011100,
			.STRB => opcode = 0b00111100,
			.STRH => opcode = 0b01011100,
			else => return InstrError.UnimplementedInstructionEncoding
		}

		const rd: u8 = @intFromEnum(this.rd);
		const rs: u8 = @intFromEnum(this.rs);
		const rr: u8 = @intFromEnum(this.rr);
		const simm9_i32: i32 = @as(i32, this.simm9);
		const simm9_masked: i32 = simm9_i32 & 0x1FF;
		const simm9_u32: u32 = @intCast(simm9_masked);

		const encoding: u32 = (@as(u32, opcode) << 24) | (simm9_u32 << 15) | (@as(u32, rs) << 10) | (@as(u32, rr) << 5) | @as(u32, rd);

		return encoding;
	}
};

test "M Instr Encoding" {
	// ld x10, [sp, #16]
	const ldInstr0 = M_Instr{
		.instrOp = .LD,
		.rd = .X10,
		.rs = .SP,
		.rr = .X30,
		.simm9 = 16,
	};

	const encoding0 = try ldInstr0.encode();
	const expectedEncoding0 = 0b0001010_0_000010000_11111_11110_01010;
	try std.testing.expectEqual(expectedEncoding0, encoding0);


	// ld x0, [x10], x2
	const ldInstr1 = M_Instr{
		.instrOp = .LD,
		.rd = .X0,
		.rs = .X10,
		.rr = .X2,
		.simm9 = 0,
	};

	const encoding1 = try ldInstr1.encode();
	const expectedEncoding1 = 0b0001010_0_000000000_01010_00010_00000;
	try std.testing.expectEqual(expectedEncoding1, encoding1);


	// str x5, [x20]
	const strInstr = M_Instr{
		.instrOp = .STR,
		.rd = .X5,
		.rs = .X20,
		.rr = .X30,
		.simm9 = 0,
	};

	const encoding2 = try strInstr.encode();
	const expectedEncoding2 = 0b0001110_0_000000000_10100_11110_00101;
	try std.testing.expectEqual(expectedEncoding2, encoding2);
}


// pub const Bi_Instr = struct {
//   instrOp: InstrOp,
//   simm24: i24
// };

// pub const Bu_Instr = struct {
//   instrOp: InstrOp,
//   rd: Reg
// };

// pub const Bc_Instr = struct {
//   instrOp: InstrOp,
//   cond: Cond,
//   simm19: i19
// };

pub const S_Instr = struct {
	instrOp: InstrOp,
	rd: Reg,
	rs: Reg,

	pub fn encode(this: S_Instr) !u32 {
		if (this.instrOp == .SYSCALL) {
			return 0b1011111_0_000100000_00000_00000_00000;
		} else {
			return InstrError.UnimplementedInstructionEncoding;
		}
	}
};

pub const Instr = union(enum) {
	I: I_Instr,
	R: R_Instr,
	M: M_Instr,
	// Bi: Bi_Instr,
	// Bu: Bu_Instr,
	// Bc: Bc_Instr,
	S: S_Instr,

	pub fn encode(this: Instr) !u32 {
		return switch (this) {
			inline else => |member| member.encode(),
		};
	}
};