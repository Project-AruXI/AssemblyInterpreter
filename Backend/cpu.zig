// zig fmt: off

const std = @import("std");

const Mem = @import("mem.zig");
const Instr = @import("instr.zig").Instr;
const OS = @import("os.zig");
// var instrMap = @import("instr.zig").instrMap;
var instrMap = [_]Instr{Instr.ERROR} ** 256;


/// Represents a single vector register in the Aru32 Architecture.
/// A vector register is 512 bits (16 4-bytes or 8 8-bytes)
pub const VecReg = struct {
	data: union {
		_v32: [16]f32,
		_v64: [8]f64,
	}
};

/// A catch-all union for register values, which can be either integer, floating-point, or vector types.
pub const RegisterValue = union(enum) {
	Int: u32,
	Float: f32,
	Vector: VecReg,
};

/// A catch-all enum for all possible register types in the Aru32 Architecture, including general-purpose, floating-point, vector, and control/status registers.
pub const Register = union(enum) {
	GP: u32, // General Purpose Register x0-x30
	SP,      // Stack Pointer
	FP: u32,  // Floating Point Register f0-f15
	VR: u32,  // Vector Register v0-v5
	CSTR,    // Control and Status Register
	IR
};

pub const CPUError = error{
	InvalidInstruction,
	MemoryAccessViolation,
	IllegalRegisterAccess,
	DivisionByZero,
};

