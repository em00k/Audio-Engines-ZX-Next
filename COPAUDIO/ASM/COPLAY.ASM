
; --------------------------------------------------------------------------
;
;
;    ********************************************************************
;    *                                                                  *
;    * File:        COPLAY.ASM                                          *
;    * Format:      SjASMPlus Z80                                       *
;    * Tabs:        28,36,44,52,60,68,76,84                             *
;    *                                                                  *
;    * Project:     COPAUDIO                                            *
;    * Platform:    ZX Spectrum Next                                    *
;    * Programmer:  KevB aka 9bitcolor                                  *
;    *                                                                  *
;    * Modified:    7th January 2025                                    *
;    *                                                                  *
;    * Description: Copper sample player.                               *
;    *                                                                  *
;    ********************************************************************
;
;
; --------------------------------------------------------------------------


; Call this to play sample / set looping buffer.


; > HL = Pointer to sample
; > DE = Sample length in bytes
; >  A = Loop count (0 forever).


play_sample:	ld	(sample_ptr),hl	; Address of sample
	ld	(sample_len),de	; Length of sample

	ld	(sample_loop),a	; Loop mode (0 forever)

	ld	hl,0
	ld	(sample_pos),hl


; Call this to hear the sound again once muted.


set_sample_sound_on:	ld	a,DAC
	ld	(sample_dac),a	; Sound on
	ret


; --------------------------------------------------------------------------


; **MUST CALL DIRECTLY BEFORE PLAY_COPPER_AUDIO AND AFTER SET_COPPER_AUIDO**


; Read raster line register and wait for line A.


; > A = Line to wait for (0..255)


wait_line:	ld	bc,SELECT
	ld	de,(RASMSB*256)+RASLSB

	out	(c),d		; MSB
	inc	b

.msb	in	d,(c)
	bit	0,d		; 256..312/311/262/261 ?
	jp	nz,.msb

	dec	b
	out	(c),e		; LSB
	inc	b

.lsb	in	e,(c)
	cp	e		; 0..255 ?
	jp	nz,.lsb

	ret


; --------------------------------------------------------------------------


; **OPTIONAL**


; > HL = Sample address (0..65535)

; < HL = As entry


;;;set_sample_pointer:	ld	(sample_ptr),hl
;;;	ret


; --------------------------------------------------------------------------


; **OPTIONAL**


; > HL = Sample length in bytes

; < HL = As entry


;;;set_sample_length:	ld	(sample_len),hl
;;;	ret


; --------------------------------------------------------------------------


; **OPTIONAL**


; > HL = Sample position (should be 0 to sample length)

; < HL = As entry


;;;set_sample_position:	ld	(sample_pos),hl
;;;	ret


; --------------------------------------------------------------------------


; **OPTIONAL**


; < HL = Sample position (should be 0 to sample length)


;;;get_sample_position:	ld	hl,(sample_pos)
;;;	ret


; --------------------------------------------------------------------------


; **OPTIONAL**


; Set sample loop count, 0 = forever / 1 = one shot / 2..255 repeats).


; > A = Loop count (0 = forever)


;;;set_sample_loop:	ld	(sample_loop),a
;;;	ret


; --------------------------------------------------------------------------


; Call this to mute the sound (same as stop_sample, buffer loop continues).


set_sample_sound_off:


; Call this to stop sample play (copper is still active outputting NOPs).


;;;stop_sample:	xor	a
;;;	ld	(sample_dac),a	; Sound off
;;;	ret


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; **MUST CALL BEFORE PLAY_COPPER_AUDIO EACH FRAME**

; **STACK POINTER ABUSE**


; Set audio copper variables and state.


; < A = Line to wait for (0..255)


set_copper_audio:	di
	ld	(.stack+1),sp

	ld	ix,copper_loop	; Auto detect timing

	ld	bc,SELECT

	ld	a,CONFIG1
	out	(c),a
	inc	b
	in	l,(c)		; Peripheral 1 register
	dec	b

	ld	a,TIMING
	out	(c),a
	inc	b
	in	a,(c)		; VGA 0..6 / HDMI 7
	ld	h,7		; MASK VGA
	and	h
	cp	h
	jr	nz,.vga
	ld	h,0		; MASK HDMI
