
; --------------------------------------------------------------------------
;
;
;    ********************************************************************
;    *                                                                  *
;    * File:        TEST.ASM                                            *
;    * Format:      SjASMPlus Z80                                       *
;    * Tabs:        28,36,44,52,60,68,76,84                             *
;    *                                                                  *
;    * Project:     COPAUDIO                                            *
;    * Platform:    ZX Spectrum Next                                    *
;    * Programmer:  KevB aka 9bitcolor                                  *
;    *                                                                  *
;    * Modified:    7th January 2025                                    *
;    *                                                                  *
;    * Description: Sample playback test.                               *
;    *                                                                  *
;    ********************************************************************
;
;
; --------------------------------------------------------------------------


; Memory Map.


irq_vector	equ	65022	;     2 BYTES Interrupt vector
stack	equ	65021	;   252 BYTES System stack
vector_table	equ	64512	;   257 BYTES Interrupt vector table


; --------------------------------------------------------------------------


; Hardware registers.


SELECT	equ	243Bh	; TBBlue register select
ACCESS	equ	253Bh	; TBBlue register access

LAYER2	equ	123Bh	; TBBlue layer 2 control

MACHINE	equ	03h	; Machine type
CONFIG1	equ	05h	; Peripheral 1 setting

TURBO	equ	07h	; Turbo control

CONFIG3	equ	08h	; Peripheral 3 setting

TIMING	equ	11h	; Video timing mode (0..7)

TRANSP	equ	14h	; Global transparency

RASMSB	equ	1Eh	; Current line drawn MSB
RASLSB	equ	1Fh	; Current line drawn LSB

INTMSB	equ	22h	; Line interrupt MSB / control
INTLSB	equ	23h	; Line interrupt LSB

DAC	equ	2Dh	; SpecDrum 8 bit DAC (mirror)

FALLBACK	equ	4Ah	; Fallback colour

MM0	equ	50h	; Memory bank8k
MM1	equ	51h
MM2	equ	52h
MM3	equ	53h
MM4	equ	54h
MM5	equ	55h
MM6	equ	56h
MM7	equ	57h

COPPER	equ	60h	; Copper list
COPLO	equ	61h
COPHI	equ	62h


; --------------------------------------------------------------------------


; Entry point.


; MM0   4 ULA 0
; MM1   5 ULA 8192
; MM2  10 ULA 16384
; MM3  11 ULA 24576
; MM4   4 RAM 32768
; MM5   5 RAM 40960
; MM6   0 RAM 49152
; MM7   1 RAM 57344


startup:	di			; Set stack and interrupts
	ld	sp,stack	; System STACK

	nextreg	TURBO,00000011b	; 28Mhz

	ld	hl,vector_table	; 252 (FCh)
	ld	a,h
	ld	i,a
	im	2

	inc	a		; 253 (FDh)
	ld	b,l		; Build 257 BYTE INT table

.irq:	ld	(hl),a
	inc	hl
	djnz	.irq		; B = 0
	ld	(hl),a

	ld	a,0FBh		; EI
	ld	hl,04DEDh	; RETI
	ld	[irq_vector-1],a
	ld	[irq_vector],hl


	nextreg	INTMSB,00000100b; ULA off / LINE interrupt off
	nextreg	INTLSB,192	; IRQ on line 192

	xor	a

	ld	hl,16384	; Clear ULA screen
	ld	de,16384+1
	ld	bc,6144-1
	ld	(hl),a
	ldir

	ld	sp,22528+768	; Set ULA attributes
	ld	hl,0707h	; PAPER 0:INK 7
	ld	b,192
.attr:	push	hl		; 4 BYTES
	push	hl
	djnz	.attr

	ld	bc,LAYER2
	out	(c),a		; LAYER 2 control OFF
	out	(254),a		; BLACK

	ld	bc,SELECT	; Setup hardware registers

	nextreg	TRANSP,a	; LAYER 2 transparent colour

	ld	a,CONFIG3
	out	(c),a
	inc	b
	in	a,(c)
	set	6,a		; Contention OFF
	set	3,a		; DAC ON
	set	1,a		; Turbosound ON
	out	(c),a

	ld	bc,0xFFFD	; Turbosound PSG #1
	ld	a,11111111b
	out	(c),a

	ld	sp,stack	; System STACK
	ei


; --------------------------------------------------------------------------


; Init copper and set sample buffer.


	ld	bc,SELECT
	ld	a,COPPER	; Initialize copper
	out	(c),a
	inc	b

	ld	hl,32768+384	; Line 384 + MOVE command
	ld	de,0		; 1024 instructions
	ld	a,DAC

.copper:	out	(c),h		; WAIT command + V MSB
	out	(c),l		; V LSB
	out	(c),a		; DAC
	out	(c),l		; 128
	inc	de
	bit	1,d		; 512 ?
	jr	z,.copper


	ld	hl,exitopen_pcm	; Sample at 32K
	ld	de,10240
	xor	a		; Loop forever
	call	play_sample


; --------------------------------------------------------------------------


; Test loop.


mainloop:	call	set_copper_audio
	call	wait_line	; VSYNC line register A

	ld	a,2		; RED
	out	(254),a

	di
	call	play_copper_audio
	ei

	ld	a,0		; BLACK
	out	(254),a

	jr	mainloop


; --------------------------------------------------------------------------

