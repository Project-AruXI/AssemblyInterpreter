// zig fmt: off

const std = @import("std");
const Token = @import("token.zig");



pub const LexerError = error{
	InvalidCharacter,
	UnexpectedEndOfInput,
};

const LexerState = struct {
	pos: usize,
	peekedChar: ?u8,
};


fn isRegister(lexeme: []const u8) bool {
	// Assert that size is at least 2
	if (lexeme.len < 2) {
		return false;
	}
	
	
	// Quickly check against sp, ir, lr, xb, xz, xr (ignore case)
	if (std.ascii.eqlIgnoreCase(lexeme, "sp") or std.ascii.eqlIgnoreCase(lexeme, "ir") or std.ascii.eqlIgnoreCase(lexeme, "lr") or 
			std.ascii.eqlIgnoreCase(lexeme, "xb") or std.ascii.eqlIgnoreCase(lexeme, "xz") or std.ascii.eqlIgnoreCase(lexeme, "xr")) {
		return true;
	}

	if (!std.ascii.isDigit(lexeme[1])) {
		return false;
	}

	// Check for x0-x30, v0-v5, f0-f15, a0-a9, c0-c4, s0-s9

	if ((lexeme[0] == 'x' or lexeme[0] == 'X') and lexeme.len >= 3 and std.ascii.isDigit(lexeme[2]) and (lexeme[1] == '0' or (lexeme[1] == '1' and lexeme[2] <= '9') or (lexeme[1] == '2' and lexeme[2] <= '9') or (lexeme[1] == '3' and lexeme[2] <= '0'))) {
		return true;
	}
	if ((lexeme[0] == 'v' or lexeme[0] == 'V') and lexeme.len >= 2 and std.ascii.isDigit(lexeme[1]) and lexeme[1] <= '5') {
		return true;
	}
	if ((lexeme[0] == 'f' or lexeme[0] == 'F') and lexeme.len >= 2 and std.ascii.isDigit(lexeme[1]) and lexeme[1] <= '5') {
		return true;
	}
	if ((lexeme[0] == 'a' or lexeme[0] == 'A') and lexeme.len >= 2 and std.ascii.isDigit(lexeme[1]) and lexeme[1] <= '9') {
		return true;
	}
	if ((lexeme[0] == 'c' or lexeme[0] == 'C') and lexeme.len >= 2 and std.ascii.isDigit(lexeme[1]) and lexeme[1] <= '4') {
		return true;
	}
	if ((lexeme[0] == 's' or lexeme[0] == 'S') and lexeme.len >= 2 and std.ascii.isDigit(lexeme[1]) and lexeme[1] <= '9') {
		return true;
	}

	return false;
}