pub const IntrepIAruCPU = struct {
	gpRegs: [31]u32,
	ir: u32,
	sp: u32,
	fpRegs: [16]f32,
	vecRegs: [6]VecReg,
	cstr: u16,
	mem: *Mem.AruMemory,

	pub fn init(mem: *Mem.AruMemory) IntrepIAruCPU {
		std.debug.print("Initializing CPU...\n", .{});


		// Initialize instruction map
		instrMap[0b10000000] = Instr.ADD;
		instrMap[0b10000001] = Instr.ADD;
		instrMap[0b10001000] = Instr.ADDS;
		instrMap[0b10001001] = Instr.ADDS;
		instrMap[0b10010000] = Instr.SUB;
		instrMap[0b10010001] = Instr.SUB;
		instrMap[0b10011000] = Instr.SUBS;
		instrMap[0b10011001] = Instr.SUBS;
		instrMap[0b10100000] = Instr.MUL;
		instrMap[0b10100010] = Instr.SMUL;
		instrMap[0b10101000] = Instr.DIV;
		instrMap[0b10101010] = Instr.SDIV;
		instrMap[0b01000000] = Instr.OR;
		instrMap[0b01000001] = Instr.OR;
		instrMap[0b01000010] = Instr.AND;
		instrMap[0b01000011] = Instr.AND;
		instrMap[0b01000100] = Instr.XOR;
		instrMap[0b01000101] = Instr.XOR;
		instrMap[0b01000110] = Instr.NOT;
		instrMap[0b01000111] = Instr.NOT;
		instrMap[0b01001000] = Instr.LSL;
		instrMap[0b01001001] = Instr.LSL;
		instrMap[0b01001010] = Instr.LSR;
		instrMap[0b01001011] = Instr.LSR;
		instrMap[0b01001100] = Instr.ASR;
		instrMap[0b01001101] = Instr.ASR;
		instrMap[0b10000100] = Instr.MV;
		instrMap[0b00010100] = Instr.LD;
		instrMap[0b00110100] = Instr.LDB;
		instrMap[0b01010100] = Instr.LDBS;
		instrMap[0b01110100] = Instr.LDBZ;
		instrMap[0b10010100] = Instr.LDH;
		instrMap[0b10110100] = Instr.LDHS;
		instrMap[0b11010100] = Instr.LDHZ;
		instrMap[0b00011100] = Instr.STR;
		instrMap[0b00111100] = Instr.STRB;
		instrMap[0b01011100] = Instr.STRH;
		instrMap[0b11000000] = Instr.UB;
		instrMap[0b11000010] = Instr.UBR;
		instrMap[0b11000100] = Instr.B;
		instrMap[0b11000110] = Instr.CALL;
		instrMap[0b11001000] = Instr.RET;
		instrMap[0b10111110] = Instr.SYS;


		return IntrepIAruCPU{
			.gpRegs = [_]u32{0} ** 31,
			.ir = 0x0,
			.sp = 0x0,
			.fpRegs = [_]f32{0} ** 16,
			.vecRegs = [_]VecReg{ VecReg{ .data = .{ ._v32 = [_]f32{0.0} ** 16 } } } ** 6,
			.cstr = 0x0,
			.mem = mem
		};
	}

	/// Steps the CPU to execute the next instruction.
	pub fn step(this: *IntrepIAruCPU) !void {
		std.debug.print("Stepping CPU...\n", .{});
		std.debug.print("Current IR: 0x{x}\n", .{this.ir});

		// Fetch
		const instr = this.mem.readWord(this.ir) catch {
			std.debug.print("Memory read error at address 0x{x}\n", .{this.ir});
			return CPUError.MemoryAccessViolation;
		};
		std.debug.print("Fetched instruction: 0x{x}\n", .{instr});
		this.ir += 4;

		try this.decodeExecute(instr);
	}

	pub fn reset(this: *IntrepIAruCPU) void {
		std.debug.print("Resetting CPU...\n", .{});
		this.gpRegs = [_]u32{0} ** 31;
		this.ir = 0x0;
		this.sp = 0x0;
		this.fpRegs = [_]f32{0} ** 16;
		this.vecRegs = [_]VecReg{ VecReg{ .data = .{ ._v32 = [_]f32{0.0} ** 16 } } } ** 6;
		this.cstr = 0x0;
	}

	pub fn dumpState(this: *IntrepIAruCPU) void {
		// TODO: Need to dump to a file instead
		std.debug.print("Dumping CPU state...\n", .{});
		std.debug.print("GP Registers:\n", .{});
		for (this.gpRegs, 0..) |reg, idx| {
			std.debug.print("  x{d}: {x}\n", .{idx, reg});
		}
		std.debug.print("IR: {x}\n", .{this.ir});
		std.debug.print("SP: {x}\n", .{this.sp});
		std.debug.print("FP Registers:\n", .{});
		for (this.fpRegs, 0..) |reg, idx| {
			std.debug.print("  f{d}: {}\n", .{idx, reg});
		}
		std.debug.print("Vector Registers:\n", .{});
		for (this.vecRegs, 0..) |vecReg, idx| {
			std.debug.print("  v{d}:\n", .{idx});
			for (vecReg.data._v32, 0..) |elem, elemIdx| {
				std.debug.print("    [{d}]: {x}\n", .{elemIdx, elem});
			}
		}
		std.debug.print("CSTR: {x}\n", .{this.cstr});
	}

	pub fn getRegister(this: *const IntrepIAruCPU, register: Register) RegisterValue {
		switch (register) {
			.GP => return .{ .Int = this.gpRegs[register.GP] },
			.SP => return .{ .Int = this.sp },
			.FP => return .{ .Float = this.fpRegs[register.FP] },
			.VR => return .{ .Vector = this.vecRegs[register.VR] },
			.CSTR => return .{ .Int = this.cstr },
			.IR => return .{ .Int = this.ir },
		}
		@panic("Unhandled register type");
	}

	pub fn setRegister(this: *IntrepIAruCPU, register: Register, value: RegisterValue) void {
		switch (register) {
			.GP => this.gpRegs[register.GP] = value.Int,
			.SP => this.sp = value.Int,
			.FP => this.fpRegs[register.FP] = value.Float,
			.VR => this.vecRegs[register.VR] = value.Vector,
			.CSTR => this.cstr = @truncate(value.Int),
			.IR => this.ir = value.Int,
		}
	}

	fn decodeExecute(this: *IntrepIAruCPU, instr: u32) !void {
		std.debug.print("Decoding and executing instruction {x}...\n", .{instr});
		const opbits = (instr >> 24) & 0xFF;
		const op = instrMap[opbits];
		std.debug.print("Decoded opcode: {x}, operation: {any}\n", .{opbits, op});

		// Since some instructions have I and R types, the only difference is the first bit in the opcode (for the most part)
		// Other than MUL, SMUL, DIV, and SDIV (which are only R-type), the other R-type instructions shared with I-type
		//   have the first bit in the opcode set to 1
		const isIType = (opbits & 0b1) == 0;
		// Note that `isIType` only applies when the instruction is one of the shared I/R types.

		// Extract all possible immediates and registers
		const rd = instr & 0x1F; // rd is bits 0-4
		// I-Types
		// imm14 starts at bit 10, goes for 14 bits to bit 23, unsigned
		const imm14 = (instr >> 10) & 0x3FFF;
		const rsI = (instr >> 5) & 0x1F; // rs is bits 5-9
		// R-Types
		const rsR = (instr >> 10) & 0x1F;
		const rrR = (instr >> 5) & 0x1F;
		// M-Types
		// simm9 start at bit 15, goes for 9 bits to bit 23, signed
		const simm9: i16 = @intCast((instr >> 15) & 0x1FF);
		const rsM = (instr >> 10) & 0x1F;
		const rrM = (instr >> 5) & 0x1F;
		// S-Types
		const rsS = (instr >> 5) & 0x1F;
		const subop = (instr >> 19) & 0x1F;

		switch (op) {
			.ADD, .ADDS, .SUB, .SUBS, .OR, .AND, .XOR, .NOT, .LSL, .LSR, .ASR, .CMP, .MV, .MVN => {
				if (isIType) try this.executeIType(rd, rsI, imm14, op) else try this.executeRType(rd, rsR, rrR, op);
			},
			.NOP => {
				// Do nothing
				// This most likely will not execute since NOP is encoded as add xz, xz, 0 so it will run through IR
			},
			.MUL, .SMUL, .DIV, .SDIV => {
				try this.executeRType(rd, rsR, rrR, op);
			},
			.LD, .LDB, .LDBS, .LDBZ, .LDH, .LDHS, .LDHZ, .STR, .STRB, .STRH => {
				try this.executeMType(rd, rsM, rrM, simm9, op);
			},
			.UB, .UBR, .B, .CALL, .RET => {
				// For now, we will not implement branching and will just print an error if we encounter these instructions
				std.debug.print("Branching instructions not implemented yet: {any}\n", .{op});
				return CPUError.InvalidInstruction;
			},
			.SYS => {
				try this.executeSType(rd, rsS, subop);
			},
			else => {
				std.debug.print("Invalid instruction with opcode {x}\n", .{opbits});
				return CPUError.InvalidInstruction;
			}
		}
	}

	fn executeIType(this: *IntrepIAruCPU, rd: u32, rs: u32, imm14: u32, op: Instr) !void {
		std.debug.print("Executing I-type instruction {any} with rd=x{d}, rs=x{d}, imm14={x}\n", .{op, rd, rs, imm14});

		var aluOp: ALUOp = undefined;
		var updateFlags: bool = false;

		switch (op) {
			.ADD, .ADDS => {
				aluOp = .ADD;
				updateFlags = op == .ADDS;
			},
			.SUB, .SUBS => {
				aluOp = .SUB;
				updateFlags = op == .SUBS;
			},
			.OR => aluOp = .OR,
			.AND => aluOp = .AND,
			.XOR => aluOp = .XOR,
			.NOT => aluOp = .NOT,
			.LSL => aluOp = .LSL,
			.LSR => aluOp = .LSR,
			.ASR => aluOp = .ASR,
			.CMP => {
				aluOp = .SUB;
				updateFlags = true;
			},
			.MV => {
				aluOp = .ADD;
			},
			.MVN => {
				aluOp = .SUB;
			},
			else => {
				std.debug.print("Invalid I-type instruction {any}\n", .{op});
				return CPUError.InvalidInstruction;
			}
		}

		const operand1 = this.gpRegs[rs];
		const operand2 = imm14;

		const result = ALU.run(aluOp, operand1, operand2, &this.cstr, updateFlags) catch |err| {
			std.debug.print("ALU error: {any}\n", .{err});
			return err;
		};
		if (rd != 30) this.gpRegs[rd] = result;
	}

	fn executeRType(this: *IntrepIAruCPU, rd: u32, rs: u32, rr: u32, op: Instr) !void {
		std.debug.print("Executing R-type instruction {any} with rd=x{d}, rs=x{d}, rr=x{d}\n", .{op, rd, rs, rr});

		var aluOp: ALUOp = undefined;
		var updateFlags: bool = false;

		switch (op) {
			.MUL, .SMUL => aluOp = .MUL,
			.DIV, .SDIV => aluOp = .DIV,
			.ADD, .ADDS => {
				aluOp = .ADD;
				updateFlags = op == .ADDS;
			},
			.SUB, .SUBS => {
				aluOp = .SUB;
				updateFlags = op == .SUBS;
			},
			.AND => aluOp = .AND,
			.OR => aluOp = .OR,
			.XOR => aluOp = .XOR,
			.NOT => aluOp = .NOT,
			.LSL => aluOp = .LSL,
			.LSR => aluOp = .LSR,
			.ASR => aluOp = .ASR,
			.CMP => {
				aluOp = .SUB;
				updateFlags = true;
			},
			.MV => {
				aluOp = .OR;
			},
			.MVN => {
				aluOp = .SUB;
			},
			else => {
				std.debug.print("Invalid R-type instruction {any}\n", .{op});
				return CPUError.InvalidInstruction;
			}
		}
		const operand1 = this.gpRegs[rs];
		const operand2 = this.gpRegs[rr];

		const result = ALU.run(aluOp, operand1, operand2, &this.cstr, updateFlags) catch |err| {
			std.debug.print("ALU error: {any}\n", .{err});
			return err;
		};
		if (rd != 30) this.gpRegs[rd] = result;
	}

	fn executeMType(this: *IntrepIAruCPU, rd: u32, rs: u32, rr: u32, simm9: i16, op: Instr) !void {
		if (rd == 30) return;

		const addr = this.gpRegs[rs] + this.gpRegs[rr] + @as(u32, @intCast(simm9));

		std.debug.print("Executing M-type instruction {any} with rd=x{d}, rs=x{d}, rr=x{d}, simm9={d}\n", .{op, rd, rs, rr, simm9});
		// For all intents and purposes, all operands (rs, rr, simm9) will be used
		// This only works with the assumption that those instructions that do not use it have the unused operands set to 
		//   either XZ for registers or 0 for immediate
		switch (op) {
			.LD => {
				// Load 4 bytes from memory at address gpRegs[rs] + gpRegs[rr] + simm9, store in gpRegs[rd]
				std.debug.print("Calculated memory address for load: 0x{x}\n", .{addr});
				this.gpRegs[rd] = this.mem.readWord(addr) catch {
					std.debug.print("Memory read error at address 0x{x}\n", .{addr});
					return CPUError.MemoryAccessViolation;
				};
			},
			.LDB => {
				// Load 1 byte from memory at address gpRegs[rs] + gpRegs[rr] + simm9, store in gpRegs[rd] keeping the upper 3 bytes unchanged
				std.debug.print("Calculated memory address for load: 0x{x}\n", .{addr});
				const byte = this.mem.readByte(addr) catch {
					std.debug.print("Memory read error at address 0x{x}\n", .{addr});
					return CPUError.MemoryAccessViolation;
				};
				this.gpRegs[rd] = (this.gpRegs[rd] & 0xFFFFFF00) | @as(u32, byte);
			},
			.LDBS => {
				// Load 1 byte from memory at address gpRegs[rs] + gpRegs[rr] + simm9, store in gpRegs[rd] with sign extension
				std.debug.print("Calculated memory address for load: 0x{x}\n", .{addr});
				const byte = this.mem.readByte(addr) catch {
					std.debug.print("Memory read error at address 0x{x}\n", .{addr});
					return CPUError.MemoryAccessViolation;
				};
				// Sign-extend the loaded byte into the full 32-bit register
				if ((byte & 0x80) != 0) this.gpRegs[rd] = 0xFFFFFF00 | @as(u32, byte) else this.gpRegs[rd] = @as(u32, byte);
			},
			.LDBZ => {
				// Load 1 byte from memory at address gpRegs[rs] + gpRegs[rr] + simm9, store in gpRegs[rd] with zero extension
				std.debug.print("Calculated memory address for load: 0x{x}\n", .{addr});
				const byte = this.mem.readByte(addr) catch {
					std.debug.print("Memory read error at address 0x{x}\n", .{addr});
					return CPUError.MemoryAccessViolation;
				};
				this.gpRegs[rd] = @as(u32, byte);
			},
			.LDH => {
				// Load 2 bytes from memory at address gpRegs[rs] + gpRegs[rr] + simm9, store in gpRegs[rd] keeping the upper 2 bytes unchanged
				std.debug.print("Calculated memory address for load: 0x{x}\n", .{addr});
				const half = this.mem.readHalfWord(addr) catch {
					std.debug.print("Memory read error at address 0x{x}\n", .{addr});
					return CPUError.MemoryAccessViolation;
				};
				this.gpRegs[rd] = (this.gpRegs[rd] & 0xFFFF0000) | @as(u32, half);
			},
			.LDHS => {
				// Load 2 bytes from memory at address gpRegs[rs] + gpRegs[rr] + simm9, store in gpRegs[rd] with sign extension
				std.debug.print("Calculated memory address for load: 0x{x}\n", .{addr});
				const half = this.mem.readHalfWord(addr) catch {
					std.debug.print("Memory read error at address 0x{x}\n", .{addr});
					return CPUError.MemoryAccessViolation;
				};
				// Sign-extend the loaded halfword into the full 32-bit register
				if ((half & 0x8000) != 0) this.gpRegs[rd] = 0xFFFF0000 | @as(u32, half) else this.gpRegs[rd] = @as(u32, half);
			},
			.LDHZ => {
				// Load 2 bytes from memory at address gpRegs[rs] + gpRegs[rr] + simm9, store in gpRegs[rd] with zero extension
				std.debug.print("Calculated memory address for load: 0x{x}\n", .{addr});
				const half = this.mem.readHalfWord(addr) catch {
					std.debug.print("Memory read error at address 0x{x}\n", .{addr});
					return CPUError.MemoryAccessViolation;
				};
				this.gpRegs[rd] = @as(u32, half);
			},
			.STR => {
				// Store 4 bytes to memory at address gpRegs[rs] + gpRegs[rr] + simm9 from gpRegs[rd]
				std.debug.print("Calculated memory address for store: 0x{x}\n", .{addr});
				try this.mem.writeWord(addr, this.gpRegs[rd]);
			},
			.STRB => {
				// Store 1 byte to memory at address gpRegs[rs] + gpRegs[rr] + simm9 from the least significant byte of gpRegs[rd]
				std.debug.print("Calculated memory address for store: 0x{x}\n", .{addr});
				try this.mem.writeByte(addr, @truncate(this.gpRegs[rd]));
			},
			.STRH => {
				// Store 2 bytes to memory at address gpRegs[rs] + gpRegs[rr] + simm9 from the least significant half of gpRegs[rd]
				std.debug.print("Calculated memory address for store: 0x{x}\n", .{addr});
				try this.mem.writeHalfWord(addr, @truncate(this.gpRegs[rd]));
			},
			else => {
				std.debug.print("Invalid M-type instruction {any}\n", .{op});
				return CPUError.InvalidInstruction;
			}
		}
	}

	fn executeSType(this: *IntrepIAruCPU, rd: u32, rs: u32, subop: u32) !void {
		std.debug.print("Executing S-type instruction with rd=x{d}, rs=x{d}, subop={x}\n", .{rd, rs, subop});

		// For now, only SYS instruction is syscall, which has subop of 0b00010
		if (subop == 0b00010) {
			// Syscall number is stored in x0
			std.debug.print("Executing SYS instruction (system call) with syscall number of {d}\n", .{this.gpRegs[0]});
			// For now, we will just print the syscall number and not actually implement any syscalls
			// Syscalls will be delegated to the OS module, which will handle the actual implementation of each syscall
			try OS.handleSyscall(.{.stype = this.gpRegs[0]}, this.mem);
		} else {
			std.debug.print("Invalid S-type instruction with subop {x}\n", .{subop});
			return CPUError.InvalidInstruction;
		}
	}
};

