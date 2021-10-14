DebugPosY = 76 ;76 affiche OK, 77 aff KO

;Comment/uncomment to unactivate/activate
DEBUGDISPLAY_TIME = 0		;=0	;COUT=2 HBL	;affiche le compteur de rater
DEBUGDISPLAY_RASTER	= 0 	;affiche la couleur raster rouge/vert
CTR=1					;count waitblit and put value in CTRWAIT:

;	incdir	"sources:sinescroll/"


; IFC Conditional Assembly String Equality Test.
; IFDEF Conditional Assembly Symbol Definition Test.
; IFEQ Conditional Assembly Equal to Zero Test.
; IFGE Conditional Assembly Nonnegative Test.
; IFGT Conditional Assembly Greater than Zero Test.
; IFLE Conditional Assembly Nonpositive Test.
; IFLT Conditional Assembly Less than Zero Test.
; IFNC Conditional Assembly String Inequality Test.
; IFNDEF Conditional Assembly Symbol Not Defined Test.
; IFNE Conditional Assembly Unequal to Zero Test. 

;References :
;Reprise architecture de Yragael / Stash of Code (http://www.stashofcode.fr)
;
;contient le fichier Font8 :
;https://www.stashofcode.fr/code/coder-un-sine-scroll-sur-amiga/sinescroll.zip
;
;Textes paragraphes 
;https://www.topster.fr/texte-ascii/ivrit.html
;

;--- Gestion de CONF ---
;Arnaud.68000
;2021-08-17	début


	SECTION Arnaud.68000,CODE_F

;Comment/uncomment to unactivate/activate
AffTexteFixe=0			;COUT=37 HBL environ	;texte fixe
EffacerBitPlaneCache=0	;COUT=43 HBL 		;3eme Bitplane



;position du centre objet. rayon maxi 92 pix  equ  sqr(3*53^2), coins max 53,53,53
RayonMaxi 	equ 96		;doit tre un miltiple de 8 pix, utilisé pour RAZ au blitter
offsetX 	equ 160		;min 87, maxi 232
offsetZ 	equ 100		;min 87, maxi 168  87=sqr(50^2+50^2+50^2) coin max (50,50,50)


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


;Programme

DISPLAY_DEPTH=1
DISPLAY_DX=320
DISPLAY_DY=256
BITPLANE_DX = DISPLAY_DX
BITPLANE_DY=256+32
DISPLAY_X=$81
DISPLAY_Y=$2C

TAILLE_BITPLANE=((BITPLANE_DX*BITPLANE_DY)>>3)



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

WAITBLIT:	MACRO
_waitBlitter0\@
	IFNE CTR
	;add.l	#1,CTRWait
	ENDC
	btst #6,DMACONR(a5)
	;bne _waitBlitter0\@
_waitBlitter1\@
	IFNE CTR
	add.l	#1,CTRWait
	ENDC
	btst #6,DMACONR(a5)
	bne _waitBlitter1\@
	IFNE CTR
	sub.l	#1,CTRWait
	ENDC
	ENDM


;AFFTEXTE 0,0,"Hello World" ;MACRO : x,y,"texte"
	
AFFTEXTE: MACRO	;\1=x.car, \2=y.car, \3="Texte" 
	move.l 	bitplaneB(pc),a2
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
	
	

	
	

       
;  ___          _             _   
; |   \   ___  | |__   _  _  | |_ 
; | |) | / -_) | '_ \ | || | |  _|
; |___/  \___| |_.__/  \_,_|  \__|
;                                 
;---------- Initialisations ----------

Debut:


	movem.l d0-d7/a0-a6,-(SP) ;Empiler les registres
	
	lea 	$DFF000,a5
	movea.l	$4.w,a6
	bsr.w		ReserverMemoireCHIP
	bsr.w		CouperHardware
	bsr.w		InitiliserCopperList
	bsr.w		CreerPolice16x16
	
	
;  _                       
; | |     ___   ___   _ __ 
; | |__  / _ \ / _ \ | '_ \
; |____| \___/ \___/ | .__/
;                    |_|   		
;---------- Boucle principale ----------


_loop:
	
	lea 	$DFF000,a5
	
	
	IFNE CTR
	move.l	#0,CTRWait
	ENDC
	

;--- Attendre que le faisceau d'électrons a terminé de tracer l'écran
_waitVBL:
	move.l VPOSR(a5),d0
	lsr.l #8,d0
	and.w #$01FF,d0
	cmp.w #DISPLAY_Y+DISPLAY_DY,d0
	blt.s _waitVBL
	
	IFNE DEBUGDISPLAY_RASTER
	move.w #$0F00,COLOR00(a5)	;si DEBUG on passe en rouge la couleur du fond
	ENDC



