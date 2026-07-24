.segment "CODE"
.ifdef EATER

; ==============================================================================
; VFD Display Driver for CIG25-1605N 
;
; Pin Assignments (VIA Port A):
;   PA0 -> RST  (Active Low Hardware Reset)
;   PA1 -> CS   (Active Low Chip Select)
;   PA2 -> CP   (Serial Clock - Clocked on Rising Edge)
;   PA3 -> DA   (Serial Data - LSB First)
; ==============================================================================

MSG_ROW1:  .asciiz "65C02 Computer"
MSG_ROW2:  .asciiz "> Hello World!"

; ------------------------------------------------------------------------------
; VFD_INIT
; ------------------------------------------------------------------------------
VFD_INIT:
    ; Set PA0-PA3 as Outputs in DDRA
    LDA DDRA
    ORA #$0F
    STA DDRA

    ; Initial Pin States: RST=1, CS=1, CP=1, DA=0 -> %00000111 ($07)
    LDA #$07
    STA PORTA

    JSR VFD_DELAY_100MS

    ; Power-on Reset Pulse: RST Low (PA0=0)
    LDA #$06                     ; RST=0, CS=1, CP=1, DA=0
    STA PORTA
    JSR VFD_DELAY_5MS
    LDA #$07                     ; RST=1, CS=1, CP=1, DA=0
    STA PORTA

    ; Command 0x70: Set Normal Display Mode
    LDA #$05                     ; CS Low (PA1=0)
    STA PORTA
    LDA #$70
    JSR VFD_SEND_BYTE
    LDA #$07                     ; CS High (PA1=1)
    STA PORTA
    JSR VFD_DELAY_1MS

    ; Command 0x6C: Set Display Digits (COM1-COM16)
    LDA #$05                     ; CS Low
    STA PORTA
    LDA #$6C
    JSR VFD_SEND_BYTE
    LDA #$07                     ; CS High
    STA PORTA
    JSR VFD_DELAY_1MS

    ; Set Brightness (Duty = 900 -> 0x50 command + 0xE1 bh)
    LDA #$05                     ; CS Low
    STA PORTA
    LDA #$50                     ; 0x50 | (900 % 4)
    JSR VFD_SEND_BYTE
    LDA #$E1                     ; 900 / 4
    JSR VFD_SEND_BYTE
    LDA #$07                     ; CS High
    STA PORTA
    JSR VFD_DELAY_1MS

    ; Clear DCRAM and ADRAM completely with spaces ($20) and zeros ($00)
    JSR VFD_CLEAR

    ; Display Default Banner Lines
    LDA #1
    STA VFD_ROW
    LDX #<MSG_ROW1
    LDY #>MSG_ROW1
    JSR VFD_PRINT_INIT_STR

    LDA #2
    STA VFD_ROW
    LDX #<MSG_ROW2
    LDY #>MSG_ROW2
    JSR VFD_PRINT_INIT_STR
    RTS

; ------------------------------------------------------------------------------
; VFDPRINT
; MSBASIC Command Handler: VFDPRINT <row>, <string>
; ------------------------------------------------------------------------------
VFDPRINT:
    JSR GETBYT                   ; Evaluate first parameter (Row 1 or 2) -> X
    DEX                          ; Convert 1-based row to 0-based index (0 or 1)
    STX VFD_ROW

    JSR CHKCOM                   ; Expect ','

    JSR FRMEVL                   ; Evaluate string expression
    JSR FRESTR                   ; Get string descriptor: len -> A, ptr -> (INDEX)

    TAX                          ; Length -> X
    STZ VFD_COL                  ; Reset column index to 0
    CPX #0
    BEQ @pad_remaining           ; If empty string, pad whole row with spaces

    LDY #0

@str_loop:
    PHY
    PHX
    LDA (INDEX),Y                ; Get character code
    JSR VFD_DISP_CHAR            ; Print character to VFD
    INC VFD_COL
    PLX
    PLY
    LDA VFD_COL
    CMP #16
    BCS @exit                    ; Stop if filled 16 columns

    INY
    DEX
    BNE @str_loop

@pad_remaining:
    ; Fill remaining row columns with ASCII spaces ($20) to erase old text
    LDA VFD_COL
    CMP #16
    BCS @exit
    LDA #$20                     ; Space character
    JSR VFD_DISP_CHAR
    INC VFD_COL
    BRA @pad_remaining

@exit:
    RTS

; ------------------------------------------------------------------------------
; VFD_DISP_CHAR
; Displays a single character at current VFD_ROW and VFD_COL.
; Input: A = Character Code
; ------------------------------------------------------------------------------
VFD_DISP_CHAR:
    PHA                          ; Save character code
    LDA #$05                     ; CS Low
    STA PORTA

    LDA VFD_ROW
    BEQ @row0
    LDA #$10                     ; Row 2 -> DCRAM_A (Bottom row)
    BRA @send_cmd
@row0:
    LDA #$90                     ; Row 1 -> DCRAM_B (Top row)
@send_cmd:
    JSR VFD_SEND_BYTE

    ; Hardware inverted column address: (15 - VFD_COL)
    LDA #15
    SEC
    SBC VFD_COL
    JSR VFD_SEND_BYTE

    PLA                          ; Restore character code
    JSR VFD_SEND_BYTE

    LDA #$07                     ; CS High
    STA PORTA
    JMP VFD_DELAY_1MS

