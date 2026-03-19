// zig fmt: off

const std = @import("std");


pub const DirectiveType = enum {
	Set
};

pub const Directive = struct {
	directiveType: DirectiveType,
	symbol: []const u8,
	exprNum: u32
};