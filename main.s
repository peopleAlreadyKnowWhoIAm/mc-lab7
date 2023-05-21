; Lower 48 registers 
.equ DDRB, 0x04 
.equ PORTB, 0x05 
.equ PINC, 0x06 
.equ DDRC, 0x07 
.equ PORTC, 0x08 
.equ DDRD, 0x0a 
.equ PORTD, 0x0b
.equ SREG, 0x3f

; Other registers 
; Timer1
.equ TCCR1A, 0x80 
.equ TCCR1B, 0x81 
.equ TCCR1C, 0x82 
.equ OCR1AL, 0x88 
.equ OCR1AH, 0x89
.equ TIMSK1, 0x6f
; Constants
.equ OCR1A_VALUE, 780; With frequency 16MHz and /1024 prescaller - 50ms 
.equ TCCR1B_VALUE, 0b00001101; CTC mode, /1024 prescaller 
.equ PERIOD, 14; 50ms * PERIOD = 0.75

;From linker script
;__data_load_start; Data section in flash
;__data_start; Data section start in ram (0x0100) 
;__data_end; Data section end

.data 
timer_count: 
.byte 0
algo_1_status:
.byte 0b00001111
algo_2_status:
.byte 0b00001111

algo_1:
.byte 0b00000001
.byte 0b10000000
.byte 0b00000010
.byte 0b01000000
.byte 0b00000100
.byte 0b00100000
.byte 0b00001000
.byte 0b00010000
.byte 0


algo_2:
.byte 0b00000001
.byte 0b00000010
.byte 0b00000100
.byte 0b00001000
.byte 0b00010000
.byte 0b00100000
.byte 0b01000000
.byte 0b10000000
.byte 0
.section .vectors
vectors:
; Flash location is addressed by words
.org 0
rjmp Reset_Handler; 0x00 reset handler 
.org 016*2
rjmp TIMER1_COMPA
.org 034*2
reti

.section .text
Reset_Handler:
; Clear status register
clr r1
out SREG,r1
; Load data into ram
; Load flash address of data 
ldi r31, hi8(__data_load_start) 
ldi r30, lo8(__data_load_start)
ldi r29, hi8(__data_start) 
ldi r28, lo8(__data_start)
ldi r25, hi8(__data_end) 
data_copy_loop: 
lpm r0, Z+
st Y+, r0 
data_copy:
cpi r28, lo8(__data_end)
cpc r29, r25
brne data_copy_loop

setup:
rcall setup_timer
ldi r25, 0xff 
out DDRD, r25 
ldi r25, 0x3f
out DDRB, r25
ldi r25, 0b110100; Pins in PORTC for output with PORTB and buzzer
out DDRC, r25
ldi r25, 0b11; Pull-up for buttons
out PORTC, r25
sei

clr r16
clr r3
main:
lds r20, timer_count
cp r20, r3
breq main

mov r3, r20
; r16 - button status
; first 2 bits - last status
in r18, PINC
andi r18, 0b11
mov r19, r18
andi r19, 0b1; First button is clicked
brne main_b1_nc
set
sbi PORTC, 2
mov r19, r16
andi r19, 0b1; First button is clicked before
brne main_b1_e
ori r16, 0b1
sts algo_1_status, r3
ldi r24, 0
call light_a
jmp main_b1_e
main_b1_nc:
andi r16, 0b11111110
main_b1_e:


mov r19, r18
andi r19, 0b10; Second button is clicked
brne main_b2_nc
set
sbi PORTC,2
mov r19, r16
andi r19, 0b10; Second button is clicked before
brne main_b2_e
ori r16, 0b10
sts algo_2_status, r3
ldi r24, 0
call light_b
rjmp main_b2_e
main_b2_nc:

andi r16, 0b11111101
main_b2_e:

rjmp main



setup_timer:
ldi r18, TCCR1B_VALUE 
ldi r30, lo8(TIMSK1)
ldi r31, hi8(TIMSK1)
std Z+(TCCR1B-TIMSK1), r18; TCCR1B
ldi r18, lo8(OCR1A_VALUE)
ldi r19, hi8(OCR1A_VALUE)
std Z+(OCR1AH-TIMSK1), r19 ; OCR1A
std Z+(OCR1AL-TIMSK1), r18
ldi r18, 0b10; Enable OCIE1A st Z, r18
ret


TIMER1_COMPA: 
cli
push r30
push r31
push r17
push r18
push r19
push r24
push r25
push r26
push r27
lds r17, timer_count
inc r17
cpi r17, PERIOD
brne TIMER1_COMPA_A
clr r17
TIMER1_COMPA_A:
brtc TIMER1_COMPA_BUZZER
cbi PORTC, 2
jmp TIMER1_COMPA_BUZZER_END
TIMER1_COMPA_BUZZER:
clt
TIMER1_COMPA_BUZZER_END:
sts timer_count, r17

; r18 - step counter 
; r19 - tick stamp 
lds r18, algo_1_status 
mov r19, r18
andi r19, 0b1111
cp r19, r17
brne TIMER1_COMPA_ALG01; If the time for update algo 1 
swap r18 ; Get posiontion of leds sequence
andi r18, 0b1111
ldi r26, lo8 (algo_1)
ldi r27, hi8(algo_1) 
add r26, r18
; Load address of the leds sequence
; Calculate address of leds in the step
brcc TIMER1_COMPA_ALGO1_A
inc r27
TIMER1_COMPA_ALGO1_A: 
ld r24, X
; Load byte sequence
; Check if there is not step to go out
inc r18
cpi r18, 9
brne TIMER1_COMPA_ALG01_B
clr r18
ldi r19, 0b1111
TIMER1_COMPA_ALG01_B:
swap r18
or r18, r19
; If it is end of the algorithm
; Reset step
; Set tickstamp out of range
; Combine status register
sts algo_1_status, r18; Save new status
call light_a
TIMER1_COMPA_ALG01:
; r18- step counter
; r19 - tick stamp
lds r18, algo_2_status 
mov r19, r18
andi r19, 0b1111
cp r19, r17
brne TIMER1_COMPA_ALGO2; If the time for update algo 1
swap r18
andi r18, 0b1111
; Get posiontion of leds sequence
ldi r26, lo8(algo_2) 
ldi r27, hi8(algo_2) 
add r26, r18
; Load address of the leds sequence
; Calculate address of leds in the step
brcc TIMER1_COMPA_ALGO2_A 
inc r27
TIMER1_COMPA_ALGO2_A: 
ld r24, X
; Load byte sequence

; Check if there is not step to go out
inc r18
cpi r18, 9
brne TIMER1_COMPA_ALGO2_B
clr r18
ldi r19, 0b1111
TIMER1_COMPA_ALGO2_B: 
swap r18
or r18, r19
; If it is end of the algorithm ;Reset step
; Set tickstamp out of range
; Combine status register
sts algo_2_status, r18; Save new status
call light_b
TIMER1_COMPA_ALGO2:
pop r27
pop r26
pop r25
pop r24
pop r19
pop r18
pop r17
pop r31
pop r30
sei
reti



light_a: 
;R24 - byte of mapping leds 
mov r25, r24; Make copy for PORTC 
andi r24, 0b111111; For PORTB 
lsr r25
lsr r25
andi r25, 0b110000 ; For PORTC
out PORTB, r24
in r26, PORTC
andi r26, 0b11001111
or r26, r25
out PORTC, r26
ret

light_b: 
;R24 - mapping leds
out PORTD, r24
ret
