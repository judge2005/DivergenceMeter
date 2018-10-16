;**********************************************************************
;     This file is a basic code template for assembly code generation *
;   on the PIC16F628A. This file contains the basic code              *
;   building blocks to build upon.                                    *
;     Refer to the MPASM User's Guide for additional information on   *
;   features of the assembler (Document DS33014).                     *
;     Refer to the respective PIC data sheet for additional           *
;   information on the instruction set.                               *
;                                                                     *
;**********************************************************************
;                                                                     *
;	Filename:		DivergenceMeter.asm                               *
;	Date:			5-12-2012										  *
;	File Version:	1.05	(REMEMBER to update number in code!)	  *
;                                                                     *
;	Author:			Tom Titor                                         *
;	Company:	    /a/                                               *
;                                                                     *
;**********************************************************************
;	Files Required: P16F628A.INC                                      *
;**********************************************************************
;                                                                     *
;	Notes:	Had to take out "& _DATA_CP_OFF " from template  __CONFIG *
;		line because it resulted in error. Why? The line was:   	  *
;		__CONFIG   _CP_OFF & _DATA_CP_OFF & _LVP_OFF & _BOREN_OFF & _MCLRE_ON & _WDT_OFF & _PWRTE_ON & _INTOSC_OSC_NOCLKOUT  *
;                                                                     *
;   Using internal oscillator 4 MHz (default)                         *
;                                                                     *
;                                                                     *
;		0.00 Had to set MCLRE_OFF in config since that pin floats 	  *
;	unconnected on my board.										  *
;		0.01 Had to turn comparators off to get PORTA to work as	  *
;	inputs, and then stupid typo in doing so wasted hours.			  *
;		0.1 (1/31) Able to display a digit on the tubes.			  *
;		0.2	(2/1) Able to display worldline number to all 8 tubes.	  *
;		0.3	(2/1) Testing animation of number.						  *
;		0.37(2/2) More animation messin'							  *
;		0.4 (2/6) Worldline number random rolls	work!				  *
;		0.43(2/7) Adjustable brightness with fading pulse at end	  *
;		0.44(2/13) Worked on long/short button pushes.				  *
;		0.45(2/15) Adding I2C to talk to DS1307 Real-time Clock chip  *
;			using Andrew D. Vassallo's bit banging from piclist.com	  *
;			(2/17) Works. Long time debugging since it apparently	  *
;			MUST have the backup battery in there to work reliably.	  *
;		0.5 (2/17) Working on the Clock display and interface.		  *
;		0.6	(2/19) Clock works. Working on settings interface.		  *
;		0.7	(2/21) Basic settings done: Time / Date / Brightness.	  *
;		0.75(2/22) Added preset world lines from anime/visual novel.  *
;		0.8	(2/25) Added manual world line entry. Added random beta	  *
;			and neg. world lines. Put useful things in subroutines.	  *
;		0.85(2/27) Date format pref (MM DD YY or DD MM YY) done.	  *
;		0.90(2/28) Tube blanking hours. Fun2 roll at top of hour.	  *
;		1.0 (3/3) Time adjustment implemented and tested.			  *
;	All originally planned features have been implemented.			  *
;		1.01 (3/22) Fixed bug in setting 12/24-hour format from 	  *
;			the value stored in EEPROM location 7F.					  *
;		1.02 (3/30) Changed so the device starts up in clock mode.	  *
;			Mainly because if there is a power outage, you don't	  *
;			want the device to wake up and stay with one number on    *
;			the nixie tubes for an extended period.					  *
;		1.03 (4/20) Fixed error in Year-setting routine.			  *
;		1.04 (5/11) Fixed error in error routine that reports "666"   *
;			if the clock chip does not respond. This did not work	  *
;			right at power-up because the tube power was still off,	  *
;			so I added lines to turn tubes on to the error handler.	  *
;			ALSO added version number display. The version number	  *
;			will be displayed as long as switch 2 is held on the way  *
;			into the Settings menu.									  *
;		1.05 (5/12) Works for either DS1307 or DS3232 clock chips.	  *
;																	  *
;**********************************************************************

	list      p=16f628A           ; list directive to define processor
	#include  "C:\Program Files\Microchip\MPASM Suite\P16F628A.INC"       ; processor specific variable definitions

	errorlevel  -302              ; suppress message 302 from list file

	__CONFIG   _CP_OFF & _LVP_OFF & _BOREN_OFF & _MCLRE_OFF & _WDT_OFF & _PWRTE_ON & _INTOSC_OSC_NOCLKOUT 

; '__CONFIG' directive is used to embed configuration word within .asm file.
; The lables following the directive are located in the respective .inc file.
; See data sheet for additional information on configuration word settings.




;***** VARIABLE DEFINITIONS
wTmp		EQU		0x7E        ; variable used for context saving 
statusTmp	EQU		0x7F        ; variable used for context saving

ShadowA		equ		20			; shadow register for PORTA
ShadowB		equ		21			; shadow register for PORTB
Delay1		equ		22			; for delay
Delay2		equ		23			; for delay
Counter		equ		24			; counter

								; NOTE! The following 26 registers must be in the order below!
LeftDP		equ		25			; Flags for left decimal places
RightDP		equ		26			; Flags for right decimal places
T0			equ		27			; Number for Tube 0 (rightmost). An 11(base 10) in these means no digit in that tube.
T1			equ		28			; etc.
T2			equ		29			; .
T3			equ		2A			; .
T4			equ		2B			; .
T5			equ		2C			; .
T6			equ		2D			; .
T7			equ		2E			; Number for Tube 7 (leftmost)
TR0			equ		2F			; Run length for Tube 0 (rightmost) (i.e., cycles to run until digits halt)
TR1			equ		30			; etc.
TR2			equ		31			; .
TR3			equ		32			; .
TR4			equ		33			; .
TR5			equ		34			; .
TR6			equ		35			; .
TR7			equ		36			; Run length for Tube 7 (leftmost)
V0			equ		37			; Values for tubes to stop at (using alternate animation method)
V1			equ		38			; .
V2			equ		39			; .
V3			equ		3A			; .
V4			equ		3B			; .
V5			equ		3C			; .
V6			equ		3D			; .
V7			equ		3E			; .

Flag		equ		3F			; Flag register
n			equ		40			; Work register used by Loader
m			equ		41			; Work register used by Loader
LDP			equ		42			; Work register used by Loader
RDP			equ		43			; Work register used by Loader
random		equ		44			; random number
work		equ		45			; Work register for use inside any subroutine
bright		equ		46			; Brightness value 0 (dimmest) to 7 (brightest) currently in use.
incMin		equ		47			; Register to hold Minimum while incrementing settings
incMax		equ		48			; Register to hold Maximum while incrementing settings
oldMin		equ		49			; Register to hold old minutes (so we can tell if they were changed)
blankStart	equ		4A			; Register to hold starting hour of tube blanking
blankEnd	equ		4B			; Register to hold ending hour of tube blanking
hourCount	equ		4C			; Register to count down hours until time adjustment
oldHour		equ		4D			; Register to track start of hour

LED			equ		0			; LED is bit 0 in PORTB
HVE			equ		1			; High Voltage Enable is bit 1 in PORTB
CLK			equ		2			; Clock line for serial-to-parallel drivers is bit 2 in PORTB
NBL			equ		3			; NOT Blank for serial-to-parallel drivers is bit 3 in PORTB
DAT			equ		4			; Data line for serial-to-parallel drivers is bit 4 in PORTB
NLE			equ		5			; NOT Latch Enable for serial-to-parallel drivers is bit 5 in PORTB
SW1			equ		2			; Switch 1 is bit 2 in PORTA
SW2			equ		3			; Switch 2 is bit 3 in PORTA

short1		equ		0			; Short press of Button 1 was made
long1		equ		1			; Long press of Button 1 was made
short2		equ		2			; Short press of Button 2 was made (or any press...not tracking long)
long2		equ		3			; (reserved in case I want to track long pressed of Button 2)
Done		equ		4			; Flag Bit 4 used to see if world line animation is done
Slide		equ		5			; Flag Bit 5 used for 'slide loading' in Loader (1=slide)
APnow		equ		6			; Flag Bit 6 keeps track of whether current time is AM or PM (1=PM)
Clk12		equ		7			; Flag Bit 7 is 12/24 hour preference flag (1=12 hour clock)

negWL		equ		7			; Bit 7 of Eflag is for negative world lines.
toggl		equ		6			; Bit 6 of Eflag is for toggling
beta		equ		5			; Bit 5 of Eflag is for beta world line

deBounceDly	equ		d'30'		; Set the constant for the deBounce delay time

; Variables for I2C routines need to be accessable in Bank1, so I'll start them at 70h (where there are registers availble to both Banks 0 and 1).
GenCount	equ		70			; General-purpose counter/scratch register
Mem_Loc		equ		71			; Memory address within DS1307 chip to access
Data_Buf	equ		72			; Byte read from DS1307 gets stored here
Out_Byte	equ		73			; Used to hold byte to be written to DS1307
Eflag		equ		74			; Flag bit register

brightSet	equ		75			; Clock Brightness preference by user (also here so it can be loaded from EEPROM 7Eh while we are in Bank 1)
dateDMY		equ		76			; Date setting peference by user 1= prefers DD MM YY  0= prefers MM DD YY  (read from in EEPROM 7Dh)
pointer		equ		77			; Pointer to track EEPROM address (accessible from both Banks)
timeAdj		equ		78			; Time adjustment register (number of hours between time adjustments)
timeFast	equ		79			; Time adjustment for Fast or Slow clock (1=fast   0=slow)

; Define port pins for I2C access of DS1307: SCL clock line is RA0. SDA data line is RA1.
; The lines have 10K pullup resistors and will be used in passive control mode where the outputs
; are set to zero, and then controlled by setting and clearing TRISA,0 and TRISA,1. Setting TRIS
; bit high will make pin an input, and the resistor will pull the line connected to that high-Z
; pin high (1). Clearing TRIS bit makes pin an output, and the zero will be output to make the
; line low (0). This must be done in Bank1 where the TRIS register can be accessed. Why all this?
; Because this way the I2C slave (DS1307) can pull the high line low in response.
; Where the assembler sees the symbols defined below, they are the same as the "TRISA,n" stuff 
; (or as "PORTA,n" in Bank0).

#define		SCL		TRISA,0
#define		SDA		TRISA,1

;**********************************************************************
			ORG     0x000		; processor reset vector
			goto    Main        ; go to beginning of program
	
;======================
;Interrupt routines
			ORG     0x004		; interrupt vector location
			movwf   wTmp		; save off current W register contents
			movf	STATUS,w    ; move status register into W register
			movwf	statusTmp	; save off contents of STATUS register
; isr code can go here or be located as a call subroutine elsewhere
			movf    statusTmp,w	; retrieve copy of STATUS register
			movwf	STATUS      ; restore pre-isr STATUS register contents
			swapf   wTmp,f
			swapf   wTmp,w		; restore pre-isr W register contents
			retfie              ; return from interrupt

;======================
;Subroutines

