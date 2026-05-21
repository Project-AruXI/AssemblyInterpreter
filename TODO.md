# Project TODOs (as of 2026-05-12)

## Frontend

### repl.zig
- Several commands are stubbed with TODOs:
  - `/dump`: Not implemented. (See: `case .Dump => { // TODO }`)
  - `/read`, `/write`: Not implemented. (See: `case .Read => { // TODO }`, `case .Write => { // TODO }`)
  - Directive processing: `processDirective` function has `// TODO` and incomplete logic for `.set` and other directives.

### command.zig
- TODO: Allow greater size or something (likely for command parsing or memory/register handling).
  - Code: `// TODO: Allow greater size or something`

### assembler/lexer.zig
- TODO: Add more tests for different instruction formats, labels, directives, etc.
  - Code: `// TODO: Add more tests for different instruction formats, labels, directives, etc.`

### assembler/instr.zig
- TODO: (Details not shown, but present at the top of the file)

## Backend

### cpu.zig
- Branching instructions are not implemented:
  - Code: `std.debug.print("Branching instructions not implemented yet: {any}\n", .{op});`
- TODO: Need to dump to a file instead (currently just prints CPU state).
  - Code: `// TODO: Need to dump to a file instead`