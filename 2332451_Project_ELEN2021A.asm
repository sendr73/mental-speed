;
; 2332451_Project_ELEN2021A.asm
;
; Created: 2021/04/29 19:33:21
; Author : dsend
;

; initilize Timer1
.set CTC = 1 << WGM12 //Sets count to clear
.set prescale1024 = (1 << CS12) | (1 << CS10) //Timer1 prescaler = 1024
.set interrupt = 1 << OCIE1A //Enables interrupt when TCNT1 = OCR1A

; initialize external interrupt
.set exInt0 = 1 << INT0 //Enables external interrupt0 (D2)
.set exInt1 = 1 << INT1 //Enables external interrupt1 (D3)
.set sense1 = (1 << ISC11) | (1 << ISC10) //Sets interrupt0 to trigger on rising edge
.set sense0 = (1 << ISC01) | (1 << ISC00) //Sets interrupt1 to trigger on rising edge

; Number combinations: M(D7)/TL(D6)/T(D5)/TR(D4)_NULL/BL(D10/B2)/BM(D9/B3)/BR(D8/B0)
.set zeroTop = 0b0111_0000 //Top values of zero
.set oneTop = 0b0001_0000 //Top values of one
.set two_threeTop = 0b1011_0000 //Top values of two and three
.set fourTop = 0b1101_0000 //Top values of four
.set five_sixTop = 0b1110_0000 //Top values of five and six
.set sevenTop = 0b0011_0000 //Top values of seven
.set eight_nineTop = 0b1111_0000 //Top values of eight and nine
.set zero_six_eightBottom = 0b0000_0111 //Bottom values of zero, six and eight
.set twoBottom = 0b0000_0110 //Bottom values of two
.set three_five_nineBottom = 0b0000_0011 //Bottom values of three, five and nine
.set one_seven_fourBottom = 0b0000_0001 //Bottom values of one, seven and four
.set decimal = 1 << PC0

; LED locations
.set greenLED = 1 << PB3
.set redLED = 1 << PB4
.set tickLED = 1 << PC1

; set register names
.def temp = R16
.def seed = R17
.def tick = R18
.def multiplicand = R19
.def multiple = R20
.def sum = R21
.def score = R22
.def toggle = R23
.def stage = R24
.def prevNum = R25
.def elapsed = R30

; initialize interrupts
.org 0x0000
JMP init
.org 0x0002 //Called when right hand button is pressed
RJMP skip
.org 0x0004 //Called when left hand button is pressed
RJMP pressed
.org 0x0016 //Called when timer equals OCR1A (0.25s)
RJMP timer

; Loop
loop:
	SBRC stage, 1 //checks if it not stage 2/3 (displaying score or toggling score)
	RJMP loop //if stage 2, return to loop
	INC seed //increment seed for randomness
	CPI seed, 9 //check if greater than 9
	BRNE loop //if not greater, return to loop
	CLR seed //reset seed
	RJMP loop //return to loop

; Pre-initialize before clicking button to start
init:
	CLR temp //disables timer1
	STS OCR1AH, temp
	STS OCR1AL, temp
	STS TIMSK1, temp
	STS TCCR1B, temp
	LDI temp, exInt1
	OUT EIMSK, temp //enable external interrupt1
	LDI temp, sense1
	STS EICRA, temp //sets interrupt1 to trigger on rising edge
	CLR temp
	STS TCNT1H, temp //reset system clock
	STS TCNT1L, temp
	SEI
	RJMP loop