.vga:	ld	(video_timing),a
	dec	b

	ld	a,MACHINE
	out	(c),a
	inc	b
	in	a,(c)
	swapnib
	and	7
	ld	de,machine_tab
	add	de,a
	ld	a,(de)
	and	h
	ld	(machine),a	; 0/1/2/3
	dec	b

	bit	2,l		; Refresh 50/60hz ?
	ld	hl,copper_config_50hz
	jr	z,.hz50
	ld	hl,copper_config_60hz
.hz50:	add	a
	add	hl,a
	ld	sp,hl
	pop	hl

	ld	a,(hl)
	inc	hl
	ld	(video_refresh),a

	ld	a,(hl)		; Copper line
	inc	hl
	ld	(.return+1),a	; Store ruturn value

	ld	sp,hl

;	------------
;	------------
;	------------

	ld	hl,(sample_len)	; Calc buffer loop offset
	ld	bc,(sample_pos)
	xor	a		; Clear CF
	sbc	hl,bc

	ld	b,h
	ld	c,l		; BC = loop offset (0..311)

	pop	hl		;  Samples per frame (312)
	ld	(video_lines),hl

	ld	a,h		; 16 bit negate
	cpl
	ld	h,a
	ld	a,l
	cpl
	ld	l,a
	inc	hl		; Samples per frame (-312)

	ld	a,20		; No loop (Out of range)

	add	hl,bc
	jp	c,.no_loop

;	----D---- ----E----
;	0000 0008 7654 3210
;	0000 0000 0008 7654	

	ld	a,c		; Loop offset / 16
	and	11110000b
	or	b
	swapnib
.no_loop:	ld	b,a		; B = 0..19 (20 no loop)

	ld	a,c
	and	00001111b
	ld	c,a

;	------------

	ld	hl,.zone+1	; Build control table
	pop	de
	ld	(hl),e		; Split
	ld	a,d		; Count

	pop	hl		; 0..15 samples routine

	ld	(copper_audio_config+1),sp ; **PATCH**

	ld	sp,copper_audio_stack
	
	cp	b
	jr	nz,.skip	; Loop 0..15 samples ?

	ex	af,af'

	ld	e,c		; 0..7
	ld	d,9
	mul	d,e		; 0..144
	ld	a,144		; 144..0
	sub	e

	add	hl,de
	push	hl
	push	ix		; Output loop
	ld	de,copper_out16
	add	de,a
	push	de

	ex	af,af'

	jr	.next

;	------------

.skip:	push	hl		; Output normal

;	------------

.next:	ld	hl,copper_out16	; 16 samples routine
	dec	a

.zone:	cp	7
	jp	nz,.no_split

	ld	de,copper_split
	push	de		; Output Split
.no_split:
	cp	b
	jp	nz,.no_zone	; Loop 16 samples ?

	ex	af,af'

	ld	e,c		; 0..15
	ld	d,9
	mul	d,e		; 0..144
	ld	a,144		; 144..0
	sub	e

	add	de,copper_out16
	push	de
	push	ix		; Output loop
	ld	de,copper_out16
	add	de,a
	push	de

	ex	af,af'

	jr	.zone_next

.no_zone:	push	hl		; Output normal

.zone_next:	dec	a
	jp	p,.zone

	ld	(copper_audio_control+1),sp ; **PATCH**

.return:	ld	a,0		; Copper line to wait for

.stack:	ld	sp,0
	ei
	ret


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; **MUST CALL EACH FRAME AFTER WAITING FOR LINE A FROM SET_COPPER_AUDIO**

; **STACK POINTER ABUSE**


; Build copper list to output one frame of sample data to DAC.


play_copper_audio:	ld	(play_copper_stack+1),sp

copper_audio_config:	ld	sp,0		; **PATCH**

	pop	hl		; Index + VBLANK
	pop	de		; Line 180 + command WAIT

	ld	a,l
	nextreg	COPLO,a
	ld	a,h
	nextreg	COPHI,a

	ld	hl,(sample_ptr)	; Calc playback position
	ld	bc,(sample_pos)
	add	hl,bc

	ld	bc,SELECT	; Port
	ld	a,COPPER
	out	(c),a
	inc	b

	ld	a,(sample_dac)	; Register to set (DAC)

