/*
 * A4.c
 *
 * Created: 2019-11-29
 * Author : Finn Morin, V00913376
 */ 
#include <stdio.h>
#include <string.h>
#include "CSC230.h"


#define	 BTN_NONE	0
#define  BTN_RIGHT	1
#define  BTN_UP		2
#define  BTN_DOWN	3
#define  BTN_LEFT	4
#define  BTN_SELECT 5

//Globals accessed by ISRs
volatile short int cursor_pos = 3;
volatile unsigned int colatz_start_val = 0;
volatile unsigned int colatz_val = 0;
volatile int speed = 0;
volatile int stored_speed = 0;
volatile int count = 0;
volatile char blink_swap;
volatile char lcd_line1[] = " n=000*   SPD:0";
volatile char lcd_line2[] = "cnt:  0 v:     0";
volatile int last_button_pressed;

int main(void){
	// Set up the PORTS
	DDRL = 0b10101010;
	DDRB = DDRB | 0b00001010;
	
    lcd_init();
	
	//ADC Set up
	ADCSRA = 0x87;
	ADMUX = 0x40;
	
	blink_swap = '0';
	
	// Set Timer 1 to 20Hz - BUTTON TIMER
	TCCR1A = 0;
	TCCR1B = (1<<CS12)|(1<<CS10);
	TCNT1 = 0xFFFF - 1041;			//20Hz
	//TCNT1 = 0;
	TIMSK1 = 1<<TOIE1;
	
	// Set up Timer 3 as disabled - COLLATZ TIMER
	TCCR3A = 0;
	TCCR3B = (1<<CS12)|(1<<CS10);
	TCNT3 = 0;			
	//TIMSK3 = 1<<TOIE3; //Disabled
	
	
	// Set Timer 4 to 0.5s - BLINK TIMER
	TCCR4A = 0;
	TCCR4B = (1<<CS12)|(1<<CS10);
	TCNT4 = 0xFFFF - 9000;			//0.8s
	TIMSK4 = 1<<TOIE4;
	
	sei();
	
	
	//Run initiation sequence
	splash_that_screen();
	
	while(1){
		char *line1_end = lcd_line1 + 14;
		char *line2_end = lcd_line2 + 10;
		lcd_xy(0,0);
		lcd_puts(lcd_line1);
		lcd_xy(14,0);
		lcd_puts(line1_end);
		lcd_xy(0,1);
		lcd_puts(lcd_line2);
		lcd_xy(10,1);
		lcd_puts(line2_end);
		_delay_ms(5);
	}
	
	
	
}

//Updates collatz timer based on current speed
void update_collatz_timer() {
	if (speed == 1 || speed == 0)	TCNT3 = 0xFFFF - 977;
	else if (speed == 2)	TCNT3 = 0xFFFF - 1953;
	else if (speed == 3)	TCNT3 = 0xFFFF - 3906;
	else if (speed == 4)	TCNT3 = 0xFFFF - 7813;
	else if (speed == 5)	TCNT3 = 0xFFFF - 15625;
	else if (speed == 6)	TCNT3 = 0xFFFF - 23438;
	else if (speed == 7)	TCNT3 = 0xFFFF - 31250;
	else if (speed == 8)	TCNT3 = 0xFFFF - 39063;
	else if (speed == 9)	TCNT3 = 0xFFFF - 46875;
	
	TIMSK3 = 1<<TOIE3;
	return;
}

//Runs a collatz iteration
//Params: (int)Value to run on
//Returns: (int)Result
int collatz_step(int val) {
	if (val == 1)	return -1;
	
	if(val%2 == 0) {
		val/=2;
	}
	else{
		val*=3;
		val++;
	}
	return val;
}

//Runs splash screen
//Params: None
//Returns: None
void splash_that_screen(void){
	lcd_xy(0,0);
	lcd_puts("Finn Morin");
	lcd_xy(0,1);
	lcd_puts("CSC230-Fall2019");
	
	_delay_ms(800);
	return;
}

//Polls ADC and returns button that was pressed
//Params: None
//Returns: (int)button pressed
//Modified from B.Bird, lab09_show_adc_result.c, CSC 230 - Summer 2018
int check_buttons(){
	unsigned short adc_result = 0; //16 bits
	
	ADCSRA |= 0x40;
	while((ADCSRA & 0x40) == 0x40); //Busy-wait
	
	unsigned short result_low = ADCL;
	unsigned short result_high = ADCH;
	
	adc_result = (result_high<<8)|result_low;
	
	
	if (adc_result < 50)	return BTN_RIGHT;
	if (adc_result < 195)	return BTN_UP; 
	if (adc_result < 380)	return BTN_DOWN; 
	if (adc_result < 555)	return BTN_LEFT;
	if (adc_result < 790)	return BTN_SELECT;
	return BTN_NONE;
}

