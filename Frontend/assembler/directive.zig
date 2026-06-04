// zig fmt: off

const std = @import("std");

const Token = @import("token.zig").Token;


pub const DirectiveType = enum {
	Text, // .text
	Data, // .data

	Set, // .set SYMBOL, EXPR
	Glob, // .glob SYMBOL

	String, // .string "STR"
	Byte, // .byte EXPR{, ...EXPR}
	Hword, // .hword EXPR{, ...EXPR}
	Word, // .word EXPR{, ...EXPR}
	Float // .float FLOAT{, ...FLOAT}
};

pub const DirectiveTypeString = std.StaticStringMap(DirectiveType).initComptime(.{
	.{ ".text", .Text },
	.{ ".data", .Data },
	.{ ".set", .Set },
	.{ ".glob", .Glob },
	.{ ".string", .String },
	.{ ".byte", .Byte },
	.{ ".hword", .Hword },
	.{ ".word", .Word },
	.{ ".float", .Float }
});

pub const Directive = struct {
	directiveType: DirectiveType,

	symbol: ?[]const u8,

	stringData: ?[]const u8,

	numberData: ?std.ArrayList([]const Token),
	floatData: ?std.ArrayList(f32),


	_allocator: std.heap.DebugAllocator(.{})
};