copper_audio_control:	ld	sp,0		; **PATCH**
	ret			; GO!!!

;	------------

copper_out16:	out	(c),d		;   0 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out15:	out	(c),d		;   9 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out14:	out	(c),d		;  18 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out13:	out	(c),d		;  27 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out12:	out	(c),d		;  36 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out11:	out	(c),d		;  45 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out10:	out	(c),d		;  54 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out9:	out	(c),d		;  63 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out8:	out	(c),d		;  72 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out7:	out	(c),d		;  81 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out6:	out	(c),d		;  90 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out5:	out	(c),d		;  99 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out4:	out	(c),d		; 108 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out3:	out	(c),d		; 117 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out2:	out	(c),d		; 126 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out1:	out	(c),d		; 135 BYTES
	out	(c),e
	out	(c),a
	outinb
	inc	de
copper_out0:	ret			; 144 BYTES

;	------------

copper_split:	out	(c),d		; Terminate
	out	(c),e
	ld	de,32768+0	; Line 0 + command WAIT
	nextreg	COPLO,000h	; Index
	nextreg	COPHI,0C0h	; Vblank

;	------------

	ex	af,af'
	dec	b
	ld	a,RASLSB
	out	(c),a
	inc	b

.l191:	in	a,(c)		; Wait for line 195 (28Mhz)
	cp	191
	jr	z,.l191

.l192:	in	a,(c)
	cp	192
	jr	z,.l192

.l193:	in	a,(c)
	cp	193
	jr	z,.l193

.l194:	in	a,(c)
	cp	194
	jr	z,.l194

	dec	b
	ld	a,COPPER
	out	(c),a
	inc	b
	ex	af,af'
	ret

;	------------

copper_loop:	ld	hl,sample_dac
	ld	a,(sample_loop)
	and	a
	jr	z,.forever
	dec	a
	jr	nz,.loop	
	ld	(hl),0		; Copper NOP (mute sound)

.loop	ld	(sample_loop),a

.forever:	ld	a,(hl)		; Read DAC mute state
	ld	hl,(sample_ptr)
	ret			; GO!!!

;	------------

copper_done:	ld	de,(sample_ptr)
	xor	a
	sbc	hl,de
	ld	(sample_pos),hl	; Update playback position

play_copper_stack:	ld	sp,0

	dec	b
	ld	a,RASLSB
	out	(c),a
	inc	b

.l197:	in	a,(c)		; Wait for line 209 (28Mhz)
	cp	197
	jr	z,.l197

.l198:	in	a,(c)
	cp	198
	jr	z,.l198

.l199:	in	a,(c)
	cp	199
	jr	z,.l199

.l200:	in	a,(c)
	cp	200
	jr	z,.l200

.l201:	in	a,(c)
	cp	201
	jr	z,.l201

.l202:	in	a,(c)
	cp	202
	jr	z,.l202

.l203:	in	a,(c)
	cp	203
	jr	z,.l203

.l204:	in	a,(c)
	cp	204
	jr	z,.l204

.l205:	in	a,(c)
	cp	205
	jr	z,.l205

.l206:	in	a,(c)
	cp	206
	jr	z,.l206

.l207:	in	a,(c)
	cp	207
	jr	z,.l207

.l208:	in	a,(c)
	cp	208
	jr	z,.l208

	ret


; --------------------------------------------------------------------------


; The copper list is made up of 2 instructions for each DAC write, a wait for
; a specific line and a move to the DAC register (4 BYTES in total). The list
; flows in order of the scanlines so index 0 waits for line 0 until all lines
; for that video mode are written to. Waiting for lines out of range is a
; convienent way to halt the copper so we add an extra line wait at the end
; of the code but there is no DAC write.

; The copper is in VBLANK reset mode so this means we are updating the copper
; list live. To avoid over-taking the copper, the list update has been split
; into two zones. We start on line 163. The copper has just wrote sample data
; to the DAC for line 163. We will fill the copper in advance for lines
; 183..310. The CPU can write around 10 sample instructions per line so we
; can easily race the copper to fill ahead avoiding it over-taking us. Line
; 183 will be filled well ahead of the copper writing on that line so we are
; safe from pops/clicks. Our point of no return is a delay of about 20 lines
; as we will hear pops/clicks if we attempt to fill lines 183..310 beyond
; line 183.
;
; Now that we have filled lines 183..310, we are now on line 174, 10 lines in
; front of the copper as the initial data that we filled is not needed until
; line 183 and was prepared starting on line 163. Now it's time to fill the
; remaining lines, 0..182. We will start filling data for these lines on line
; 174 and finish on line 191 in time for the VBLANK period. We will avoid
; over-take the cooper as we are filling behind it for lines 0..182 unless we
; are delayed by many lines.

