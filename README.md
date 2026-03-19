# Assembly Interpreter

## Frontend


CLI:
`./asmintrep [options] [file?]`
- If file provided - execute the assembly code in the file and print any output
- If no file provided - start a REPL for interactive assembly execution

Options:
- `--mem-size [size]`: Sets memory size for the interpreter (code+data+stack+heap). Default is 64KB.
- `--stack-size [size]`: Sets stack size for the interpreter. Default is 4KB.
- `--heap-size [size]`: Sets heap size for the interpreter. Default is 16KB.
- `--help`: Show usage information and exit
- `--avext`: Enable AVExt (if supported by the engine)


Repl-only options:
- `--allow-system`: Allow execution of system commands. Use with caution as it directly touches the engine.


File-only options:


### Repl

```sh
$ ./asmintrep
> /registers
[show register values]
> /memory [address] [length] [format?(hex|dec|bin)]
[show memory contents starting at address for length bytes in specified format (default hex)]
> mv x0, #42
x0 <- 42
> mv x1, #0x2
x1 <- 2
> add x2, x0, x1
x2 <- 44
> /exit
Exiting REPL...
$ 
```

Commands:
- `/registers`: Print current register values (GP registers, IR, CSTR, FP registers, Vector registers) in both hex and decimal
- `/register [reg]`: Print value of specific register in both hex and decimal
- `/memory [address|label|segment] [length] [format?(hex|dec|bin)]`: Print memory contents starting at address for length bytes in specified format (default hex)
	- If `[address]` is replaced by either `text`, `data`, `heap`, or `stack`, it will print from the start of that segment
		- For `stack`, it starts from the current stack pointer (SP) value
	- If `[address]` is replaced by a label, it will print from the address associated with that label (FUTURE WORK)
		- Uses the label map created by the memory component to resolve label names to addresses
		- If no label found, it errors out
- `/exit`: Exit the REPL
- `/dump`: Dump CPU state and memory contents to a file for debugging
- `/help`: Show available commands and usage
- `/write [address] [label] [str]`: Write a string to memory at the specified address and associate it with a label
	- The string will be null-terminated in memory
	- The label will be added to the label map with the address it was written to
		- The address is enforced to be within the data segment, otherwise it will error out
		- If a label with the same name already exists, it will error out to prevent accidental overwrites
- `/read [address|label] [length]`: Read length bytes from memory starting at address and print it as a string
	- The address must be within the data segment, otherwise it will error out
	- If a label is provided instead of an address, it will resolve the label to an address using the label map
	- It will read until it encounters a null terminator or reaches the specified length, whichever comes first

System Commands (only available if `--allow-system` is enabled, use with caution):
- `/set-reg [reg] [value]`: Set register to a specific value
	- Only registers not allowed to be set is IR and CSTR
	- Value will be truncated or padded with zeros to fit the register size
- `/set-mem [address] [value] [length]`: Set memory at address to a specific value
	- Size can be any number of bytes within 1 to 8
	- Value will be truncated or padded with zeros to fit the specified size


Disallowed Instructions:
- Branching instructions
- Privileged instructions


### File

```sh
$ ./asmintrep file.as
[any prints done by the assembly code]
```


### IO

For repl:
```sh
> /write 0x0 greeting "Hello, World!"
<Wrote "Hello, World!" to memory at address 0x0 and associated it with label "greeting">
> /read greeting 13
"Hello, World!"
> /read 0x0 13
"Hello, World!"
```

For file:
```as
.const
msg: .string "Enter a number: "
.bss
buffer: .zero 3
.text
% Print the prompt
mv x0, #0x1
mv a0, #16
mv a1, msg
syscall
% Read user input into buffer
mv x0, #0x0
mv a0, #3
mv a1, buffer
syscall
% Print the input back to the user
mv x0, #0x1
mv a0, #3
mv a1, buffer
syscall
```
```sh
$ ./asmintrep file.as
Enter a number: 20
20
```

## Backend

Two functional units:
- CPU
- Memory


### API

Main Engine:
- `engineInit(Config) -> AruEngine`
- `AruEngine.getCPU() -> CPU`
- `AruEngine.getMemory() -> Memory`
- `engineDeinit(engine)`

CPU:
- `getRegister(register) -> RegisterValue`
- `setRegister(register, value)`
- `step()`
- `reset()`
- `dumpState() -> CpuState`


Memory:
- `read(address, length) -> []u8`
- `write(address, data)`
- `dumpMemory(start, length) -> []u8`
- `createLabelMap() -> LabelMap<string,u32>`
- `addLabel(labelName, address)`
- `getLabelMap() -> LabelMap<string,u32>`





### Usage

```zig
const Engine = @import("Engine");

let aruEngine = Engine.engineInit(.{}); // Use default config

const cpu = aruEngine.getCPU();
const memory = aruEngine.getMemory();


```





## NOTES

Instruction Feedback on Repl:

Data movement/manipulation instructions:
```sh
> mv x0, #42
x0 <- 42
> mv x1, #0x2
x1 <- 2
> add x2, x0, x1
x2 <- 44
> add x2, x2, #10
x2 <- 54
> ld x3, [x1]
x3 <- [0x2] (value at memory address 0x2)
> str x3, [x1]
0x2 <- x3 (value of x3)
```
> Need to figure out how to provide feedback on `cmp`


## FUTURE WORK

- Implement label maps
- Implement "symbol" map; allowing runtime constants
	- Aka doing `.set name val` would place `val` with key `name` in the symbol map, then doing `mv x0, name`