; Initialize after starting the game
start:
	CLI //Globally disables interrupts
	LDI temp, 0b0001_1111 //sets PB0-PB4 to write
	OUT DDRB, temp
	LDI temp, 0b1111_0000 //sets PD4-PD7 to write
	OUT DDRD, temp
	;Timer
	LDI temp, 0x0F //sets OCR1A to 0x0F42 = 3906 ticks = 0.25s at 16MHz (This is deliberate because 4 ticks per second for 60 seconds is 240 - the largest multiple of 60, less than 255)
	STS OCR1AH, temp
	LDI temp, 0x42
	STS OCR1AL, temp
	LDI temp, interrupt //enables OCR1A interrupt
	STS TIMSK1, temp
	LDI temp, prescale1024 | CTC //sets prescale and count to clear
	STS TCCR1B, temp
	; Interrupt0
	LDI temp, exInt0 | exInt1 //enable external interrupt1 and interrupt0
	OUT EIMSK, temp
	LDI temp, sense0 | sense1 //sets interrupt1 and interrupt0 to trigger on rising edge
	STS EICRA, temp
	; set up variables
	LDI multiplicand, 1 //loads 1 for method: checking if number is a multiple in 'pressed:'
	LDI multiple, 3 //sets multiple (would use ADC value here) 
	CLR toggle //resets necessary variables
	CLR score
	CLR sum
	CLR tick
	CLR temp
	CLR prevNUm
	CLR elapsed
	CLR xh
	CLR xl
	LDI stage, 1 //sets stage 1 (ongoing game)
	LDI temp, greenLED | redLED
	OUT PORTB, temp
	LDI temp, tickLED
	OUT PORTC, temp
	CLR temp
	OUT PORTD, temp
	STS TCNT1H, temp //resets system clock
	STS TCNT1L, temp
	SEI //Globally enables interrupts
	RJMP loop

; Push Button1 Interrupt (right hand side)
pressed:
	CPI stage, 0 //checks if game is in stage 0 (has not started)
	BREQ start //if has not started, begin game
	CPI stage, 3 //check if game is in stage 3 (toggling score)
	BREQ start //if toggling score, restart game
	CLI
	; if clicked on turn (checks if lights are on already)
	IN temp, PORTB
	SBRC temp, 3 //checks green light status
	RETI //if on, return
	SBRC temp, 4 //checks green light status
	RETI //if on, return
	; if not, check if is multiple
	MOV temp, multiplicand //move current multiplicand into temp
	MUL temp, multiple //multiply by multiple
	INC multiplicand //increment multiplicand in case of next loop
	CP R0, sum //number will always be stored in R0 due to size, so compare to current sum when the user clicked the button
	BRLO pressed //if R0 is lower, then repeat
	BRNE not //if multiple has remainder, then not divisable
is: //is correct
	IN temp, PORTB //lights green LED
	ORI temp, greenLED //ORI ensures that the displayed value does not disappear
	OUT PORTB, temp
	CLR sum //resets multiple variables
	LDI multiplicand, 1
	INC score //increases score
	SEI
	RETI
not: //is not correct
	IN temp, PORTB //lights red LED
	ORI temp, redLED //ORI ensures that the displayed value does not disappear
	OUT PORTB, temp
	CLR sum //resets multiple variables
	LDI multiplicand, 1
	CPI score, 2 //checks if score is less than 2
	BRLO zeroScore //if lower branch
	DEC score //if greater than two, decreased score by 2
	DEC score
	SEI
	RETI
zeroScore: //avoids negative score
	CLR score //sets score to 0
	SEI
	RETI

; Push Button0 Interrupt (left hand side)
skip:
	CLI
	CPI tick, 3 //since ORC1A is 250ms, if tick is 2 - that means 0.5ms have passed (at least)
	BRSH executeSkip //if same or higher, skip the number
	RJMP debounce //otherwise debounce (software fix)

executeSkip: //skip number
	CLR temp //reset system clock
	STS TCNT1H, temp
	STS TCNT1L, temp
	RJMP updateRound //increment elpased time

debounce:
	SEI
	RETI

; Timer1 interrupt (OCR1A is matched)
timer:
	CPI stage, 1 //checks if is stage 1 (game is ongoing)
	BREQ number //show number (at bottom to the 'relative branch out of reach errors')
	CPI stage, 2 //checks if it not stage 2 (calculating and displaying score)
	BREQ displayScore //calculate and show first iteration of score
	CPI stage, 3 //checks if it not stage 3 (toggling score)
	BREQ toggleScore //toggle score