fn getNextToken(state: *LexerState, input: []const u8) !?Token.Token {
	// Skip whitespace
	while (state.pos < input.len and std.ascii.isWhitespace(input[state.pos])) : (state.pos += 1) {}

	if (state.pos >= input.len) {
		return null; // End of input
	}

	// Peek
	if (state.pos + 1 < input.len) {
		state.peekedChar = input[state.pos + 1];
	} else {
		state.peekedChar = null;
	}

	var token = Token.Token{
		.lexeme = undefined,
		.tokType = .UNKNOWN,
	};

	switch (input[state.pos]) {
		'\n' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .NL;
		},
		0 => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .EOL;
		},
		'+' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .PLUS;
		},
		'-' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .MINUS;
		},
		'*' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .ASTERISK;
		},
		'/' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .DIVIDE;
		},
		'&' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .BITWISE_AND;
		},
		'|' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .BITWISE_OR;
		},
		'^' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .BITWISE_XOR;
		},
		'~' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .BITWISE_NOT;
		},
		'<' => {
			// Check for '<<'
			if (state.peekedChar != null and state.peekedChar.? == '<') {
				token.lexeme = input[state.pos..state.pos+2];
				token.tokType = .SHIFT_LEFT;
				state.pos += 1; // Consume extra character
			} else {
				return LexerError.InvalidCharacter;
			}
		},
		'>' => {
			// Check for '>>'
			if (state.peekedChar != null and state.peekedChar.? == '>') {
				token.lexeme = input[state.pos..state.pos+2];
				token.tokType = .SHIFT_RIGHT;
				state.pos += 1; // Consume extra character
			} else {
				return LexerError.InvalidCharacter;
			}
		},
		'@' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .LP;
		},
		',' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .COMMA;
		},
		'#' => {
			// Indicating immediate value, needs to be followed by an integer, otherwise invalid
			if (state.pos + 1 < input.len and (std.ascii.isAlphanumeric(input[state.pos + 1]) or input[state.pos + 1] == '-' or input[state.pos + 1] == '+')) {
				// Advance until non-alphanumeric character to get full immediate value
				var endPos = state.pos + 1;
				while (endPos < input.len and (std.ascii.isAlphanumeric(input[endPos]) or input[endPos] == '-' or input[endPos] == '+')) : (endPos += 1) {}

				token.lexeme = input[state.pos..endPos];
				token.tokType = .IMM;
				state.pos = endPos - 1; // Move back to last character of immediate
			} else {
				return LexerError.InvalidCharacter;
			}
		},
		'\'' => {
			// Character literal, consume until closing quote
			var endPos = state.pos + 1;
			while (endPos < input.len and input[endPos] != '\'') : (endPos += 1) {}
			if (endPos >= input.len) {
				return LexerError.UnexpectedEndOfInput;
			}
			token.lexeme = input[state.pos..endPos+1];
			token.tokType = .CHAR;
			state.pos = endPos; // Move past closing quote
		},
		'(' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .LPAREN;
		},
		')' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .RPAREN;
		},
		'[' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .LSQBRACKET;
		},
		']' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .RSQBRACKET;
		},
		'{' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .LBRACKET;
		},
		'}' => {
			token.lexeme = input[state.pos..state.pos+1];
			token.tokType = .RBRACKET;
		},
		'.' => {
			// A dot can have multiple meanings: directive or part of floating point
			// For now, assume FP and consume following digits if present
			if (state.peekedChar != null and std.ascii.isDigit(state.peekedChar.?)) {
				var endPos = state.pos + 1;
				while (endPos < input.len and (std.ascii.isDigit(input[endPos]) or input[endPos] == '.')) : (endPos += 1) {}
				token.lexeme = input[state.pos..endPos];
				token.tokType = .FLOAT;
				state.pos = endPos - 1;
			} else {
				return LexerError.InvalidCharacter;
			}
		},
		'"' => {
			// String literal, consume until closing quote, allowing for escaped quotes
			var endPos = state.pos + 1;
			while (endPos < input.len) {
				if (input[endPos] == '"' and input[endPos - 1] != '\\') {
					break;
				}
				endPos += 1;
			}
			if (endPos >= input.len) {
				return LexerError.UnexpectedEndOfInput;
			}
			token.lexeme = input[state.pos..endPos+1];
			token.tokType = .STRING;
			state.pos = endPos; // Move past closing quote
		},
		else => {
			if (std.ascii.isAlphabetic(input[state.pos]) or input[state.pos] == '_') {
				// Identifier or register
				var endPos = state.pos;
				while (endPos < input.len and (std.ascii.isAlphanumeric(input[endPos]) or input[endPos] == '_')) : (endPos += 1) {}

				token.lexeme = input[state.pos..endPos];
				// If `[idenfier]:` then label, need to consume ':'
				if (endPos < input.len and input[endPos] == ':') {
					token.tokType = .LABEL;
					state.pos = endPos + 1; // Move past ':'
				} else if (isRegister(token.lexeme)) {
					token.tokType = .REGISTER;
				} else {
					token.tokType = .IDENTIFIER;
				}
				state.pos = endPos - 1;
			} else if (std.ascii.isDigit(input[state.pos])) {
				// Number (integer or float)
				var endPos = state.pos;

				// Check for hex
				if (input[state.pos] == '0' and state.peekedChar != null and (state.peekedChar.? == 'x' or state.peekedChar.? == 'X')) {
					endPos += 2; // Skip '0x'
					while (endPos < input.len and (std.ascii.isHex(input[endPos]))) : (endPos += 1) {}
					

					// It can be the case there is a non-hex character immediately
					if (endPos < input.len and (std.ascii.isAlphabetic(input[endPos]) or input[endPos] == '_')) {
						// Then this is actually an identifier that starts with a number, which is invalid
						return LexerError.InvalidCharacter;
					}

					token.lexeme = input[state.pos..endPos];
					token.tokType = .INTEGER;
					state.pos = endPos - 1;
				} else if (input[state.pos] == '0' and state.peekedChar != null and (state.peekedChar.? == 'b' or state.peekedChar.? == 'B')) {
					endPos += 2; // Skip '0b'
					while (endPos < input.len and (input[endPos] == '0' or input[endPos] == '1')) : (endPos += 1) {}

					// It can be the case there is a non-binary character immediately
					if (endPos < input.len and (std.ascii.isAlphabetic(input[endPos]) or input[endPos] == '_')) {
						// Then this is actually an identifier that starts with a number, which is invalid
						return LexerError.InvalidCharacter;
					}

					token.lexeme = input[state.pos..endPos];
					token.tokType = .INTEGER;
					state.pos = endPos - 1;
				} else {
					while (endPos < input.len and (std.ascii.isDigit(input[endPos]))) : (endPos += 1) {}
				}
				// Check for float
				if (endPos < input.len and input[endPos] == '.') {
					endPos += 1; // Skip '.'
					while (endPos < input.len and std.ascii.isDigit(input[endPos])) : (endPos += 1) {}

					token.lexeme = input[state.pos..endPos];
					token.tokType = .FLOAT;
					state.pos = endPos - 1;
				} else {
					token.lexeme = input[state.pos..endPos];
					token.tokType = .INTEGER;
					state.pos = endPos - 1;
				}
			} else {
				return LexerError.InvalidCharacter;
			}
		}
	}
	state.pos += 1;

	return token;
}

