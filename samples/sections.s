.glob main

.text
main:
	ld x0, =STR
	ld x1, [x0]
	add x1, x1, #1
	str x1, [x0]


.data
	STR: .string "Interpreting"
	CARR: .byte 0x00, 0x01, 0b10, 3
	SARR: .hword 0x1111, 0x2026
	IARR: .word 0x110ba034, 0xffff00dd

	FL: .float 3.4