//Updates collatz starting val and resets count when user selects one
//Params: (int)reset - 1 or 0
//Returns: None
void new_collatz_val(int reset) {
	int i;
	//Clear cnt: and v:
	for(i=4;i<6;i++)	lcd_line2[i] = ' ';
	for(i=10;i<15;i++)	lcd_line2[i] = ' ';
		
	if (reset == 1){
		colatz_val = colatz_start_val;
		count = 0;
		lcd_line2[6] = '0'; //Count on LCD
	}
	
	else{
		//Load new count to LCD
		char cnt_temp[4];
		sprintf(cnt_temp,"%3d",count+1);
		int last_idx = sizeof(cnt_temp)/sizeof(cnt_temp[0]) - 2;
		for(i=6;i>3;i--){
			lcd_line2[i] = cnt_temp[last_idx-(6-i)];
		}
	}
	
	//Load new starting val to LCD string
	char val_tmp[7];
	sprintf(val_tmp,"%6d",colatz_val);
	int last_idx = sizeof(val_tmp)/sizeof(val_tmp[0]) - 2;
	
	for(i=15;i>10;i--){
		lcd_line2[i] = val_tmp[last_idx-(15-i)];
	}
	
	//Sometimes first char of line1 gets fucked
	lcd_line1[0] = ' ';

	return;
}


//Button poll ISR
ISR(TIMER1_OVF_vect){
	cli();
	int button_pressed = check_buttons();
	if (button_pressed == last_button_pressed) {
		TCNT1 = 0xFFFF - 1041; //15Hz
		return;
	}
	//Restore character if it got blinked
	lcd_line1[cursor_pos] = blink_swap;
	
	if (button_pressed == BTN_RIGHT){
		//Move cursor_pos right
		if (cursor_pos < 6)		cursor_pos++;
		else if (cursor_pos == 6)	cursor_pos = 14;
	}
	
	else if(button_pressed == BTN_LEFT){
		//Move cursor_pos left
		if (cursor_pos == 14)	cursor_pos = 6;
		else if(cursor_pos > 3)	cursor_pos--;
	}
	
	else if(button_pressed == BTN_UP){
		//Inc. number or load collatz val TODO: trigger collatz start
		if (cursor_pos == 6){
			new_collatz_val(1);
			update_collatz_timer();
			
		}
		else if (cursor_pos == 5){
			if (colatz_start_val%10 < 9)	colatz_start_val++;
			else					colatz_start_val-= 9;
		}
		
		else if(cursor_pos == 4) {
			if (colatz_start_val%100 < 90)	colatz_start_val+= 10;
			else					colatz_start_val-= 90;
		}
		
		else if(cursor_pos == 3){
			if (colatz_start_val < 900)	colatz_start_val+= 100;
			else					colatz_start_val-= 900;
		}
		
		else if(cursor_pos == 14){
			if (speed < 9)	speed++;
			else			speed-=9;
		}

	}
	
	else if(button_pressed == BTN_DOWN){
		//Dec. number or TODO: trigger collatz start
		if (cursor_pos == 6){
			new_collatz_val(1);
			update_collatz_timer();
		}
		else if (cursor_pos == 5){
			if (colatz_start_val%10 != 0)	colatz_start_val--;
			else					colatz_start_val+= 9;
		}
		
		else if(cursor_pos == 4) {
			if (colatz_start_val%100 != 0)	colatz_start_val-= 10;
			else					colatz_start_val+= 90;
		}
		
		else if(cursor_pos == 3){
			if (colatz_start_val >= 100)	colatz_start_val-= 100;
			else					colatz_start_val+= 900;
		}
		
		else if(cursor_pos == 14){
			if (speed > 0)	speed--;
			else			speed+=9;
		}
	}
	
	//TEST THIS
	else if(button_pressed == BTN_SELECT) {
		char speed_str;
		int temp = stored_speed;
		stored_speed = speed;
		speed = temp;
		lcd_line1[14] = speed+48;
	}
	
	//Update val on display
	if (button_pressed == BTN_DOWN || button_pressed == BTN_UP) {
		char temp[3];
		sprintf(temp, "%03u", colatz_start_val);
		lcd_line1[3] = temp[0];
		lcd_line1[4] = temp[1];
		lcd_line1[5] = temp[2];
		
		lcd_line1[14] = speed+48; //ASCII representation
	}
	
	last_button_pressed = button_pressed;
	
	//Put new character in blink_swap
	blink_swap = lcd_line1[cursor_pos];
	
	TCNT1 = 0xFFFF - 782; //20Hz
	sei();
}

//Collatz ISR
ISR(TIMER3_OVF_vect){
	cli();
	update_collatz_timer();
	if(colatz_start_val == 1 && colatz_val == 1) {
		count = 1;
		lcd_line2[6] = '1';
		sei();
		return;
	}
	
	if (speed == 0 || colatz_val <= 1){	
		sei();
		return;
	}
	
	unsigned int new_collatz = collatz_step(colatz_val);
	if (new_collatz == -1){ //We've hit our last value
		sei();
		return;
	}
	else {
		colatz_val = new_collatz;
		count++;
		new_collatz_val(0);
	}
	sei();
}

//Blink ISR
ISR(TIMER4_OVF_vect){
	cli();
	char current_char = lcd_line1[cursor_pos];
	
	//Toggle value w/ " "
	if (current_char == ' '){
		if (blink_swap != ' ') {
			lcd_line1[cursor_pos] = blink_swap;
		}
		else {
			blink_swap = '!';
		}
	}
	else{
		blink_swap = current_char;
		lcd_line1[cursor_pos] = ' ';
	}
	
	TCNT4 = 0xFFFF - 9000;	//0.8s
	sei();
}