
; --------------------------------------------------------------------------
;
;
;    ********************************************************************
;    *                                                                  *
;    * File:        TEST.ASM                                            *
;    * Format:      SjASMPlus Z80                                       *
;    * Tabs:        28,36,44,52,60,68,76,84                             *
;    *                                                                  *
;    * Project:     CTCAUDIO                                            *
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

TURBO	equ	07h	; Turbo control

CONFIG3	equ	08h	; Peripheral 3 setting

TIMING	equ	11h	; Video timing mode (0..7)

TRANSP	equ	14h	; Global transparency

INTMSB	equ	22h	; Line interrupt MSB / control
INTLSB	equ	23h	; Line interrupt LSB

FALLBACK	equ	4Ah	; Fallback colour

MM0	equ	50h	; Memory bank8k
MM1	equ	51h
MM2	equ	52h
MM3	equ	53h
MM4	equ	54h
MM5	equ	55h
MM6	equ	56h
MM7	equ	57h

INTCTL	equ	0C0h	; Interrupt control
INTEN0	equ	0C4h	; INT EN 0
INTEN1	equ	0C5h	; INT EN 1
INTEN2	equ	0C6h	; INT EN 2
INTST0	equ	0C8h	; INT status 0
INTST1	equ	0C9h	; INT status 1
INTST2	equ	0CAh	; INT status 2
INTDM0	equ	0CCh	; INT DMA EN 0
INTDM1	equ	0CDh	; INT DMA EN 1
INTDM2	equ	0CEh	; INT DMA EN 2

CTC0	equ	183Bh	; CTC channel 0 port
CTC1	equ	193Bh	; CTC channel 1 port
CTC2	equ	1A3Bh	; CTC channel 2 port
CTC3	equ	1B3Bh	; CTC channel 3 port


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


; Init four CTC timers to play sample on DACs A,B,C,D @ 15625Hz

; We have already set a simple 257 byte table at address 64512 but we

; will change that in routine ctcpcm_init to use the hardware vector mode.


	nextreg	MM0,4		; Page 16K 'exitopen' at 0
	nextreg	MM1,5

	ld	de,ctcpcm_line  ; Use internal LINE
	ld	bc,192		; Vsync line
	call	ctcpcm_init	; Init sound engine


; --------------------------------------------------------------------------


; Test loop.


mainloop:	call	ctcpcm_vsync

	ld	a,2		; RED
	out	(254),a

	ld	b,0
.wait:	djnz	.wait

	ld	a,0		; BLACK
	out	(254),a

	jr	mainloop


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; LINE interrupt vsync.


ctcpcm_vsync:	ld	hl,ctcpcm_frame
	ld	a,(hl)

.vsync:	cp	(hl)	; Wait for LINE to change variable
	jr	z,.vsync
	ret

;
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; **ONLY NEED TO DO THIS ONCE**


; Init the four Next CTC channels using I register for vector table address.


; Interrupt vectors:


; =  0 line interrupt (highest priority)
; =  1 uart0 Rx
; =  2 uart1 Rx
; =  3 ctc channels 0-7
; =  4 ctc channels 0-7
; =  5 ctc channels 0-7
; =  6 ctc channels 0-7
; =  7 ctc channels 0-7 *
; =  8 ctc channels 0-7 *
; =  9 ctc channels 0-7 *
; = 10 ctc channels 0-7 *
; = 11 ula
; = 12 uart0 Tx
; = 13 uart1 Tx (lowest priority)


; * Reserved for future cores


; > DE = Pointer to LINE interrupt routine
; > BC = Line number

; <  A = Video mode (0 VGA / 7 HDMI)


ctcpcm_init:	di

	ld	a,i		; Build IM2 vector table
	ld	h,a
	xor	a
	ld	l,a		; HL = vector table

	ld	(ctcpcm_frame),a

	ld	(hl),e		; Set LINE interrupt
	inc	l
	ld	(hl),d

	ld	l,6		; CTC vectors 3*2 (WORDS)

	ld	de,ctcpcm_ctc0	; Set CTC0 interrupt
	ld	(hl),e
	inc	l
	ld	(hl),d
	inc	l

	ld	de,ctcpcm_ctc1	; Set CTC1 interrupt
	ld	(hl),e
	inc	l
	ld	(hl),d
	inc	l

	ld	de,ctcpcm_ctc2	; Set CTC2 interrupt
	ld	(hl),e
	inc	l
	ld	(hl),d
	inc	l

	ld	de,ctcpcm_ctc3	; Set CTC3 interrupt
	ld	(hl),e
	inc	l
	ld	(hl),d

	ld	a,b
	and	00000001b
	or	00000110b	; ULA OFF / LINE interrupt ON
	nextreg	INTMSB,a
	ld	a,c
	nextreg	INTLSB,a	; IM2 on line BC

	ld	bc,SELECT	 ; Read timing register
	ld	a,INTCTL
	out	(c),a
	inc	b
	in	a,(c)
	and	00001000b	 ; Preserve stackless mode
	or	00000001b	 ; Vector I + 0, IM2 ON
	out	(c),a
	dec	b

	nextreg INTEN0,00000010b ; Interrupt enable LINE
	nextreg INTEN1,00000001b ; CTC channel 0 zc/to
	nextreg INTEN2,00000000b ; Interrupters

	nextreg INTST0,11111111b ; 
	nextreg INTST1,11111111b ; Set status bits to clear
	nextreg INTST2,11111111b ; 

	nextreg INTDM0,00000010b ; LINE can break over DMA
	nextreg INTDM1,00000011b ; CTC can break over DMA
	nextreg INTDM2,00000000b ; Dont care

	ld	a,TIMING
	out	(c),a
	inc	b
	in	a,(c)
	and	7		; 0-6 VGA / 7 HDMI