;STAGE 2 - calculating and displaying score
displayScore: //display score
	CLR seed
	CPI score, 10 //checks if score is greater than or equal to 10
	BRLO singleDigit //if not, show single digit
doubleDigit: //if score is greater than 10
	SUBI score, 10 //sub 10 from score
	INC seed //increment seed (which has been cleared)
	CPI score, 10 //check if score is greater than or equal to 10
	BRSH doubleDigit //if still greater or equal to loop
	LDI temp, 0b0000_0001
	OUT DDRC, temp //enables decimal point (won't need if only single digit - so enabled here)
	MOV xh, seed //move into xl for toggle (once less than, the amount of increments is the unit of the tens)
	RJMP numberswitch //display first digit
singleDigit: //once score is less than 10
	MOV seed, score //move into seed to display digit
	MOV xl, score //move into xl for toggle
	LDI temp, decimal //displays decimal point (if DDRC written)
	OUT PORTC, temp
	LDI stage, 3 //set stage to 3 (toggling score)
	RJMP numberswitch //display second digit

;STAGE 3 - toggling score
toggleScore: //toggle score
	CPI toggle, 0 //if toggle variable is 0, show blank
	BREQ blank
	CPI toggle, 1 //if toggle variable is 1, 'double' digit
	BREQ doubleToggle
	CPI toggle, 2 //if toggle variable is 2, 'single' digit
	BREQ singleToggle
blank:
	CLR temp //clear all ports
	OUT PORTB, temp
	OUT PORTD, temp
	OUT PORTC, temp
	CPI xh, 0 //check if xh is blank, therefore, score is in the single digits
	BREQ noDouble //if blank, no double, so jump to method
	INC toggle //if not empty, there is a 'double' digit so set toggle to 1
	RETI
noDouble: //if no 'double' digit
	LDI toggle, 2 //make toggle 2, so it doesnt display a '0' in the loop (skips 'double' digit)
	RETI
doubleToggle:
	MOV seed, xh //display value in xh
	INC toggle //set toggle to 2 (single)
	RJMP numberSwitch //display number
singleToggle:
	MOV seed, xl //display value in xl
	LDI temp, decimal
	OUT PORTC, temp
	CLR toggle //set toggle to 0 (blank)
	RJMP numberSwitch //display number

;STAGE 1 - game is ongoing
number: //display random number
	CLI
	CLR temp //in case current number is the same as previous number

;Toggle LED
toggleLight: //Toggle distraction LED
	IN temp, PORTC
	SBRC temp, 1 //checks tickLED light status
	RJMP off //if on, turn off
	RJMP on
off:
	CLR temp //turn off
	OUT PORTC, temp
	RJMP checkRound
on:
	LDI temp, tickLED //turn on
	OUT PORTC, temp
	RJMP checkRound

;Update timing variables
checkRound: //checks if 3s have passed (250ms * 12 cycles)
	INC tick
	CPI tick, 12 //if 12 cycles have passed
	BREQ updateRound //increment elapsed variable
	SEI //if not return
	RETI
updateRound:
	ADD elapsed, tick //add cycles to elapsed
	CLR tick //reset cycles of interrupts
	LDI temp, 0b0000_0010 //sets PC1 to write (only want to start after first number has appeared)
	OUT DDRC, temp
checkComplete:
	CPI elapsed, 240 //game is 60 seconds, and four, 250ms ticks per second, so game is 240 ticks
	BRSH complete //if complete, jump to method (same or higher because skipping numbers wont be exactly 12 cycles, but will never overflow because 239 + 12 < 255)
	SEI
	RJMP checkPrevious

; if game is complete
complete:
	LDI temp, 0x7A //set ORC1A to 0x7A12 = 31250 ticks = 2s at 16MHz
	STS OCR1AH, temp
	LDI temp, 0x12
	STS OCR1AL, temp
	LDI temp, exInt1 //disable interrupt0, but enable interrupt1
	OUT EIMSK, temp
	LDI temp, sense1 //sets ONLY interrupt1 to trigger on rising edge
	STS EICRA, temp
	CLR temp //clear top of LED and bottom of LED to ONLY display lights - signifies that game has ended
	OUT PORTD, temp
	LDI temp, redLED | greenLED
	OUT PORTB, temp
	CLR temp
	OUT DDRC, temp
	INC stage //set to stage 2 (calculating and displaying score)
	SEI
	RETI

