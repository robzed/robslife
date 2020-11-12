; Based on Tape file example by Günter Woigk

; fill byte is 0x00
; #code has an additional argument: the sync byte for the block.
; The assembler calculates and appends checksum byte to each segment.
; Note: If a segment is appended without an explicite address, then the sync byte and the checksum byte
; of the preceding segment are not counted when calculating the start address of this segment.

#target tap


; sync bytes:
headerflag:     equ 0
dataflag:       equ 0xff


; some Basic tokens:
tCLEAR      equ     $FD             ; token CLEAR
tLOAD       equ     $EF             ; token LOAD
tCODE       equ     $AF             ; token CODE
tPRINT      equ     $F5             ; token PRINT
tRANDOMIZE  equ     $F9             ; token RANDOMIZE
tUSR        equ     $C0             ; token USR
tPLOT       equ     $F6
tCOLON      equ     $3A
tCOMMA      equ     $2C

pixels_start    equ 0x4000      ; ZXSP screen pixels
attr_start      equ 0x5800      ; ZXSP screen attributes
printer_buffer  equ 0x5B00      ; ZXSP printer buffer
code_start      equ 55555


; image buffer is at 49152-32, scree copy is at 49152.

; ---------------------------------------------------
;       a Basic Loader:
; ---------------------------------------------------

#code PROG_HEADER,0,17,headerflag
        defb    0                       ; Indicates a Basic program
        defb    "mloader   "            ; the block name, 10 bytes long
        defw    variables_end-0         ; length of block = length of basic program plus variables
        defw    10                      ; line number for auto-start, 0x8000 if none
        defw    program_end-0           ; length of the basic program without variables


#code PROG_DATA,0,*,dataflag

        ; ZX Spectrum Basic tokens

; 10 CLEAR 49000
        defb    0,10                    ; line number
        defb    end10-($+1)             ; line length
        defb    0                       ; statement number
        defb    tCLEAR                  ; token CLEAR
        defm    "49000",$0e000068bf00   ; number 49000, ascii & internal format
end10:  defb    $0d                     ; line end marker

; 20 LOAD "" CODE 55555
        defb    0,20                    ; line number
        defb    end20-($+1)             ; line length
        defb    0                       ; statement number
        defb    tLOAD,'"','"',tCODE     ; token LOAD, 2 quotes, token CODE
        defm    "55555",$0e000003d900   ; number 55555, ascii & internal format
end20:  defb    $0d                     ; line end marker

; 30 plot 2, 175: plot 2,174; plot 2, 173: plot 0, 174, plot 1,173
        defb    0,30                    ; line number
        defb    end30-($+1)             ; line length
        defb    0                       ; statement number
        defb    tPLOT
        defm    "2",   $0e0000020000
        defm    ",175",$0e0000af0000
        defb    tCOLON
        defb    tPLOT
        defm    "2",   $0e0000020000
        defm    ",174",$0e0000ae0000
        defb    tCOLON
        defb    tPLOT
        defm    "2",   $0e0000020000
        defm    ",173",$0e0000ad0000
        defb    tCOLON
        defb    tPLOT
        defm    "0",   $0e0000000000
        defm    ",174",$0e0000ae0000
        defb    tCOLON
        defb    tPLOT
        defm    "1",   $0e0000010000
        defm    ",173",$0e0000ad0000

end30:  defb    $0d                     ; line end marker


; 40 RANDOMIZE USR 55555
        defb    0,40                    ; line number
        defb    end40-($+1)             ; line length
        defb    0                       ; statement number
        defb    tRANDOMIZE,tUSR         ; token RANDOMIZE, token USR
        defm    "55555",$0e000003d900   ; number 55555, ascii & internal format
end40:  defb    $0d                     ; line end marker

program_end:

        ; ZX Spectrum Basic variables

variables_end:

; 
; ---------------------------------------------------
;       a machine code block:
; ---------------------------------------------------

#code CODE_HEADER,0,17,headerflag
        defb    3                       ; Indicates binary data
        defb    "mcode     "            ; the block name, 10 bytes long
        defw    code_end-code_start     ; length of data block which follows
        defw    code_start              ; default location for the data
        defw    0                       ; unused


#code CODE_DATA, code_start,*,dataflag

 include "robslife.asm"

code_end:

