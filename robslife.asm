; ZX Spectrum Full screen Life
;
; My attempt at beating Macro-Life by Toni Baker (10.5 seconds full screen)
; and Outlet Life by Paul Hiley (3.5 seconds 2/3 screen)
; Assembled with zasm https://k1.spdns.de/Develop/Projects/zasm/Documentation/

;
; We don't use stack based memory copy/mem clear operations ... yet :-)
;

    org 55555 ; = $d903, well above the screen copy

; screen copy at $C000, and a 32 byte buffer before that. 
; this code above that
; plenty of room for basic, or anything else


start:
; The IY register must be preserved if the Spectrum ROM's interrupt handler is to be used, and so must 
; therefore be saved if returning from a USR routine. Its value must be restored to 0x5c3a 
; ("ERRNO", at 23610 in decimal) in these conditions, although it arguably more portable to save 
; the value in IY, rather than to assume that it will always be 0x5c3a. 
; HL′ and SP must also be preserved. 
; For a successful return to BASIC, HL' must on exit from the machine code contain the 
; address of the 'end-calc' instruction at 10072.

    ld a, 192  ; number of lines - unsigned 8 bit
    ld e, 0    ; start row - unsigned 8 bit
    exx
    push hl
    exx        ; get register e back
    call main
    pop hl
    exx        ; make sure that's HL'
    ret

main:
    ld (current_line_count), a

    ; we get the address of the target line address from the list of line addresses here
    ld d, 0
    ld hl, line_addresses_back_one

    add hl, de
    adc hl, de
    ld (current_line_indirect_address), hl

;
; We copy the screen here. 
; Above and below are a blank line
;

; make a blank line before

; first get the address of the line
;    ld  a, (hl)
;    inc hl
;    ld l, (hl)
;    ld h, a
; we need don't need to step back to the previous line (-32) in current_line_indirect_address


;    ld hl,$c000-32
;    call clear32_aligned4
;    ex hl, de
; ldir line before and line afterward
;    ld d, h
;    ld e, l
;    res 7, d

    ld hl,$4000
    ld de,$C000
    
;    ld a, (current_line_count)
;<<< fix this
    ld bc,$1800/32
    call fast_ldir32

;    ex hl,de
;    call clear32_aligned4

;
; clear the right lines after we've copied the whole screen
;
; clear the one before the first line
    ld hl, (current_line_indirect_address)
    ld d, (hl)
    inc l
    ld e, (hl)
    ex de, hl
    call clear32_aligned4

; now clear the one past the last line
    ld a,(current_line_count)
; need to multiply *2
    ld l,a
    ld h,0
    add hl, hl ; *2
    ex de, hl
    ld hl, (current_line_indirect_address)
    add hl, de          ; we have the address of last line being processed
; need to stop one more line
    ld d,0
    ld e,2              ; each entry is 2 bytes
    add hl, de

; now get the line address
    ld d, (hl)
    inc l
    ld e, (hl)
    ex de, hl
; clear that line
    call clear32_aligned4



; ----------------------------------------------------------------

line_loop:

; set up de/hl/bc using line array (one behind processing lines)
; and push onto stack
    ld hl, (current_line_indirect_address) ; 20
    ld b, (hl)          ; 7 = 27
    inc l               ; 4 = 31
    ld c, (hl)          ; 7 = 38  top row=BC (back one)
    inc hl              ; 6 = 44
    ld (current_line_indirect_address), hl   ; save new line table address
    ld d, (hl)          ; 7 = 51  middle row=DE (one we are processing)
    inc l               ; 4 = 55
    ld e, (hl)          ; 7 = 62  
    inc hl              ; 6 = 68
    ld a, (hl)          ; 7 = 75  bottom row=HL
    inc l               ; 4 = 79 
    ld l, (hl)          ; 7 = 86
    ld h, a             ; 4 = 90
; now we have the three pointers to the lines

; get the first byte of each line
    ld a, (bc)      ; 7=37 top row, show be d but put it temporarily in a
    inc bc
    push bc     ; 11=48

    ld b, (hl)      ; 7=55 bottom row = b
    inc hl      ; 6=61
    push hl     ; 11=72

    ld h, a     ; mode to h on its way to d
    ld a, (de)  ; 7=79    ; middLe row = e
    inc de      ; 6=85
    push de     ; 11=96  ; de short for destination? :-)

    ld d, h         ; 4=100 move to top row = d
    ld e, a         ; move to e