const ALUOp = enum {
	ADD,
	SUB,
	AND,
	OR,
	XOR,
	NOT,
	LSL,
	LSR,
	ASR,
	MUL,
	DIV
};

const ALU = struct {
	// ALU operations would be defined here
	fn run(op: ALUOp, operand1: u32, operand2: u32, cstr: *u16, updateFlags: bool) !u32 {
		var result: u32 = 0;
		switch (op) {
			ALUOp.ADD => result = operand1 + operand2,
			ALUOp.SUB => result = operand1 - operand2,
			ALUOp.AND => result = operand1 & operand2,
			ALUOp.OR => result = operand1 | operand2,
			ALUOp.XOR => result = operand1 ^ operand2,
			ALUOp.NOT => result = ~operand1,
			ALUOp.LSL => result = operand1 << @intCast(operand2),
			ALUOp.LSR => result = operand1 >> @intCast(operand2),
			ALUOp.ASR => {
				const signed: i32 = @intCast(operand1);
				const shift: i32 = @intCast(operand2);
				const arith = signed >> @intCast(shift);
				result = @intCast(arith);
			},
			ALUOp.MUL => result = operand1 * operand2,
			ALUOp.DIV => result = if (operand2 != 0) operand1 / operand2 else return CPUError.DivisionByZero
		}
		if (updateFlags) {
			// Lower 4 bits of CSTR are flags: Carry (bit 3), Overflow (bit 2), Negative (bit 1), Zero (bit 0)
			var flags: u16 = 0;
			if (result == 0) flags |= 0b0001; // Zero flag
			if ((result & 0x80000000) != 0) flags |= 0b0010; // Negative flag
			// Carry and Overflow:
			if (op == ALUOp.ADD) {
				if (result < operand1) flags |= 0b1000; // Carry
				if (((operand1 ^ operand2) & 0x80000000) == 0 and ((operand1 ^ result) & 0x80000000) != 0) flags |= 0b0100; // Overflow
			} else if (op == ALUOp.SUB) {
				if (result > operand1) flags |= 0b1000; // Carry (borrow)
				if (((operand1 ^ operand2) & 0x80000000) != 0 and ((operand1 ^ result) & 0x80000000) != 0) flags |= 0b0100; // Overflow
			}
			cstr.* = (cstr.* & 0xFFF0) | flags; // Update only the lower 4 bits of CSTR
			std.debug.print("Updated CSTR flags: {b}\n", .{flags});
			std.debug.print("New CSTR value: {x}\n", .{cstr.*});
		}
		return result;
	}
};

const FPUOp = enum {
	FADD,
	FSUB,
	FMUL,
	FDIV,
};

const FPU = struct {
	fn run(op: FPUOp, operand1: f32, operand2: f32) !f32 {
		var result: f32 = 0;
		switch (op) {
			FPUOp.FADD => result = operand1 + operand2,
			FPUOp.FSUB => result = operand1 - operand2,
			FPUOp.FMUL => result = operand1 * operand2,
			FPUOp.FDIV => result = if (operand2 != 0.0) operand1 / operand2 else return CPUError.DivisionByZero,
			else => @panic("Invalid FPU operation"),
		}
		return result;
	}
};

const VPU = struct {
	// VPU operations would be defined here
};