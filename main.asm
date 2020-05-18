.cseg
.org 0x0000
	jmp setup

.org 0x0028
	jmp blink_ISR

.org 0x0046
	jmp collatz_ISR

.org 0x0072

setup:
	.def temp = r16
	.def cursor_x = r17	
	.def move_dir = r19
	.def zero = r20
	.def r24_last_val = r21

	;LED init
	ldi	r16, 0b10101010
	out DDRB, r16
	ldi	r16, 0b00001010
	sts DDRL, r16

	; set the stack pointer
	ldi temp, high(RAMEND)
	out SPH, temp
	ldi temp, low(RAMEND)
	out SPL, temp
	
	;Initialize ADC
	ldi temp, 0x87
	sts ADCSRA, temp
	ldi temp, 0x40
	sts ADMUX, temp

	; initialize the LCD
	;Set cursor to 3
	ldi ZH, high(lcd_x)
	ldi ZL, low(lcd_x)
	ldi temp, 5
	st Z, temp
	call lcd_init			
	
	; clear the screen
	call lcd_clr	

	;Show splashscreen
	ldi temp, low(splash_line1_p << 1)
	push temp
	ldi temp, high(splash_line1_p << 1)
	push temp
	ldi temp, low(splash_line2_p << 1)
	push temp
	ldi temp, high(splash_line2_p << 1)
	push temp

	call init_strings
	pop temp
	pop temp
	pop temp
	pop temp

	call update_lcd

	;Show splashscreen for a bit
	call delay
.	call delay

	;Load default strings to datamem
	ldi temp, low(line1_p << 1)
	push temp
	ldi temp, high(line1_p << 1)
	push temp
	ldi temp, low(line2_p << 1)
	push temp
	ldi temp, high(line2_p << 1)
	push temp

	call init_strings
	clr r24_last_val ;Nothing pressed
	call update_lcd 
	pop temp
	pop temp
	pop temp
	pop temp

	;Load our starting collatz value into memory (000)
	ldi ZH, high(colatz_cur_val) 
	ldi ZL, low(colatz_cur_val)
	ldi temp, 0
	st Z+, temp ;Low
	st Z+, temp ;Mid
	st Z+, temp ;High

	;Load our starting number picker value into memory (000)
	ldi ZH, high(colatz_start_val) 
	ldi ZL, low(colatz_start_val)
	ldi temp, 0
	st Z+, temp ;Low
	st Z+, temp ;High

	;Load our starting speed value into memory (0)
	ldi ZH, high(spd) 
	ldi ZL, low(spd)
	ldi temp, 0
	st Z, temp ;Low


	;Initialize blink timer
	call blink_timer_setup


	main:
		;Blank out digit spots to erase anything that will be left over
		ldi ZH, high(cnt_str_loc)
		ldi ZL, low(cnt_str_loc)
		ldi temp, 0x20
		st Z+, temp
		st Z+, temp
		st Z, temp

		ldi ZH, high(colatz_str_loc)
		ldi ZL, low(colatz_str_loc)
		st Z+, temp
		st Z+, temp
		st Z+, temp
		st Z+, temp
		st Z+, temp
		st Z, temp

		
		;Update collatz count on LCD
		;Push str. len onto stack
		ldi temp, 3
		push temp
		;Push dest. address onto stack
		ldi temp, low(cnt_str_loc)
		push temp
		ldi temp, high(cnt_str_loc)
		push temp

		ldi YH, high(colatz_cnt)
		ldi YL, low(colatz_cnt)
		ld temp, Y+
		push temp ;Push the number onto stack
		ld temp, Y
		push temp
		clr temp
		push temp ;Padding for 3 byte requirement
				
		call int_to_string
		pop temp
		pop temp
		pop temp
		pop temp
		pop temp
		pop temp
		;;;



		;Update collatz cur val on LCD
		;Push str. len onto stack
		ldi temp, 6
		push temp
		;Push dest. address onto stack
		ldi temp, low(colatz_str_loc)
		push temp
		ldi temp, high(colatz_str_loc)
		push temp

		ldi YH, high(colatz_cur_val)
		ldi YL, low(colatz_cur_val)
		ld temp, Y+
		push temp ;Push the number onto stack
		ld temp, Y+
		push temp
		ld temp, Y 
		push temp ;Padding for 3 byte requirement
				
		call int_to_string
		pop temp
		pop temp
		pop temp
		pop temp
		pop temp
		pop temp
		;;;

		
		

		call update_lcd
		;;;;;;;Poll buttons
		clr zero
		; start a2d conversion
		lds	r16, ADCSRA	  ; get the current value of SDRA
		ori r16, 0x40     ; set the ADSC bit to 1 to initiate conversion
		sts	ADCSRA, r16

		; wait for A2D conversion to complete
		wait:
			lds r16, ADCSRA
			andi r16, 0x40     ; see if conversion is over by checking ADSC bit
			brne wait          ; ADSC will be reset to 0 is finished

		; read the value available as 10 bits in ADCH:ADCL
		lds r16, ADCL
		lds r17, ADCH
	
		push r18
		push r19

		ldi r18, 0x01 ;High bit for down and left
		ldi r19, 0x02

		;RIGHT
		ldi r24, 1
		cpi r16, 0x32
		cpc r17, zero
		brlo skip

		rjmp not_this

