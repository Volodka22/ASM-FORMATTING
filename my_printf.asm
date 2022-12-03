section .text
global _print

; void print(char *out_buf, const char *format, const char *hex_number);
; портит все несохраняемые регистры (такие дела)
_print:
	mov eax, [esp + 12]; hex_number
	push ebx; is negative? and other flags
	push esi; width
	xor esi, esi
	xor ebx, ebx
	; start parse
	cmp byte [eax], 45
	jnz parse
	inc eax
	xor bl, 1
parse:
	movzx ecx, byte [eax]
	call _parse_hex_char
	
	xor edx, edx
	dec eax
	;найти конец
	find_end:
		inc eax
		inc edx
		movzx esi, byte [eax]
		test esi, esi
		jnz find_end
	; eax is end of hex_number
	
	cmp edx, 33
	jnz parse_positive
	test ecx, 8
	jz parse_positive
	xor bl, 1
	xor bl, 64; is neg hex?

parse_positive:

	_add_empty_lists:
	mov edx, 80
	add_zero:
		dec esp
		mov byte [esp], 0
		dec edx
		jnz add_zero


	mov byte [esp], 1


	;начать перебирать с конца
	parsing_loop:
		dec eax

		cmp byte [eax], 45
		jz end_parsing_loop

		mov edx, 40
		copy_last:
			dec esp
			mov cl, [esp + 40]
			mov byte [esp], cl
			dec edx
			jnz copy_last


		movzx ecx, byte [eax]

		call _parse_hex_char
		call _reverse_ecx_if_negative
		call _mul_last_list_on_ecx
		call _add_copy_to_first

		add esp, 40; Delete list

		mov ecx, 16
		call _mul_last_list_on_ecx


		cmp eax, [esp + 100] ; 12 + 8(registers) + 80 (2*list)
		ja parsing_loop

	end_parsing_loop:

	add esp, 40; Delete list

	test bl, 64
	jz parse_format
	call _add_one

parse_format:

	xor edx, edx
	mov eax, [esp + 56] ; 8 + 8(registers) + 40(list)

	parse_flags:
		movzx ecx, byte [eax]
		inc eax

		test ecx, ecx
		jz end_parse_format
		cmp ecx, 32
		jz parse_space
		cmp ecx, 43
		jz parse_plus
		cmp ecx, 45
		jz parse_minus
		cmp ecx, 48
		jz parse_zero

		jmp parse_width

		parse_space:
			or ebx, 2
			jmp parse_flags
		parse_plus:
			or ebx, 4
			jmp parse_flags
		parse_minus:
			or ebx, 8
			jmp parse_flags
		parse_zero:
			or ebx, 16
			jmp parse_flags

	parse_width:
		mov edx, 10
		xchg eax, esi
		mul edx
		xchg eax, esi
		sub ecx, 48
		add esi, ecx

		movzx ecx, byte [eax]
		inc eax
		test ecx, ecx
		jnz parse_width

	end_parse_format:


	lea eax, [esp + 39];

	mov edx, 0
	find_size_list:
		mov cl, byte [eax]
		test cl, cl
		jnz end_size_find
		cmp edx, 39
		jz end_size_find
		dec eax
		inc edx
		jmp find_size_list

	end_size_find:

	mov ecx, 40
	sub ecx, edx
	xchg ecx, edx

	; ифаем случай с 0
	cmp edx, 1
	jnz end_fix_ebx
	cmp byte [eax], 0
	jnz end_fix_ebx

	not ebx
	or ebx, 1
	not ebx
	end_fix_ebx:

	test ebx, 7; is neg (1), space(2) or plus (4)
	jz fix_width
	inc edx

fix_width:
	cmp esi, edx
	jae find_insert_position
	mov esi, edx

find_insert_position:
	mov ecx, [esp + 52]; 4 + 8 + 40
	test ebx, 8
	jz right_justify

left_justify:
	call _insert_sign
	call _insert_int

	test esi, esi
	jz end_print

	insert_space_from_left:
		mov byte [ecx], 32

		inc ecx
		dec esi
		jnz insert_space_from_left

	jmp end_print

right_justify:
	test ebx, 16
	jnz insert_zeros
	insert_space_from_right:
		cmp esi, edx
		jz end_space_insert
		mov byte [ecx], 32

		inc ecx
		dec esi
		jmp insert_space_from_right