; make sure the bit count table is read for the HL index.
    ld h, bit_count_table/256
    exx
    ld h, bit_count_table/256

; off the left edge is zero (the previous byte of each line)
    xor a
    ld d, a
    ld e, a
    ld b, a

; 32 bytes on each line
    ld a, 32

column_loop:
    ld (line_byte_count), a

; Previous concept was memory access each byte:
;;  bit 1 - top row
;    ld a,(de)          ; 7
;    or 7               ; 4
;    ld l, a            ; 4
;    ld c,(hl)          ; 7 count in c
;    exx                ; 4=26
;; bit 1 - middle row
;    ld a,(de)          ; 7 hl'
;    or 5               ; 4 don't analyse our cell, only neighbours
;    ld l, a            ; 4
;    ld a,(hl)          ; 7
;    ex af, af'         ; 4 save count A away until we switch
                        ; 26->52
;; bit 1 - bottom row
;    ld a,(de)          ; 7 A'
;    or 7               ; 4
;    ld l, a            ; 4
;    ld a,(hl)          ; 7 count for middle in A'
                        ; 22->74
;; add up counts
;    exx                ; 4 back to main set
;    add a, c           ; 4 c is now free
;    ld c, a            ; 4 c now has count of top and bottom
;    ex af, af'         ; 4
;    add a, c           ; 4 a now has count of all three rows
                        ; 20->94
                        ; 94 for the load from memory VS. 69 for the register based method

; This method is to keep the pixels in registers, rather than addresses to pixels in registers:
; There are just about enough registers on the Z80 to do this. It saves a slight amount of time.
; previous in H, L, B ... h = high pixel line, l = middLe, b=bottom pixel line
; current in H' L' B' 
; DE = bit counting
; C and C' are count of bits
; A = working
; A' = output pixel byte
; ----------------------------------
; deal with remainders from last column
; bit 7 - top row, left
    ld a, d
    and 1                ; literally the count!
    ld c, a
; bit 7 - middle row, left
    ld a, e
    and 1
    add a, c
    ld c, a
; bit 7 - bottom row, left
    ld a, b
    and 1
    add a, c            ; we have count for left neighbours now
; hl and bc are now free.
    exx
    ld c, a
 ; bit 7 - top row, mid/right
    ld a, d
    and $c0
    ld l, a
    ld a, (hl)
    add a, c
    ld c, a
; bit 7 - middle row, mid/right
    ld a, e
    and $40
    ld l, a
    ld a, (hl)
    add a, c
    ld c, a
; bit 7 - bottom row, mid/right
    ld a, b
    and $c0
    ld l, a
    ld a, (hl)
    add a, c

; A contains the count of bits
    ld a, h
    ld a, h
    ld a, h
    ld a, h
    ld a, h
    ld a, h
    ld a, h
    ld a, h
    ld a, h
    ld a, h
    or $80
    or $80
    or $80
    or $80
    or $80
    or $80
    or $80
    or $80
    or $80
    or $80
    cp 3
    jr z, alive7    ;In terms of speed jp is faster when a jump occurs (10 T-states) and jr is faster when it doesn't occur.
    cp 2
    jr z, remain7
;dead
;    ex af, af'         ; redundant
    xor a
    jp skip7
alive7:
    ld a, $1
skip7:
    ex af, af'
remain7:


; ----------------------------------
 ; bit 6 - top row, mid/right
    ld a, d
    or $e0
    ld l, a
    ld c, (hl)
; bit 6 - middle row, mid/right
    ld a, e
    or $a0
    ld l, a
    ld a, (hl)
    add a, c
    ld c, a
; bit 6 - bottom row, mid/right
    ld a, b
    or $e0
    ld l, a
    ld a, (hl)
    add a, c

; A contains the count of bits
    cp 3
    jr z, alive6    ;In terms of speed jp is faster when a jump occurs (10 T-states) and jr is faster when it doesn't occur.
    cp 2
    jr z, remain6
;dead
    ex af, af'
    and $bf     ; res 6, a
    jp skip6
alive6:
    and $40     ; set 6, a
skip6:
    ex af, af'
remain6:

; ----------------------------------
 ; bit 5 - top row, mid/right
    ld a, d
    or $70
    ld l, a
    ld c, (hl)
; bit 5 - middle row, mid/right
    ld a, e
    or $50
    ld l, a
    ld a, (hl)
    add a, c
    ld c, a