RunLength	addwf	PCL,f		; Lookup Table for run lengths (appropriate random number in W... 0-7, 0-15, 0-63)
			retlw	d'20'		; The first 8 are multiples of 10, for use when tube 7 returns to starting digit.
			retlw	d'30'		; The first 16 are multiples of 5, for use when two cycles return digits to same.
			retlw	d'40'		; The rest of the 64 are spaced to give good stopping distribution.
			retlw	d'50'		;
			retlw	d'50'		;
			retlw	d'60'		;
			retlw	d'60'		;
			retlw	d'70'		; Last of the first 8
			retlw	d'15'		;
			retlw	d'25'		;
			retlw	d'35'		;
			retlw	d'45'		;
			retlw	d'55'		;
			retlw	d'55'		;
			retlw	d'55'		;
			retlw	d'65'		; Last of the first 16
			retlw	d'18'		;
			retlw	d'19'		;
			retlw	d'22'		;
			retlw	d'23'		;
			retlw	d'24'		;
			retlw	d'26'		;
			retlw	d'27'		;
			retlw	d'28'		;
			retlw	d'29'		;
			retlw	d'31'		;
			retlw	d'32'		;
			retlw	d'33'		;
			retlw	d'34'		;
			retlw	d'36'		;
			retlw	d'37'		;
			retlw	d'38'		;
			retlw	d'39'		;
			retlw	d'41'		;
			retlw	d'42'		;
			retlw	d'43'		;
			retlw	d'44'		;
			retlw	d'46'		;
			retlw	d'47'		;
			retlw	d'48'		;
			retlw	d'49'		;
			retlw	d'16'		;
			retlw	d'51'		;
			retlw	d'17'		;
			retlw	d'52'		;
			retlw	d'68'		;
			retlw	d'53'		;
			retlw	d'67'		;
			retlw	d'21'		;
			retlw	d'69'		;
			retlw	d'54'		;
			retlw	d'56'		;
			retlw	d'56'		;
			retlw	d'64'		;
			retlw	d'57'		;
			retlw	d'57'		;
			retlw	d'66'		;
			retlw	d'58'		;
			retlw	d'58'		;
			retlw	d'63'		;
			retlw	d'59'		;
			retlw	d'59'		;
			retlw	d'61'		;
			retlw	d'62'		; Last of 64

;--------

deBounce						; Debounce delay with brightness control
			bsf		ShadowB,NBL	; Set bit for tubes NOT Blanked
			movfw	Delay2		; Get current Delay2 value
			andlw	b'00000111'	; Keep only 3 rightmost digits (0 to 7)
			subwf	bright,w	; See if result is greater than brightness number
			btfss	STATUS,C	;   If Y<w, C=0
			bcf		ShadowB,NBL	;   So if Y<w, Clear bit for tubes Blanked
			movfw	ShadowB		; Move tube blanking result to PORTB
			movwf	PORTB		;
deBounce1	decfsz	Delay1,f	; Runs through 256 loopings of Delay1
			goto	deBounce1	; 
			decfsz	Delay2,f	; Decrements Delay2
			goto	deBounce	; If Delay2 not over, wait more.
			movlw	deBounceDly	; Delay2 ran out, so reload it for next time
			movwf	Delay2
			return
	
;-------

delay		movwf	Counter		; Delay with brightness control. Time in W when called.
delay1		bsf		ShadowB,NBL	; Set bit for tubes NOT Blanked
			movfw	Counter		; Get current Counter value
			andlw	b'00000111'	; Keep only 3 rightmost digits (0 to 7)
			subwf	bright,w	; See if result is greater than brightness number
			btfss	STATUS,C	;   If Y<w, C=0
			bcf		ShadowB,NBL	;   So if Y<w, Clear bit for tubes Blanked
			movfw	ShadowB		; Move tube blanking result to PORTB
			movwf	PORTB		;
delay2		decfsz	Delay1,f	; Inner loop...
			goto	delay2		;   runs through 256 loopings decrementing Delay1
			decfsz	Counter,f	; Decrement Counter.
			goto	delay1		;   and do more loops until Counter is zero
			return

;-------

delay100	movwf	Counter		; Delay 100% brightness. Time in W when called.
delay3		decfsz	Delay1,f	; Inner loop...
			goto	delay3		;   runs through 256 loopings decrementing Delay1
			decfsz	Counter,f	; Decrement Counter.
			goto	delay3		;   and do more loops until Counter is zero
			return				; Retuns with W intact to call again if desired

;-------

FillBlanks	movlw	d'8'		; Going to blank 8 tubes
			movwf	Counter		;   with this counter
			movlw	T0			; ADDRESS of T0
			movwf	FSR			;   for indirect addressing
			movlw	d'10'		; 10 will display blank in tube
nextBlank	movwf	INDF		; Put it in a tube register
			incf	FSR,f			; Increment for next tube
			decfsz	Counter,f	; See if I'm done
			goto	nextBlank	;   Not yet
			return				;

;-------

; This routine gets the contents of a register from DS1307 and puts the ones digit in T0 and
; the ones digit in T1.
; Call with memory location value in W, *or* call GetT1T0b if location is already in Mem_Loc

GetT1T0		movwf	Mem_Loc		
GetT1T0b	call	ReadDS1307	; Get the contents from the clock register with location already in Mem_Loc
FillT1T0	movfw	Data_Buf	; (for calls that jump in here, bring Data_Buf into W)
			andlw	b'00001111'	;
			movwf	T0			; Put ones digit into T0
			swapf	Data_Buf,w	;
			andlw	b'00001111'	;
			movwf	T1			; Put tens digit into T
			return

;-------

Buttons		movlw	b'11110000'	; Clear the Button flag return bits (bits 0-3)
			andwf	Flag,f		;
			call	deBounce	; Call deBounce to give the tubes some properly dimmed display time
			btfsc	PORTA,SW1	; Button 1 pressed?
			goto	length		;    ...yes, go see if it's long or short
			btfsc	PORTA,SW2	; Button 2 pressed?
			goto	any2press	;    ...yes, go handle button 2 press
			goto	Buttons		; Neither button pressed. Wait more.
length		movlw	d'40'		; This many deBounce times is a long push
			movwf	Counter		;   (With deBounce Delay2=30 and Counter=40, about 1 second)
watch		btfss	PORTA,SW1	; Button 1 released?
			goto	short1press	;    ...yes. Go handle short push of Button 1.
			call	deBounce	; Wait some (tubes get displayed with dimming during deBounce)
			decfsz	Counter,f	; Done counting?
			goto	watch		;   ...still counting. Go wait more.
								; Fallen out of long delay...
long1press	btfsc	PORTA,SW1	; Handle long press of button 1
			goto	long1press	;    ...after first waiting for release.
			call	deBounce	; deBounce after relase.						
			bsf		Flag,long1	; Flag long press of Button 1
			return
short1press	call	deBounce	; 
			bsf		Flag,short1	;
			return
any2press	btfsc	PORTA,SW2	; Handle press of button 2
			goto	any2press	;    ...after first waiting for release.
			call	deBounce	; deBounce after relase.	
			bsf		Flag,short2	;
			return

;--------

Increment	call	deBounce	; This routine increment/decrements settings values
			call	Buttons
			btfsc	Flag,short2	; If Button 2 press, done adjusting
			return  
			btfsc	Flag,short1	; If Button 1 short press...
			goto	incValue	;    ...go increment value
decValue	movfw	incMin		;    ...otherwise, decrement value. First we see if it already at Min...
			subwf	Data_Buf,w	;       ...by subtracting (packed BCD numbers). Result will be Zero if they are the same.
			btfsc	STATUS,Z	; 
			goto	setToMax	; If Z=1, they were the same, so go set Data_Buf to incMax.
								; If Z=0, decrement the packed BCD. 
decBCD		movlw 	b'00001111'	; First check to see if the right digit is 0000...
			andwf	Data_Buf,w	;   ...by grabbing the right digit into W
			btfss	STATUS,Z	; If the result in W was Zero, the Z bit will be set
			goto	decNow		;   ...If Z=0, go decrement directly
			movlw	b'00001001'	;   ...If Z=1, the right digit was zero, and we must set it to 9 and borrow
			addwf	Data_Buf,f	;        Here is the setting the right digit to 9 instead of zer0
			movlw	b'00010000'	;        And then...
			subwf	Data_Buf,f	;        ...here is the subtracting 1 from the left digit (borrow).
			goto	valueOK
decNow		decf	Data_Buf,f	; If the right digit is not zero, we can just decrement the packed BCD directly.
			goto	valueOK		;    and be done.
setToMax	movfw	incMax		; Take the packed BCD pattern of incMax...
			movwf	Data_Buf	; ...and put it into Data_Buf.
			goto	valueOK		;
incValue	movfw	incMax		; Move incMac (packed BCD) into W for compare	
			subwf	Data_Buf,w	; If Data_Buf is >= max, result will Carry flag will be set
			btfsc	STATUS,C	;   If C clear, go increment.
			goto	setToMin	;   If C set, go put incMin in.
incBCD		incf	Data_Buf,f	; Increment the packed BCD. This might cause right digit to go to hex A...
			movlw	b'00001111'	;    so let's get that digit...
			andwf	Data_Buf,w	;    by doing this...
			sublw	b'00001010'	;    so we can compare to hex A
			btfss	STATUS,Z	; Is that digit hex A? If it is, Z=1
			goto	valueOK		;    If Z is not set, we are fine and quit
			movlw	b'11110000'	;    If Z is set...
			andwf	Data_Buf,f	;       ...do this AND to zero out the right digit...
			movlw	b'00010000'	;		...and add one to the left digit...
			addwf	Data_Buf,f	;       ...and done!
			goto	valueOK		;
setToMin	movfw	incMin		; Take the packed BCD pattern of incMin...
			movwf	Data_Buf	; ...and put it into Data_Buf.
			goto	valueOK		;	
valueOK		call	FillT1T0	; Fill new value into tubes
			call 	Loader		;
			goto	Increment	;


;--------

								; Routine to send a 1 to the serial-to-parallel drivers.
send1		bsf		ShadowB,DAT	; Set Data line high for one
			bsf		ShadowB,CLK	; Set clock high
			movfw	ShadowB		; Copy ShadowB...
			movwf	PORTB		; ...to PORTB
			bcf		ShadowB,CLK	; Set clock low
			movfw	ShadowB		; Copy ShadowB...
			movwf	PORTB		; ...to PORTB
			return
;-------
								; Routine to send a 0 to the serial-to-parallel drivers.
send0		bcf		ShadowB,DAT	; Set Data line high for one
			bsf		ShadowB,CLK	; Set clock high
			movfw	ShadowB		; Copy ShadowB...
			movwf	PORTB		; ...to PORTB
			bcf		ShadowB,CLK	; Set clock low
			movfw	ShadowB		; Copy ShadowB...
			movwf	PORTB		; ...to PORTB
			return
;-------

RandomNum	movlw	d'63'		; Pseudo-random number generator
			addwf	random,w	; newRandom = 3 x oldRandom + 63
			addwf	random,w	;
			addwf	random,f	;
			movfw	random		;
			return				;


;-------

; Call with: DS1307 register address in Mem_Loc
; Returns with: byte in Data_Buf