another_fucking_midpoint_jmp_main:
	rjmp main

		not_this:
		;UP
		ldi r24, 2
		cpi r16, 0xC3
		cpc r17, zero
		brlo skip

		;DOWN
		ldi r24, 3
		cpi r16, 0x7C
		cpc r17, r18
		brlo skip

		;LEFT
		ldi r24, 4
		cpi r16, 0x2B
		cpc r17, r19
		brlo skip
	
		ldi r24, 0 ;Nothing pressed

	skip:
		pop r18
		pop r19
		;;;;;;;

		;Buttons polled, decide what to do with results

		ldi ZH, high(lcd_x)
		ldi ZL, low(lcd_x)
		ld cursor_x, Z ;cursor_x contains LCD cursor offset from 0 (valid values are 3,4,5,6,14)


	check_btn:
		cp r24, r24_last_val
		breq another_fucking_midpoint_jmp_main

		mov r24_last_val, r24

		cpi r24, 1       ; Compare temp to decide which button pressed
		breq right_press
		cpi r24, 2
		breq up_press
		cpi r24, 3
		breq down_press_midpoint
		cpi r24, 4
		breq left_press

		clr r24_last_val

main_jmp_midpoint:
		rjmp main

		right_press: ;If cursor_x>6 go to 14, >14 go to 14
			cpi cursor_x, 14
			breq another_fucking_midpoint_jmp_main

			ldi move_dir, 1
			cpi cursor_x, 6
			brsh to_14
			inc cursor_x

			rjmp done_main
			;rjmp store_val
			
			to_14:
				ldi cursor_x, 14

			rjmp done_main
			;rjmp store_val

		left_press: ;If cursor_x>5 go to 14, >14 go to 14
			cpi cursor_x, 3
			breq main_jmp_midpoint

			ldi move_dir, 0
			cpi cursor_x, 14
			brsh to_6
			dec cursor_x

			rjmp done_main

			to_6:
				ldi cursor_x, 6
			rjmp done_main

		up_press:
			;cli ;Disable interupts
			ldi move_dir, 3 ;No move
			ldi ZH, high(colatz_start_val)
			ldi ZL, low(colatz_start_val)
			ld YL, Z+ ;Y contains the current starting value
			ld YH, Z

			clr zero
			cpi cursor_x, 3 ;Biggest, add 100
			breq add_100
			cpi cursor_x, 4 ;add 10
			breq add_10
			cpi cursor_x, 5 ;add 1
			breq add_1
			cpi cursor_x, 6
			breq star_pressed_jump
			cpi cursor_x, 14 ;add 1 to speed
			breq inc_spd
			rjmp done_main

			inc_spd:
				ldi XH, high(spd)
				ldi XL, low(spd)
				ld temp, X ;temp contains the current speed
				cpi temp, 9
				breq dont_inc_spd
				inc temp
				dont_inc_spd:
				st X, temp
				rjmp store_val