;----- PERMUTER LES BITPLANE ----------
	;Permuter circulairement les bitplanes : A(à afficher) --> C(à effacer) --> B(à construire) --> A
	move.l bitplaneA(pc),d0
	move.l bitplaneB(pc),d1
	move.l bitplaneC(pc),d2
	move.l d1,bitplaneA	;Bitplane Affiché
	move.l d2,bitplaneB	;Bitplane en construction
	move.l d0,bitplaneC ;Bitplane en effacement



; CMP A,B 	Entier (signé) 	Naturel(non signé)
; A >  B 		BLT 	BLO (ou BCS)
; A >= B 		BLE 	BLS
; A =  B 		BEQ 	BEQ
; A <> B 		BNE 	BNE
; A <  B 		BGT 	BHI
; A <= B 		BGE 	BHS (ou BCC)


;----- Incremente Position affichage
	moveq.l	#0,d1
	move.w	AffLigneY,d1
	bra Calcul_sens_haut
	
Calcul_sens_bas:
	;--- Sens descente
	subq	#1,d1
	bne		.pasFin	;tester si <0
	move.w	#BITPLANE_DY,d1
.pasFin:
	bra 	fin_calcul_sens
		
Calcul_sens_haut:
	;--- Sens montée 
	addq	#1,d1
	cmp.w	#BITPLANE_DY,d1
	bls		.pasFin
	moveq.l	#0,d1
.pasFin:

	
fin_calcul_sens:
	
	;move.w	#DebugPosY,d1 ;DEBUG fixe ecran ----------------------------
	move.w	d1,AffLigneY
	
;----- Calcul Position affichage
	;d1 = d0 + AffLigneY * (BITPLANE_DX / 8)
	mulu	#BITPLANE_DX>>3,d1
	add.l	d0,d1
	

;----- AFFICHER BitPlaneA VIA COPPERLIST ----------
	;ecriture des adresses bitplane dans la copperlist
	movea.l	Copperlist_BitPlanes_PTR(pc),a0
aff:	
	;Bitplane0
	move.w 	d1,2(a0)
	swap 	d1
	move.w 	d1,6(a0)
	
	IFGE DISPLAY_DEPTH-2
	;Bitplane1
	swap 	d1
	add.l	#TAILLE_BITPLANE,d1
	move.w	d1,10(a0)	
	swap 	d1
	move.w	d1,14(a0)
	ENDC
	
	IFGE DISPLAY_DEPTH-3
	;Bitplane2
	swap 	d1
	add.l	#TAILLE_BITPLANE,d1
	move.w	d1,18(a0)
	swap 	d1
	move.w	d1,22(a0)
	ENDC
	

;---- Affiche partie 2 (partie basse pointant sur le début du btplane)
	;wait ligne (BITPLANE_DY - AFFLigneY) si < DISPLAY_DY

	
; CplBitPlanesPart2:
	; dc.w $FFE1,$FFFE ;wait V7...V0 H8...H2 1,BCB BMV6...BMV0 BMH8...BMH2 0
	; dc.w BPL1PTL,0,BPL1PTH,0
	movea.l	Copperlist_BitPlanes_PTR(pc),a0
	add.l	#CplBitPlanesPart2-CplBitPlanes,a0
	
	
	moveq.l	#0,d1
	move.w	#BITPLANE_DY,d1	;288
	sub.w	AffLigneY,d1	;288-y
	sub.w	#1,d1
	
	cmp.w	#DISPLAY_DY,d1 	;256,d1
	blo		.EcranTronque	;si d1 < DISPLAY_Y (non signé)
	
	;pas trounqué
	;moveq.l	#$00,d1	;$00E1,$FFFE
	move.l	#$01FE0000,(A0)+	;Copper NOP
	move.l	#$01FE0000,(A0)+	;Copper NOP
	move.l	#$01FE0000,(A0)+	;Copper NOP
	move.l	#$01FE0000,(A0)		;Copper NOP
	bra		.fin
.EcranTronque:

	move.w	d1,Debug1	;***************************** DEBUG
	
	;DISPLAY_Y
	;-- Ajout décalage position DISPLAY_Y
	add.w	#DISPLAY_Y,d1
	move.w	d1,Debug2	;***************************** DEBUG
	
	cmp.w	#255,d1	;on depasse les 255
	blo		.pasWait
		;mettre un wait 255
		move.l	#$FFE1FFFE,(A0)+	;Copper NOP
		sub.w	#$FF+1,d1

		bra		.FinWait