; Our sample data is read in normal linear order but we fill the copper list
; out of order as zone 1 is lines 183..310 and zone two is lines 0..182 !!!

; The above method works for each of the four video configs where the line
; numbers and sample count may change slightly.


; NEXTEST version starts later ending on line 209.



; **VGA**	311 LINES @ 50hz


; COPPER    DISPLAY

; 188 -->   199...?	START HERE TO FILL 112 SAMPLES **INTERRUPT 188**
; 189 -->   ?.....?
; 190 -->   ?.....?
; 191 -->   ?.....?
; 192 -->   ?.....? 28Mhz 	ZONE 1 COMPLETE! SAMPLE DATA LINES 199..310 READY
; 193 -->   ?.....?
; 194 -->   ?.....?
; 195 -->   ?...310 14Mhz	ZONE 1 COMPLETE! SAMPLE DATA LINES 199..310 READY

; 195 -->   0.....?	START HERE TO FILL 199 SAMPLES
; 196 -->   ?.....?
; 197 -->   ?.....?
; 198 -->   ?.....?
; 199 -->   ?.....?
; 200 -->   ?.....? 28Mhz	ZONE 2 COMPLETE! SAMPLE DATA LINES 0..198 READY!
; 201 -->   ?.....?
; 202 -->   ?.....?
; 203 -->   ?.....?
; 204 -->   ?.....?
; 205 -->   ?.....?
; 206 -->   ?.....?
; 207 -->   ?.....?
; 208 -->   ?...198 14Mhz	ZONE 2 COMPLETE! SAMPLE DATA LINES 0..198 READY!


; --------------------------------------------------------------------------


; **VGA**	264 LINES @ 60hz


; COPPER    DISPLAY

; 191 -->   200...?	START HERE TO FILL 64 SAMPLES **INTERRUPT 191**
; 192 -->   ?.....?
; 193 -->   ?.....? 28Mhz	ZONE 1 COMPLETE! SAMPLE DATA LINES 200..263 READY
; 194 -->   ?.....?
; 195 -->   ?...263 14Mhz	ZONE 1 COMPLETE! SAMPLE DATA LINES 200..263 READY

; 195 -->   0.....?	START HERE TO FILL 200 SAMPLES
; 196 -->   ?.....?
; 197 -->   ?.....?
; 198 -->   ?.....?
; 199 -->   ?.....?
; 200 -->   ?.....?
; 201 -->   ?.....? 28Mhz	ZONE 2 COMPLETE! SAMPLE DATA LINES 0..199 READY!
; 202 -->   ?.....?
; 203 -->   ?.....?
; 204 -->   ?.....?
; 205 -->   ?.....?
; 206 -->   ?.....?
; 207 -->   ?.....?
; 208 -->   ?...199 14Mhz	ZONE 2 COMPLETE! SAMPLE DATA LINES 0..199 READY!


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; **HDMI**	312 LINES @ 50hz


; COPPER    DISPLAY

; 187 -->   200...?	START HERE TO FILL 112 SAMPLES **INTERRUPT 187**
; 188 -->   ?.....?
; 189 -->   ?.....?
; 190 -->   ?.....?
; 191 -->   ?.....? 28Mhz	ZONE 1 COMPLETE! SAMPLE DATA LINES 200..311 READY
; 192 -->   ?.....?
; 193 -->   ?.....?
; 194 -->   ?.....?
; 195 -->   ?...311 14Mhz	ZONE 1 COMPLETE! SAMPLE DATA LINES 200..311 READY