down_press_midpoint:
	rjmp down_press

			add_100:
				cpi YH, 0x03 ;If we're over 900 subtract 900 to rotate digit over (eg, 964 -> 064)
				brlo not_overflow_100
				cpi YL, 0x84
				brlo not_overflow_100
				;subi YL, 0x84
				;sbc YH, zero
				;subi YH, 0x03
				rjmp store_val

				not_overflow_100:
					ldi temp, 100
					add YL, temp
					adc YH, zero
					rjmp store_val
			add_10:
				;Load character from memory, if it's an ascii 9 (0x39) roll over to 0 by subtracting 90 from the number
				ldi XH, high(blink_swap_char)
				ldi XL, low(blink_swap_char)
				ld temp, X
				cpi temp, 0x39
				brne not_overflow_10
				;sbiw YH:YL, 60
				;sbiw YH:YL, 30 ;Yeah there's a better way to do this
				rjmp store_val

				not_overflow_10:
					adiw YH:YL, 10
					rjmp store_val
			add_1:
				;Load character from memory, if it's an ascii 9 (0x39) roll over to 0 by subtracting 9 from the number
				ldi XH, high(blink_swap_char)
				ldi XL, low(blink_swap_char)
				ld temp, X
				cpi temp, 0x39
				brne not_overflow_1
				;Remove line below to disable wrapping numbers
				sbiw YH:YL, 9
				rjmp store_val

				not_overflow_1:
					adiw YH:YL, 1
					rjmp store_val
				
		down_press:
			;cli ;Disable interupts
			ldi move_dir, 3 ;No move
			ldi ZH, high(colatz_start_val)
			ldi ZL, low(colatz_start_val)
			ld YL, Z+ ;Y contains the current starting value
			ld YH, Z

			clr zero
			cpi cursor_x, 3 ;Biggest, sub 100
			breq sub_100
			cpi cursor_x, 4 ;sub 10
			breq sub_10
			cpi cursor_x, 5 ;sub 1
			breq sub_1
			cpi cursor_x, 6
			breq star_pressed_jump
			cpi cursor_x, 14 ;sub 1 from speed
			breq dec_spd
			rjmp done_main

			star_pressed_jump:
				call star_pressed
				rjmp store_val

			dec_spd:
				ldi XH, high(spd)
				ldi XL, low(spd)
				ld temp, X ;temp contains the current speed
				cpi temp, 0
				breq dont_dec_spd
				dec temp
				dont_dec_spd:
				st X, temp
				rjmp store_val

			sub_100:
				cpi YH, 1 ;If we're at/over 100 perform the subtraction
				brsh not_overflow_100_sub
				cpi YL, 100
				brsh not_overflow_100_sub
				;subi YL, 0x84
				;sbc YH, zero
				;subi YH, 0x03
				rjmp store_val

				not_overflow_100_sub:
					ldi temp, 100
					sub YL, temp
					sbc YH, zero

					;re-zero memory so the string updates correctly
					ldi temp, 0x30
					sts start_str_loc, temp

					rjmp store_val
			sub_10:
				;Load character from memory, if it's an ascii 0 (0x30) roll over to 9 by adding 90 to the number
				ldi XH, high(blink_swap_char)
				ldi XL, low(blink_swap_char)
				ld temp, X
				cpi temp, 0x30
				brne not_overflow_10_sub
				;sbiw YH:YL, 60
				;sbiw YH:YL, 30 ;Yeah there's a better way to do this
				rjmp store_val

				not_overflow_10_sub:
					sbiw YH:YL, 10
					rjmp store_val
			sub_1:
				;Load character from memory, if it's an ascii 9 (0x39) roll over to 0 by subtracting 9 from the number
				ldi XH, high(blink_swap_char)
				ldi XL, low(blink_swap_char)
				ld temp, X
				cpi temp, 0x30
				brne not_overflow_1_sub
				;Remove line below to disable wrapping numbers
				adiw YH:YL, 9
				rjmp store_val

				not_overflow_1_sub:
					sbiw YH:YL, 1
					rjmp store_val

			store_val:
				st Z, YH ;Store new number back to memory
				sbiw ZH:ZL, 1
				st Z, YL

				;;;Update string display with new STARTING VAL
				;Push str. len onto stack
				ldi temp, 3
				push temp
				;Push dest. address onto stack
				ldi temp, low(start_str_loc)
				push temp
				ldi temp, high(start_str_loc)
				push temp

				push YL ;Push the number onto stack
				push YH 
				push zero ;Padding for 3 byte requirement
				
				call int_to_string
				pop zero
				pop YH
				pop YL
				pop temp
				pop temp
				pop temp
				;;;

				;Update collatz cur val on LCD
				;Push str. len onto stack
				ldi temp, 6
				push temp
				;Push dest. address onto stack
				ldi temp, low(colatz_str_loc)
				push temp
				ldi temp, high(colatz_str_loc)
				push temp

				ldi YH, high(colatz_cur_val)
				ldi YL, low(colatz_cur_val)
				ld temp, Y+
				push temp ;Push the number onto stack
				ld temp, Y+
				push temp
				ld temp, Y 
				push temp ;Padding for 3 byte requirement
				
				call int_to_string
				pop temp
				pop temp
				pop temp
				pop temp
				pop temp
				pop temp
				;;;

				clr zero ;Can't be too careful
				;;;SPEED
				;Push str. len onto stack
				ldi temp, 1
				push temp
				;Push dest. address onto stack
				ldi temp, low(spd_str_loc)
				push temp
				ldi temp, high(spd_str_loc)
				push temp

				lds temp, spd

				push temp ;Push the number onto stack
				push zero
				push zero ;Padding for 3 byte requirement
				
				call int_to_string
				pop zero
				pop zero
				pop temp

				pop temp
				pop temp
				pop temp



				call blink_ISR
				call blink_ISR
				rjmp done_main


		done_main:
			cpi move_dir, 3 ;No move, skip all this
			breq cont_btn

			;Force the blinking character to be restored, then move the cursor
			ldi YH, high(blink_swap_char)
			ldi YL, low(blink_swap_char)
			ld r18, Y ;r18 contains character to swap back in

			ldi ZH, high(lcd_x)
			ldi ZL, low(lcd_x)
			ld r16, Z ;r16 contains LCD cursor offset from 0
			ldi ZH, high(line1)
			ldi ZL, low(line1)
			add ZL, r16
			clr r16
			adc ZH, r16 ;Z is now the address of the current spot in mem
			st Z, r18

			;Now sub in the next character into blink_swap_char
			cpi move_dir, 1
			breq swap_right

			swap_left:
				cpi cursor_x, 6
				breq moved_far_left
				rjmp moved_one_left
				moved_far_left:
					sbiw ZH:ZL, 6
				moved_one_left:
					sbiw ZH:ZL, 1
					ld temp, Z
					st Y, temp
					rjmp cont_btn

			swap_right:
				cpi cursor_x, 14
				breq moved_far_right
				rjmp moved_one_right
				moved_far_right:
					adiw ZH:ZL, 6
				moved_one_right:
					adiw ZH:ZL, 1
					ld temp, Z
					st Y, temp

			cont_btn:
				ldi ZH, high(lcd_x)
				ldi ZL, low(lcd_x)

				st Z, cursor_x
				call update_lcd
				call btn_debounce_delay
				rjmp main