.pasWait:
	move.l	#$01FE0000,(A0)+
.FinWait:
	lsl.w	#8,d1		;(288-y) sur poid fort (V7..V0)
	add.w	#$E1,d1		;ajout de $E1 (H8...H2 1)
	move.w	d1,Debug3	;***************************** DEBUG
	move.w	d1,(a0)+	;dc.w $xxE1,$FFFE
	move.w	d1,Debug4 ;***************************** DEBUG
	move.w	#$FFFE,(a0)+
	
	;add.l	4,a0
	move.l 	bitplaneA(pc),d1
	move.w	#BPL1PTL,(A0)+
	move.w 	d1,(a0)+
	swap 	d1
	move.w	#BPL1PTH,(A0)+
	move.w 	d1,(a0)
.fin:


	bra	sauteDebug ;***************************** DEBUG
	Debug:
	Debug1:	dc.w	0
	Debug2:	dc.w	0
	Debug3:	dc.w	0
	Debug4:	dc.w	0
	
sauteDebug:
	
	IFNE AffTexteFixe
	AFFTEXTE 0,0,"Scroll - Arnaud - 2021-09-28" ;MACRO : x,y,"texte"
	AFFTEXTE 0,1,"Amiga68000@gmail.com" ;MACRO : x,y,"texte"	;(pc)	;cout 37 HBL
	ENDC




	
	
	movem.l d0-d7/a0-a6,-(sp)
	
	; ;--- TRACER LIGNE PLEINE AU BLITTER	
	; ;Entree (d0=x1,d1=y1,d2=x2,d3=y2, a1=adresse du bitplane)
	; move.l	bitplaneB(pc),a1
	; move.l	#100,d0
	; move.l	#100,d1
	; move.l	#200,d2
	; move.l	#200,d3
	; bsr.w	TracerLignePleine

	movem.l (sp)+,d0-d7/a0-a6




		

;--- EFFACER LE BITPLANE CACHE -------------------
	IFNE EffacerBitPlaneCache
	
	;--- Efface dans Bitplane C
		
	;jsr		Effacer_BitPlaneC(pc)
	bsr.w		Effacer_BitPlaneC0	;(pc)
	bsr.w		Effacer_BitPlaneC1	;(pc)
	bsr.w		Effacer_BitPlaneC2	;(pc)

	
	ENDC
	
	
	
	
	
;--- AFFICHE LE FAISCEAU EN VERT
	IFNE DEBUGDISPLAY_RASTER
	move.w	#$00F0,COLOR00(a5)
	ENDC
	
	
;********** DEBUGDISPLAYTIME (start) **********
	;affiche en décimal le nombre de lignes écoulées depuis la fin de l'écran (depuis la ligne DISPLAY_Y+DISPLAY_DY incluse)
	;la trame se termine en DISPLAY_Y+DISPLAY_DY-1
	;le temps est donc compté en nombre de ligne à partir de DISPLAY_Y+DISPLAY_DY incluse
	IFNE DEBUGDISPLAY_TIME
	movem.l	d0-d2/a0-a3,-(sp)

	move.l	VPOSR(a5),d0
	lsr.l	#8,d0
	and.w	#$01FF,d0
	cmp.w	#DISPLAY_Y+DISPLAY_DY,d0
	bge.s 	_timeBelowBitplanes
	;on est passé en haut de l'écran
	add.w 	#1+312-(DISPLAY_Y+DISPLAY_DY-1),d0	;312 est la ligne la plus basse que peut trace le faisceau d'électrons
	bra.s 	_timeDisplayCounter
_timeBelowBitplanes:
	;on est toujours en bas de l'écran
	sub.w	#DISPLAY_Y+DISPLAY_DY-1,d0
 _timeDisplayCounter:
	movea.l	bitplaneB(pc),a1
	lea 	24*(DISPLAY_DX>>3)(a1),a1

	bsr.s	AFficherNombre	;(pc)	;D0=nombre 9999, A1=ptr 

	movem.l	(sp)+,d0-d2/a0-a3
	ENDC
	
	


;--- SOURIS PRESSEE ?
TestClicDroit;
	btst 	#10,$dff016 ; test RIGHT mouse click
	bne.s		TestClicGauche
	;-- clic droit enfoncé
	
	
.loopCG:
	;-- clic droit non laché
	btst 	#10,$dff016 ; test RIGHT mouse click
	beq		.loopCG	
	;-- clic droit laché
	

	bra.w 	_loop
	
TestClicGauche:		

	btst	#6,$bfe001
	bne.w	_loop
	;-- clic Gauche enfoncé
	
	