; 195 -->   0.....?	200 SAMPLES
; 196 -->   ?.....?
; 197 -->   ?.....?
; 198 -->   ?.....?
; 199 -->   ?.....? 28Mhz	ZONE 2 COMPLETE! SAMPLE DATA LINES 0..199 READY!
; 200 -->   ?.....?
; 201 -->   ?.....?
; 202 -->   ?.....?
; 203 -->   ?.....?
; 204 -->   ?.....?
; 205 -->   ?.....?
; 206 -->   ?.....?
; 207 -->   ?.....?
; 208 -->   ?...199 14Mhz	ZONE 2 COMPLETE! SAMPLE DATA LINES 0..199 READY!


; --------------------------------------------------------------------------


; **HDMI**	262 LINES @ 60hz


; COPPER    DISPLAY

; 190 -->   198...?	START HERE TO FILL 64 SAMPLES **INTERRUPT 190**
; 191 -->   ?.....?
; 192 -->   ?.....? 28Mhz	ZONE 1 COMPLETE! SAMPLE DATA LINES 198..261 READY
; 193 -->   ?.....?
; 194 -->   ?...261 14Mhz	ZONE 1 COMPLETE! SAMPLE DATA LINES 198..261 READY

; 194 -->   0.....?	198 SAMPLES
; 195 -->   ?.....?
; 196 -->   ?.....?
; 197 -->   ?.....?
; 198 -->   ?.....?
; 199 -->   ?.....?
; 200 -->   ?.....? 28Mhz	ZONE 2 COMPLETE! SAMPLE DATA LINES 0..197 READY!
; 201 -->   ?.....?
; 202 -->   ?.....?
; 203 -->   ?.....?
; 204 -->   ?.....?
; 205 -->   ?.....?
; 206 -->   ?.....?
; 207 -->   ?.....?
; 208 -->   ?...197 14Mhz	ZONE 2 COMPLETE! SAMPLE DATA LINES 0..197 READY!


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; **PENTAGON**	320 LINES @ 50hz


; COPPER    DISPLAY

; 187 -->   192...?	START HERE TO FILL 128 SAMPLES **INTERRUPT 187**
; 188 -->   ?.....?
; 189 -->   ?.....?
; 190 -->   ?.....?
; 191 -->   ?.....?
; 192 -->   ?.....? 28Mhz	ZONE 1 COMPLETE! SAMPLE DATA LINES 192..319 READY
; 193 -->   ?.....?
; 194 -->   ?.....?
; 195 -->   ?...319 14Mhz	ZONE 1 COMPLETE! SAMPLE DATA LINES 192..319 READY

; 195 -->   0.....?	192 SAMPLES
; 196 -->   ?.....?
; 197 -->   ?.....?
; 198 -->   ?.....?
; 199 -->   ?.....? 28Mhz	ZONE 2 COMPLETE! SAMPLE DATA LINES 0..191 READY!
; 200 -->   ?.....?
; 201 -->   ?.....?
; 202 -->   ?.....?
; 203 -->   ?.....?
; 204 -->   ?.....?    
; 205 -->   ?.....?
; 206 -->   ?.....?
; 207 -->   ?.....?
; 208 -->   ?...191 14Mhz	ZONE 2 COMPLETE! SAMPLE DATA LINES 0..191 READY!


; --------------------------------------------------------------------------


; The sample output code is controlled by real-time generated lists to call
; unrolled code for speed. A loop point, zone split is inserted into the
; control list. One word is needed for 16 samples plus a small overhead for
; loop/split control.


; Example: The following routine outputs 16 samples.


;	dw	copper_out16


; Example: The following routine outputs 8 samples as 19*16+8 = 312


;	dw	copper_out8


; Example: Inserting a loop point at offset 4 into 16 sample unrolled code.


;	dw	copper_out4	; Output 4 samples
;	dw	copper_loop	; Reset read pointer (loop)
;	dw	copper_out12	; Output 12 samples


; --------------------------------------------------------------------------


; Control lists for each of the four video modes (without looping).


;		**VGA 50**

;	dw	copper_out16	; 128 (8*16) samples
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;
;	dw	copper_split
;
;	dw	copper_out16	; 183 (11*16) samples
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out7
;
;	dw	copper_done

;		**VGA 60**

;	dw	copper_out16	; 80 (5*16) samples
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;
;	dw	copper_split
;
;	dw	copper_out16	; 181 (11*16) samples
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out5
;
;	dw	copper_done

;		**HDMI 50**

