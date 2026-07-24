.setcpu "65C02"
.debuginfo

.zeropage
                .org ZP_START0
READ_PTR:       .res 1
WRITE_PTR:      .res 1

.segment "SBUFF"
SBUFF:          .res $100

.segment "BIOS"

ACIA_DATA       = $5000
ACIA_STATUS     = $5001
ACIA_CMD        = $5002
ACIA_CTRL       = $5003

PORTB           = $6000
PORTA           = $6001

DDRB            = $6002
DDRA            = $6003

IFR             = $600D ; Interrupt Flag Register
T1LL            = $6006
T1LH            = $6007
LOAD:
                rts

SAVE:
                rts


; Input a character from the serial interface.
; On return, carry flag indicates whether a key was pressed
; If a key was pressed, the key value will be in the A register
;
; Modifies: flags, A
MONRDKEY:
CHRIN:
                LDA     ACIA_STATUS
                AND     #$08
                BEQ     @rxdelay
                LDA     ACIA_DATA
                JSR     CHROUT
                SEC
                RTS
@rxdelay:
                CLC
                RTS


; Output a character (from the A register) to the serial interface.
;
; Modifies: flags
MONCOUT:
CHROUT:
                PHA                    ; Save A.
                STA     ACIA_DATA      ; Output character.  
@txdelay:       
                LDA     ACIA_STATUS
                AND     #$10           ; check Rx buffer status flag
                BEQ     @txdelay        ; loop if Tx buffer is not empty
                PLA                    ; Restore A.
                RTS                    ; Return.

IRQ_HANDLER:
                PHA
                PHX
                
                ; 1. Check if a Timer 1 interrupt is actually pending
                LDA     IFR
                AND     #$40                ; Check Bit 6 (Timer 1 Flag)
                BEQ     @skip_sound         ; If T1 didn't cause this, skip
                
                ; 2. Check if Timer 1 interrupts are currently enabled
                LDA     IER
                AND     #$40                ; Is Bit 6 enabled?
                BEQ     @clear_t1_and_skip  ; If disabled, clear flag and skip!

                ; 3. Handle Duty-Cycle Audio
                LDA     PORTB
                BMI     @duty_high

                ; Load low Phase Duration
                LDA     DLC
                STA     T1LL
                LDA     DLC+1
                STA     T1LH                ; Writing T1LH clears T1 IFR flag
                JMP     @irq_exit    

@duty_high:     
                LDA     DHC
                STA     T1LL
                LDA     DHC+1
                STA     T1LH                ; Writing T1LH clears T1 IFR flag
                JMP     @irq_exit

@clear_t1_and_skip:
                LDA     T1CL                ; <--- READ T1CL TO CLEAR INTERRUPT FLAG!

@skip_sound:
                ; --- FUTURE EXPANSION ---

@irq_exit: 
                PLX
                PLA
                RTI

.include "wozmon.s"
.segment "RESETVEC"

.word   $0F00           ; NMI vector
.word   RESET           ; RESET vector
.word   IRQ_HANDLER     ; IRQ vector