;  ___   _        
; | __| (_)  _ _  
; | _|  | | | ' \ 
; |_|   |_| |_||_|	
;	
;--- ON QUITTE ------------
	
_loopEnd:	
	WAITBLIT
	bsr.w	RestaurerHardware
	bsr.w	LibererMemoireCHIP
ErrorMem:
	movem.l (sp)+,d0-d7/a0-a6	;Dépiler les registres
	rts


AffLigneY:	dc.w	BITPLANE_DY	;0 .. 287


AFficherNombre:
	;=>d0.w = #nombre 9999 max à afficher
	and.l	#$0000FFFF,d0	;nombre à afficher
	moveq	#0,d1
	moveq	#3-1,d2	;4 digits
.blcConvert:
		divu	#10,d0		;=> d0=reste:quotient de la division de d0 sur 32 bits
		swap	d0
		add.b	#$30-$20,d0	;code ASCII "0" moins l'offset de début dans font8 ($20)
		move.b	d0,d1
		lsl.l	#8,d1
		clr.w	d0
		swap	d0
	dbf 	d2,.blcConvert
	divu 	#10,d0		;=> d0=reste:quotient de la division de d0 sur 32 bits
	swap 	d0
	add.b	#$30-$20,d0	;code ASCII de "0" moins l'offset de début dans font8 ($20)
	move.b	d0,d1
	;d1 = suite des 4 offsets ASCII dans la police des 4 chiffres à afficher
	;     mais en sens inverse (ex: 123 => "3210")
	lea 	font8(pc),a0
	moveq 	#4-1,d0
.timeLoopDisplay:
		clr.w 	d2
		move.b 	d1,d2
		lsl.w 	#3,d2
		lea 	(a0,d2.w),a2
		move.l 	a1,a3
		moveq	#8-1,d2
.timeLoopDisplayChar:
			move.b	(a2)+,(a3)
			lea 	DISPLAY_DX>>3(a3),a3
		dbf 	d2,.timeLoopDisplayChar
		lea 	1(a1),a1
		lsr.l	#8,d1
	dbf	d0,.timeLoopDisplay
	rts

	

;  ___   _   _   ___         ___                _     _                   
; / __| | | | | | _ )  ___  | _ \  ___   _  _  | |_  (_)  _ _    ___   ___
; \__ \ | |_| | | _ \ |___| |   / / _ \ | || | |  _| | | | ' \  / -_) (_-<
; |___/  \___/  |___/       |_|_\ \___/  \_,_|  \__| |_| |_||_| \___| /__/
;                                                                         



;--- TIRER DES NOMBRES ALEATOIRES

Aleatoire1A6:	;D0=1..6 ; d0, d1, d2
	bsr.s		_RandomByte
	;bit 0 (0 ou 1)
	move.b	d0,d1
	and.w	#%0001,d1
	;bit 1 (0 ou 1)
	move.b	d0,d2
	and.w	#%0010,d2
	lsr.w	#1,d2
	add.w	d2,d1
	;bit 2 et 3 (0 à 3)
	and.w	#%1100,d0
	lsr.w	#2,d0
	add.w	d1,d0
	;on ajoute 1
	addq.w	#1,d0
	rts


_RandomWord:
	bsr.s	_RandomByte
	rol.w   #8,d0
_RandomByte:
	move.b  $dff007,d0
	move.b  $bfd800,d1
	eor.b   d1,d0
	rts






;  _____ 
; |_   _|
;   | |  
;   |_|  TRACER AU BLITTER
;        



TracerLignePleine:
	;--- TRACER LIGNE PLEINE AU BLITTER	
	;Entree (d0=x1,d1=y1,d2=x2,d3=y2, a1=adresse du bitplane)
	;utilisés en lecture : a1, a5
	;        en écriture : d0..d6, a0, a1, a2

	move.l	a1,a2	;Bitplane
	
	; ------------------------------
	; BIT# BLTCON0     BLTCON1
	; ---- -------     -------
	; 15   START3      TEXTURE3
	; 14   START2      TEXTURE2
	; 13   START1      TEXTURE1
	; 12   START0      TEXTURE0
	; 11    1              0
	; 10    0              0
	; 09    1              0
	; 08    1              0
	; 07   LF7             0
	; 06   LF6            SIGN
	; 05   LF5             0 (Reserved)
	; 04   LF4            SUD
	; 03   LF3            SUL
	; 02   LF2            AUL
	; 01   LF1            SING
	; 00   LF0            LINE(=1) = LINE DRAW 
	
	;---- Calculer Octant ----
	moveq.l	#0,d4	;4 cycles
	sub.w	d1,d3	;d3=dy=y2-y1
	bpl.b	y2_sup_y1
	bset	#2,d4	;8 cycles
	neg.w	d3		;d3=abs(dy)