ReadDS1307	bcf		STATUS,RP0	; Bank0
			movfw	ShadowA		; Clear bits RA0 and RA1 in shadowA and PORTA...
			andlw	b'11111100'	;   ...for passive control of the I2C lines (if one of those pins gets
			movwf	ShadowA		;   ...set as output, these zeros will make the line low, and if the
			movwf	PORTA		;	...pin is set as (Hi-Z) inputs, a resistor pulls the line high.
			bsf		STATUS,RP0	; Select Bank 1 for TRISA access (passive SCL/SDA control)
			bsf		SDA			; Let SDA line get pulled high (by setting it as a input)
			bsf		SCL			; Let SCL line get pulled high (by setting it as a input)
			bcf		SDA			; START condition = data line going low while clock line is high
			movlw	b'11010000'	; Send Write (to set address before reading)
			call	Byte_Out	;
			btfsc	Eflag,0		; Eflag bit0 will be set if no ACK received from DS1307
			goto	Err_Routine	; NOTE: MUST USE "RETURN" FROM THAT ROUTINE
			movfw	Mem_Loc		; Memory location we want to read is in Mem_Loc
			call	Byte_Out	;   ...and needs to be in W when Byte_Out is called
			btfsc	Eflag,0		;
			goto	Err_Routine	;
			bcf		SCL			; Pull clock line low in preparation for 2nd START bit
			nop					;
			bsf		SDA			; Data line gets pulled high - data transition during clock low
			bsf		SCL			; Clock line gets pulled high to begin generating START
			bcf		SDA			; 2nd START condition as data line goes low
			movlw	b'11010001'	; Request data read from DS1307 register
			call	Byte_Out	;
			btfsc	Eflag,0		;
			goto	Err_Routine	;
								; Note that Byte_Out leaves with SDA line freed to allow slave to send data in to master.
			call	Byte_In		;
			movfw	Data_Buf	; put result into W register for returning from CALL
			bcf		SCL			; extra cycle for SDA line to be freed from DS1307
			nop					;
			bcf		SDA			; ensure SDA line low before generating STOP
			bsf		SCL			; pull clock high for STOP
			bsf		SDA			; STOP condition = data line goes high while clock line is high
			bcf		STATUS,RP0	; leave with Bank 0 active as default
			return

;-------

; Save each byte as it's written
; Call with: a DS1307 resister address in Mem_Loc, byte to be sent in Data_Buf
; Returns with:  nothing returned

WriteDS1307	bcf		STATUS,RP0	; Bank0
			movfw	ShadowA		; Clear bits RA0 and RA1 in shadowA and PORTA
			andlw	b'11111100'	;   ...for passive control of the I2C lines (if one of those pins gets
			movwf	ShadowA		;   ...set as output, these zeros will make the line low, and if the
			movwf	PORTA		;	...pin is set as (Hi-Z) inputs, a resistor pulls the line high.
			bsf		STATUS,RP0	; select Bank 1 for TRISB access (passive SCL/SDA control)
			bsf		SDA			; ensure SDA line is high
			bsf		SCL			; clock high gets pulled high
			bcf		SDA			; START condition = data line going low while clock is high
			movlw	b'11010000'	; Send Write code (to set address first)
			call	Byte_Out	;
			btfsc	Eflag,0		; Eflag bit0 gets set of not ACK received from DS1307
			goto	Err_Routine	; NOTE: MUST USE "RETURN" FROM THAT ROUTINE
			movfw	Mem_Loc		; Send the memory location to wite to...
			call	Byte_Out	; ...now
			btfsc	Eflag,0		;
			goto	Err_Routine	;
			movfw	Data_Buf	; move data byte to be sent to W
			call	Byte_Out	;
			btfsc	Eflag,0		;
			goto	Err_Routine	;
			bcf		SCL			; extra cycle for SDA line to be freed from DS1307
			nop					;
			bcf		SDA			; Ensure SDA line low before generating STOP...
			bsf		SCL			; pull clock high for STOP..
			bsf		SDA			; STOP condition = data line goes high.
			bcf		STATUS,RP0	; Leave with Bank 0 active by default
			return

;-------

; This routine reads one byte of data from the DS307 real-time Clock chip into Data_Buf

Byte_In		clrf	Data_Buf	;
			movlw	0x08		; 8 bits to receive
			movwf	GenCount	;
ControlIn	rlf		Data_Buf,f	; Shift bits into buffer
			bcf		SCL			; Pull clock line low
			nop					;
			bsf		SCL			; Clock line gets pulled high to read bit
			bcf		STATUS,RP0	; Select Bank 0 to read PORTA bits directly!
			btfss	SDA			; Test bit from DS1307 (if bit=clear, skip because Data_Buf is clear)
			goto	$+3			; Jump ahead 3 instructions
			bsf		STATUS,RP0	; Select Bank 1 to access variables (Don't think I need this [could nop], but I'll leave it.)
			bsf		Data_Buf,0	; Read bit into 0 first, then eventually shift to 7
			bsf		STATUS,RP0	; Select Bank 1 to access variables (Don't think I need this [could nop], but I'll leave it.)
			decfsz	GenCount,f	;
			goto	ControlIn	;
			return

;-------

; This routine sends out the byte in the W register and then waits for ACK from DS1307 (256us timeout period)
Byte_Out	movwf	Out_Byte	; Byte to send was in W...now also in Out_Byte
			movlw	0x08		; 8 bits to send
			movwf	GenCount	;
			rrf		Out_Byte,f	; shift right in preparation for next loop
ControlOut	rlf		Out_Byte,f	; shift bits out of buffer
			bcf		SCL			; pull clock line low
			nop					;
			btfsc	Out_Byte,7	; send current "bit 7"
			goto	BitHigh		;
			bcf		SDA			;
			goto	ClockOut	;
BitHigh		bsf		SDA			;
ClockOut	bsf		SCL			; pull clock high after sending bit
			decfsz	GenCount,f	;
			goto	ControlOut	;
			bcf		SCL			; pull clock low for ACK change
			bsf		SDA			; free up SDA line for slave to generate ACK
			nop					; wait for slave to pull down ACK
			nop
			nop					
			bsf		SCL			; pull clock high for ACK read
			clrf	GenCount	; reuse this register as a timeout counter (to 256us) to test for ACK
WaitForACK	bsf		STATUS,RP0	; select Bank1 for GenCount access (Don't think I need this [could nop], but I'll leave it.)
			incf	GenCount,f	; increase timeout counter each time ACK is not received
			btfsc	STATUS,Z	; Z will be clear until we increment GenCount all the way up to zero (after 256 times)
			goto	No_ACK_Rec	;
			bcf		STATUS,RP0	; select Bank0 to test SDA PORTA input directly!
			btfsc	SDA			; test pin. If clear, EEPROM is pulling SDA low for ACK
			goto	WaitForACK	; ...otherwise, continue to wait
			bsf		STATUS,RP0	; select Bank1 as default during these routines
			bcf		Eflag,0		; clear flag bit (ACK received)
			return

;-------

; No ACK received from DS1307 (must use "return" from here)
; Set a flag bit to indicate failed write and check for it upon return.
No_ACK_Rec	bsf		Eflag,0		; set flag bit
			return				; returns to Byte_Out routine (Bank 1 selected)

;-------

; No ACK received from slave.  This is the error handler.
Err_Routine
			bcf		STATUS,RP0	; make sure I'm in Bank0 to flash LED
			call	FillBlanks	; fill tubes with blanks
			movlw	d'6'		; Put error code "666" in tubes 0-2
			movwf	T2
			movwf	T1
			movwf	T0
			clrf	LeftDP		; Clear the decimal points
			clrf	RightDP
			call	Loader		; Load the display
			bsf		ShadowB,NBL	; set NOT Blanking high (tubes no longer blanked),
			bsf		ShadowB,HVE	; and Set High Voltage Enable ON to display the tubes now, too.
			movfw	ShadowB		; Copy ShadowB...
			movwf	PORTB		; ...to PORTB 
Crash666	goto	Crash666	; Infinite loop crash.
								; And unused below, just for the look of things:
			return				; returns to INITIAL calling routine

;------

Fun			clrf	T7			; Zero out the leftmost tube for most random world lines
			bcf		Eflag,beta	; Clear the beta world line flag.
			bcf		Eflag,negWL	; Clear negative world line flag.
			movfw	TMR0		; Seed 0-255 randomly by switch release that got us here
			movwf	random		; Store the random number.
								; Other worldline branchings will go here:
			call	RandomNum	; Gets 0-255 in W
			andlw	b'11111100'	; This will clear the right two bits of W and leave the rest unaltered. If W is now zero, it
								;    must have been 0 to 3 before the AND.																  
			btfsc	STATUS,Z	; See if the random number is now zero (4 out of 256 chance)
			bsf		Eflag,negWL	;    If so, make this a negative world line (first tube will show up blank).
			andlw	b'11110000'	; This will clear the right three bits of W and leave the rest unaltered. If W is now zero, it
								;    must have been 0 to 15 before the AND.
			btfsc	STATUS,Z	; See if W is now zero (16 out of 256 chance it is)
			bsf		Eflag,beta	; Display a beta world line number (1.xxxxxx)
								; (Of course, it was 0, we already flagged it as negative WL)
			call	RandomNum	; Gets 0-255 in W
			andlw	b'00000111'	; 0-7 in W
			call	RunLength	; Gets runlength that's a multiple of 10 for tube 7
			movwf	TR7			;    so leftmost tube will return to 0.
			btfsc	Eflag,beta	; But if we got a beta world line...
			incf	TR7,f		;   increment the run length so it will stop at one.
			clrf	TR6			; Decimal point tube does no incrementing.
FillRunLens	movlw	TR5			; ADDRESS of TR5
			movwf	FSR			;    for indirect addressing.
nextRL		call	RandomNum	; Gets 0-255 in W
			andlw	b'00111111'	; 0-63 in W
			call 	RunLength	; Gets tube's run length
			movwf	INDF		;    and puts it in TRn
			decf	FSR,f		; Decrement for next tube
			movlw	T7			; ADDRESS of T7 register (below the TRn registers)
			subwf	FSR,w		; Does FSR minus T7;s address
			btfss	STATUS,Z	;   see if result is zero
			goto	nextRL		;   no...go get runlength for next tube
								;   yes...all TRn filled
			call	animate		;
			return				;

;-------

animate		bcf		Flag,Done	; Clear bit Done of Flag for tracking if animation is done.
			movfw	TR7			; Load TR7 runlength into W
			btfsc	STATUS,Z	;   and see if it's zero.
			goto	chkNeg		;   If zero, skip to tubes 5 thru 0 (7 has already stopped)
			decf	TR7,f		;	If not zero, do tube 7. Decrement runlength.
			bsf		Flag,Done	; Set bit so we know we haven't finished aniation.
			incf	T7,f		; Increment T7 value
			movlw	d'10'		; See if it went over 9...
			subwf	T7,w		;
			btfsc	STATUS,C	;   If new T7 < 10, C=0
			clrf	T7			;     so clear T7 to zero if it reached 10.
			goto	IncTubes	; On to tubes 5-0
chkNeg		movlw	d'10'		; Before we go one to tubes 5-0, check to see if this is a negative world line...
			btfsc	Eflag,negWL	;  
			movwf	T7			;    ...If it is, we blank tube 7. 
IncTubes	movlw	TR5			; ADDRESS of TR5
			movwf	FSR			;   for indirect addressing
nextTube	movfw	INDF		; Put TRn runlength into W
			btfsc	STATUS,Z	;    and see if it's zero.
			goto	notthis		;    If zero, don't do this tube (done animating it), and go to next one.
			decf	INDF,f		;    If not zero, do this tube. Decrement runlength.
			bsf		Flag,Done	; Set bit so we know we haven't finished aniation.
			movlw	d'8'		; Subtract 8 from FSR so it points
			subwf	FSR,f		;   to Tn instead of TRn
			incf	INDF,f		; Increment Tn
			movlw	d'10'		; See if it went over 9...
			subwf	INDF,w		;
			btfsc	STATUS,C	;   If new Tn < 10, C=0
			clrf	INDF		;     so clear Tn to zero if it reached 10.		
			movlw	d'8'		; Add 8 back into FSR to
			addwf	FSR,f		;    put it back to TRn
notthis		decf	FSR,f		; Decrement to do next tube
			movlw	T7			; ADDRESS of T7 register (below the TRn registers)
			subwf	FSR,w		; Does FSR minus T7's address
			btfss	STATUS,Z	; If we have done all the tubes, Zero flag will be clear.
			goto	nextTube	;    if Zero not clear, go do next tube
								;    We get here if all tubes done.
			btfss	Flag,Done	; See if no tubes were changed (Flag,Done would be clear).
			goto	alldone		;    No tubes changed...we are finished

			call 	Loader		; Display the new number in the tubes
			movlw	d'30'		; Delay to see the number
			call	delay		; 
			goto	animate		; And go to the next animation step.
alldone		call	Pulse		; Animation done. Do flash at end of animation
			return				;

;------

Pulse		movlw	d'7'		; Flash full brightness
			movwf	bright		;
			movlw	d'200'		; Flash at end of animation
			call	delay		; 
			movlw	d'6'		; Fade to level 6 brightness
			movwf	bright		;
			movlw	d'50'		; 
			call	delay		; 
			movlw	d'5'		; Fade to level 5 brightness
			movwf	bright		;
			movlw	d'40'		; 
			call	delay		; 
			movlw	d'4'		; Fade to level 4 brightness
			movwf	bright		;
			movlw	d'30'		; 
			call	delay		; 
			movlw	d'3'		; Fade to level 3 brightness
			movwf	bright		;
			return				; 

;------

Fun2		movfw	TMR0		; Seed 0-255 randomly by switch release that got us here
			movwf	random		; Store the random number.
FillRuns	movlw	TR7			; ADDRESS of TR7
			movwf	FSR			;    for indirect addressing.
nextRLen	call	RandomNum	; Gets 0-255 in W
			andlw	b'00111111'	; 0-63 in W
			call 	RunLength	; Gets tube's run length
			movwf	INDF		;    and puts it in TRn
			decf	FSR,f		; Decrement for next tube
			movlw	T7			; ADDRESS of T7 register (below the TRn registers)
			subwf	FSR,w		; Does FSR minus T7's address
			btfss	STATUS,Z	;   see if result is zero
			goto	nextRLen	;   no...go get runlength for next tube
								;   yes...all TRn filled
			clrf	TR6			; Decimal point tube does no incrementing. I could have not filled it, but it seems simpler to just clear it now.
			call	animate2	;
			return

;------
								; animate2 is different from animate in that when it stops it will be displaying V7-V0 values.
animate2	bcf		Flag,Done	; Clear bit Done of Flag, for tracking if animation is done.
IncTubes2	movlw	TR7			; ADDRESS of TR7
			movwf	FSR			;   for indirect addressing
nextTube2	movfw	INDF		; Bring TRn runlength into W
			btfsc	STATUS,Z	;    and see if it's zero.
			goto	notthis2	;    If zero, this tube's run length has run out (done animating it), and go to next one.
			decf	INDF,f		;    If not zero, do this tube. Decrement runlength.
			movfw	INDF		; Let's see if it just got to zero after the decrement above
			btfss	STATUS,Z	; 
			goto	keepon		; If it was decremented to zero, we go on as before
			movlw	d'8'		; But if the runtime just decremented to zero, let's make sure it has it's final value in it:
			addwf	FSR,f		;    Add 8 to FSR to get the corresponding Vn register
			movfw	INDF		;    and take the value from that register
			movwf	work		;    hold it here for a while
			movlw	d'16'		;    then point tho the corresponding Tn tube
			subwf	FSR,f		;    by adjusting FSR 16 registers down
			movfw	work		;    grabbing the value
			movwf	INDF		;    and putting it into Tn
			movlw	d'8'		; Then let's bring FSR back to the TRn registers, but one register lower than before
			addwf	FSR,f		;    so we can do the next tube.
			goto	notthis2	;
keepon		bsf		Flag,Done	; Set bit so we know we haven't finished aniation.
			movlw	d'8'		; Subtract 8 from FSR so it points
			subwf	FSR,f		;   to Tn instead of TRn
			incf	INDF,f		; Increment Tn
			movlw	d'10'		; See if it went over 9...
			subwf	INDF,w		;
			btfsc	STATUS,C	;   If new Tn < 10, C=0
			clrf	INDF		;     so clear Tn to zero if it reached 10.		
			movlw	d'8'		; Add 8 back into FSR to
			addwf	FSR,f		;    put it back to TRn
notthis2	decf	FSR,f		; Decrement for next tube.
			movlw	T7			; ADDRESS of T7 register (below the TRn registers)
			subwf	FSR,w		; This does FSR minus T7's address
			btfss	STATUS,Z	; If we have gone through all the tubes another time, Zero flag will be clear.
			goto	nextTube2	;    if Zero not clear, go do next tube
								;    We get here if all tubes done.
			btfss	Flag,Done	; See if no tubes were changed (Flag,Done would be clear).
			goto	alldone2	;    No tubes changed...we are finished
			call 	Loader		; Display the new number in the tubes
			movlw	d'30'		; Delay to see the number
			call	delay		; 
			goto	animate2	; And go to the next animation step.
alldone2	call	Loader		; Final load
			call	Pulse		; Animation done. Do flash at end of animation
			return				;


;------

								; Routin copies T0-T7 into V0-V7
moveNumber	movlw	T0			; ADDRESS of T0
			movwf	FSR			;    for indirect addressing.
nextMove	movfw	INDF		; Get Tn
			movwf	work		; put it in work
			movlw	d'16'		; Change the FSR pointer by +16 to point		
			addwf	FSR,f		;    to the corresponding Vn register
			movfw	work		; Get the value
			movwf	INDF		; and put it where it Vn
			movlw	d'15'		; Change the FSR pointer by -15 to point		
			subwf	FSR,f		;    to the T(n+1) register
			movlw	TR0			; ADDRESS of TR0 (which is right above T7)
			subwf	FSR,w		; Test to see if FSR is pointing to TR0
			btfss	STATUS,Z	;    which will be true if the Zero bit is set;
			goto	nextMove	;    If it's not true, we go do the next tube's values
			return				;    And if it is true, we are all done moving and get here, so Return.


;------

Loader		movfw	LeftDP		; Routine to load a number into all 8 tubes. Values are in T0-T7, LeftDP, and RightDP.
			movwf	LDP			; Make copies of LeftDP and RightDP so contents are not destroyed.
			movfw	RightDP		; 
			movwf	RDP			;
			movlw	T7			; Put the *ADDRESS* of T7 register into W ("T7" is equated to that address)
			movwf	FSR			; ...and then into the File Select Register. We can now access the number we want displayed on a tube using INDF.
loopLoad	rlf		LDP,f		; Rotate a dp flag into the Carry bit
			btfsc	STATUS,C	; Is the dp flag set?
			goto	dpset		;   ...yes, jump to dpset.
			call	send0		;   ...no, so send 0 to the shift registers.
			goto	digi		;      and then jump to continue with the digit.
dpset		call	send1		; dp flag was set, so send 1 to shift registers
digi		movlw	d'9'		; Put 9 into m. This will decrement as we go through loopdigi.
			movwf	m
			clrf	n			; Start with n=0. This will increment as we go through loopdigi.
loopdigi	incf	n,f			; Increment n (n is the number we compare against the digit we want to show).
			movfw	n			; Get the current n...
			subwf	INDF,w		; See if the digit we want to display equals n by subtract n from that digit (via INDF) and leave result in W
			btfsc	STATUS,Z	; If that digit=n (Zero flag will be set from subtraction), then...
			goto	yesdigi		;   ...goto yesdigi
			call 	send0		;   ...otherwise send a 0 to the shift registers.
			goto	nextshift	;      and check the next bit to shift
yesdigi		call	send1		; Digit=n, so send a 1 to the shift registers.
nextshift	decfsz	m,f			; Decrement m and see if we are done.
			goto	loopdigi	;   ...if not done go back to loopdigi
			movfw	INDF		; When we get here we still need to see if the digit is a zero
			btfsc	STATUS,Z	; If that digit=0 (Zero flag will be set from moving it into W), then...
			goto	yeszero		;   ...goto yeszero
			call 	send0		;   ...otherwise send a 0 to the shift registers.
			goto	checkRDP	;      and check the next bit to shift
yeszero		call	send1		; Digit=n, so send a 1 to the shift registers.
checkRDP	rlf		RDP,f		; Digit is done, so check for right decimal point
			btfsc	STATUS,C	; Is the dp flag set?
			goto	dpset2		;   ...yes, jump.
			call	send0		;   ...no, so send 0 to the shift registers.
			goto	tubeDone	;      and then jump to continue		
dpset2		call	send1		; dp flag was set, so send 1 to shift registers
tubeDone	decf	FSR,f		; Decrement File Select Register to do next tube.

			btfss	Flag,Slide	; "Slide Loading" flag
			goto	noSlide		;    If Flag,Slide is clear, normal load (skip this next stuff)
LatchSlide	bsf		ShadowB,NLE	; Latch the result sf current tubes:
			movfw	ShadowB		; Copy ShadowB...
			movwf	PORTB		; ...to PORTB (Latches load when NLE is high)
			bcf		ShadowB,NLE	; Get ready to lock the latches.
			bsf		ShadowB,NBL	; Set NOT Blanking high (tubes no longer blanked) while I'm at it
			movfw	ShadowB		; Copy ShadowB...
			movwf	PORTB		; ...to PORTB (Latches lock when NLE is low)
			movlw	d'80'		; Pause for display
			call 	delay

noSlide		movlw	RightDP		; Put the *ADDRESS* of the RightDP register into W ("RightDP" is equated to that address)
			subwf	FSR,w		; ...and subtract it from FSR to see if we did all the tubes.
			btfss	STATUS,Z	;    If we haven't done all the tubes, Zero flag will be clear
			goto	loopLoad	;    so go back and do the next tube.
Latch		bsf		ShadowB,NLE	; Latch the result:
			movfw	ShadowB		; Copy ShadowB...
			movwf	PORTB		; ...to PORTB (Latches load when NLE is high)
			bcf		ShadowB,NLE	; Get ready to lock the latches.
			bsf		ShadowB,NBL	; Set NOT Blanking high (tubes no longer blanked) while I'm at it
			movfw	ShadowB		; Copy ShadowB...
			movwf	PORTB		; ...to PORTB (Latches lock when NLE is low)
			return





;======================================================================
;Program Start

Main							; Main routine	
Init		clrf	PORTA		; Clear Port A
			clrf	ShadowA		; Clear ShadowA
			movlw	0x07		; Turn comparators off and
			movwf	CMCON		;    enable pins for I/O functions
			clrf	PORTB		; Clear Port B
			clrf	ShadowB		; Clear ShadowB

			bcf		STATUS,RP1	; First time, make sure this is also clear so the next command...
			bsf		STATUS,RP0	; Goes to Bank 1
			movlw	b'00101111'	; Set input/output pins in PORTA
			movwf	TRISA		;	RA0 is SCL (clock) to clock chip
								;	RA1 is SDA (data) to clock chip
								;	RA2 is button 1
								;   RA3 is button 2
								;	RA4-RA7 are not used (except RA5 is for programmer)
			movlw	b'00000000'	; Set all pins as outputs
			movwf	TRISB		;	RB0 is LED output for testing
								;	RB1 is High Voltage Enable
								;	RB2 is Clock line to serial chips
								;	RB3	is NOT Blank line to serial chips
								;	RB4 is Data line to serial chips
								;	RB5 is NOT Latch Enable to serial chips
								;	RB6-RB7 are for programmer
			movlw	b'11011111'	; Set TMR0 to clock off the internal clock, no prescaler (prescaler assigned to WDT)
			movwf	0x81		; Huh... "OPTION" was not recognized here. Why?

								; Read timeFast setting from EEPROM
			movlw	0x7B		; Address to read...
			movwf	EEADR 		; ...gets put here.
			bsf		EECON1,RD	; EE Read
			movfw	EEDATA		; W = EEDATA
			movwf	timeFast	; Put it in its place (which is a register also available in Bank 1)
								; Read timeAdj setting from EEPROM
			movlw	0x7C		; Address to read...
			movwf	EEADR 		; ...gets put here.
			bsf		EECON1,RD	; EE Read
			movfw	EEDATA		; W = EEDATA
			movwf	timeAdj		; Put it in its place (which is a register also available in Bank 1)
								; Read date format setting from EEPROM
			movlw	0x7D		; Address to read...
			movwf	EEADR 		; ...gets put here.
			bsf		EECON1,RD	; EE Read
			movfw	EEDATA		; W = EEDATA
			movwf	dateDMY		; Put it in its place (which is a register also available in Bank 1)
								; Read brightness setting from EEPROM
			movlw	0x7E		; Address to read...
			movwf	EEADR 		; ...gets put here.
			bsf		EECON1,RD	; EE Read
			movfw	EEDATA		; W = EEDATA
			movwf	brightSet	; Put it in its place (which is a register also available in Bank 1)
								; Read 12/24 clock setting from EEPROM
			movlw	0x7F 		; Address to read...
			movwf	EEADR 		; ...gets put here.
			bsf		EECON1,RD	; EE Read
			movfw	EEDATA		; W = EEDATA (W will now have the 12/24 setting, either 00000001 for 12-hour, or 00000000 for 24-hour)
			bcf		STATUS,RP0	; Back to Bank 0
			clrf	Flag		; Clear the Flag register
;			btfsc	W,0			; Clock preference setting from EEPROM is in W from before  <-- ERROR HERE. Can't test bits in W like this!
			movwf	work		; Move W to register "work"...
			btfsc	work,0		;   ...and do the test there.
			bsf		Flag,Clk12	; Set the 12/24 flag based upon it. (1 = 12 hour)
								; I am handling 12/24 setting myself and leaving DS1307 in 24 hour mode.

			movfw	timeAdj		; Copy the timeAdj value into the
			movwf	hourCount	;   hour counter to track when time adjustments need to be made.
								;   Note that this will get reset if you unplug/replug the device, since it may have been previously partway 
								;   through a count...so don't unplug for maximum accuracy (or reset time after unplug). But it will be close.
								;   Also, the hour counter won't count if you are playing in D.M. mode at the top of the hour.

			clrf	Delay1		; Will be used to loop 256 times
			movlw	deBounceDly	; Will loop deBounce this many times (constant deifned in equates)
			movwf	Delay2		; Will be used to loop n times


			bcf		ShadowB,LED	; Set bit for LED OFF in ShadowB
			bcf		ShadowB,NBL	; Set Not Blanking low (this will blank the tubes)
			bcf		ShadowB,HVE	; Set bit for High Voltage Enable OFF
			bcf		ShadowB,NLE	; Set NOT Latch Enable low (transfer of bits from shift registers to latches is OFF)
			bcf		ShadowB,CLK	; Set Clock line low (setting it high and back low will clock the serial chips...62 ns minimum pulse width) 
			movfw	ShadowB		; copy ShadowB to PORTB
			movwf	PORTB		; 
			clrf	Eflag		; Clear the error flag register

								; See if the Real Time Clock is running (or if loss of backup battery power has stopped it). 
			clrf	Mem_Loc		; First check CH (Clock Halt) bit in the seconds register (00h) to see if DS1307 is halted
			call	ReadDS1307	; Read the seconds register (Mem_Loc = 00h) from DS1307 
			btfsc	Data_Buf,7	; Test CH bit (bit 7) 
			goto	Start1307	;   ...if CH is set, DS1307 is stopped and needs startup
								;   ...if CH is clear, either DS1307 is running, or this may be a DS3232 (running or stopped).
			movlw	0x0F		; See if the DS3232 Clock is running by checking bit 7 of 0Fh in the clock chip
			movwf	Mem_Loc		;
			call	ReadDS1307	; Read the 0Fh register (a control/status register in the DS3232; a RAM register in the DS1307)
			btfss	Data_Buf,7	; Oscillator Stopped Flag is bit 7 
			goto	ClockON		;   ...if OSF is clear, Clock was running (with battery backup)
								;   ...if we get here, this is either a stopped DS3232, or a running DS1307 that just 
								;	happens to have RAM 0Fh bit 7 set. To test this, we will try writing a 1 to 0Fh Bit 0 
								;	which is a flag bit in the DS3232 that CAN'T have a 1 written to it.
			bcf		Data_Buf,0	; First we clear bit 0
			call	WriteDS1307	;   ...and write a zero to that bit in 0Fh (just in case there was a 1 there to bein with)
			bsf		Data_Buf,0	;	...then we SET bit 0 to 1 in Data_Buf
			call	WriteDS1307	;   ...and write Data_Buf back to 0Fh
			nop					;
			call	ReadDS1307	;   ...and then read back from 0Fh
			btfsc	Data_Buf,0	;   ...so we can est bit 0
			goto	ClockON		; If the bit was 1, this can't be a DS3232, so must be a running DS1307. Leap!
			clrf	Data_Buf	; If we get here, we have a stopped DS3232, so clear 0Fh and do clock setup
			call	WriteDS1307	; Clear the 0Fh register starts the DS3232 Clock.
Start1307	clrf	Mem_Loc		; Going to clear Seconds register (00h)
			clrf	Data_Buf	;
			call	WriteDS1307	; Clearing the seconds register starts a halted DS1307 (and doesn't hurt a DS3232 startup)
			incf	Mem_Loc,f	; Fill the clock with July 7, 2010, 12:30 PM (when first D-mail was sent) just for giggles (otherwise it would be 01/01/00 00:00:00)
			movlw	b'00110000'	; 30 minutes
			movwf	Data_Buf	;
			call	WriteDS1307	; Write to minutes RAM
			incf	Mem_Loc,f	; 
			movlw	b'00010010'	; 12 hours
			movwf	Data_Buf	;
			call	WriteDS1307	; Write to hours RAM
			incf	Mem_Loc,f	; 
			incf	Mem_Loc,f	; 
			movlw	b'00101000'	; 28th
			movwf	Data_Buf	;
			call	WriteDS1307	; Write to days RAM
			incf	Mem_Loc,f	; 
			movlw	b'00000111'	; 7 (July)
			movwf	Data_Buf	;
			call	WriteDS1307	; Write to months RAM
			incf	Mem_Loc,f	; 
			movlw	b'00010000'	; 10 (2010)
			movwf	Data_Buf	;
			call	WriteDS1307	; Write to years months RAM
			clrf	Data_Buf	; Clear the Data_Buf so we can...
			movlw	0x14		; Clear the blankStart and blankEnd values in clock's RAM (since they will be garbage)
			movwf	Mem_Loc		; Address of RAM where blankStart is stored
			call	WriteDS1307	; Write a zero there
			incf	Mem_Loc,f	; Address of RAM where blankEnd is stored is 0x15
			call	WriteDS1307	; Write a zero there.
ClockON		movlw	0x02		; Hours register in clock RAM
			movwf	Mem_Loc		; Put it into Mem_Loc
			call	ReadDS1307	; Read the hours from DS1307 (result is in W and Data_Buf)
			movwf	oldHour		;   and store it in oldHour (to track hour changes)	
			movlw	0x14		; RAM location in clock where blankStart values is stored
			movwf	Mem_Loc		; Put it into Mem_Loc
			call	ReadDS1307	; Read the vlaue from DS1307 (result is in W and Data_Buf)
			movwf	blankStart	;   and store it in blankStart (to track tube blanking)	
			incf	Mem_Loc,f	; Increment to 0x15 where blankEnd is stored
			call	ReadDS1307	; Read the value from DS1307 (result is in W and Data_Buf)
			movwf	blankEnd	;   and store it in blankEnd (to track tube blanking)

			clrf	LeftDP		; Clear all left decimal places
			clrf	RightDP		; Clear all right decimal places
			call	FillBlanks	; Blank the tubes before powering up high voltage.
			call	Loader		; Load blanks into tube drivers
			bsf		ShadowB,NBL	; set NOT Blanking high (tubes no longer blanked) while I'm at it,
			bsf		ShadowB,HVE	; and Set High Voltage Enable ON to display the tubes now, too.
			movfw	ShadowB		; Copy ShadowB...
			movwf	PORTB		; ...to PORTB 
;End Init
			goto	GetTime		; Start in clock mode.


PreLoad		movlw	d'1'		; Load up Steins Gate worldline number
			movwf	T7
			movlw	d'10'
			movwf	T6
			movlw	d'0'
			movwf	T5
			movlw	d'4'
			movwf	T4
			movlw	d'8'
			movwf	T3
			movlw	d'5'
			movwf	T2
			movlw	d'9'
			movwf	T1
			movlw	d'6'
			movwf	T0
			clrf	LeftDP		; Clear all left decimal places
			clrf	RightDP		; Clear all right decimal places
			bsf		RightDP,6	; Set right decimal point on for Tube 6

			bsf		ShadowB,NBL	; set NOT Blanking high (tubes no longer blanked) while I'm at it,
			bsf		ShadowB,HVE	; and Set High Voltage Enable ON to display the tubes now, too.
			movfw	ShadowB		; Copy ShadowB...
			movwf	PORTB		; ...to PORTB 
			call 	Loader		; Display the above numbers into the tubes.


MainLoop						; Main work loop here
			movlw	d'3'		; Set brightness value
			movwf	bright		;
			bcf		Eflag,negWL	; This bit only gets set for negative world lines
			call	Buttons		; Call routine that watches the buttons
			btfsc	Flag,short1	; If there was a short press of Button 1...
			goto	funtime		;	...go to tube animation fun.
			btfsc	Flag,long1	; If there was a long press of Button 1...
			goto	WorldLines	;   ...go oto preset sequence of World Lines
			goto	GetTime		; We get here is 2 was pressed. Go to Time display.
funtime		call	Fun			; Roll a random world line number with animation.
			goto	MainLoop	;




WorldLines	clrf	pointer		; Display world lines from anime and visual novel:
			movlw	d'0'		; Start with the W.L. number we first see in the anime,
			movwf	T7			; then get to the next ones using tube runtimes that 	
			movlw	d'10'		; are stored in EEPROM staring at 0x00
			movwf	T6
			movlw	d'3'
			movwf	T5
			movlw	d'3'
			movwf	T4
			movlw	d'7'
			movwf	T3
			movlw	d'1'
			movwf	T2
			movlw	d'8'
			movwf	T1
			movlw	d'7'
			movwf	T0
			call 	Loader		; Display the above numbers into the tubes.
								; We will get subsequent run lengths from EEPROM to reach next world lines
loiter		call	Buttons		; Call routine that watches the buttons
			btfsc	Flag,short1	; If there was a short press of Button 1...
			goto	WLnext		;	...go to the next world line
			btfsc	Flag,long1	; If there was a long press of Button 1...
			goto	GetTime		;   ...go to Clock display
			goto	OwnTime		; We get here is 2 was pressed. Go to Enter Your Own Number

WLnext		movlw	d'8'		; Going to get 8 tube runtimes from EEPROM
			movwf	GenCount	; Use the general counter from the Clock I/O routines (it's free)
			movlw	TR7			; ADDRESS of tube 7 runtime register
			movwf	FSR			;    for indirect addressing.

moreTRn		bsf		STATUS,RP0	; Bank 1
			movfw	pointer		; Address to read...
			movwf	EEADR 		; ...gets put here.
			bsf		EECON1,RD	; EE Read
			movfw	EEDATA		; W = EEDATA
			bcf		STATUS,RP0	; Bank 0
			movwf	INDF		; Put runtime into register TRn
			incf	pointer,f	; Increment for next EEPROM location
			decf	FSR,f		; Decrement for next TR register
			decfsz	GenCount,f	; All 8 done?
			goto	moreTRn		;   No. Keep filling TRn values
			movlw	0x78		;   Yes. See if this is the last world line in EEPROM (it's the negative one)
			subwf	pointer,w	;     If we are out of numbers, zero flag will be set by this subtraction
			btfsc	STATUS,Z	;     Zero bit set?
			bsf		Eflag,negWL	;	  Yes.  Flag the negative world line number
			call	animate		;     No.  Roll the tubes!
			movlw	0x78		; See if we have run out of our numbers in EEPROM
			subwf	pointer,w	; If we are out of numbers, zero flag will be set by this subtraction
			btfss	STATUS,Z	; Zero bit set?
			goto	loiter		;    No. Go wait for buttons to activate next number.
			goto	MainLoop



OwnTime		call	FillBlanks	; Routine to let you enter any number manually. Start with blanks.
			movlw	T7			; ADDRESS of T7
			movwf	pointer		; pointer will track the tube address
nextDigi	movfw	pointer		; Use pointer
			movwf	FSR			;    to set indirect address
			clrf	INDF		; Zero tube Tn
more		call	Loader		; Display the number
			movfw	pointer		; Loader destroys FSR, so use pointer
			movwf	FSR			;    to set indirect address again
			call	Buttons		; Wait for buttons
			btfsc	Flag,short1	; If there was a short press of Button 1...
			goto	incDigi		;	...go increment the digit
			btfsc	Flag,long1	; If there was a long press of Button 1...
			goto	decDigi		;   ...go decrement the digit
								; We get here is 2 was pressed. Go to next digit (after seeing if we are done)
			decf	pointer,f	;   decrement pointer for next tube
			movlw	RightDP		; ADDRESS of RightDP (the register below T0)
			subwf	pointer,w	; If all tubes are full, this subtraction sets Zero flag
			btfsc	STATUS,Z	;
			goto	doneDigits	;
			movlw	T6			; ADDRESS of tube 6
			subwf	pointer,w	; Check to see if we are at tube 6 (if so, we want to skip it)
			btfsc	STATUS,Z	;
			decf	pointer,f	; Skips tube 6
			goto	nextDigi	;
			call 	Loader		;
doneDigits	movlw	d'8'		; Going to blink 4 times (4 off, 4 on ...so 8 here)
			movwf	GenCount	;   using this counter
blinkies	movlw	b'00001000'	;
			xorwf	ShadowB,f	;
			movfw	ShadowB		;
			movwf	PORTB		;
			movlw	d'10'		; Value for blink delay
			movwf	work		;
blinkie2	call	delay100	;
			decfsz	work,f		;
			goto	blinkie2	;
			decfsz	GenCount,f	;
			goto	blinkies	;
			call	moveNumber	; Copy the user's number from T0-T7 to V0-V7
waitin		call	Buttons		; Wait for any button
			btfsc	Flag,short1	; See if button 1 was pressed...
			goto	spinOwn		;    and if it was, spin the user's world line number.
			goto	GetTime		;    Otherwise, Finished with world line playing. Go Clock mode.
spinOwn		movlw	b'01000000'	; Toggle the flag
			xorwf	Eflag,f		;
			btfss	Eflag,toggl ;
			goto	myWorld		;
			call	Fun			; Animate random world line
			goto	waitin		;
myWorld		call	Fun2		; Animate that ends in number in V0-V7
			goto	waitin		;

incDigi		incf	INDF,f		;
			movlw	d'11'		; See if we have overrun to 11 (10 is allowed for blank tube)
			subwf	INDF,w		; This subtraction will set Zero flag if we go to 11
			btfsc	STATUS,Z	;
			clrf	INDF		; ...and if we do, we clear the digit
			goto	more		; And we go for more inc/dec
decDigi		movfw	INDF		; Load the tube value so we can check for zero
			btfsc	STATUS,Z	; 
			goto	zipDigi		; Digit is zero, go set it to 10
			decf	INDF,f		; Decrement and go for more inc/dec
			goto	more		;
zipDigi		movlw	d'10'		; Tube was 0, so set to 10 (blank)
			movwf	INDF		
			goto	more		; go for more inc/dec



GetTime							; Time Display from DS1307 Clock Chip.
			movfw	brightSet	; set brightness from brightSet value for clock display
			movwf	bright		;
wait123		btfsc	PORTA,SW2	; Wait for SW2 release
			goto	wait123		;
			call	deBounce	;
			movlw	d'10'		; Make Tubes 2 and 5 display no digit
			movwf	T2
			movwf	T5

ReadSec		bcf		Flag,Slide
			call	deBounce	; A little tube display time here (with dimming).
			clrf	Mem_Loc		; Memory location of the seconds register of the DS1307 is 00h
			call	ReadDS1307	; Now let's read the seconds register from DS1307 (Mem_Loc still zero)
								; Will return with seconds reg in W and Data_Buf
			andlw	b'00001111'	; AND the W reg so only single digit of seconds (in BCD) remains
			subwf	T0,w		; See if seconds value has changed...
			btfss	STATUS,Z	;   ...Z will be set if seconds has NOT changed
			goto	NewSec		;   ...so if Z is clear, handle the new second.
			call	deBounce	;   ...otherwise deBounce (for displaying time) and check the buttons. 
			btfsc	PORTA,SW1	; Switch 1 pressed?
			goto	pressed1	;    ...yes, go handle it.
			btfsc	PORTA,SW2	; Switch2 pressed?
			goto	pressed2	;    ...yes, go handle it.
			goto	ReadSec		; Neither button pressed. Go read seconds Clock again.
pressed1	btfss	ShadowB,HVE	; Are tubes blanked by High Voltage turned off?
			goto	unblankem	;   yes, go unblank them. Otherwise...
			btfsc	PORTA,SW1	; SW1 was pressed...(go back to D.M. display after release of SW1).
			goto	pressed1	;    Waiting for release
			call	deBounce	;
			goto	PreLoad		;    And off we go to the D.M. display.
pressed2	btfss	ShadowB,HVE	; Are tubes blanked by High Voltage turned off?
			goto	unblankem	;   yes, go unblank them. Otherwise...
			goto	GetDate		; Go display date
unblankem	bsf		ShadowB,HVE	; Set High Voltage Enable ON to display the tubes now.
			movfw	ShadowB		; Copy ShadowB...
			movwf	PORTB		; ...to PORTB 
wait456		btfsc	PORTA,SW1	; Wait for SW1 release
			goto	wait456		;
			goto	GetTime		; (it will wait for SW2 release, and will deBounce)

NewSec
;			call	deBounce	; First a little displaying time here.
			movfw	Data_Buf	; Bring the seconds register's value into W.
			andlw	b'00001111'	; AND the W reg so only the ones digit of seconds (in BCD) remains
			movwf	T0			; Put it into register for Tube 0 (rightmost)
			swapf	Data_Buf,w	; Get the seconds tens digit by swapping nybbles from Data_Buf...
			andlw	b'00001111'	;   ...and keeping only the right nybble
			movwf	T1			; Put it in Tube 1
			movfw	Data_Buf	; Get the full seconds value again.
			sublw	b'00110000'	; See if it's 30 (that's BCD)
			btfsc	STATUS,Z	;   If it is 30, the subtraction will set the Zero flag
			goto	_30sec
			movfw	Data_Buf	; Get the full seconds value again.
			sublw	b'01011001'	; See if it's 59 (that's BCD)
			btfsc	STATUS,Z	;   If it is 59, the subtraction will set the Zero flag
			goto	_00sec
			goto	minutes		;    ...otherwise we jump to the minutes.

_30sec		movlw	d'40'		; Spin the digits and then get the date.
			movwf	GenCount	;   We will spin through n iterations of incrementing the tubes.
			clrf	T2			; Let the blank tubes play as well.
			clrf	T5			;
			clrf	T7			;   ...and T7, too, in case I blanked leading zero of hours
			clrf	LeftDP		; Clear the decimal points
			clrf	RightDP
nextSet		movlw	T0			; ADDRESS of T0
			movwf	FSR			;   for indirect addressing.
nextTubeA	incf	INDF,f		; Increment the tube value
			movlw	d'10'		; See if it went over 9
			subwf	INDF,w		;
			btfsc	STATUS,C	;   If new tube value <10, C=0
			clrf	INDF		;      so clear bak to zero if it reached 10.
			incf	FSR,f		; Increment to do next tube
			movlw	TR0			; ADDRESS of register above T7
			subwf	FSR,w		; FSR minus TR0 address
			btfss	STATUS,Z	; If we incremented all the tubes, Z will be clear
			goto	nextTubeA 	;   ...if clear, go increment next tube
			call	Loader		;   ...otherwise, Display 
			call	deBounce
			decfsz	GenCount,f	; See if we are done spinning
			goto	nextSet		;    ...so if it's clear, go spin more
			goto	GetDate		; Go display date.

_00sec		call	FillBlanks
			bsf		Flag,Slide	
			call	Loader
			call	deBounce
			goto	minutes		; WHY IS THIS HERE?

minutes		incf	Mem_Loc,f	; Increment memory location to get minutes
			call	ReadDS1307	;
			andlw	b'00001111'	; AND the W reg so only single digit of minutes (in BCD) remains
			movwf	T3			; Put it into register for Tube 3
			swapf	Data_Buf,w	; Get the minutes tens digit by swapping nybbles from Data_Buf...
			andlw	b'00001111'	;   ...and keeping only the right nybble
			movwf	T4			; Put it in Tube 4

hours		incf	Mem_Loc,f	; Increment memory location to get hours
			call	ReadDS1307	;
			andlw	b'00001111'	; AND the W reg so only single digit of hours (in BCD) remains
			movwf	T6			; Put it into register for Tube 6
			swapf	Data_Buf,w	; Get the hours tens digit by swapping nybbles from Data_Buf...
			andlw	b'00001111'	;   ...and keeping only the right nybble
			movwf	T7			; Put it in Tube 7
			btfss	Flag,Clk12	; See if 12 or 24 hour preference
			goto	_do24		;   If flag is clear, 24 hour
_do12		movfw	T6			; Get hours ones into W
			btfsc	T7,0		; See if bit 0 set (it will be if hour is 10-19)
			addlw	d'10'		;	...if so, add 10
			btfsc	T7,1		; See is bit 1 set (it will be if hour is 20-23)
			addlw	d'20'		;   ...if so, add 20
			movwf	n			; Now we have binary hours in W, and I'll save it in n
			bcf		Flag,APnow	; Clear this bit means AM
			sublw	d'11'		; See if hours<=11
			btfsc	STATUS,C	;    ...if it is, C=1
			goto	AM			;    ...and we jump
			bsf		Flag,APnow	; It's PM, so set the flag to remember this
			movlw	d'12'		; Subtract 12 from...
			subwf	n,f			;   ...the binary hours, and leave it in n (now 0 to 11)
AM								; AM & PM calculated the same from here
			movfw	n			; Move binary hours to W
			btfsc	STATUS,Z	; If binary hours is zero, Z=1
			goto	zerohr		;    ...and if so, we need to change the zero to 12
			movlw	d'10'		; 
			subwf	n,w			; See if binary hours<10
			btfss	STATUS,C	;   ...if it is, C=0
			goto	under10		;   ..and we jump
			movwf	T6			; We are here if n>=10, and n-10 is still in W, so put it in T6
			movlw	d'1'		; and put a one in T7
			movwf	T7			;
			goto	done12		;
under10		movfw	n			; n<10, so put n in T6
			movwf	T6			;
			movlw	d'10'		; and put 10 in T7 to blank it
			movwf	T7			;
			goto	done12		;
zerohr		movlw	d'1'		; Put a 1 in T7
			movwf	T7
			movlw	d'2'		; Put a 2 in T6
			movwf	T6
done12					
_do24		
decimalpts	clrf	LeftDP		; Clear all left decimal places
			clrf	RightDP		; Clear all right decimal places
			movlw	b'00100100'	; Set decimal points
			btfss	T0,0		; See if seconds digit is odd or even
			goto	evenSec
			movwf	RightDP		; Set decimal points
			goto	showTime
evenSec		movwf	LeftDP		; ...or set other decimal points
showTime	movfw	oldHour		; Before we display the time, let's do the top-of-the-hour check. Data_Buf still holds hours (BCD). Compare with oldHour.
			subwf	Data_Buf,w	; 
			btfsc	STATUS,Z	; If the current Hour is the same as the oldHour value (subtraction is zero)...
			goto	showTime2	;   ...continue with showing the time.
TOPofHOUR	movfw	Data_Buf	;   ...but if they were NOT the same, we get here. First, set oldHour to the current Hour value
			movwf	oldHour		;
			subwf	blankStart,w	; 
			btfss	STATUS,Z	; See if Hour is same as blankStart hour
			goto	notBlnkSt	;    ...if not, jump
			bcf		ShadowB,HVE	;    ...if so, blank the tubes by turning off the high voltage
			movfw	ShadowB		; copy ShadowB to PORTB
			movwf	PORTB
notBlnkSt	movfw	Data_Buf	; 
			subwf	blankEnd,w	; 
			btfss	STATUS,Z	; See if Hour is same as blankEnd hour
			goto	notBlnkEnd	;    ...if not, jump
			bsf		ShadowB,HVE	;    ...if so, UN-blank the tubes by turning on the high voltage
			movfw	ShadowB		; copy ShadowB to PORTB
			movwf	PORTB		; NOTE that if the same hour is set to blank and unblank, it will do both...and remain unblanked.
notBlnkEnd	
			movfw	timeAdj		; See if time Adj has been set (will be non-zero)
			btfsc	STATUS,Z	;   
			goto	HourRoll 	;	If not (timeAdj=0) skip the handler
			decfsz	hourCount,f	;	If so, handle the time adjustment check
			goto	HourRoll	;      If the hour counter has not reached zero, do the normal
doAdjust	movwf	hourCount	;      If it has reached zero, do the adjustment. Begin by resetting the hourCount (as long as I have timeAdj in W now)
			clrf	Mem_Loc		; Memory location of the seconds register of the DS1307 is 00h
waitForOne	call	ReadDS1307	; Now let's read the seconds register from DS1307 (Mem_Loc still zero). Will return with seconds reg in W and Data_Buf
			btfss	Data_Buf,0	; Wait until we hit 1 second
			goto	waitForOne	;
			movlw	d'2'		; If we are slow, jump ahead to 2 seconds after
			btfsc	timeFast,0	; But if we are fast, clear to 0 seconds after
			clrf	Data_Buf	;     by clearing Data_Buf back to zero seconds.
			call	WriteDS1307	; Write the value to the seconds register. We have jumped back or ahead by one second.

HourRoll	call	moveNumber	; Top of the hour, so do a Divergence Meter style roll.
			movlw	d'2'		;
			movwf	V0			;
			call	Fun2		;
			movfw	brightSet	; set brightness from brightSet value for clock display
			movwf	bright		;
			goto	showTime2
showTime2
			call	Loader		; Display number
			call	deBounce	; Wait a bit
			goto	ReadSec		; Go read seconds from Clock again.



GetDate		movlw	0x04		; Memory location of Date (days) in DS1307
			movwf	Mem_Loc		;
			call	ReadDS1307	; Read the date
			andlw	b'00001111'	; AND the W reg so only single digit of date remains
			movwf	T3			; Put days ones digit in Tube 3
			swapf	Data_Buf,w	; Get the date (days) tens digit by swapping nybbles from Data_Buf...
			andlw	b'00001111'	;   ...and keeping only the right nybble
			movwf	T4			; Put it in Tube 4
			incf	Mem_Loc,f	; Increment Mem_Loc for Month register
			call	ReadDS1307	; Read the month
			andlw	b'00001111'	; AND the W reg so only single digit of month remains
			movwf	T6			; Put months ones digit in Tube 6
			swapf	Data_Buf,w	; Get the month tens digit by swapping nybbles from Data_Buf...
			andlw	b'00001111'	;   ...and keeping only the right nybble
			movwf	T7			; Put it in Tube 7
			incf	Mem_Loc,f	; Increment Mem_Loc for Year register
			call	GetT1T0b	; Since the year goes in T1 & T0, I can use this subroutine to load it.
			movlw	d'10'		; Make sure Tubes 2 and 5 are blank
			movwf	T2			;
			movwf	T5			;
			clrf	LeftDP		; Clear all left decimal places
			clrf	RightDP		; Clear all right decimal places
			btfss	dateDMY,0	; See if they prefer DD MM YY format
			goto	release2a	;   If not, skip next part
			movfw	T7			;   If so, do the swap
			movwf	n			; store temporarily in n and m
			movfw	T6			;
			movwf	m			;
			movfw	T4			;
			movwf	T7			; T4 now in T7
			movfw	T3			;
			movwf	T6			; T3 now in T6
			movfw	n			;
			movwf	T4			; T7 now in T4
			movfw	m			;
			movwf	T3			; T6 now in T3
release2a	btfsc	PORTA,SW2	; Wait for relese of SW2 (that got us here)
			goto	release2a	;    Still waiting
			call 	Loader		; display the date
			call	deBounce	; Debounce from release of SW2
			movlw	d'120'		; Show date for this many deBounce times
			movwf	Counter		;   (With deBounce Delay2=30 and Counter=120, about 3 seconds)
watch2a		btfsc	PORTA,SW2	; Switch2 pressed again (to get to Settings)?
			goto	Settings	;    ...yes. Go handle Settings.
			btfsc	PORTA,SW1	; Switch1 pressed (to go set brightness)?
			goto	SetBright	;    ...yes. Go set brightness.
			call	deBounce	; Wait some (tubes get dimmed during wait by deBounce)
			decfsz	Counter,f	; Done counting?
			goto	watch2a		;   ...still counting. Go wait more.
			goto	ReadSec		; Done counting. Go read seconds again.


	
Settings	call	FillBlanks	; Blank the tubes
			bsf		LeftDP,2	; Set decimal point in tube 2
								; VERSION NUMBER GOES BELOW ************************** 
			movlw	d'1'		; Ones digit of version number.
			movwf	T3
			movlw	d'0'		; Tenths digit of ersion number.
			movwf	T1
			movlw	d'5'		; Hundredths digit of version number.
			movwf	T0
			call	Loader		; display version number
Settings2	btfsc	PORTA,SW2	; Wait for release of SW2
			goto	Settings2
			call	deBounce
			clrf	LeftDP

SetHours	call	FillBlanks	; Blank the tubes
			movlw	d'0'		; Put setting number in Tubes 6 & 7
			movwf	T7
			movlw	d'1'		
			movwf	T6
			movlw	0x02		; Address of hours reg in DS1307
			call	GetT1T0		; Subroutine gets value from Clock reg and puts into T1 & T0
			call	Loader		; display: 01____hh Where hh is hours
			clrf	incMin		; Minimum hour setting is 00 (24-hour clock)...packed BCD
			movlw	b'00100011'	; Maximum hour setting is 23...packed BCD
			movwf	incMax		; 
			call	Increment	; Call routine to increment/decrement setting (returns when Button 2 pressed)
			call	WriteDS1307	; Write the new hour register value back to DS1307

SetMins		movlw	d'2'		; Put setting number in Tube 6 	(still has 0 in T7)
			movwf	T6
			movlw	0x01		; Address of minutes reg in DS1307
			call	GetT1T0		; Subroutine gets value from Clock reg and puts into T1 & T0
			call	Loader		; display: 02____mm Where mm is minutes
			movfw	Data_Buf	; Get the minute number...
			movwf	oldMin		;   ...and put it here so we can tell if it gets changed.
			clrf	incMin		; Minimum minute setting is 00...packed BCD
			movlw	b'01011001'	; Maximum minute setting is 59...packed BCD
			movwf	incMax		; 
			call	Increment	; Call routine to increment/decrement setting (returns when Button 2 pressed)
			movfw	oldMin		; Get the old minutes setting...
			subwf	Data_Buf,w	;    ...to see if it was changed to something different.
			btfsc	STATUS,Z	;    If there was no change Zero bit will be set
			goto	noMinChange	;	 and we want to leave without writing any changes (we care, since seconds get reset, too).
			call	WriteDS1307	; Write the new minute register value back to DS1307
			clrf	Mem_Loc		; Address of seconds register is 0x00
			clrf	Data_Buf	; We will clear the seconds register as we set minutes
			call	WriteDS1307	; 		
noMinChange						; 

Set1224		movlw	d'3'		; Put setting number in Tube 6 	(still has 0 in T7)
			movwf	T6
loop1224	movlw	b'00010010'	; We might want 12-hour time (that's 12 in packed BCD)...
			btfss	Flag,Clk12	;
			movlw	b'00100100'	; But if the Clk12 flag is not set, want 24 hour time (that's 24 in packed BCD)
			movwf	Data_Buf	; ...and we'll display whichever
			call	FillT1T0	; Use the entry point that reads nothing from the Clock.
			call	Loader		; display: 03____12  or  03____24
			call	Buttons		;
			btfsc	Flag,short2	; If the Button 2 was pressed...
			goto	done1224	;    ...go finish up this setting
			movlw	b'10000000'	;    ...otherwise, button 1 was pressed (short? long? don't care), so toggle the
			xorwf	Flag,f		;		...setting for the 12/24 preference
			goto	loop1224	; Go for more toggling
done1224	movlw	d'1'		; When done, write the setting to EEPROM. (Babby's first EEPROM write!)
			btfss	Flag,Clk12	; Make W=1 if Clk12 flag is set, or W=0 if Clk12 flag is clear
			clrw				; (This clears W to 0 if bit was clear.)
			bsf		STATUS,RP0	; Bank 1
			movwf	EEDATA		; Moves number to be witten into EEDATA
			movlw	0x7F		; Move EEPROM address to be written to...
			movwf	EEADR		;   ...into EEADR.
			bsf		EECON1,WREN	; Enable write
			movlw	0x55 		;
			movwf	EECON2		; Write 55h
			movlw	0xAA		;
			movwf	EECON2		; Write AAh
			bsf		EECON1,WR	; Set WR bit
								; begin write. I won't waitfor it to end because I won't mess with it anytime soon.
			bcf		STATUS,RP0	; Bank 0

SetDays		movlw	d'4'		; Put setting number in Tube 6 	(still has 0 in T7)
			movwf	T6
			movlw	0x04		; Address of date reg in DS1307
			call	GetT1T0		; Subroutine gets value from Clock reg and puts into T1 & T0
			call	Loader		; display: 04____dd  Where dd is days part of date
			movlw	b'00000001'	; Minimum day setting is 01...packed BCD
			movwf	incMin		; 
			movlw	b'00110001'	; Maximum day setting is 31...packed BCD
			movwf	incMax		;   (I'm not going to try to stop fools from setting Feb 31 or some such shit)
			call	Increment	; Call routine to increment/decrement setting (returns when Button 2 pressed)
			call	WriteDS1307	; Write the new days register value back to DS1307	

SetMonth	movlw	d'5'		; Put setting number in Tube 6 	(still has 0 in T7)	
			movwf	T6
			movlw	0x05		; Address of month reg in DS1307
			call	GetT1T0		; Subroutine gets value from Clock reg and puts into T1 & T0
			call	Loader		; display: 05____MM  Where MM is months
			movlw	b'00000001'	; Minimum month setting is 01...packed BCD
			movwf	incMin		; 
			movlw	b'00010010'	; Maximum month setting is 12...packed BCD
			movwf	incMax		;  
			call	Increment	; Call routine to increment/decrement setting (returns when Button 2 pressed)
			call	WriteDS1307	; Write the new month register value back to DS1307

SetYear		movlw	d'6'		; Put setting number in Tube 6 	(still has 0 in T7)	
			movwf	T6
			movlw	0x06		; Address of year reg in DS1307
			call	GetT1T0		; Subroutine gets value from Clock reg and puts into T1 & T0
			call	Loader		; display: 06____YY  Where YY is the year
			movlw	b'00000000'	; Minimum year setting is 00...packed BCD
			movwf	incMin		; 
			movlw	b'10011001'	; Maximum year setting is 99...packed BCD
			movwf	incMax		;  
			call	Increment	; Call routine to increment/decrement setting (returns when Button 2 pressed)
			call	WriteDS1307	; Write the new year register value back to DS1307

SetDateFormat
			movlw	d'7'		; Put setting number in Tube 6 	(still has 0 in T7)	
			movwf	T6
			clrw				; Clear W
			movwf	T1			; Put zero in T1
			movfw	dateDMY		; Get date DMY setting (0= MM DD YY preferred. 1= DD MM YY preferred)
			movwf	T0			; Put it in T0
			movwf	Data_Buf	; Also put the value where Increment routine expects to find it
			call	Loader		; display: 07____0x  Where x is 0 or 1
			movlw	b'00000000'	; Minimum setting is 00...packed BCD
			movwf	incMin		; 
			movlw	b'00000001'	; Maximum setting is 01...packed BCD
			movwf	incMax		;  
			call	Increment	; Call routine to increment/decrement setting (returns when Button 2 pressed)
			movfw	Data_Buf	; Get the result
			movwf	dateDMY		; Put it into register...then write it to EEPROM
			bsf		STATUS,RP0	; Bank 1
			movwf	EEDATA		; Moves number to be witten into EEDATA
			movlw	0x7D		; Move EEPROM address to be written to...
			movwf	EEADR		;   ...into EEADR.
			bsf		EECON1,WREN	; Enable write
			movlw	0x55 		;
			movwf	EECON2		; Write 55h
			movlw	0xAA		;
			movwf	EECON2		; Write AAh
			bsf		EECON1,WR	; Set WR bit
								; begin write. I won't wait for it to end because I won't mess with it anytime soon.
			bcf		STATUS,RP0	; Bank 0


SetBlankStart	
			movlw	d'8'		; Put setting number in Tube 6 	(still has 0 in T7)		
			movwf	T6
			movlw	0x14		; Address of blankStart reg in DS1307 (I'm storing this in the clock's RAM) 
			call	GetT1T0		; Subroutine gets value from Clock reg and puts into T1 & T0
			call	Loader		; display: 08____hh Where hh is hour to start tube blanking
			clrf	incMin		; Minimum hour setting is 00 (24-hour clock)...packed BCD
			movlw	b'00100011'	; Maximum hour setting is 23...packed BCD
			movwf	incMax		; 
			call	Increment	; Call routine to increment/decrement setting (returns when Button 2 pressed)
			call	WriteDS1307	; Write the new blankStart value back to RAM in the  DS1307
			movfw	Data_Buf	; And get the value to put it
			movwf	blankStart	;   ...into blankStart variable as well.

SetBlankEnd	
			movlw	d'9'		; Put setting number in Tube 6 	(still has 0 in T7)		
			movwf	T6
			movlw	0x15		; Address of blankEnd reg in DS1307 (I'm storing this in the clock's RAM) 
			call	GetT1T0		; Subroutine gets value from Clock reg and puts into T1 & T0
			call	Loader		; display: 09____hh Where hh is hour to end tube blanking
			clrf	incMin		; Minimum hour setting is 00 (24-hour clock)...packed BCD
			movlw	b'00100011'	; Maximum hour setting is 23...packed BCD
			movwf	incMax		; 
			call	Increment	; Call routine to increment/decrement setting (returns when Button 2 pressed)
			call	WriteDS1307	; Write the new blankEnd value back to RAM in the DS1307
			movfw	Data_Buf	; And get the value to put it
			movwf	blankEnd	;   ...into blankEnd variable as well.

SetTimeAdjust
			movlw	d'1'		; Put 1 in Tube 7
			movwf	T7			;
			clrf	T6			; Put 0 in Tube 6
			movfw	timeAdj		; Get the time adjustment value
			movwf	oldMin		; Use oldMin to see if a change is made (at the end)
Bin2BCD		movfw	timeAdj		; Get the time adjustment value
			movwf	T0			; Put the whole thing into the ones (T0) to start
			clrf	T1			; Clear tens (T1)
			clrf	T2			; Clear hundreds (T2)
dotens		movlw	d'10'		; Subtract dec. 10...
			subwf	T0,w		;   ...from what remains in the ones. Leave result in W.
			btfss	STATUS,C	; Look to see if we went negative (if there were no more tens left, C will be clear. Yes, really.)
			goto	dohundreds	;    If there was no more tens left, jump to doing the hundreds.
			movwf	T0			;    If we did get a ten out, move the subtraction result from W into the ones... 
			incf	T1,f		;      ...and increment the tens.
			goto	dotens		; ...and we go back to look for more tens.
dohundreds	movlw	d'10'		; Subtract dec. 10...
			subwf	T1,w		;  ...from what remains in the tens. Leave result in W.
			btfss	STATUS,C	; Look to see if we went negative (if there were no more hundreds left, C will be clear. Oh, yeah.)
			goto	doneBCD		;   If there are no more hundreds, we are done.
			movwf	T1			;   If we did get a hundred, move the subtraction result from W into the tens...
			incf	T2,f		;     ...and increment the hundreds.
			goto	dotens		; ...and go look for more hundreds.
doneBCD		clrf	LeftDP		; BCD conversion done, and result is in T0-T2. Set DPs to indicate positive or negative.
			clrf	RightDP		;
			btfsc	timeFast,0	; timeFast=1 for fast, =0 for slow (negative)
			goto	showBCD		;   If fast, go here
			movlw	b'00001000'	;   If slow, show DPs
			movwf	LeftDP		;
			movwF	RightDP		;
showBCD		call	Loader
			call	deBounce
			call	Buttons
			btfsc	Flag,short2	; Exit if button 2 pressed
			goto	exitTASet	;
			btfsc	Flag,short1	; If short1 press...
			goto	incTAdj		;    go increment
decTAdj		btfss	timeFast,0	; See if timeFast is set
			goto	decSlow		;    if not, go decrement negative
			movfw	timeAdj		; See if timaAdj is zero
			btfsc	STATUS,Z	;   
			goto	hitzipper	;    if so, go here
			decf	timeAdj,f	;    if not, normal decrement
			goto	Bin2BCD		;   
hitzipper	clrf	timeFast	; We went negative
			incf	timeAdj,f	; increase in the negative direction
			goto	Bin2BCD		; go display
decSlow		incf	timeAdj,f	; If slow, "decrement" goes more negative
			btfss	STATUS,Z	; See if we rolled over
			goto	Bin2BCD		;   if not, display
			bsf		timeFast,0	;   if so, make use timeFast=1 at 255
			decf	timeAdj,f	;     backup from 0 to 255.
			goto	Bin2BCD		; go display
incTAdj		btfss	timeFast,0	; See if timeFast is set
			goto	incSlow		;    if not, go increment negative
			incf	timeAdj,f	; Increment
			btfss	STATUS,Z	; See if we incremented 255-->0
			goto	Bin2BCD		;    If not, increment done... go display.
			decf	timeAdj,f	;    If so, put it back to 255...
			clrf	timeFast	;      and make timeFast flag negative (slow)
			goto	Bin2BCD		; go display
incSlow		decf	timeAdj,f	; If slow, "increment" brings you closer to zero
			btfss	STATUS,Z	; See if we hit zero
			goto	Bin2BCD		;   If not, go display
			bsf		timeFast,0	;   If so, set timeFast to 1 (fast)
			goto	Bin2BCD		; go display
exitTASet	clrf	LeftDP
			clrf	RightDP
			movfw	oldMin		; Get the previous value into W
			subwf	timeAdj,w	; See if any change was made
			btfsc	STATUS,Z	; 
			goto	noAdjChange ; If there was no change of th setting, jump past all this.
			movfw	timeAdj		; Get the final timeAdj value into W
			movwf	hourCount	; Set the hourCount to the new timeAdj
			bsf		STATUS,RP0	; Bank 1
			movwf	EEDATA		; Moves number to be witten into EEDATA
			movlw	0x7C		; Move EEPROM address to be written to...
			movwf	EEADR		;   ...into EEADR.
			bsf		EECON1,WREN	; Enable write
			movlw	0x55 		;
			movwf	EECON2		; Write 55h
			movlw	0xAA		;
			movwf	EECON2		; Write AAh
			bsf		EECON1,WR	; Set WR bit
waitwrite	btfsc	EECON1,WR	; Wait until write is done
			goto	waitwrite	;
			movfw	timeFast	; Get the final timeFast value into W
			movwf	EEDATA		; Moves number to be witten into EEDATA
			movlw	0x7B		; Move EEPROM address to be written to...
			movwf	EEADR		;   ...into EEADR.
			bsf		EECON1,WREN	; Enable write
			movlw	0x55 		;
			movwf	EECON2		; Write 55h
			movlw	0xAA		;
			movwf	EECON2		; Write AAh
			bsf		EECON1,WR	; Set WR bit
			bcf		STATUS,RP0	; Bank 0
noAdjChange			

SetBright	btfsc	PORTA,SW1	; If we got here from Date, SW1 might still be pressed. Wait for release.
			goto	SetBright	;
			call	deBounce	;
			call	FillBlanks	; Blank the tubes (in case I jump directly here)
			movlw	d'1'		; Put setting number in Tubes 6 & 7
			movwf	T7
			movlw	d'1'		
			movwf	T6
			movfw	brightSet	; Get brightness preference for clock
			movwf	T0			;	and put it into T0 for display.
loopBrSet	movfw	T0			; Update bright from T0 as we loop so the effect can be seen
			movwf	bright		;
			call	Loader		; display: 11_____B Where B is brightness 0-7
			call	Buttons		;
			btfsc	Flag,short2	; Exit if button 2 pressed
			goto	exitBrSet	;
			btfsc	Flag,short1	; If short1 press...
			goto	incBrSet	;    go increment
decBrSet	movfw	T0
			btfss	STATUS,Z	; If T0 is zero, allow no decrement
			decf	T0,f		; Otherwise, decrement.
			goto	loopBrSet	;
incBrSet	incf	T0,f		; Increment brightness
			movlw	b'00000111'	; To make sure it stays below 8, do this
			andwf	T0,f		;    and thing (it will roll to zero).
			goto	loopBrSet	;
exitBrSet	movfw	T0			; Get the brightness
			movwf	brightSet	;
			bsf		STATUS,RP0	; Bank 1
			movwf	EEDATA		; Moves number to be witten into EEDATA
			movlw	0x7E		; Move EEPROM address to be written to...
			movwf	EEADR		;   ...into EEADR.
			bsf		EECON1,WREN	; Enable write
			movlw	0x55 		;
			movwf	EECON2		; Write 55h
			movlw	0xAA		;
			movwf	EECON2		; Write AAh
			bsf		EECON1,WR	; Set WR bit
								; begin write. I won't wait for it to end because I won't mess with it anytime soon.
			bcf		STATUS,RP0	; Bank 0

								; End of settings.
			goto	GetTime		; 



; initialize eeprom locations
			ORG	0x2100
			DE	0x32, 0x00, 0x15, 0x11, 0x3E, 0x45, 0x23, 0x36
			DE	0x47, 0x00, 0x11, 0x2B, 0x3D, 0x18, 0x27, 0x37
			DE	0x3B, 0x00, 0x22, 0x18, 0x33, 0x38, 0x28, 0x44
			DE	0x32, 0x00, 0x32, 0x14, 0x1E, 0x28, 0x1D, 0x3D
			DE	0x28, 0x00, 0x28, 0x0F, 0x34, 0x20, 0x12, 0x40
			DE	0x32, 0x00, 0x31, 0x17, 0x35, 0x1B, 0x29, 0x40
			DE	0x28, 0x00, 0x28, 0x0F, 0x35, 0x37, 0x16, 0x1B
			DE	0x32, 0x00, 0x27, 0x17, 0x1C, 0x39, 0x42, 0x25
			DE	0x3C, 0x00, 0x1F, 0x11, 0x16, 0x3F, 0x37, 0x22
			DE	0x3C, 0x00, 0x32, 0x23, 0x11, 0x19, 0x26, 0x3F
			DE	0x3C, 0x00, 0x15, 0x25, 0x11, 0x22, 0x31, 0x3F
			DE	0x3C, 0x00, 0x1E, 0x37, 0x12, 0x11, 0x2C, 0x45
			DE	0x47, 0x00, 0x10, 0x1A, 0x31, 0x20, 0x24, 0x31
			DE	0x3C, 0x00, 0x59, 0x79, 0x94, 0xB7, 0xD1, 0xF1
			DE	0x1D, 0x00, 0x3E, 0x21, 0x11, 0x26, 0x37, 0x3F
			DE	0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x05, 0x01

; Above...
;   Tube runtimes for pre-set world line number sequence are in the first 15 lines.
;   12/24-hour time format preference stored in 7F (last location)
;   Clock brightness stored in 7E (second-to-last location).
;	Date format stored in 7D
;	Time adjustment timeAdj value in 7C
;	Time adjustment fast or slow timeFast in 7B

			END					; directive 'end of program'