;	dw	copper_out16	; 128 (8*16) samples
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;
;	dw	copper_split
;
;	dw	copper_out16	; 184 (11*16) samples
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out8
;
;	dw	copper_done

;		**HDMI 60**

;	dw	copper_out16	; 80 (5*16) samples
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;
;	dw	copper_split
;
;	dw	copper_out16	; 182 (11*16) samples
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out16
;	dw	copper_out6
;
;	dw	copper_done


; --------------------------------------------------------------------------


; The playback frequency is tied to the raster line generation.

; NEXT/128K 228.0T per line; 28,000,000 / 8 / 228.0 = 15350.87Hz
;       48K 224.0T per line; 28,000,000 / 8 / 224.0 = 15625.00Hz

; 50HZ HDMI 216.0T per line; 27,000,000 / 8 / 216.0 = 15625.00Hz
; 60HZ HDMI 214.5T per line; 27,000,000 / 8 / 214.5 = 15734.27Hz

; VGA1 to VGA6 increase the playback pitch as the system clock reaches 33Mhz.


copper_config_50hz	dw	copper_312_config	; HDMI 50Hz 27MHZ
	dw	copper_312_config	; 48K  224T 28MHZ
	dw	copper_311_config	; 128K 228T 28MHZ
	dw	copper_320_config	; PENTAGON

copper_config_60hz	dw	copper_262_config	; HDMI 60Hz 27MHZ
	dw	copper_264_config	; 48K  224T 28MHZ
	dw	copper_264_config	; 128K 228T 28MHZ
	dw	copper_320_config	; PENTAGON


; --------------------------------------------------------------------------


; Control data (11 BYTES).


copper_311_config	db	50
	db	188		; Copper line 188 (50hz)
	dw	311		; Samples per frame
	db	6		; Split
	db	7+12		; Count
	dw	copper_out7	; Routine (311-304)
	db	$1C		; Index + VBLANK
	db	$C3
	dw	32768+199	; Line 199 + command WAIT

copper_264_config	db	60
	db	191		; Copper line 191 (60hz)
	dw	264		; Samples per frame
	db	3		; Split
	db	4+12		; Count
	dw	copper_out8	; Routine (264-256)
	db	$20		; Index + VBLANK
	db	$C3
	dw	32768+200	; Line 200 + command WAIT

copper_312_config	db	50
	db	187		; Copper line 187 (50hz)
	dw	312		; Samples per frame
	db	6		; Split
	db	7+12		; Count
	dw	copper_out8	; Routine (312-304)
	db	$20		; Index + VBLANK
	db	$C3
	dw	32768+200	; Line 200 + command WAIT

copper_262_config	db	60
	db	190		; Copper line 190 (60hz)
	dw	262		; Samples per frame
	db	3		; Split
	db	4+12		; Count
	dw	copper_out6	; Routine (262-256)
	db	$18		; Index + VBLANK
	db	$C3
	dw	32768+198	; Line 198 + command WAIT

copper_320_config	db	50
	db	187		; Copper line 187 (50hz)
	dw	320		; Samples per frame
	db	7		; Split
	db	7+12		; Count
	dw	copper_out16	; Routine (320-304)
	db	$00		; Index + VBLANK
	db	$C3
	dw	32768+192	; Line 192 + command WAIT


; --------------------------------------------------------------------------


; Machine ID translation (0=HDMI / 1=48K / 2=128K / 3=PENTAGON)


machine_tab	db	1		; 000b
	db	1		; 001b
	db	2		; 010b
	db	2		; 011b
	db	3		; 100b
	db	2		; 101b
	db	2		; 110b
	db	2		; 111b

machine	db	0


; --------------------------------------------------------------------------


; Variables.


sample_ptr	dw	0		; 32768
sample_pos	dw	0
sample_len	dw	0		; 10181
sample_dac	db	0		; DAC register

sample_loop	db	0		; 0..255

video_lines	dw	0		; 311/312/262/264
video_timing	db	0		; 0..7
video_refresh	db	0		; 50/60

	dw	0,0,0,0,0,0,0,0	;
	dw	0,0,0,0,0,0,0,0	; Define 23 WORDS
	dw	0,0,0,0,0,0,0  	;

copper_audio_stack	dw	copper_done


; --------------------------------------------------------------------------