; if game is not complete
checkPrevious: //if previous number is the same as current number, will not distinguish between changes
	CP prevNum, seed
	BREQ changeSeed //if same as previous number, chnage current number
	RJMP numberSwitch //else display number
changeSeed:
	CPI seed, 7 //if number is less than 7, decrease seed (adding twice, so anything above 7 will be an error)
	BRSH decreaseSeed //if higher decrease
increaseSeed: //otherwise increase
	INC seed
	INC seed //increase by two
	RJMP numberSwitch //display number
decreaseSeed: //decrease by 4 (found to lead to more multiples of 3)
	DEC seed
	INC temp //increment temp - which has been cleared beforehand in 'number:'
	CPI temp, 4 //if looped four times
	BRNE decreaseSeed //if not repeat
	RJMP numberSwitch //display number

; Display number
numberSwitch: //pseudo-switch statement based on seed value (self-explantory so no extra comments)
	MOV prevNum, seed
	CPI seed, 1
	BREQ one
	CPI seed, 2
	BREQ two
	CPI seed, 3
	BREQ three
	CPI seed, 4
	BREQ four
	CPI seed, 5
	BREQ five
	CPI seed, 6
	BREQ six
	CPI seed, 7
	BREQ seven
	CPI seed, 8
	BREQ eight
	CPI seed, 9
	BREQ nine
	CPI seed, 0
	BREQ zero
one:
	LDI temp, 1 //Increase sum
	ADD sum, temp
	LDI temp, oneTop //Display to LED
	OUT PORTD, temp
	LDI temp, one_seven_fourBottom
	OUT PORTB, temp
	RETI
two:
	LDI temp, 2 //Increase sum
	ADD sum, temp
	LDI temp, two_threeTop //Display to LED
	OUT PORTD, temp
	LDI temp, twoBottom
	OUT PORTB, temp
	RETI
three:
	LDI temp, 3 //Increase sum
	ADD sum, temp
	LDI temp, two_threeTop //Display to LED
	OUT PORTD, temp
	LDI temp, three_five_nineBottom
	OUT PORTB, temp
	RETI
four:
	LDI temp, 4 //Increase sum
	ADD sum, temp
	LDI temp, fourTop //Display to LED
	OUT PORTD, temp
	LDI temp, one_seven_fourBottom
	OUT PORTB, temp
	RETI
five:
	LDI temp, 5 //Increase sum
	ADD sum, temp
	LDI temp, five_sixTop //Display to LED
	OUT PORTD, temp
	LDI temp, three_five_nineBottom
	OUT PORTB, temp
	RETI
six:
	LDI temp, 6 //Increase sum
	ADD sum, temp
	LDI temp, five_sixTop //Display to LED
	OUT PORTD, temp
	LDI temp, zero_six_eightBottom
	OUT PORTB, temp
	RETI
seven:
	LDI temp, 7 //Increase sum
	ADD sum, temp
	LDI temp, sevenTop //Display to LED
	OUT PORTD, temp
	LDI temp, one_seven_fourBottom
	OUT PORTB, temp
	RETI
eight:
	LDI temp, 8 //Increase sum
	ADD sum, temp
	LDI temp, eight_nineTop //Display to LED
	OUT PORTD, temp
	LDI temp, zero_six_eightBottom
	OUT PORTB, temp
	RETI
nine:
	LDI temp, 9 //Increase sum
	ADD sum, temp
	LDI temp, eight_nineTop //Display to LED
	OUT PORTD, temp
	LDI temp, three_five_nineBottom
	OUT PORTB, temp
	RETI
zero:
	CLR seed //Resets number variable (seed)
	LDI temp, zeroTop //Display to LED
	OUT PORTD, temp
	LDI temp, zero_six_eightBottom
	OUT PORTB, temp
	RETI