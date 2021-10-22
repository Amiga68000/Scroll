;---- Librairies -----
ExecBase 		equ 4		;location of the exec.lib
OldOpenLibrary 	equ -408
OpenLib 		equ -552	;offset to the openLibrary function
OpenLibVersion 	equ 34		;minimum version to use
CloseLib 		equ -414	;offset to closeLibrary function
PutString 		equ -948	;offset to putStr() function
AllocMem		equ	-198
FreeMem			equ	-210
Forbid 			equ -132
Permit 			equ -138

;---- Registres -----
VPOSR 	equ $004
VHPOSR 	equ $006
INTENA 	equ $09A
INTENAR equ $01C
INTREQ 	equ $09C
INTREQR equ $01E
DMACON 	equ $096
DMACONR equ $002
BLTAFWM equ $044
BLTALWM equ $046
BLTAPTH equ $050
BLTAPTL equ $052
BLTCPTH equ $048
BLTDPTH equ $054
BLTAMOD equ $064
BLTBMOD equ $062
BLTCMOD equ $060
BLTDMOD equ $066
BLTADAT equ $074
BLTBDAT equ $072
BLTCON0 equ $040
BLTCON1 equ $042
BLTSIZE equ $058
DIWSTRT equ $08E
DIWSTOP equ $090
BPLCON0 equ $100
BPLCON1 equ $102
BPLCON2 equ $104
DDFSTRT equ $092
DDFSTOP equ $094
BPL1MOD equ $108
BPL2MOD equ $10A
BPL1PTH equ $0E0
BPL1PTL equ $0E2
BPL2PTH equ $0E4
BPL2PTL equ $0E6
BPL3PTH equ $0E8
BPL3PTL equ $0EA
BPL4PTH equ $0EC
BPL4PTL equ $0EE
BPL5PTH equ $0F0
BPL5PTL equ $0F2
BPL6PTH equ $0F4
BPL6PTL equ $0F6


COLOR00 equ $180
COLOR01 equ $182
COLOR02 equ $184
COLOR03 equ $186
COLOR04 equ $188
COLOR05 equ $18A
COLOR06 equ $18C
COLOR07 equ $18E
COLOR08	equ	$190
COP1LCH equ $080
COPJMP1 equ $088
FMODE 	equ $1FC