; bit 5 - bottom row, mid/right
    ld a, b
    or $70
    ld l, a
    ld a, (hl)
    add a, c

; A contains the count of bits
    cp 3
    jr z, alive5    ;In terms of speed jp is faster when a jump occurs (10 T-states) and jr is faster when it doesn't occur.
    cp 2
    jr z, remain5
;dead
    ex af, af'
    and $df             ; res 5, a
    jp skip5
alive5:
    or $20              ; set 5, a
skip5:
    ex af, af'
remain5:

; ----------------------------------
 ; bit 4 - top row, mid/right
    ld a, d
    or $38
    ld l, a
    ld c, (hl)
; bit 4 - middle row, mid/right
    ld a, e
    or $28
    ld l, a
    ld a, (hl)
    add a, c
    ld c, a
; bit 4 - bottom row, mid/right
    ld a, b
    or $38
    ld l, a
    ld a, (hl)
    add a, c

; A contains the count of bits
    cp 3
    jr z, alive4    ;In terms of speed jp is faster when a jump occurs (10 T-states) and jr is faster when it doesn't occur.
    cp 2
    jr z, remain4
;dead
    ex af, af'
    or $ef              ; res 4, a
    jp skip4
alive4:
    or $10              ; set 4, a
skip4:
    ex af, af'
remain4:

; ----------------------------------
 ; bit 3 - top row, mid/right
    ld a, d
    or $1c
    ld l, a
    ld c, (hl)
; bit 3 - middle row, mid/right
    ld a, e
    or $14
    ld l, a
    ld a, (hl)
    add a, c
    ld c, a
; bit 3 - bottom row, mid/right
    ld a, b
    or $1c
    ld l, a
    ld a, (hl)
    add a, c

; A contains the count of bits
    cp 3
    jr z, alive3    ;In terms of speed jp is faster when a jump occurs (10 T-states) and jr is faster when it doesn't occur.
    cp 2
    jr z, remain3
;dead
    ex af, af'
    and $f7     ; res 3, a
    jp skip3
alive3:
    or $8       ; set 3, a
skip3:
    ex af, af'
remain3:

; ----------------------------------
 ; bit 2 - top row, mid/right
    ld a, d
    or $0e
    ld l, a
    ld c, (hl)
; bit 2 - middle row, mid/right
    ld a, e
    or $0a
    ld l, a
    ld a, (hl)
    add a, c
    ld c, a
; bit 2 - bottom row, mid/right
    ld a, b
    or $0e
    ld l, a
    ld a, (hl)
    add a, c

; A contains the count of bits
    cp 3
    jr z, alive2    ;In terms of speed jp is faster when a jump occurs (10 T-states) and jr is faster when it doesn't occur.
    cp 2
    jr z, remain2
;dead
    ex af, af'
    and $fb             ;res 2, a
    jp skip2
alive2:
    or 4                ; set 2, a
skip2:
    ex af, af'
remain2:

; ----------------------------------
 ; bit 1 - top row, mid/right
    ld a, d     ; 4
    or 7        ; 7
    ld l, a     ; 4
    ld c, (hl)  ; 7=22
; bit 1 - middle row, mid/right
    ld a, e     ; 4
    or 5        ; 7
    ld l, a     ; 4
    ld a, (hl)  ; 7
    add a, c    ; 4
    ld c, a     ; 4=30
; bit 1 - bottom row, mid/right
    ld a, b     ; 4
    or 7        ; 7
    ld l, a     ; 4
    ld a, (hl) ; 7
    add a, c    ; 4=26
                ; 22+30+26=78

; A contains the count of bits
    cp 3
    jr z, alive1    ;In terms of speed jp is faster when a jump occurs (10 T-states) and jr is faster when it doesn't occur.
    cp 2
    jr z, remain1
;dead
    ex af, af'
    and $fd     ; res 1, a
    jp skip1
alive1:
    or 2       ; set 1, a
skip1:
    ex af, af'
remain1:


; swap current to old (B, HL -> B' HL')
;  C, E, E' and C' are empty at this point, 
; D and D' have both the same thing in.
; so save to exchange to do this
    exx