; Bit 7: I Interrupt (disabled / enabled)
; Bit 6: M Mode (timer / counter)
; Bit 5: P Prescaler (16 / 256)
; Bit 4: E Edge select (falling / rising)
; Bit 3: T Trigger (constant load / CLK pulse)
; Bit 2: C Time constant (no constant / follows)
; Bit 1: R Reset (continued / software reset)
; Bit 0: V Control (vector / control word)

	ld	hl,.timing_tab
	add	hl,a
	ld	l,(hl)		; Read time constant

;                                    IMPETCRV	; Bits 7-0
	ld	h,10000101b	; CLK / 16

	ld	bc,CTC0		; Channel 0 port
	out	(c),h		; Control word
	out	(c),l		; Time constant

	ld	bc,CTC1		; Channel 1 port
	out	(c),h		; Control word
	out	(c),l		; Time constant

	ld	bc,CTC2		; Channel 2 port
	out	(c),h		; Control word
	out	(c),l		; Time constant

	ld	bc,CTC3		; Channel 3 port
	out	(c),h		; Control word
	out	(c),l		; Time constant

	ei
	ret


.timing_tab	db	112 ; VGA0 28000000 / 16 / 112 (15625)
	db	114 ; VGA1 28571429 / 16 / 114 (15664) *
	db	118 ; VGA2 29464286 / 16 / 118 (15606) *
	db	120 ; VGA3 30000000 / 16 / 120 (15625)
	db	124 ; VGA4 31000000 / 16 / 124 (15625)
	db	128 ; VGA5 32000000 / 16 / 128 (15625)
	db	132 ; VGA6 33000000 / 16 / 132 (15625)
	db	108 ; HDMI 27000000 / 16 / 108 (15625)


; * Next clock does not produce an exact rate of 15625


; Sample rate is calculated by taking FPGA clock (28Mhz) and dividing by 16
;
; then by the sample rate:
;
; 28,000,000 / 16    = 1,750,000
;
;  1,750,000 / 15625 = 112 (time constant to program CTC channel)


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; **IM2 LINE INTERRUPT**


; Interrupt mode 2 LINE routine.


ctcpcm_line:	ei
	push	af

	db	62		; LD A,N
ctcpcm_frame	db	0
	inc	a
	ld	(ctcpcm_frame),a

	pop	af
	reti


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; Spectrum Next DAC ports:


; 0x1f DAC A
; 0xf1 DAC A
; 0x3f DAC A
; 0x0f DAC B
; 0xf3 DAC B
; 0xdf DAC A,D
; 0xfb DAC A,D
; 0xb3 DAC B,C
; 0x4f DAC C
; 0xf9 DAC C
; 0x5f DAC D


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; 15Khz IM2 timer routine for CTC channel 0.


ctcpcm_ctc0:	push	af
	push	hl

	ld	hl,(dac_a_ptr)
	ld	a,(hl)
	inc	hl
	res	6,h		; Wrap to 0 at 16384
	ld	(dac_a_ptr),hl

	out	($3f),a		; DAC A (left)

	pop	hl
	pop	af

	ei
	reti


; --------------------------------------------------------------------------


; 15Khz IM2 timer routine for CTC channel 1.


ctcpcm_ctc1:	push	af
	push	hl

	ld	hl,(dac_b_ptr)
	ld	a,(hl)
	inc	hl
	res	6,h		; Wrap to 0 at 16384
	ld	(dac_b_ptr),hl

	out	($0f),a		; DAC B (left)

	pop	hl
	pop	af

	ei
	reti


; --------------------------------------------------------------------------


; 15Khz IM2 timer routine for CTC channel 2.


ctcpcm_ctc2:	push	af
	push	hl

	ld	hl,(dac_c_ptr)
	ld	a,(hl)
	inc	hl
	res	6,h		; Wrap to 0 at 16384
	ld	(dac_c_ptr),hl

	out	($4f),a		; DAC C (right)

	pop	hl
	pop	af

	ei
	reti


; --------------------------------------------------------------------------


; 15Khz IM2 timer routine for CTC channel 3.


ctcpcm_ctc3:	push	af
	push	hl

	ld	hl,(dac_d_ptr)
	ld	a,(hl)
	inc	hl
	res	6,h		; Wrap to 0 at 16384
	ld	(dac_d_ptr),hl

	out	($5f),a		; DAC D (right)

	pop	hl
	pop	af

	ei
	reti


; --------------------------------------------------------------------------


; Test variables.


dac_a_ptr	dw	0		; Offsets into sample
dac_b_ptr	dw	4096		; wraps at 16384 to 0
dac_c_ptr	dw	8192		; Very simple loop logic
dac_d_ptr	dw	12288		; using these pointers


; --------------------------------------------------------------------------