end_space_insert:
	call _insert_sign
	jmp insert_int_from_right

insert_zeros:
	call _insert_sign
	insert_zeros_from_right:
		cmp esi, edx
		jz insert_int_from_right
		mov byte [ecx], 48

		inc ecx
		dec esi
		jmp insert_zeros_from_right

insert_int_from_right:
	call _insert_int

end_print:

	mov byte [ecx], 0

	add esp, 40; Delete list

	pop esi
	pop ebx

	ret



; может показаться, что эта функция портит кучу регистров (на самом деле 0)
_insert_sign:
	test bl, 1
	jnz insert_minus
	test bl, 4
	jnz insert_plus
	test bl, 2
	jnz insert_space
	jmp end_insert_sign

	insert_minus:
		mov byte [ecx], 45
		dec edx
		dec esi
		inc ecx
		jmp end_insert_sign

	insert_plus:
		mov byte [ecx], 43
		dec edx
		dec esi
		inc ecx
		jmp end_insert_sign

	insert_space:
		mov byte [ecx], 32
		dec edx
		dec esi
		inc ecx

	end_insert_sign:
	ret

; ломает ebx
_insert_int:
	insert_int_loop:
		mov bh, [eax]
		add bh, 48
		mov [ecx], bh

		inc ecx
		dec eax
		dec esi
		dec edx
		jnz insert_int_loop
	ret

_parse_hex_char:

	parse_number:
		cmp ecx, 57; сравниваем с '9'
		ja parse_big_letter
		sub ecx, 48
		jmp end_parse_char

	parse_big_letter:
		cmp ecx, 70
		ja parse_small_letter
		sub ecx, 65
		add ecx, 10
		jmp end_parse_char

	parse_small_letter:
		sub ecx, 97
		add ecx, 10

	end_parse_char:
		ret


_reverse_ecx_if_negative:
	test ebx, 64
	jz end_reverse_ecx
	not ecx
	and ecx, 15

	end_reverse_ecx:
	ret

; здесь и далее считаем, что нам необходимо 40 цифр для 128 бит :)

; портит edx
_mul_last_list_on_ecx:
	mov [esp - 4], eax
	mov [esp - 8], ebx
	mov [esp - 12], edi
	mov [esp - 16], esi

	xor ebx, ebx; iterator
	xor edi, edi; reminder
	mov esi, 10

	add esp, 4

	mul_last:
		add esp, ebx
		movzx eax, byte [esp]

		mul ecx
		add eax, edi
		xor edx, edx
		div esi

		mov byte [esp], dl; ???
		mov edi, eax

		sub esp, ebx
		inc ebx
		cmp ebx, 40
		jnz mul_last


	sub esp, 4

	mov esi, [esp - 16]
	mov edi, [esp - 12]
	mov ebx, [esp - 8]
	mov eax, [esp - 4]
	ret

; портит edx и ecx
_add_copy_to_first:
	mov [esp - 4], eax
	mov [esp - 8], ebx
	mov [esp - 12], esi
	mov [esp - 16], ebp

	xor edx, edx
	mov esi, 10
	mov ebx, 40

	add esp, 4

	parse_copy:
		movzx ecx, byte [esp]
		add esp, 80

		mov ebp, ebx
		add_to_first:
			movzx eax, byte [esp]
			add eax, ecx

			xor edx, edx
			div esi

			mov ecx, eax
			mov [esp], dl; ???

			inc esp
			dec ebp
			jnz add_to_first

		sub esp, ebx
		sub esp, 80
		inc esp
		dec ebx
		test ebx, ebx
		jnz parse_copy

	sub esp, 40
	sub esp, 4

	mov ebp, [esp - 16]
	mov esi, [esp - 12]
	mov ebx, [esp - 8]
	mov eax, [esp - 4]

	ret

; портит ecx, edx
_add_one:
	add esp, 4

	mov edx, 0
	add_one:
		add esp, edx
		mov cl, byte [esp]
		inc cl
		sub esp, edx

		mov byte [esp], cl
		cmp cl, 10
		jb end_add_one

		mov byte [esp], 0;
		inc edx
		sub edx, 40
		jnz add_one

	end_add_one:

	sub esp, 4
	ret
