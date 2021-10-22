;  __  __     _      ___   ___    ___  
; |  \/  |   /_\    / __| | _ \  / _ \ 
; | |\/| |  / _ \  | (__  |   / | (_) |
; |_|  |_| /_/ \_\  \___| |_|_\  \___/ 
;
;--- MACROS ---

;--- MACRO Attendre le Blitter. 
;Quand la seconde opérande est une adresse, BTST ne permet de tester que les bits 7-0 de l'octet pointé, 
;mais traitant la première opérande comme le numéro du bit modulo 8, 
;BTST #14,DMACONR(a5) revient à tester le bit 14%8=6 de l'octet de poids fort de DMACONR, 
;ce qui correspond bien à BBUSY...

;Utilisation
;lea 	$DFF000,a5
;WAITBLIT

WAITBLIT:	MACRO
_waitBlitter0\@
	IFNE CST.DEBUG.CountWaitBlit
	;add.l	#1,CTRWait
	ENDC
	btst #6,DMACONR(a5)
	;bne _waitBlitter0\@
_waitBlitter1\@
	IFNE CST.DEBUG.CountWaitBlit
	add.l	#1,CTRWait
	ENDC
	btst #6,DMACONR(a5)
	bne _waitBlitter1\@
	IFNE CST.DEBUG.CountWaitBlit
	sub.l	#1,CTRWait
	ENDC
	ENDM


;Utilisation 
;AFFTEXTE 0,0,"Hello World" ;MACRO : x.car,y.car,"texte"

AFFTEXTE: MACRO	;\1=x.car, \2=y.car, \3="Texte" 
	move.l 	bitplaneB_ptr(pc),a2
	;add.l	#TAILLE_BITPLANE,a2
	lea		.txt\@(pc),a3
	add.l	#\2*40*8+\1,A2	;y*40*8+x (pas de 8 pix)
	bsr		AfficherTexte8x8	;d0,A0,A2,A3 utilisés
	bra		.finTxt\@
.txt\@:
	dc.b	\3,0
	even	
.finTxt\@:
	ENDM	
	