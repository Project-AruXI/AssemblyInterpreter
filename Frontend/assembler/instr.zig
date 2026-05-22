// zig fmt: off

const std = @import("std");

pub const Opcodes = @import("opcodes");
pub const Arch = @import("arch");


pub const InstrError = error {
	UnimplementedInstructionEncoding,
	InstructionEncodingError,
	UnreachableInstructionEncoding,
};

pub const I_Instr = struct {
	instrOp: Opcodes.Opcode,
	rd: Arch.IntReg,
	rs: Arch.IntReg,
	imm14: u16,

	pub fn encode(this: I_Instr) !u32 {
		const opcode: u8 = @intFromEnum(this.instrOp);

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
	instrOp: Opcodes.Opcode,
	rd: Arch.IntReg,
	rs: Arch.IntReg,
	rr: Arch.IntReg,

	pub fn encode(this: R_Instr) !u32 {
		const opcode: u8 = @intFromEnum(this.instrOp);

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
		.rd = .x5,
		.rs = .x10,
		.rr = .x15,
	};

	const encoding = try addInstr.encode();
	const expectedEncoding = 0b1000000_0_000000000_01010_01111_00101;
	try std.testing.expectEqual(expectedEncoding, encoding);


	// TODO
}


pub const M_Instr = struct {
	instrOp: Opcodes.Opcode,
	rd: Arch.IntReg,
	rs: Arch.IntReg,
	rr: Arch.IntReg,
	simm9: i9,

	pub fn encode(this: M_Instr) !u32 {
		const opcode: u8 = @intFromEnum(this.instrOp);

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
		.rd = .x10,
		.rs = .sp,
		.rr = .x30,
		.simm9 = 16,
	};

	const encoding0 = try ldInstr0.encode();
	const expectedEncoding0 = 0b0001010_0_000010000_11111_11110_01010;
	try std.testing.expectEqual(expectedEncoding0, encoding0);


	// ld x0, [x10], x2
	const ldInstr1 = M_Instr{
		.instrOp = .LD,
		.rd = .x0,
		.rs = .x10,
		.rr = .x2,
		.simm9 = 0,
	};

	const encoding1 = try ldInstr1.encode();
	const expectedEncoding1 = 0b0001010_0_000000000_01010_00010_00000;
	try std.testing.expectEqual(expectedEncoding1, encoding1);


	// str x5, [x20]
	const strInstr = M_Instr{
		.instrOp = .STR,
		.rd = .x5,
		.rs = .x20,
		.rr = .x30,
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
	instrOp: Opcodes.SysSubOp,
	rd: Arch.IntReg,
	rs: Arch.IntReg,

	pub fn encode(this: S_Instr) !u32 {
		const opcode = @intFromEnum(Opcodes.Opcode.SYS);

		if (this.instrOp == .SYSCALL) {
			return (@as(u32, opcode) << 24) | (@as(u32, @intFromEnum(this.instrOp)) << 19);
		} else if (this.instrOp == .HLT) {
			return (@as(u32, opcode) << 24) | (@as(u32, @intFromEnum(this.instrOp)) << 19);
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