y2_sup_y1:
	sub.w	d0,d2	;d2=dx=x2-x1
	bpl.b	x2_sup_x1
	bset	#1,d4	
	neg.w	d2		;d2=abs(dx)
x2_sup_x1:
	cmp.w	d3,d2	;D3=dy vs D2=dx	
	bpl.b	dX_sup_dY
	bset	#0,d4
	exg		d2,d3
dX_sup_dY:
	move.b	(a0,d4),d5	;octant dans D5
	;d0=x1, d1=y1
	;d2=dx=GRAND DELTA, d3=dy=petit delta
	;d5=octant
	;--- Calculer Adresse de départ ----
	ror.l   #4,d0   ;move upper four bits into hi word
    add.w	d0,d0	;d0=d0*2 car d0 contient le nb de mots --> devient nb d'octets
	add.l	d0,a2	;bitplaneB+x1/8 modulo 16 pix (l'adressage étant sur 24 bits les 4 bits HI n'influent pas)
	lsl.w	#3,d1	;d1=y1*8
	add.w	d1,a2	;A2=bitplaneB+(x1/8)+y1*8
	add.w	d1,d1	;d1=y1*16
	add.w	d1,d1	;d1=y1*32
	add.l	d1,a2	;a2=bitplaneB+(x1/8)+y1*40 = adresse de départ	

	moveq.l	#0,d6	;RAZ d6
	add.w   d3,d3	;d3=dy*2
    add.w   d3,d3	;d3=dy*4	;;lsl.w	#2,d3		;10 cycles
	move.w	D3,D4	;D4=4*dy
	
	move.w	d2,d1	;d1=d2=dX 
	
	add.w	#$01,d2	;dx+1
	lsl.w	#6,d2	;(dx+1)*64 ; 20 cycles
	add.w	#$02,d2	;(dx+1)*64+2
	
	add.w	d1,d1	;lsl.w	#1,d1	;D1=2*dx
	sub.w	d1,D3	;| d3=4*dy - 2*dx
	roxl.w	#7,D6	;| si D3<0, placer le bit SIGN à 1 dans BLTCON1 
	add.w	d1,d1	;D1=2*2dx
	
	or.w	d6,d5	;%xxxx000000xxxx01 ;bit 1 = 1 point par ligne 
					;dans Tableoctant pour éviter bset #1,d5
	swap	d0
	or.w	d6,D0	
	or.w	#$0BCA,D0
	WAITBLIT
	;move.l	d0,BLTCON0(A5)	;TODO voir si gain de charger BLTCON0 et CON1 en meme temps
	move.w	d0,BLTCON0(A5)	;bits 15,14,13,12  = point de départ de la droite
	move.w	d5,BLTCON1(A5)	;bits 15,14,13, 12  = point de départ de la droite
	move.w	d4,BLTBMOD(A5)	;=4*dy
	move.l	d3,BLTAPTH(A5)	;=4*dY-2*dX, 
	sub.w	d1,D4			;d4=4*dy-4*dx
	move.w	d4,BLTAMOD(A5)	;=4*dy-4*dx
	move.l	a2,BLTCPTH(A5)	;adresse du point de départ de la droite
	move.l	a2,BLTDPTH(A5)	;idem
	move.w	d2,BLTSIZE(A5)	;c'est parti = (dX+1)*64+2
	rts	
TableOctant:	;3 premiers bits=octant, bit1 = 1 si 1 pt /ligne, bit 0=1 mode tracé de ligne
	dc.b	%10001
	dc.b	%00001
	dc.b	%10101
	dc.b	%01001
	dc.b	%11001
	dc.b	%00101
	dc.b	%11101
	dc.b	%01101
	even




;--- EFFACER BITPLANE C	-------------------
	
OffsetOctetRAZBLT=(((offsetZ-RayonMaxi)*DISPLAY_DX)+(offsetX-RayonMaxi))/8

Effacer_BitPlaneC:
	;--- effacement complet (152 HBL)
	; move.w	#0,BLTDMOD(a5)
	; move.w	#$0000,BLTCON1(a5)
	; move.w	#%0000000100000000,BLTCON0(a5)
	; move.l	bitplaneC,BLTDPTH(a5)
	; move.w	#(DISPLAY_DX>>4)!(DISPLAY_DY<<6),BLTSIZE(a5)
	bsr.s		Effacer_BitPlaneC0	;(pc)
	bsr.s		Effacer_BitPlaneC1	;(pc)
	bsr.w		Effacer_BitPlaneC2	;(pc)
	rts
	
	;--- Effacement selectif = rubiks seul
	;RayonMaxi=92
	;offsetX=160
	;offsetZ=100
	;TAILLE_BITPLANE=((DISPLAY_DX*DISPLAY_DY)>>3)
	