; ------------------------------------------------------------------------------
; VFD_SEND_BYTE
; Transmits an 8-bit byte serially (LSB First)
; Input: A = Byte to transfer
; ------------------------------------------------------------------------------
VFD_SEND_BYTE:
    STA VFD_TMP
    PHX
    LDX #8
@bit_loop:
    LSR VFD_TMP                  ; Shift LSB into Carry
    BCS @bit_one
@bit_zero:
    LDA #$01                     ; RST=1, CS=0, CP=0, DA=0
    STA PORTA
    NOP
    LDA #$05                     ; Clock High
    STA PORTA
    BRA @next_bit
@bit_one:
    LDA #$09                     ; RST=1, CS=0, CP=0, DA=1
    STA PORTA
    NOP
    LDA #$0D                     ; Clock High
    STA PORTA
@next_bit:
    DEX
    BNE @bit_loop
    PLX
    RTS

; ------------------------------------------------------------------------------
; VFD_CLEAR
; Clears character memory (DCRAM) with ASCII spaces ($20) and symbol memory (ADRAM).
; ------------------------------------------------------------------------------
VFD_CLEAR:
    ; 1. Clear DCRAM_B (Top Row 1 = 0x90) with Space ($20)
    LDA #$05                     ; CS Low
    STA PORTA
    LDA #$90
    JSR VFD_SEND_BYTE
    LDA #$00                     ; Address 0x00
    JSR VFD_SEND_BYTE
    LDX #16
    LDA #$20                     ; ASCII Space
@cl1:
    JSR VFD_SEND_BYTE
    DEX
    BNE @cl1
    LDA #$07                     ; CS High
    STA PORTA
    JSR VFD_DELAY_1MS

    ; 2. Clear DCRAM_A (Bottom Row 2 = 0x10) with Space ($20)
    LDA #$05                     ; CS Low
    STA PORTA
    LDA #$10
    JSR VFD_SEND_BYTE
    LDA #$00
    JSR VFD_SEND_BYTE
    LDX #16
    LDA #$20                     ; ASCII Space
@cl2:
    JSR VFD_SEND_BYTE
    DEX
    BNE @cl2
    LDA #$07                     ; CS High
    STA PORTA
    JSR VFD_DELAY_1MS

    ; 3. Clear ADRAM_B (Top Row Symbols = 0xB0)
    LDA #$05                     ; CS Low
    STA PORTA
    LDA #$B0
    JSR VFD_SEND_BYTE
    LDA #$00                     ; Address 0x00
    JSR VFD_SEND_BYTE
    LDX #20                      ; Cover all 20 locations
    LDA #$00
@cl3:
    JSR VFD_SEND_BYTE
    DEX
    BNE @cl3
    LDA #$07                     ; CS High
    STA PORTA
    JSR VFD_DELAY_1MS

    ; 4. Clear ADRAM_A (Bottom Row Symbols = 0x30)
    LDA #$05                     ; CS Low
    STA PORTA
    LDA #$30
    JSR VFD_SEND_BYTE
    LDA #$00                     ; Address 0x00
    JSR VFD_SEND_BYTE
    LDX #20                      ; Cover all 20 locations
    LDA #$00
@cl4:
    JSR VFD_SEND_BYTE
    DEX
    BNE @cl4
    LDA #$07                     ; CS High
    STA PORTA
    JMP VFD_DELAY_1MS

; ------------------------------------------------------------------------------
; VFD_PRINT_INIT_STR
; ------------------------------------------------------------------------------
VFD_PRINT_INIT_STR:
    STX INDEX
    STY INDEX+1
    LDA VFD_ROW
    DEC                          ; Convert 1..2 to 0..1
    STA VFD_ROW
    STZ VFD_COL
    LDY #0
@p_loop:
    LDA (INDEX),Y
    BEQ @p_pad
    JSR VFD_DISP_CHAR
    INC VFD_COL
    LDA VFD_COL
    CMP #16
    BCS @p_done
    INY
    BRA @p_loop
@p_pad:
    ; Pad remaining line with spaces
    LDA VFD_COL
    CMP #16
    BCS @p_done
    LDA #$20
    JSR VFD_DISP_CHAR
    INC VFD_COL
    BRA @p_pad
@p_done:
    RTS

; ------------------------------------------------------------------------------
; Delay Routines (Calibrated for 2MHz Clock)
; ------------------------------------------------------------------------------
VFD_DELAY_1MS:
    PHX
    PHY
    LDY #4
@d1:
    LDX #100
@d2:
    DEX
    BNE @d2
    DEY
    BNE @d1
    PLY
    PLX
    RTS

VFD_DELAY_5MS:
    PHX
    PHY
    LDY #20
@d1:
    LDX #100
@d2:
    DEX
    BNE @d2
    DEY
    BNE @d1
    PLY
    PLX
    RTS

VFD_DELAY_100MS:
    PHX
    PHY
    LDY #200
@d1:
    LDX #200
@d2:
    DEX
    BNE @d2
    DEY
    BNE @d1
    PLY
    PLX
    RTS

.endif