.undef temp
.undef cursor_x
.undef move_dir
.undef zero

star_pressed:
	push ZH
	push ZL
	push YH
	push YL
	push r16
	;Copy colatz_start_val to colatz_cur_val
	ldi ZH, high(colatz_start_val)
	ldi ZL, low(colatz_start_val)

	ldi YH, high(colatz_cur_val)
	ldi YL, low(colatz_cur_val)


	ld r16, Z+
	st Y+, r16
	ld r16, Z
	st Y, r16

	;Reset count
	ldi ZH, high(colatz_cnt)
	ldi ZL, low(colatz_cnt)
	clr r16
	st Z+, r16
	st Z, r16


	call collatz_timer_init

	;call colatz_step
	;call colatz_step

	pop r16
	pop YL
	pop YH
	pop ZL
	pop ZH
	ret

;Timer init, Modified from lab8, CSC 230 Fall 2019
blink_timer_setup:
	push r16
	ldi r16, 0x00		; normal operation
	sts TCCR1A, r16

	; prescale 
	; Our clock is 16 MHz, which is 16,000,000 per second
	;
	; scale values are the last 3 bits of TCCR1B:
	;
	; 000 - timer disabled
	; 001 - clock (no scaling)
	; 010 - clock / 8
	; 011 - clock / 64
	; 100 - clock / 256
	; 101 - clock / 1024
	; 110 - external pin Tx falling edge
	; 111 - external pin Tx rising edge
	ldi r16, (1<<CS12)|(1<<CS10)	; clock / 1024
	sts TCCR1B, r16

	; set timer counter to TIMER1_COUNTER_INIT (defined above)
	ldi r16, high(BLINK_COUNTER_INIT)
	sts TCNT1H, r16 	; must WRITE high byte first 
	ldi r16, low(BLINK_COUNTER_INIT)
	sts TCNT1L, r16		; low byte
	
	; allow timer to interrupt the CPU when it's counter overflows
	ldi r16, 1<<TOIE1
	sts TIMSK1, r16

	; enable interrupts (the I bit in SREG)
	sei	

	pop r16
	ret

;Blinks the current cursor position, Modified interrupt code from lab8, CSC 230 Fall 2019
blink_ISR:
	push r16
	push r18
	push ZH
	push ZL
	push YH
	push YL
	push r17
	lds r16, SREG
	push r16

	; RESET timer counter to BLINK_COUNTER_INIT (defined below)
	ldi r16, high(BLINK_COUNTER_INIT)
	sts TCNT1H, r16 	; must WRITE high byte first 
	ldi r16, low(BLINK_COUNTER_INIT)
	sts TCNT1L, r16		; low byte

	ldi ZH, high(lcd_x)
	ldi ZL, low(lcd_x)
	ld r16, Z ;r16 contains LCD cursor offset from 0
	mov r18, r16
	ldi ZH, high(line1)
	ldi ZL, low(line1)
	add ZL, r16
	clr r16
	adc ZH, r16
	ld r17, Z ;r17 contains charater at current cursor pos.

	cpi r17, 0x20
	breq remove_placeholder ;If the placeholder character is already there remove it

	insert_placeholder:
		ldi YH, high(blink_swap_char)
		ldi YL, low(blink_swap_char)
		st Y, r17 ;Save the current character in memory
		ldi r17, 0x20
		st Z, r17 ;Insert placeholder character
		rjmp done_blink


	remove_placeholder:
		cpi r18, 6
		breq insert_star
		star_is_in:
			ldi YH, high(blink_swap_char)
			ldi YL, low(blink_swap_char)
			ld r17, Y ;r17 contains character to swap back in
			st Z, r17 ;Swap character back
			rjmp done_blink

	insert_star:
		ldi YH, high(blink_swap_char)
		ldi YL, low(blink_swap_char)
		ldi r18, 0x2A
		st Y, r18
		rjmp star_is_in

	done_blink:
		pop r16
		sts SREG, r16
		pop r17
		pop YL
		pop YH
		pop ZL
		pop ZH
		pop r18
		pop r16
		reti

collatz_timer_init:
	push r16
	push r17
	push XL
	push XH
	push ZL
	push ZH

	ldi r16, 0x00		; normal operation
	sts TCCR3A, r16

	;Load speed from memory
	ldi ZH, high(spd)
	ldi ZL, low(spd)
	ld r16, Z

	clr XH
	clr XL

	cpi r16, 0
	breq quit_timer
	cpi r16, 1
	breq hz16
	cpi r16, 2
	breq hz8
	cpi r16, 3
	breq hz8
	cpi r16, 4
	breq hz2
	cpi r16, 5
	breq hz1
	cpi r16, 6
	breq hz06
	cpi r16, 7
	breq hz05
	cpi r16, 8
	breq hz04
	cpi r16, 9
	breq hz03

	hz16:
		ldi XH, 0xFC
		ldi XL, 0x2E
		rjmp set_scalar
	hz8:
		ldi XH, 0xF8
		ldi XL, 0x5E
		rjmp set_scalar
	hz4:
		ldi XH, 0xF0
		ldi ZL, 0xBD
		rjmp set_scalar
	hz2:
		ldi XH, 0xE1
		ldi XL, 0x7A
		rjmp set_scalar
	hz1:
		ldi XH, 0xC2
		ldi XL, 0xF6
		rjmp set_scalar
	hz06:
		ldi XH, 0xA4
		ldi XL, 0x70
		rjmp set_scalar
	hz05:
		ldi XH, 0x85
		ldi XL, 0xED
		rjmp set_scalar
	hz04:
		ldi XH, 0x67
		ldi XL, 0x69
		rjmp set_scalar
	hz03:
		ldi XH, 0x34
		ldi XL, 0x8C
		rjmp set_scalar

	set_scalar:
	ldi r16, (1<<CS12)|(1<<CS10)	; clock / 1024
	sts TCCR3B, r16

	; set timer counter
	sts TCNT3H, XH 	; must WRITE high byte first 
	sts TCNT3L, XL		; low byte
	
	; allow timer to interrupt the CPU when it's counter overflows
	ldi r16, 1<<TOIE3
	sts TIMSK3, r16

	; enable interrupts (the I bit in SREG)
	sei	

	quit_timer:
	pop ZH
	pop ZL
	pop XH
	pop XL
	pop r17
	pop r16
	ret