; reload current B and HL. NOTE: BC and HL are free now, as is A and E
; this only works if it's not the end of a row (because we will get the wrong next pixel)
    ld a,(line_byte_count)
    cp 1
    jr z, skip_end_of_row
    pop de          ; middle
    pop hl          ; bottom
    pop bc          ; top

    ld a, (bc)      ; top row, should be d but put it temporarily in a
    inc bc
    push bc

    ld b, (hl)      ; bottom row = b
    inc hl
    push hl

    ld h, a         ; shift top row to h

    ld a, (de)      ; middle row = e
    inc de
    push de

    ld d, h         ; move to top row
    ld e, a

    ; restore d
    ld h, bit_count_table/256

resume_end_of_line:
; now we can calculate the bit 0
    exx ; use old ones
 ; bit 0&1 - top row
    ld a, d
    or $03
    ld l, a
    ld c, (hl)
; bit 1 - middle row
    ld a, e
    or $02      ; not own bit
    ld l, a
    ld a, (hl)
    add a, c
    ld c, a
; bit 0&1 - bottom row
    ld a, b
    or $03
    ld l, a
    ld a, (hl)
    add a, c
; swap!
    exx
    ld c, a     ; store it back after swapping!

 ; bit 7 - top row
    ld a, d
    or $80
    ld l, a
    ld a, (hl)
    add a, c
    ld c, a
; bit 7 - middle row
    ld a, e
    or $80
    ld l, a
    ld a, (hl)
    add a, c
    ld c, a
; bit 7 - bottom row
    ld a, b
    or $80
    ld l, a
    ld a, (hl)
    add a, c

; A contains the count of bits
    cp 3
    jr z, alive0    ;In terms of speed jp is faster when a jump occurs (10 T-states) and jr is faster when it doesn't occur.
    cp 2
    jr z, remain0
;dead
    ex af, af'
    and $fe
    jp skip0
alive0:
    or 1
skip0:
    ex af, af'
remain0:

; swap to obsolete registers
    exx
; write back the data to the screen 
    pop hl      ; middle row always in middle of stack
    push hl
    dec hl      ; it was pre-incremented
    res 7, h
    ex af, af'
    ld (hl), a
    ld a,(line_byte_count)
    dec a
    jp nz, column_loop

; end of line
    ld a, (current_line_count)
    dec a
    jp nz, line_loop

; copy back to screen not required - we've been copying
; back to screen as we go.
    ret

skip_end_of_row:
    ld hl,0
    ld b, 0
    jp resume_end_of_line

    .db 0
    dm "Fast Spectrum Life (c) 2020 Rob Probin"
    .db 0

fast_ldir8:
; https://wikiti.brandonw.net/index.php?title=Z80_Optimization
; "Classic" with LDIR is ~21 T-states per byte copied
; ld hl,src
; ld de,dest
; ld bc,size
; ldir

; Unrolled : (16 * size + 10) / n -> ~18 T-states per byte copied when unrolling 8 times
; ld hl,src
; ld de,dest
; ld bc,size  ; if the size is not a multiple of the number of unrolled ldi then a small trick must be used to jump appropriately inside the loop for the first iteration
loopldi:    ;you can use this entry for a call
 ldi
 ldi
 ldi
 ldi
 ldi
 ldi
 ldi
 ldi
 jp pe, loopldi    ; jp used as it is faster and in the case of a loop unrolling we assume speed matters more than size
 ret ; if this is a subroutine and use the unrolled ldi's with a call.

fast_ldir32:
; Unrolled : (32 * size + 10) / n = (32*16 + 10) / 32 = ~16.3 T-states per byte copied when unrolled 32 times
 ldi
 ldi
 ldi
 ldi
 ldi
 ldi
 ldi
 ldi

 ldi
 ldi
 ldi
 ldi
 ldi
 ldi
 ldi
 ldi

 ldi
 ldi
 ldi
 ldi
 ldi
 ldi
 ldi
 ldi

 ldi
 ldi
 ldi
 ldi
 ldi
 ldi
 ldi
 ldi
 jp pe, fast_ldir32
 ret



; https://retrocomputing.stackexchange.com/questions/4744/how-fast-is-memcpy-on-the-z80
;fast_ldir2:
; 175 cycles / 14 bytes = 12.5 cycles/byte.
;    di
;    ld      sp,src  ; 10
;    pop     af      ; 10
;    pop     bc      ; 10
;    pop     de      ; 10
;    pop     hl      ; 10
;    exx             ; 4
;    pop     bc      ; 10
;    pop     de      ; 10
;    pop     hl      ; 10
;    ld      sp,dst  ; 10
;    push    hl      ; 11
;    push    de      ; 11
;    push    bc      ; 11
;    exx             ; 4
;    push    hl      ; 11
;    push    de      ; 11
;    push    bc      ; 11
;    push    af      ; 11
;    ei
;    ret


