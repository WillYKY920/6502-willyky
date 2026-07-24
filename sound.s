.segment "CODE"
.ifdef EATER

T1CL            = $6004
T1CH            = $6005

ACR             = $600B
IER             = $600E

BEEP: ; BEEP(period, duration)
                JSR     FRMEVL
                JSR     MKINT
                ; Check if parameter is zero (frequency in Hz)
                LDA     FAC+4
                ORA     FAC+3
                BEQ     DURATION

                ; Convert uS to 2MHz CPU Cycles: Multiplied by 2
                ASL     FAC+4   ; Shift low byte left
                ROL     FAC+3   ; Rotate high byte left with carry

                ; Calculate timer count for the desired frequency
                LDA     FAC+4
                STA     T1CL
                LDA     FAC+3
                STA     T1CH
                ; Generate a square wave on pin PB7
                LDA     #$C0
                STA     ACR

                JMP     DURATION ; get second parameter (duration in ms)

SYNTH: ; SYNTH(V1_HalfPeriod, V2_HalfPeriod, Duration)
                LDA     #$40    ; Bit 7 is 0 (Disable mode), Bit 6 is 1 (Timer 1)
                STA     IER     ; Turn off Timer 1 interrupts for 2-Voice mode

                JSR     FRMEVL  ; Parse first parameter (Voice 1)
                JSR     MKINT
                
                ; Check if Voice 1 is 0 (rest)
                LDA     FAC+4
                ORA     FAC+3
                BEQ     @skip_v1

                ; Convert uS to 2MHz CPU Cycles: Multiply by 2
                ASL     FAC+4   
                ROL     FAC+3   

                ; Load Timer 1 
                LDA     FAC+4
                STA     T1CL
                LDA     FAC+3
                STA     T1CH

                ; Enable T1 Continuous Square Wave on PB7
                LDA     #$C0
                STA     ACR
                JMP     @parse_v2

@skip_v1:
                LDA     #$00
                STA     ACR     ; Disable PB7 hardware toggle if V1 is 0

@parse_v2:
                JSR     CHKCOM  ; Check for comma separating params
                JSR     FRMEVL  ; Parse second parameter (Voice 2)
                JSR     MKINT
                
                ; Check if Voice 2 is 0
                LDA     FAC+4
                ORA     FAC+3
                BEQ     DURATION

                ; Convert uS to 2MHz CPU Cycles: Multiply by 2 
                ASL     FAC+4
                ROL     FAC+3

                ; Store Voice 2 values in temporary zero-page memory (reusing DLC)
                LDA     FAC+4
                STA     DLC
                LDA     FAC+3
                STA     DLC+1

                ; Set PB6 to Output Mode in DDRB (Address $6002)
                LDA     $6002
                ORA     #$40
                STA     $6002

                ; Load Timer 2 Latch (T2CL = $6008, T2CH = $6009)
                LDA     DLC
                STA     $6008
                LDA     DLC+1
                STA     $6009

DURATION:
                JSR     CHKCOM  ; Check for final comma
                JSR     GETBYT  ; Duration placed into X register
                
                CPX     #$00
                BEQ     DONE
                
@delay1:
                LDY     #$FF
@delay2:
                ; --- SOFTWARE POLL FOR TIMER 2 (VOICE 2 on PB6) ---
                LDA     $600D   ; Read Interrupt Flag Register (IFR)
                AND     #$20    ; Check Timer 2 flag (Bit 5)
                BEQ     @no_t2_toggle
                
                ; Timer 2 triggered! Toggle PB6
                LDA     $6000   ; Read ORB
                EOR     #$40    ; Flip Bit 6
                STA     $6000   ; Write ORB
                
                ; Reload T2CH to clear the IFR flag and restart Timer 2
                LDA     DLC+1
                STA     $6009
                
@no_t2_toggle:
                ; Delay padding to perfectly match your original loop's timing
                ; This ensures the 2.17 division in the Python script remains perfectly accurate
                NOP
                NOP

                DEY
                BNE     @delay2
                DEX
                BNE     @delay1        

DONE:           
                ; Stop Timer 1 square wave and reset ACR
                LDA     #$00
                STA     ACR
                
                ; Pull PB6 Low to prevent DC drain on the speaker
                LDA     $6000
                AND     #$BF
                STA     $6000
                
                ; Reset IER (From your original file)
                LDA     #$40
                STA     IER
                
                RTS

PULSE: ; PULSE(t_DutyHigh, t_DutyLow)
                JSR     FRMEVL  ; parse first parameter
                JSR     MKINT
                ; Check if first parameter (t_dutyHigh) is zero 
                LDA     FAC+4
                ORA     FAC+3
                BEQ     DONE

                ASL     FAC+4   ; Shift low byte left
                ROL     FAC+3   ; Rotate high byte left with carry

                ; Calculate timer count for the desired frequency
                SEC             ; Set carry flag before subtraction
                LDA     FAC+4   ; Load low byte
                SBC     #2      ; Subtract 2
                STA     DLC+1
                LDA     FAC+3
                STA     DLC

                JSR     CHKCOM  ; check for second parameter (t_dutyLow)
                JSR     FRMEVL  ; parse second parameter
                JSR     MKINT   ; convert second parameter to integer
                
                ASL     FAC+4   ; Shift low byte left
                ROL     FAC+3   ; Rotate high byte left with carry

                SEC             ; Set carry flag before subtraction
                LDA     FAC+4   ; Load low byte
                SBC     #2      ; Subtract 2 
                STA     DHC+1
                LDA     FAC+3
                STA     DHC

                ; Generate a square wave on pin PB7
                LDA     #$C0
                STA     ACR
                STA     IER

                LDA     DLC+1
                STA     T1CL
                LDA     DLC
                STA     T1CH

                RTS

.endif