collatz_ISR:
	.def temp = r16
	push r16
	push r17
	push r18
	push r19
	push XH
	push XL
	lds r16, SREG
	push r16

	ldi XH, high(colatz_cur_val)
	ldi XL, low(colatz_cur_val)
	ld r16, X+ ;Low
	ld r17, X+ ;Mid
	ld r18, X ;High

	clr r19

	or r19, r18
	or r19, r17
	cpi r19, 0
	breq check_if1
	rjmp not_1
	check_if1:
		cpi r16, 1
		breq stop_timer_mid

	not_1:
	call colatz_step


	rjmp dont_run_this
	stop_timer_mid:
		rjmp stop_timer
	dont_run_this:



	lds r16, spd

	cpi r16, 0
	breq stop_timer
	cpi r16, 1
	breq hz16_I
	cpi r16, 2
	breq hz8_I
	cpi r16, 3
	breq hz8_I
	cpi r16, 4
	breq hz2_I
	cpi r16, 5
	breq hz1_I
	cpi r16, 6
	breq hz06_I
	cpi r16, 7
	breq hz05_I
	cpi r16, 8
	breq hz04_I
	cpi r16, 9
	breq hz03_I


	hz16_I:
		ldi XH, 0xFC
		ldi XL, 0x2E
		rjmp set_clock
	hz8_I:
		ldi XH, 0xF8
		ldi XL, 0x5E
		rjmp set_clock
	hz4_I:
		ldi XH, 0xF0
		ldi ZL, 0xBD
		rjmp set_clock
	hz2_I:
		ldi XH, 0xE1
		ldi XL, 0x7A
		rjmp set_clock
	hz1_I:
		ldi XH, 0xC2
		ldi XL, 0xF6
		rjmp set_clock
	hz06_I:
		ldi XH, 0xA4
		ldi XL, 0x70
		rjmp set_clock
	hz05_I:
		ldi XH, 0x85
		ldi XL, 0xED
		rjmp set_clock
	hz04_I:
		ldi XH, 0x67
		ldi XL, 0x69
		rjmp set_clock
	hz03_I:
		ldi XH, 0x34
		ldi XL, 0x8C
		rjmp set_clock

	set_clock:
	sts TCNT3H, XH 	; must WRITE high byte first 
	sts TCNT3L, XL		; low byte

	ldi r16, (1<<CS12)|(1<<CS10)	; clock / 1024
	sts TCCR3B, r16
	rjmp no_stop_timer

	stop_timer:
		clr r16
		sts TCCR3B, r16
	no_stop_timer:

	sei

	pop r16
	sts SREG, r16
	pop XL
	pop XH
	pop r19
	pop r18
	pop r17
	pop r16
	reti
	.undef temp

update_lcd:
	push ZH
	push ZL
	push r16

	;Display starting val.
	ldi r16, 0
	push r16
	push r16

	call lcd_gotoxy

	pop r16
	pop r16

	;Display the digits
	ldi r16, high(line1)
	push r16
	ldi r16, low(line1)
	push r16

	call lcd_puts

	pop r16
	pop r16

	;Display SPD
	ldi r16, 0
	push r16
	ldi r16, 10
	push r16

	call lcd_gotoxy

	pop r16
	pop r16

	;Display the digits
	ldi ZH, high(line1)
	ldi ZL, low(line1)
	adiw Z, 10
	push ZH
	push ZL
	

	call lcd_puts

	pop r16
	pop r16

	;Display Count
	ldi r16, 1
	push r16
	ldi r16, 0
	push r16

	call lcd_gotoxy

	pop r16
	pop r16

	ldi r16, high(line2)
	push r16
	ldi r16, low(line2)
	push r16

	call lcd_puts

	pop r16
	pop r16


	;Display Val
	ldi r16, 1
	push r16
	ldi r16, 8
	push r16

	call lcd_gotoxy

	pop r16
	pop r16

	ldi ZH, high(line2)
	ldi ZL, low(line2)
	adiw Z, 8
	push ZH
	push ZL

	call lcd_puts

	pop r16
	pop r16

	pop r16
	pop ZL
	pop ZH
	ret
	
;function that converts an 3-byte unsigned integer to a c-string. Modified from lab7, CSC 230 Fall 2019
;Loads low,mid,high or number, then low,high of address to write string from stack
int_to_string:
	.def one=r24
	.def divisor=r25
	.def quotientLow=r16
	.def inHigh=r17
	.def inMid=r18
	.def inLow=r19
	.def tempt=r20
	.def char0=r21
	.def quotientMid=r22
	.def quotientHigh=r23

	;preserve the values of the registers
	push one
	push divisor
	push quotientLow
	push quotientMid
	push quotientHigh
	push inHigh
	push inMid
	push inLow
	push tempt
	push char0
	push ZH
	push ZL
	push YL
	push YH

	
	in YH, SPH
	in YL, SPL


	.EQU INT_OFFSET = 18
	ldd inHigh, Y+INT_OFFSET	; High
	ldd inMid, Y+INT_OFFSET+1	; Mid
	ldd inLow, Y+INT_OFFSET+2	; Low

	;Z points to first character of num in SRAM
	ldd ZH, Y+INT_OFFSET+3		; High dest.
	ldd ZL, Y+INT_OFFSET+4		; Low dest.

	clr char0
	ldd tempt, Y+INT_OFFSET+5 ;Max str. len
	add ZL, tempt
	adc ZH, char0
	;adiw ZH:ZL, 6 ;Z points to null character

	;store '0' in char0
	ldi tempt, '0'
	mov char0, tempt

	clr tempt 
	st Z, tempt ;set the last character to null
	sbiw ZH:ZL, 1 ;Z points the last digit location

	;initialize value for divisor
	ldi divisor, 10
	
	clr quotientLow
	clr quotientMid
	clr quotientHigh
	ldi one, 1

	digit2str:
		clr tempt
		or tempt, inHigh
		or tempt, inMid
		cpi tempt, 0
		brne division
		cp inLow, divisor
		brlo finish_str
		division:
			clr tempt
			add quotientLow, one
			adc quotientMid, tempt
			adc quotientHigh, tempt ;Increment quotient
			sub inLow, divisor
			sbci inMid, 0
			sbci inHigh, 0 ;Subtract divisor from big number
			or tempt, inHigh
			or tempt, inMid
			cpi tempt, 0
			brne division ;If high and mid not 0 keep going
			cp inLow, divisor ;If low isn't less than divisor keep going
			brsh division
		;change unsigned integer to character integer
		add inLow, char0
		st Z, inLow;store digits in reverse order
		sbiw r31:r30, 1 ;Z points to previous digit
		mov inLow, quotientLow
		mov inMid, quotientMid
		mov inHigh, quotientHigh
		clr quotientLow
		clr quotientMid
		clr quotientHigh
		rjmp digit2str
	finish_str:
	add inLow, char0
	st Z, inLow ;store the most significant digit

	clean_stack:
	;restore the values of the registers
	pop YH
	pop YL
	pop ZL
	pop ZH
	pop char0
	pop tempt
	pop inLow
	pop inMid
	pop inHigh
	pop quotientHigh
	pop quotientMid
	pop quotientLow
	pop divisor
	pop one
	ret
	.undef one
	.undef divisor
	.undef quotientLow
	.undef inHigh
	.undef inMid
	.undef inLow
	.undef tempt
	.undef char0
	.undef quotientMid
	.undef quotientHigh