Effacer_BitPlaneC0:
	move.l	bitplaneC(pc),a0
	WAITBLIT
	move.w	#$0000,BLTCON1(a5)
	move.w	#%0000000100000000,BLTCON0(a5)
	lea		OffsetOctetRAZBLT(a0),a0	;adresse de départ
	move.l	a0,BLTDPTH(a5)
	move.w	#(display_DX-(RayonMAxi*2))/8,BLTDMOD(a5)
	move.w	#((RayonMaxi*2)>>4)!((RayonMaxi*2)<<6),BLTSIZE(a5)
	rts
Effacer_BitPlaneC1:	
	move.l	bitplaneC(pc),a0
	WAITBLIT
	move.w	#$0000,BLTCON1(a5)
	move.w	#%0000000100000000,BLTCON0(a5)
	lea		OffsetOctetRAZBLT+TAILLE_BITPLANE(a0),a0	;adresse de départ
	move.l	a0,BLTDPTH(a5)
	move.w	#(display_DX-(RayonMAxi*2))/8,BLTDMOD(a5)
	move.w	#((RayonMaxi*2)>>4)!((RayonMaxi*2)<<6),BLTSIZE(a5)
	rts
Effacer_BitPlaneC2:
	move.l	bitplaneC(pc),a0
	WAITBLIT
	move.w	#$0000,BLTCON1(a5)
	move.w	#%0000000100000000,BLTCON0(a5)
	lea		OffsetOctetRAZBLT+2*TAILLE_BITPLANE(a0),a0	;adresse de départ
	move.l	a0,BLTDPTH(a5)
	move.w	#(display_DX-(RayonMAxi*2))/8,BLTDMOD(a5)
	move.w	#((RayonMaxi*2)>>4)!((RayonMaxi*2)<<6),BLTSIZE(a5)
	rts





;--- Afficher un Texte 8x8 
;A2=adresse dans le bitplane
;A3=adresse du texte à afficher,0
;utilisé : d0, a0, a1
AfficherTexte8x8:	;conso 89 HBL
	lea		font8(pc),a1
.bcl:
	moveq.l	#0,d0
	move.b	(a3)+,d0	;on lit le caratère
.bcl2:
	sub.b	#$20,d0		;la table commence au caractère " "
	lsl.w	#3,d0		;8 octets / caractère
	lea		(a1,d0),a0	;a0=a1+d0
	moveq.l	#8-1,d0
.aff8x8:
	move.b	(A0)+,(A2)
	lea		(DISPLAY_DX>>3)(a2),a2	;ligne suivante
	dbf		d0,.aff8x8
	;fin de cara
	;sub.l	#(DISPLAY_DX>>3)*8-1,a2	;position car suivant
	lea     -((DISPLAY_DX>>3)*8-1)(a2),a2
	moveq.l	#0,d0
	move.b	(a3)+,d0	;on lit le caratère
	bne.s		.bcl2		;si 0 on est  la fin du texte
.fin:
	rts







;--- Reserver la memoire
TAILLE_FONT16 = 256<<5

ReserverMemoireCHIP:	
	;memoire font16
	move.l #TAILLE_FONT16,d0
	move.l #$10002,d1
	jsr AllocMem(a6)
	move.l d0,Font16_PTR
	rts

;--- Libérer la mémoire
LibererMemoireCHIP:
	;memoire font16
	movea.l 	Font16_PTR(pc),a1
	move.l 	#TAILLE_FONT16,d0
	jsr 	FreeMem(a6)
	rts


;--- Couper et Restaurer le Hardware
CouperHardware:
	;Couper le système multi-taches
	jsr Forbid(a6)
	;Couper le hardware
	move.w INTENAR(a5),intena_PTR
	move.w #$7FFF,INTENA(a5)
	move.w INTREQR(a5),intreq_PTR
	move.w #$7FFF,INTREQ(a5)
	move.w DMACONR(a5),dmacon_PTR
	move.w #$07FF,DMACON(a5)
	rts