; https://zxsnippets.fandom.com/wiki/Clearing_screen
clear32_aligned4:
    xor a
    ld b, #8             ;set B to zero it will cause 256 repeations of loop
clear32_loop:
    ld (hl), a           ;7 set byte to zero
    inc l                ;4 move to the next byte
    ld (hl), a
    inc l
    ld (hl), a
    inc l
    ld (hl), a
    inc hl               ;7 this time we are not sure that inc l will not cause overflow
    djnz clear32_loop    ;repeat for next 4 bytes
    ret

; cycles
; ======
; exx               4
; ld r, r           4
; ld r, (rr)        7
; ld r, n           7
; ld rr, n          10
; ex af, af         4
; add a, r          4
; sub r             4
; ld (rr), r        7
; add a,(hl)        7
; add a, n          7
; or n              7
; and n             7
; or r              4
; push rr           11
; pop rr            10
; set b, r          08
; res b, r          08
; setr b,(hl)       15
; jr cc,n           12, 7
; jp cc, nn         10, 10
; jp nn             10
; jr n              12
; ld (rr), r        7
; inc rr            6
; dec rr            6
; ldi               16
; ldir              21/16

line_byte_count:
    .dw 0
current_line_indirect_address:
    .dw 0
current_line_count:
    .dw 0

    align 256
bit_count_table:
 .db 0, 1, 1, 2, 1, 2, 2, 3  ; 0-7
 .db 1, 2, 2, 3, 2, 3, 3, 4  ; 8-15
 .db 1, 2, 2, 3, 2, 3, 3, 4  ; 16-23
 .db 2, 3, 3, 4, 3, 4, 4, 5  ; 24-31
 .db 1, 2, 2, 3, 2, 3, 3, 4  ; 32-39
 .db 2, 3, 3, 4, 3, 4, 4, 5  ; 40-47
 .db 2, 3, 3, 4, 3, 4, 4, 5  ; 48-55
 .db 3, 4, 4, 5, 4, 5, 5, 6  ; 56-63
 .db 1, 2, 2, 3, 2, 3, 3, 4  ; 64-71
 .db 2, 3, 3, 4, 3, 4, 4, 5  ; 72-79
 .db 2, 3, 3, 4, 3, 4, 4, 5  ; 80-87
 .db 3, 4, 4, 5, 4, 5, 5, 6  ; 88-95
 .db 2, 3, 3, 4, 3, 4, 4, 5  ; 96-103
 .db 3, 4, 4, 5, 4, 5, 5, 6  ; 104-111
 .db 3, 4, 4, 5, 4, 5, 5, 6  ; 112-119
 .db 4, 5, 5, 6, 5, 6, 6, 7  ; 120-127
 .db 1, 2, 2, 3, 2, 3, 3, 4  ; 128-135
 .db 2, 3, 3, 4, 3, 4, 4, 5  ; 136-143
 .db 2, 3, 3, 4, 3, 4, 4, 5  ; 144-151
 .db 3, 4, 4, 5, 4, 5, 5, 6  ; 152-159
 .db 2, 3, 3, 4, 3, 4, 4, 5  ; 160-167
 .db 3, 4, 4, 5, 4, 5, 5, 6  ; 168-175
 .db 3, 4, 4, 5, 4, 5, 5, 6  ; 176-183
 .db 4, 5, 5, 6, 5, 6, 6, 7  ; 184-191
 .db 2, 3, 3, 4, 3, 4, 4, 5  ; 192-199
 .db 3, 4, 4, 5, 4, 5, 5, 6  ; 200-207
 .db 3, 4, 4, 5, 4, 5, 5, 6  ; 208-215
 .db 4, 5, 5, 6, 5, 6, 6, 7  ; 216-223
 .db 3, 4, 4, 5, 4, 5, 5, 6  ; 224-231
 .db 4, 5, 5, 6, 5, 6, 6, 7  ; 232-239
 .db 4, 5, 5, 6, 5, 6, 6, 7  ; 240-247
 .db 5, 6, 6, 7, 6, 7, 7, 8  ; 248-255

; Notice we have a line ahead and behind (so that top and bottom pixel lines are blank always)
; This table is big endian, it is ok for us because there is no ld rr,(hl) on the Z80. 
; (Z80 hl load/store is little endian).
 align 2
