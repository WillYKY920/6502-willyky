# 65C02 Computer on PCB

<img width="1080" height="662" alt="made-my-pcb-version-of-the-6502-computer-v0-0i04rzigg0fh1" src="https://github.com/user-attachments/assets/f2999c70-7f47-4d27-98b6-a30438679015" />

## Hardware Requirements
* 65C02 CPU
* 65C22 VIA
* 6551 ACIA
* AT28C256 ROM
* 62256 RAM
* 74HC00 NAND Gate
* NE555 Timer (Optional)
* LM386 Op-amp
* CIG25-1605N VFD
* LM1117 5V-to-3.3V

## Note
- The PCB and schamatics were drawn using EasyEDA Pro. Please open the downloaded .epro2 file on EasyEDA Pro.
- Replace all 10uF capacitor with an electrolytic capacitor.
- For those who wants to use the VIA timer as synthesizer to generate electronic music, the script for generating the masbasic program is in the /script/midi-converter with an example program. However, please note that the VIA synthesizer can only generate 2 voices at once. i.e a dual-channel synthesizer. If more than two sounds are played simultaneously, the remaining sounds will not be emitted.