RestaurerHardware:
	movea.l $4.w,a6
	;Couper le hardware
	move.w #$7FFF,INTENA(a5)
	move.w #$7FFF,INTREQ(a5)
	move.w #$07FF,DMACON(a5)
	;Rétablir le hardware
	move.w dmacon_PTR(pc),d0
	bset #15,d0
	move.w d0,DMACON(a5)
	move.w intreq_PTR(pc),d0
	bset #15,d0
	move.w d0,INTREQ(a5)
	move.w intena_PTR(pc),d0
	bset #15,d0
	move.w d0,INTENA(a5)
	;Rétablir la Copper list
	lea graphicslibrary(pc),a1
	jsr	OldOpenLibrary(a6) ;-408
	move.l d0,a1
	move.l 38(a1),COP1LCH(a5)
	clr.w COPJMP1(a5)
	jsr CloseLib(a6) ;-414
	;Rétablir le système multi-taches
	jsr Permit(a6) 
	rts

;--- Creer et activer la Copper list ----------
InitiliserCopperList:
	;copie les adresses des 3 premiers bitplanes dans copperlist
	moveq	#DISPLAY_DEPTH-1,d1
	move.l 	#bitplaneA,a0
	move.l	#CplBitPlanes,a1	;adresse de CplBitPlanes
	add.l	#2,a1
.l1:	
	move.l	(a0)+,d0	;adresse du pitplane
	move.w	d0,(a1)		;poids faible
	swap	d0	
	add.l	#4,a1
	move.w	d0,(a1)		;poids fort
	add.l	#4,a1
	add.l	#TAILLE_BITPLANE,a0 ;plan suivant du bitplaneA
	dbf		d1,.l1
	
	move.l	#CopListDataStart,COP1LCH(a5) ;
	clr.w 	COPJMP1(a5)
	move.w 	#$83C0,DMACON(a5)	;DMAEN=1, COPEN=1, BPLEN=1, COPEN=1, BLTEN=1
	rts


;---------- Création d'une police 16x16 à partir d'une police 8x8 ----------
CreerPolice16x16:
	;Préparer les données de la police
	;1er  octet = suite des bits 7 des 8 lignes / octets du caractère, 
	;2ème octet = suite des bits 6 des 8 lignes / octets du caractère, etc. 
	;rotation de -90°). 
	;Noter qu'au Blitter il faudra donc tracer les colonnes de la dernière à la première ligne 
	;du fait de l'orientation du motif.
	;il faudrait lui appliquer une symétrie d'axe Y avant pour tracer de la première à la dernière ligne
	lea 	font8(pc),a0
	move.l 	Font16_PTR(pc),a1
	move.w 	#256-1,d0
_fontLoop:
	moveq 	#7,d1		;
_fontLineLoop:
	clr.w 	d5
	clr.w 	d3
	clr.w 	d4
_fontColumnLoop:
	move.b 	(a0,d5.w),d2	;
	btst 	d1,d2		;on teste le bit D1
	beq.s 	_fontPixelEmpty
	bset 	d4,d3		;
	addq.b 	#1,d4
	bset 	d4,d3
	addq.b 	#1,d4
	bra.s 	_fontPixelNext
_fontPixelEmpty:
	addq.b 	#2,d4
_fontPixelNext:
	addq.b 	#1,d5
	btst 	#4,d4
	beq.s 	_fontColumnLoop
	move.w 	d3,(a1)+
	move.w 	d3,(a1)+
	dbf 	d1,_fontLineLoop
	lea 	8(a0),a0
	dbf 	d0,_fontLoop
	rts





;  _   _                               _     ___          _         
; | | | |  _ _    _  _   ___  ___   __| |   / __|  _  _  | |__   ___
; | |_| | | ' \  | || | (_-< / -_) / _` |   \__ \ | || | | '_ \ (_-<
;  \___/  |_||_|  \_,_| /__/ \___| \__,_|   |___/  \_,_| |_.__/ /__/
;

Assembly=0
	IFNE Assembly	;ne pas assembler


	ENDC



;  ___      _     _____     _   
; |   \    /_\   |_   _|   /_\  
; | |) |  / _ \    | |    / _ \ 
; |___/  /_/ \_\   |_|   /_/ \_\
;
;---------- Données ----------


;--- COMPTEUR WAITBLIT
	IFNE CTR
CTRWait:	dc.l	0
	ENDC
	
	
graphicslibrary:
	DC.B "graphics.library",0
	EVEN
font8:	
	INCBIN "font8.fnt"	;32 à 127
	EVEN

			
TEXT_POS:			dc.l	0
dmacon_PTR:			DC.w	0
intena_PTR:			DC.w	0
intreq_PTR:			DC.w	0
scrollColumn:		DC.W	0
scrollChar:			DC.W	0
angle:				DC.W	0
copperlist_PTR:		DC.L 	CopListDataStart
Copperlist_BitPlanes_PTR:	dc.l	CplBitPlanes
Font16_PTR:			DC.L 	0
bitplaneA:			DC.L 	ScreenA
bitplaneB:			DC.L 	ScreenB
bitplaneC:			DC.L 	ScreenC










	section	coplist,data_c