;This function is a mess, I'm protecting almost every register here
colatz_step:
	.def temp = r16
	.def count = r17
	.def count2 = r29
	.def res0 = r21
	.def res1 = r22
	.def res2 = r23
	.def res3 = r24
	.def three = r25
	.def zero = r26
	.def one = r28

	push r0
	push r1
	push temp
	push count
	push count2
	push res0
	push res1
	push res2
	push res3
	push three
	push zero
	push one
	push r27
	push r18
	push r19
	push r20
	push ZH
	push ZL


	ldi three, 3 ;There's no unsigned immidiate multiplication/addition so here we are
	ldi one, 1
	clr zero
	clr count
	ldi ZH, high(colatz_cur_val)
	ldi ZL, low(colatz_cur_val)
	ld r18, Z+ ;Load 4 bytes of the number in (r18 low, 27high)
	ld r19, Z+ 
	ld r20, Z 
	clr r27

	lds count, colatz_cnt
	lds count2, colatz_cnt+1


	while:
		clr temp
		;Temp will not be 0 if any of these are not 0
		or temp, r27
		or temp, r20
		or temp, r19
		cpi temp, 0 ;Skip comparing the last byte if the others are not 0
			brne continue

		cpi r18, 1 ;We're done if all other bytes are 0 and the last one is 1 or 0
			breq finish
		cpi r18, 0
			breq finish

	continue:
		add count, one ;Inc count
		adc count2, zero
		mov temp, r18 ;Load low byte into a temp register
		lsr temp ;divide temp by 2
		brcs odd ;Branch if odd

	even:
		lsr r27 ;Divide high byte by 2
		ror r20 ;Divide middle byte by 2 with carry
		ror r19 ;Divide middle byte by 2 with carry
		ror r18 ;Divide low byte by 2 with carry

		mov res0, r18
		mov res1, r19
		mov res2, r20
		mov res3, r27

		clc ;clear carry flag
		rjmp finish

	odd:
		clc ;clear carry flag
		mul r18, three ;Multiply low byte by 3
		mov res1, r1
		mov res0, r0 ;Copy result to res1:res0

		mul r19, three ;Multiply middle byte by 3
		mov res2, r1 ;Move high byte of result to res2
		add res1, r0 ;Add low byte to res1
		adc res2, zero ;Add carry flag incase last addition overflowed

		mul r20, three ;Multiply middle byte by 3
		mov res3, r1 ;Move high byte of result to res3
		add res2, r0 ;Add low byte to res2
		adc res3, zero ;Add carry flag incase last addition overflowed

		mul r27, three;Multiply high byte by 3
		add res3, r0 ;Add result to res3

		;Increment by one
		add res0, one
		adc res1, zero ;Incase of overflow
		adc res2, zero
		adc res3, zero

	finish:
		;Fix count off by 1 and no action on 0
		/*clr temp
		or temp, res3
		or temp, res2
		or temp, res1
		cpi temp, 0
		breq take_action
		rjmp no_action
		take_action:
			cpi res0, 0
			breq no_store

			cpi res0, 1
			breq no_action
			
			;Value is greater than 1, see if count is too
			cpi count2, 0
			brne no_action
			cpi count, 1
			brne no_action

			add count, one
			adc count2, zero

		no_action:*/
		;Store result in mem
		ldi ZH, high(colatz_cur_val) ;Point Z to our destination
		ldi ZL, low(colatz_cur_val)
		st Z+, res0 ;Low
		st Z+, res1 ;Mid
		st Z+, res2 ;High
		st Z, res3 ;High

		
		;Store count
		sts colatz_cnt, count
		sts colatz_cnt+1, count2

		no_store:
		pop ZL
		pop ZH
		pop r20
		pop r19
		pop r18
		pop r27
		pop one
		pop zero
		pop three
		pop res3
		pop res2
		pop res1
		pop res0
		pop count2
		pop count
		pop temp
		pop r1
		pop r0
		.undef temp
		.undef count
		.undef count2
		.undef res0
		.undef res1
		.undef res2
		.undef res3
		.undef three
		.undef zero
		.undef one
		ret

