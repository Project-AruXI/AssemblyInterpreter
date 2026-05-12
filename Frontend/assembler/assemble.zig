// zig fmt: off

const std = @import("std");
const Lexer = @import("lexer.zig");
const Parser = @import("parser.zig");
const _directive = @import("directive.zig");


pub fn assemble(instrStr: []const u8) !u32 {
	std.debug.print("Assembling {s}", .{instrStr});

	var gpa: std.heap.DebugAllocator(.{}) = .init;
	defer _ = gpa.deinit();
	const allocator = gpa.allocator();

	const tokens = Lexer.lex(allocator, instrStr) catch |err| {
		std.debug.print("Lexing error: {any}\n", .{err});
		return err;
	};
	// errdefer allocator.free(tokens); // Apparently not needed????
	defer allocator.free(tokens);

	const instr = Parser.parseInstruction(tokens) catch |err| {
		std.debug.print("Parsing error: {any}\n", .{err});
		return err;
	};

	const encoding = instr.encode() catch |err| {
		std.debug.print("Encoding error: {any}\n", .{err});
		return err;
	};

	// std.debug.print("Successfully assembled instruction: 0x{x} (0b{b})\n", .{encoding, encoding});

	return encoding;
}

pub fn assembleDirective(directiveStr: []const u8) !_directive.Directive {
	std.debug.print("Assembling directive {s}\n", .{directiveStr});
	

	var gpa: std.heap.DebugAllocator(.{}) = .init;
	defer _ = gpa.deinit();
	const allocator = gpa.allocator();

	const tokens = Lexer.lex(allocator, directiveStr) catch |err| {
		std.debug.print("Lexing error: {any}\n", .{err});
		return err;
	};
	errdefer allocator.free(tokens);
	defer allocator.free(tokens);

	const directive = Parser.parseDirective(tokens) catch |err| {
		std.debug.print("Parsing error: {any}\n", .{err});
		return err;
	};

	return directive;
}