pub fn lex(allocator: std.mem.Allocator, instrStr: []const u8) ![]Token.Token {
	// std.debug.print("Lexing instruction string: {s}", .{instrStr});

	// ArrayList to hold tokens, need to convert to slice before returning
	var tokensList = try std.ArrayList(Token.Token).initCapacity(allocator, 10);
	defer tokensList.deinit(allocator);

	var lexerState = LexerState{
		.pos = 0,
		.peekedChar = null,
	};

	var tok = getNextToken(&lexerState, instrStr) catch |err| {
		std.debug.print("Lexer error: {any}\n", .{err});
		return err;
	};
	while (tok != null and tok.?.tokType != .NL) {
		// std.debug.print("Got token: {s}\n", .{tok.?.lexeme});
		try tokensList.append(allocator, tok.?);
		tok = getNextToken(&lexerState, instrStr) catch |err| {
			// std.debug.print("Lexer error: {any}\n", .{err});
			return err;
		};
	}

	return tokensList.toOwnedSlice(allocator);
}

test "Lexer I-Type Instructions" {
	var gpa = std.heap.DebugAllocator(.{}).init;
	defer _ = gpa.deinit();
	const allocator = gpa.allocator();

	const instrStr0 = "mv x0, #0x1234";
	const tokens = lex(allocator, instrStr0) catch |err| {
		std.debug.print("Lexing error: {any}\n", .{err});
		return;
	};
	errdefer allocator.free(tokens);

	const expectedTokens = [_]Token.Token{
		Token.Token{ .lexeme = "mv", .tokType = .IDENTIFIER },
		Token.Token{ .lexeme = "x0", .tokType = .REGISTER },
		Token.Token{ .lexeme = ",", .tokType = .COMMA },
		Token.Token{ .lexeme = "#0x1234", .tokType = .IMM },
	};
	for (tokens,0..tokens.len) |token, i| {
		std.debug.print("Token {d}: {s} (type: {any})\n", .{i, token.lexeme, token.tokType});
		std.debug.print("Expected Token {d}: {s} (type: {any})\n", .{i, expectedTokens[i].lexeme, expectedTokens[i].tokType});

		try std.testing.expectEqualStrings(expectedTokens[i].lexeme, token.lexeme);
		try std.testing.expect(token.tokType == expectedTokens[i].tokType);
	}

	allocator.free(tokens);
}

// TODO: Add more tests for different instruction formats, labels, directives, etc.