// zig fmt: off

const std = @import("std");


	// OP_NOP,

	// OP_MUL,
	// OP_SMUL,
	// OP_DIV,
	// OP_SDIV,
	// OP_ADD,
	// OP_ADDS,
	// OP_SUB,
	// OP_SUBS,
	// OP_OR,
	// OP_AND,
	// OP_XOR,
	// OP_NOT,
	// OP_LSL,
	// OP_LSR,
	// OP_ASR,
	// OP_CMP,
	// OP_MV,
	// OP_MVN,

	// OP_SXB,
	// OP_SXH,
	// OP_UXB,
	// OP_UXH,

	// OP_LD,
	// OP_LDB,
	// OP_LDBS,
	// OP_LDBZ,
	// OP_LDH,
	// OP_LDHS,
	// OP_LDHZ,
	// OP_STR,
	// OP_STRB,
	// OP_STRH,

	// OP_UB,
	// OP_UBR,
	// OP_B,
	// OP_CALL,
	// OP_RET,

	// OP_ADDF,
	// OP_SUBF,
	// OP_MULF,
	// OP_DIVF,
	// OP_LDF,
	// OP_STRF,
	// OP_MVF,

	// OP_SYS, // Applies to all S-types
	// OP_SYSCALL,
	// OP_HLT,
	// OP_SI,
	// OP_DI,
	// OP_ERET,
	// OP_LDIR,
	// OP_MVCSTR,
	// OP_LDCSTR,
	// OP_RESR,

	// OP_ERROR = -1

pub const Instr = enum {
	NOP,
	MUL,
	SMUL,
	DIV,
	SDIV,
	ADD,
	ADDS,
	SUB,
	SUBS,
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

	ADDF,
	SUBF,
	MULF,
	DIVF,
	LDF,
	STRF,
	MVF,

	SYS, // Applies to all S-types
	SYSCALL,
	HLT,
	_SI,
	_DI,
	ERET,
	LDIR,
	MVCSTR,
	LDCSTR,
	RESR,

	ERROR
};



	// imap[0b10000000] = OP_ADD;
	// imap[0b10000001] = OP_ADD;
	// imap[0b10001000] = OP_ADDS;
	// imap[0b10001001] = OP_ADDS;
	// imap[0b10010000] = OP_SUB;
	// imap[0b10010001] = OP_SUB;
	// imap[0b10011000] = OP_SUBS;
	// imap[0b10011001] = OP_SUBS;
	// imap[0b10100000] = OP_MUL;
	// imap[0b10100010] = OP_SMUL;
	// imap[0b10101000] = OP_DIV;
	// imap[0b10101010] = OP_SDIV;
	// imap[0b01000000] = OP_OR;
	// imap[0b01000001] = OP_OR;
	// imap[0b01000010] = OP_AND;
	// imap[0b01000011] = OP_AND;
	// imap[0b01000100] = OP_XOR;
	// imap[0b01000101] = OP_XOR;
	// imap[0b01000110] = OP_NOT;
	// imap[0b01000111] = OP_NOT;
	// imap[0b01001000] = OP_LSL;
	// imap[0b01001001] = OP_LSL;
	// imap[0b01001010] = OP_LSR;
	// imap[0b01001011] = OP_LSR;
	// imap[0b01001100] = OP_ASR;
	// imap[0b01001101] = OP_ASR;
	// imap[0b10000100] = OP_MV;
	// imap[0b00000000] = OP_SXB;
	// imap[0b00000000] = OP_SXH;
	// imap[0b00000000] = OP_UXB;
	// imap[0b00000000] = OP_UXH;
	// imap[0b00010100] = OP_LD;
	// imap[0b00110100] = OP_LDB;
	// imap[0b01010100] = OP_LDBS;
	// imap[0b01110100] = OP_LDBZ;
	// imap[0b10010100] = OP_LDH;
	// imap[0b10110100] = OP_LDHS;
	// imap[0b11010100] = OP_LDHZ;
	// imap[0b00011100] = OP_STR;
	// imap[0b00111100] = OP_STRB;
	// imap[0b01011100] = OP_STRH;
	// imap[0b11000000] = OP_UB;
	// imap[0b11000010] = OP_UBR;
	// imap[0b11000100] = OP_B;
	// imap[0b11000110] = OP_CALL;
	// imap[0b11001000] = OP_RET;
	// imap[0b10111110] = OP_SYS;
	// // imap[0b00000000] = OP_ADDF;
	// // imap[0b00000000] = OP_SUBF;
	// // imap[0b00000000] = OP_MULF;
	// // imap[0b00000000] = OP_DIVF;
	// // imap[0b00000000] = OP_LDF;
	// // imap[0b00000000] = OP_STRF;
	// // imap[0b00000000] = OP_MVF;


// An instruction map that maps an opcode to the corresponding Instr
// Size of map is 1<<8
// pub var instrMap = [_]Instr{Instr.ERROR} ** 256;