;Loads strings from progmem to datamem, Modified from lab7, CSC 230 Fall 2019
;Takes low,high of 2 source addresses and writes to the standard LCD line spot in memory
init_strings:
	.def line1_p_low = r17
	.def line1_p_high = r18
	.def line2_p_low = r19
	.def line2_p_high = r20

	push r16
	push line1_p_low
	push line1_p_high
	push line2_p_low
	push line2_p_high
	push YL
	push YH

	in YH, SPH
	in YL, SPL


	.EQU INT_STR_OFFSET = 11

	ldd line2_p_high, Y+INT_STR_OFFSET
	ldd line2_p_low, Y+INT_STR_OFFSET+1
	ldd line1_p_high, Y+INT_STR_OFFSET+2
	ldd line1_p_low, Y+INT_STR_OFFSET+3
	
	

	; copy strings from program memory to data memory
	ldi r16, high(line1)		; address of the destination string in data memory
	push r16
	ldi r16, low(line1)
	push r16

	push line1_p_high
	push line1_p_low

	call str_init			; copy from program to data

	pop line1_p_low
	pop line1_p_high
	pop r16
	pop r16

	ldi r16, high(line2)
	push r16
	ldi r16, low(line2)
	push r16
	push line2_p_high
	push line2_p_low

	call str_init

	pop line2_p_low
	pop line2_p_high
	pop r16
	pop r16
	

	pop YH
	pop YL
	pop line2_p_high
	pop line2_p_low
	pop line1_p_high
	pop line1_p_low
	pop r16

	.undef line1_p_low
	.undef line1_p_high
	.undef line2_p_low
	.undef line2_p_high
	ret

;Busy delay loop
delay:
	push r20
	push r21
	push r22

	ldi r20, 0x4F
x1:
		ldi r21, 0xFF
x2:
			ldi r22, 0xFF
x3:
				dec r22
				brne x3
			dec r21
			brne x2
		dec r20
		brne x1

	pop r22
	pop r21
	pop r20
	ret

;Lil delay
btn_debounce_delay:
	push r20
	push r21
	push r22

	ldi r20, 0x07
x_1:
		ldi r21, 0xFF
x_2:
			ldi r22, 0xFF
x_3:
				dec r22
				brne x3
			dec r21
			brne x2
		dec r20
		brne x1

	pop r22
	pop r21
	pop r20
	ret

splash_line1_p: .db "Finn Morin", 0
splash_line2_p: .db "CSC230-Fall2019", 0

line1_p: .db " n=000*   SPD:0", 0
line2_p: .db "cnt:  0 v:     0", 0
.EQU colatz_str_loc = line2+10
.EQU cnt_str_loc = line2+4
.EQU start_str_loc = line1+3
.EQU spd_str_loc = line1+14
.EQU colatz_str_len = 6
.EQU cnt_str_len = 3

.EQU BLINK_DELAY = 8000
.EQU BLINK_MAX_COUNT = 0xFFFF
.EQU BLINK_COUNTER_INIT=BLINK_MAX_COUNT-BLINK_DELAY

.dseg
.org 0x0200
colatz_cur_val:		.byte 4
colatz_cnt:			.byte 2
colatz_cnt_str:		.byte 4
line1:				.byte 17
line2:				.byte 17
lcd_x:				.byte 1
blink_swap_char:	.byte 1
colatz_start_val:	.byte 2
spd:				.byte 1

; Include the HD44780 LCD Driver for ATmega2560
;
; This library has it's own .cseg, .dseg, and .def
; which is why it's included last, so it would not interfere
; with the main program design.
#define LCD_LIBONLY
.include "lcd.asm"
