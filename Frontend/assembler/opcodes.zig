// AUTO-GENERATED — DO NOT EDIT
// Source: opcodes.json  |  ISA: Aru32 v1.1.0  |  Generated: 2026-05-11
// To update: edit opcodes.json then run scripts/generate.py

// zig fmt: off

const std = @import("std");

pub const meta = .{
  .wordSize = 32,
  .opcodeBits = 8,
  .intRegisters = 32,
  .fpRegisters = 16,
  .vecRegisters = 6,
};

// ── Opcodes ───────────────────────────────────────────────────────────────────
// I/R pairs share a mnemonic. The I-variant opcode is even, R-variant is odd.
pub const Opcode = enum(u8) {

  // Bi
  UB = 0x5B, // ub — 

  // Bu
  UBR = 0x5C, // ubr — 

  // Bc
  B = 0x5D, // b — 

  // Bi
  CALL = 0x5E, // call — 

  // Bu
  RET = 0x5F, // ret — 

  // FM
  ADDF = 0x6E, // addf — FP add

  // fp
  SUBF = 0x6F, // subf — FP subtract

  // fp
  MULF = 0x70, // mulf — FP multiply

  // fp
  DIVF = 0x71, // divf — FP divide

  // fp
  SQRTF = 0x72, // sqrtf — FP square root

  // fp
  MINF = 0x73, // minf — FP minimum

  // fp
  MAXF = 0x74, // maxf — FP maximum

  // fp
  ABSF = 0x75, // absf — FP absolute value

  // fp
  NEGF = 0x76, // negf — FP negate

  // 
  FUSEDF = 0x77, // fusedf — FP fused operations

  // fp
  MVF = 0x7D, // mvf — FP register copy

  // fp
  MVFI = 0x7E, // mvfi — FP to int reg — bit-pattern, no conversion

  // fp
  MVIF = 0x7F, // mvif — Int reg to FP — bit-pattern, no conversion

  // fp_convert
  CVTFU = 0x80, // cvtfu — FP to unsigned int32

  // fp_convert
  CVTFS = 0x81, // cvtfs — FP to signed int32

  // fp_convert
  CVTUF = 0x82, // cvtuf — Unsigned int32 to FP

  // fp_convert
  CVTSF = 0x83, // cvtsf — Signed int32 to FP

  // fp
  CLASSF = 0x87, // classf — FP classify — result bitmask to int reg

  // fp
  CMPF = 0x88, // cmpf — Compare FP

  // fp
  CMPFE = 0x89, // cmpfe — Compare FP, exception raise

  // I
  ADD_I = 0x90, // add — 

  // R
  ADD_R = 0x91, // add — 

  // I
  ADDS_I = 0x92, // adds — 

  // R
  ADDS_R = 0x93, // adds — 

  // I
  SUB_I = 0x94, // sub — 

  // R
  SUB_R = 0x95, // sub — 

  // I
  SUBS_I = 0x96, // subs — 

  // R
  SUBS_R = 0x97, // subs — 

  // R
  MUL = 0x98, // mul — 

  // R
  SMUL = 0x99, // smul — 

  // R
  DIV = 0x9A, // div — 

  // R
  SDIV = 0x9B, // sdiv — 

  // I
  OR_I = 0xA2, // or — 

  // R
  OR_R = 0xA3, // or — 

  // I
  AND_I = 0xA4, // and — 

  // R
  AND_R = 0xA5, // and — 

  // I
  XOR_I = 0xA6, // xor — 

  // R
  XOR_R = 0xA7, // xor — 

  // I
  NOT_I = 0xA8, // not — 

  // R
  NOT_R = 0xA9, // not — 

  // I
  LSL_I = 0xAA, // lsl — 

  // R
  LSL_R = 0xAB, // lsl — 

  // I
  LSR_I = 0xAC, // lsr — 

  // 
  LSR_R = 0xAD, // lsr — 

  // I
  ASR_I = 0xAE, // asr — 

  // 
  ASR_R = 0xAF, // asr — 

  // I
  MVI = 0xB0, // mvi — 

  // R
  SXB = 0xB1, // sxb — 

  // R
  SXH = 0xB2, // sxh — 

  // R
  UXB = 0xB3, // uxb — 

  // R
  UXH = 0xB4, // uxh — 

  // M
  LD = 0xC0, // ld — 

  // M
  LDB = 0xC1, // ldb — 

  // M
  LDBS = 0xC2, // ldbs — 

  // M
  LDBZ = 0xC3, // ldbz — 

  // M
  LDH = 0xC4, // ldh — 

  // M
  LDHS = 0xC5, // ldhs — 

  // M
  LDHZ = 0xC6, // ldhz — 

  // M
  STR = 0xC7, // str — 

  // M
  STRB = 0xC8, // strb — 

  // M
  STRH = 0xC9, // strh — 

  // fp_memory
  LDF = 0xCA, // ldf — FP load word

  // fp_memory
  STRF = 0xCB, // strf — FP store word

  // S
  SYS = 0xFF, // sys — System specific instruction in sub-opcode field (S-type)


  pub fn fromByte(b: u8) ?Opcode {
    return std.meta.intToEnum(Opcode, b) catch null;
  }
  pub fn mnemonic(self: Opcode) []const u8 {
    return switch (self) {

      .UB => "ub",

      .UBR => "ubr",

      .B => "b",

      .CALL => "call",

      .RET => "ret",

      .ADDF => "addf",

      .SUBF => "subf",

      .MULF => "mulf",

      .DIVF => "divf",

      .SQRTF => "sqrtf",

      .MINF => "minf",

      .MAXF => "maxf",

      .ABSF => "absf",

      .NEGF => "negf",

      .FUSEDF => "fusedf",

      .MVF => "mvf",

      .MVFI => "mvfi",

      .MVIF => "mvif",

      .CVTFU => "cvtfu",

      .CVTFS => "cvtfs",

      .CVTUF => "cvtuf",

      .CVTSF => "cvtsf",

      .CLASSF => "classf",

      .CMPF => "cmpf",

      .CMPFE => "cmpfe",

      .ADD_I => "add",

      .ADD_R => "add",

      .ADDS_I => "adds",

      .ADDS_R => "adds",

      .SUB_I => "sub",

      .SUB_R => "sub",

      .SUBS_I => "subs",

      .SUBS_R => "subs",

      .MUL => "mul",

      .SMUL => "smul",

      .DIV => "div",

      .SDIV => "sdiv",

      .OR_I => "or",

      .OR_R => "or",

      .AND_I => "and",

      .AND_R => "and",

      .XOR_I => "xor",

      .XOR_R => "xor",

      .NOT_I => "not",

      .NOT_R => "not",

      .LSL_I => "lsl",

      .LSL_R => "lsl",

      .LSR_I => "lsr",

      .LSR_R => "lsr",

      .ASR_I => "asr",

      .ASR_R => "asr",

      .MVI => "mvi",

      .SXB => "sxb",

      .SXH => "sxh",

      .UXB => "uxb",

      .UXH => "uxh",

      .LD => "ld",

      .LDB => "ldb",

      .LDBS => "ldbs",

      .LDBZ => "ldbz",

      .LDH => "ldh",

      .LDHS => "ldhs",

      .LDHZ => "ldhz",

      .STR => "str",

      .STRB => "strb",

      .STRBH => "strbh",

      .LDF => "ldf",

      .STRF => "strf",

      .SYS => "sys",

    };
  }
  pub fn isImmediate(self: Opcode) bool { return (@intFromEnum(self) & 1) == 0; }
  pub fn isRegister(self: Opcode)  bool { return (@intFromEnum(self) & 1) == 1; }
};

// ── Sub-opcodes ───────────────────────────────────────────────────────────────

pub const FusedfSubOp = enum(u8) {

  FMADDF = 0x00, // FP fused multiply-add: fd = fs1*fs2 + fs3

  FMSUBF = 0x01, // FP fused multiply-subtract: fd = fs1*fs2 - fs3

  FNMADDF = 0x02, // FP negated fused multiply-add: fd = -(fs1*fs2 + fs3)

  FNMSUBF = 0x03, // FP negated fused multiply-subtract

};

pub const SysSubOp = enum(u8) {

  SYSCALL = 0x00, // Invoke OS syscall

  HLT = 0x01, // Halt processor

  SI = 0x02, // Set interrupt bit

  DI = 0x03, // Disable interrupt bit

  ERET = 0x04, // Return from exception

  MVIR = 0x05, // Move IR to integer register

  WCSTR = 0x06, // Move integer register to CSTR

  RCSTR = 0x07, // Move CSTR to integer register

  WFCSR = 0x08, // Move integer register to FCSR

  RFCSR = 0x09, // Move FCSR to integer register

};


// ── Aliases ───────────────────────────────────────────────────────────────────

pub const NOP = Opcode.add_i; // No-op (add r0, r0, #0)