;   ___                                   _      _        _   
;  / __|  ___   _ __   _ __   ___   _ _  | |    (_)  ___ | |_ 
; | (__  / _ \ | '_ \ | '_ \ / -_) | '_| | |__  | | (_-< |  _|
;  \___| \___/ | .__/ | .__/ \___| |_|   |____| |_| /__/  \__|
;              |_|    |_|                                     
; Copper List

CopListDataStart:
	;Compatibilité ECS avec AGA
	dc.w	$0106,$0c00	; bplcon3
	dc.w	FMODE,0
	dc.w	$010C,$0011	; bplcon4
	;Configuration de l'écran
	;dc.w	DIWSTRT,$2c81,DIWSTOP,$2cc1
	;dc.w	DDFSTRT,$38,DDFSTOP,$d0
	; & = AND, ! = OR , ~ = EOR
	dc.w DIWSTRT,(DISPLAY_Y<<8)!DISPLAY_X ;$2c81	
	dc.w DIWSTOP,((DISPLAY_Y+DISPLAY_DY-256)<<8)!(DISPLAY_X+DISPLAY_DX-256) ;$2cc1
	dc.w DDFSTRT,((DISPLAY_X-17)>>1)&$00FC	;$0038
	dc.w DDFSTOP,((DISPLAY_X-17+(((DISPLAY_DX>>4)-1)<<4))>>1)&$00FC	;$00d0
	;Ce qui revient ((DISPLAY_X-17+DISPLAY_DX-16)>>1)&$00FC si DISPLAY_DX est multiple de 16
	
	dc.w BPLCON0,(DISPLAY_DEPTH<<12)!$0200
	dc.w BPLCON1,0
	dc.w BPLCON2,0
	dc.w BPL1MOD,0
	dc.w BPL2MOD,0

;Adresse des bitplanes

CplBitPlanes:
	dc.w BPL1PTL,0,BPL1PTH,0
	IFGE DISPLAY_DEPTH-2
	dc.w BPL2PTL,0,BPL2PTH,0
	ENDC
	IFGE DISPLAY_DEPTH-3
	dc.w BPL3PTL,0,BPL3PTH,0
	ENDC
	IFGE DISPLAY_DEPTH-4
	dc.w BPL4PTL,0,BPL4PTH,0
	ENDC
	IFGE DISPLAY_DEPTH-5
	dc.w BPL5PTL,0,BPL5PTH,0
	ENDC	
	IFGE DISPLAY_DEPTH-6
	dc.w BPL6PTL,0,BPL6PTH,0
	ENDC
	
	;wait
CplBitPlanesPart2:
	dc.w 	$FFE1,$FFFE ;wait V7...V0 H8...H2 1,BCB BMV6...BMV0 BMH8...BMH2 0
	dc.w 	$FFE1,$FFFE ;wait V7...V0 H8...H2 1,BCB BMV6...BMV0 BMH8...BMH2 0
	dc.w 	BPL1PTL,0
	dc.w	BPL1PTH,0
	
;Couleurs

	IFNE DEBUGDISPLAY_RASTER
	dc.w COLOR08,$F00		;Color8 pas utilisée, pour neutraliser de manière quelconque la modification de COLOR00...
	ELSE
	dc.w COLOR00,0
	ENDC
	dc.w COLOR01,$FFF	;SCROLL_COLOR
	; dc.w COLOR02,$F00	;rouge 
	; dc.w COLOR03,$0F0	;Vert
	; dc.w COLOR04,$00F	;bleu
	; dc.w COLOR05,$F0F	;
	; dc.w COLOR06,$FF0
	; dc.w COLOR07,$0FF
	


	dc.l 	-2	
	dc.l 	-2	

;CopListDataEnd:





;Bitplanes

	section	screen,bss_c

ScreenA	
	INCBIN "sources:Arn-Scroll/320x288x1p.bmp.bin"	;32 à 127
	EVEN
ScreenB 
	INCBIN "sources:Arn-Scroll/320x288x1p.bmp.bin"	;32 à 127
	EVEN
ScreenC 
	INCBIN "sources:Arn-Scroll/320x288x1p.bmp.bin"	;32 à 127
	EVEN
;ScreenA	ds.b	DISPLAY_DEPTH*TAILLE_BITPLANE
;ScreenB	ds.b	DISPLAY_DEPTH*TAILLE_BITPLANE
;ScreenC	ds.b	DISPLAY_DEPTH*TAILLE_BITPLANE