line_addresses_back_one:
 defb $bf, $e0                 ; one line above
line_addresses:
 defb $c0, $00,   $c1, $00,   $c2, $00,   $c3, $00,   $c4, $00,   $c5, $00,   $c6, $00,   $c7, $00
 defb $c0, $20,   $c1, $20,   $c2, $20,   $c3, $20,   $c4, $20,   $c5, $20,   $c6, $20,   $c7, $20
 defb $c0, $40,   $c1, $40,   $c2, $40,   $c3, $40,   $c4, $40,   $c5, $40,   $c6, $40,   $c7, $40
 defb $c0, $60,   $c1, $60,   $c2, $60,   $c3, $60,   $c4, $60,   $c5, $60,   $c6, $60,   $c7, $60
 defb $c0, $80,   $c1, $80,   $c2, $80,   $c3, $80,   $c4, $80,   $c5, $80,   $c6, $80,   $c7, $80
 defb $c0, $a0,   $c1, $a0,   $c2, $a0,   $c3, $a0,   $c4, $a0,   $c5, $a0,   $c6, $a0,   $c7, $a0
 defb $c0, $c0,   $c1, $c0,   $c2, $c0,   $c3, $c0,   $c4, $c0,   $c5, $c0,   $c6, $c0,   $c7, $c0
 defb $c0, $e0,   $c1, $e0,   $c2, $e0,   $c3, $e0,   $c4, $e0,   $c5, $e0,   $c6, $e0,   $c7, $e0
 defb $c8, $00,   $c9, $00,   $ca, $00,   $cb, $00,   $cc, $00,   $cd, $00,   $ce, $00,   $cf, $00
 defb $c8, $20,   $c9, $20,   $ca, $20,   $cb, $20,   $cc, $20,   $cd, $20,   $ce, $20,   $cf, $20
 defb $c8, $40,   $c9, $40,   $ca, $40,   $cb, $40,   $cc, $40,   $cd, $40,   $ce, $40,   $cf, $40
 defb $c8, $60,   $c9, $60,   $ca, $60,   $cb, $60,   $cc, $60,   $cd, $60,   $ce, $60,   $cf, $60
 defb $c8, $80,   $c9, $80,   $ca, $80,   $cb, $80,   $cc, $80,   $cd, $80,   $ce, $80,   $cf, $80
 defb $c8, $a0,   $c9, $a0,   $ca, $a0,   $cb, $a0,   $cc, $a0,   $cd, $a0,   $ce, $a0,   $cf, $a0
 defb $c8, $c0,   $c9, $c0,   $ca, $c0,   $cb, $c0,   $cc, $c0,   $cd, $c0,   $ce, $c0,   $cf, $c0
 defb $c8, $e0,   $c9, $e0,   $ca, $e0,   $cb, $e0,   $cc, $e0,   $cd, $e0,   $ce, $e0,   $cf, $e0
 defb $d0, $00,   $d1, $00,   $d2, $00,   $d3, $00,   $d4, $00,   $d5, $00,   $d6, $00,   $d7, $00
 defb $d0, $20,   $d1, $20,   $d2, $20,   $d3, $20,   $d4, $20,   $d5, $20,   $d6, $20,   $d7, $20
 defb $d0, $40,   $d1, $40,   $d2, $40,   $d3, $40,   $d4, $40,   $d5, $40,   $d6, $40,   $d7, $40
 defb $d0, $60,   $d1, $60,   $d2, $60,   $d3, $60,   $d4, $60,   $d5, $60,   $d6, $60,   $d7, $60
 defb $d0, $80,   $d1, $80,   $d2, $80,   $d3, $80,   $d4, $80,   $d5, $80,   $d6, $80,   $d7, $80
 defb $d0, $a0,   $d1, $a0,   $d2, $a0,   $d3, $a0,   $d4, $a0,   $d5, $a0,   $d6, $a0,   $d7, $a0
 defb $d0, $c0,   $d1, $c0,   $d2, $c0,   $d3, $c0,   $d4, $c0,   $d5, $c0,   $d6, $c0,   $d7, $c0
 defb $d0, $e0,   $d1, $e0,   $d2, $e0,   $d3, $e0,   $d4, $e0,   $d5, $e0,   $d6, $e0,   $d7, $e0
; line below
 defb $d8, $00


; END
