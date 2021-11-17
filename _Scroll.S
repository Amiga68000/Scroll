;
; SCROLLING USING VIDEO POINTER
; Arnaud FBY
;
;--- GESTION DE CONF ---
;2021-10-12	début
;2021-10-25 scrolling avec Tiles
;2021-11-10 Scrolling 1 bitplane


;--- TODO
;séquenceur TILES  = f(position 65535)
;séquenceur OBJETS = f(position 65535)
;scrolling horizontal 
;passer en 32 couleurs
;affichage BOB 32x32 en x,y au blitter
;affichage BOB 32x32 en x,y au CPU
;affichage BOB 16x16 en x,y au blitter
;affichage BOB 16x16 en x,y au CPU
;affichage BOB 8x8 en x,y au blitter
;affichage BOB 8x8 en x,y au CPU
;LIFO restauration background pour les BOB
;gestion d'objets (BOB) : déclenchement, trajectoire, comportement, fin de vie
;gestion collisions
;gestion interface joystick
;gestion clavier
;afficher les sprites
;Gain cycles : organiser les Data TILES à la suite (et pas en matrice)



;--- CONFIGURATION
CST.DEBUG.DisplayTime = 1		;=0	;COUT=2 HBL	;affiche le compteur de rater
CST.DEBUG.DisplayRaster	= 1 	;affiche la couleur raster rouge/vert
CST.DEBUG.CountWaitBlit=1		;count waitblit and put value in CTRWAIT:
CST.DEBUG.AfficherVariables = 0	;COUT=60 HBL

CST_Scroll_PasAPas = 0		;1 : step by step with right button
CST_Scroll_PosYInit = 0		;starting position? bug=138
CST_Scroll_Sens = 0 		;0 bas, 1 haut

CST.RUN.AfficherTexteFixe = 0		;COUT=37 HBL environ	;texte fixe
CST.RUN.EffacerBitPlaneCache = 0	;COUT=43 HBL 		;3eme Bitplane

	incdir	"Arn-Scroll/"

;--- REFERENCES
;Architecture de Yragael http://www.stashofcode.fr
;Font8 de Yragael https://www.stashofcode.fr/code/coder-un-sine-scroll-sur-amiga/sinescroll.zip
;Textes paragraphes https://www.topster.fr/texte-ascii/ivrit.html


;--- DOC

;http://obligement.free.fr/articles/assembleur_programmation_blitter.php

; CMP A,B 	Entier (signé) 	Naturel(non signé)
; A >  B 		BLT 	BLO (ou BCS)
; A >= B 		BLE 	BLS
; A =  B 		BEQ 	BEQ
; A <> B 		BNE 	BNE
; A <  B 		BGT 	BHI
; A <= B 		BGE 	BHS (ou BCC)

; CONDITION D ASSEMBLAGE
; IFEQ Assemble if expression = zero 
; IFNE Assemble if expression <> zero 
; IFGT Assemble if expression > zero 
; 1FGE Assemble if expression >= zero 
; IFLT Assemble if expression < zero 
; IFLE Assemble if expression <= zero 
; ENDC


;--- BLITTER
; 			AREA MODE 			LINE MODE
; Bit 		BLTCON0 BLTCON1 Bit BLTCON0 BLTCON1
; 15 		ASH3 	BSH3 	15 	ASH3 	BSH3
; 14 		ASH2 	BSH2 	14 	ASH2 	BSH2
; 13 		ASH1 	BSH1 	13 	ASH1 	BSH1
; 12 		ASA0 	BSH0 	12 	ASH0 	BSH0
; 11 		USEA 	0 		11 	1 		0
; 10 		USEB 	0 		10 	0 		0
; 09 		USEC 	0 		09 	1 		0
; 08 		USED 	0 		08 	1 		0
; 07 		LF7 	DOFF 	07 	LF7 	DPFF
; 06 		LF6 	0 		06 	LF6 	SIGN
; 05 		LF5 	0 		05 	LF5 	OVF
; 04 		LF4 	EFE 	04 	LF4 	SUD
; 03 		LF3 	IFE 	03 	LF3 	SUL
; 02 		LF2 	FCI 	02 	LF2 	AUL
; 01 		LF1 	DESC 	01 	LF1 	SING
; 00 		LF0 	LINE(=0)00 	LF0 	LINE(=1)
;
; Function 	Description
; ASH3-0 	Shift value of A source
; BSH3-0 	Shift value of B source and line texture
; USEA 	Mode control bit to use source A
; USEB 	Mode control bit to use source B
; USEC 	Mode control bit to use source C
; USED 	Mode control bit to use destination D
; LF7-0 	Logic function minterm select lines
;  LFx	Minterm
;	0	/a /b /c
;	1	/a /b  C
;	2	/a  B /c
;	3	/a  B  C
;	4	 A /b /c
;	5	 A /b  C
;	6	 A  B /c
;	7	 A  B  C

; EFE 	Exclusive fill enable
; IFE 	Inclusive fill enable
; FCI 	Fill carry input
; DESC 	Descending (dec address)control bit
; LINE 	Line mode control bit
; SIGN 	Line draw sign flag
; OVF 	Line/draw r/l word overflow flag
; SUD 	Line draw, Sometimes up or down (=AUD)
; SUL 	Line draw, Sometimes up or left
; AUL 	Line draw, Always up or left
; SING 	Line draw, Single bit per horiz line
; DOFF 	Disables the D output- for external ALUs
; The cycle occurs normally, but the data
; bus is tristate (hires chips only)


	SECTION Arnaud.68000,CODE_F

	include	"Lib_Et_Registres.s"
	include "macros.s"

;Config Programme

DISPLAY_X_MASQUES = 16
DISPLAY_DEPTH=5
DISPLAY_DX=320+DISPLAY_X_MASQUES	;car 16 pixels masqués pour scroll H
DISPLAY_DY=256
BITPLANE_DX=DISPLAY_DX+16	;au final 32 pixels
BITPLANE_DY=DISPLAY_DY+64
DISPLAY_X=$81-DISPLAY_X_MASQUES
DISPLAY_Y=$2C

TAILLE_BITPLANE=((BITPLANE_DX*BITPLANE_DY)>>3)


       
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
	bsr.w	ReserverMemoireCHIP
	bsr.w	CouperHardware
	bsr.w	InitiliserCopperList
	bsr.w	CreerPolice16x16
	

;  _                       
; | |     ___   ___   _ __ 
; | |__  / _ \ / _ \ | '_ \
; |____| \___/ \___/ | .__/
;                    |_|   		
;---------- Boucle principale ----------

_loop:
	
	lea 	$DFF000,a5
	
	IFNE CST.DEBUG.CountWaitBlit
	move.l	#0,CTRWait
	ENDC

;--- Attendre que le faisceau d'électrons a terminé de tracer l'écran
_waitVBL:
	move.l VPOSR(a5),d0
	lsr.l #8,d0
	and.w #$01FF,d0
	cmp.w #DISPLAY_Y+DISPLAY_DY,d0
	blt.s _waitVBL
	
	IFNE CST.DEBUG.DisplayRaster
	move.w #$0FFF,COLOR00(a5)	;si DEBUG on passe en rouge la couleur du fond
	ENDC

;--- CONFIGURER L'AFFICHAGE
	bsr	PermuterBplEtConfigurerAffichage
	
	IFNE CST.DEBUG.DisplayRaster
	move.w #$0AAA,COLOR00(a5)	;si DEBUG on passe en rouge la couleur du fond
	ENDC

;--- CONSTRUIRE L'IMAGE

	;Incrémenter valeur du scrolling
	IFEQ CST_Scroll_PasAPas
	bsr		CompterCTR65536
	bsr 	TraiterScrolling ;crée TILES -> bpl C et copie -> bpl A et B
	ENDC
		
	IFNE CST.DEBUG.DisplayRaster
	move.w #$0d00,COLOR00(a5)	;si DEBUG on passe en rouge la couleur du fond
	ENDC
		
	;Afficher du texte
	IFNE CST.RUN.AfficherTexteFixe
	AFFTEXTE 0,8,"Scroll - Arnaud - 2021-09-28" ;MACRO : x,y,"texte"
	AFFTEXTE 0,9,"Amiga68000@gmail.com" ;MACRO : x,y,"texte"	;(pc)	;cout 37 HBL
	ENDC

	IFNE CST.DEBUG.DisplayRaster
	move.w #$044f,COLOR00(a5)	;si DEBUG on passe en rouge la couleur du fond
	ENDC

	;--- AFFICHER LES VARIABLES
	IFNE CST.DEBUG.AfficherVariables
	bsr	Afficher_Variables
	ENDC
	
	IFNE CST.DEBUG.DisplayRaster
	move.w #$088f,COLOR00(a5)	;si DEBUG on passe en rouge la couleur du fond
	ENDC

	bsr	TestAffBob32
	
	; ;--- AFFICHER TEST COULEUR
	; movea.l	bitplaneB_ptr(pc),a1
	; move.l	#%10101010101010101010101010101010,(a1)
	; add.l	#TAILLE_BITPLANE,a1
	; move.l	#%11001100110011001100110011001100,(a1)
	; add.l	#TAILLE_BITPLANE,a1
	; move.l	#%11110000111100001111000011110000,(a1)
	; add.l	#TAILLE_BITPLANE,a1
	; move.l	#%11111111000000001111111100000000,(a1)
	; add.l	#TAILLE_BITPLANE,a1
	; move.l	#%11111111111111110000000000000000,(a1)
	

	;--- EFFACER LE BITPLANE CACHE (Bitplane C) 
	IFNE CST.RUN.EffacerBitPlaneCache
	;jsr		Effacer_BitPlaneC(pc)
	bsr.w		Effacer_BitPlaneC0	;(pc)
	bsr.w		Effacer_BitPlaneC1	;(pc)
	bsr.w		Effacer_BitPlaneC2	;(pc)
	ENDC
	


	
	;--- AFFICHER LE FAISCEAU EN VERT
	IFNE CST.DEBUG.DisplayRaster
	move.w	#$044f,COLOR00(a5)
	ENDC
	
	
	;--- DEBUGDISPLAYTIME
	IFNE CST.DEBUG.DisplayTime
	;affiche le nb de lignes écoulées depuis la fin de l'écran (depuis la ligne DISPLAY_Y+DISPLAY_DY incluse)
	;la trame se termine en DISPLAY_Y+DISPLAY_DY-1
	;le temps est donc compté en nombre de ligne à partir de DISPLAY_Y+DISPLAY_DY incluse
	movem.l	d0-d2/a0-a3,-(sp)
	
	AFFTEXTE 0,0,"Time=" ;MACRO : x.car,y.car,"texte"
	
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
	movea.l	bitplaneB_ptr(pc),a1
	lea 	8*(BITPLANE_DX>>3)(a1),a1
	bsr		AFficherNombre	;(pc)	;D0=nombre 9999, A1=ptr 
	
	movem.l	(sp)+,d0-d2/a0-a3
	ENDC
	
	
	
	;--- AFFICHER LE FAISCEAU EN VERT
	IFNE CST.DEBUG.DisplayRaster
	move.w	#$00F0,COLOR00(a5)
	ENDC


	;--- SOURIS PRESSEE ?
	
TestClicDroit;
	btst 	#10,$dff016 ; test RIGHT mouse click
	bne.s	.clicDroitNonEnfonce
	;-- clic droit enfoncé
.loopCG:
	;-- clic droit non laché
	btst 	#10,$dff016 ; test RIGHT mouse click
	
	beq		.loopCG	
	;-- clic droit laché

	;-- ACTION ICI
	IFNE CST_Scroll_PasAPas
	bsr		CompterCTR65536
	bsr		TraiterScrolling ;modifie AffLigneY
	ENDC
.clicDroitNonEnfonce:

	
TestClicGauche:		
	btst	#6,$bfe001
	bne.w	_loop 	;enfoncé
	;-- ici enfoncé
	
	
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


	

;  ___   _   _   ___         ___                _     _                   
; / __| | | | | | _ )  ___  | _ \  ___   _  _  | |_  (_)  _ _    ___   ___
; \__ \ | |_| | | _ \ |___| |   / / _ \ | || | |  _| | | | ' \  / -_) (_-<
; |___/  \___/  |___/       |_|_\ \___/  \_,_|  \__| |_| |_||_| \___| /__/
;                                                                         

	IFNE CST.DEBUG.AfficherVariables
Afficher_Variables:
	
	;--- AFFICHER LA POSITION SCROLLING
	AFFTEXTE 0,5,"AffLigneY=" ;MACRO : x,y,"texte"
	;1er endroit
	movea.l	bitplaneB_ptr(pc),a1
	lea 	6*8*(BITPLANE_DX>>3)(a1),a1
	move.w	AffLigneY,d0
	bsr		AFficherNombre	;(pc)	;D0=nombre 9999, A1=ptr 
	;2eme endroit
	AFFTEXTE 0,16,"AffLigneY=" ;MACRO : x.car,y.car,"texte"
	movea.l	bitplaneB_ptr(pc),a1
	lea 	17*8*(BITPLANE_DX>>3)(a1),a1
	move.w	AffLigneY,d0
	bsr		AFficherNombre	;(pc)	;D0=nombre 9999, A1=ptr 
	
	;-- AFFICHER CTR 65536
	move.w	CTR_65536,d0
	movea.l	bitplaneB_ptr(pc),a1
	lea 	32+(0*8*(BITPLANE_DX>>3))(a1),a1
	bsr		AFficherNombre	;(pc)	;D0=nombre 9999, A1=ptr 
	AFFTEXTE 20,0,"CTR 65536=" ;MACRO : x.car,y.car,"texte"
	
	;-- AFFICHER CTR 32
	move.w	CTR0..31,d0
	movea.l	bitplaneB_ptr(pc),a1
	lea 	32+(3*8*(BITPLANE_DX>>3))(a1),a1
	bsr		AFficherNombre	;(pc)	;D0=nombre 9999, A1=ptr 
	AFFTEXTE 20,3,"CTR 0..31=" ;MACRO : x.car,y.car,"texte"
	
	;-- AFFICHER Pos Tile ;DEBUG ***************************
	move.w	CTR_posYTile,d0
	movea.l	bitplaneB_ptr(pc),a1
	lea 	32+(5*8*(BITPLANE_DX>>3))(a1),a1
	bsr		AFficherNombre	;(pc)	;D0=nombre 9999, A1=ptr 
	AFFTEXTE 20,5,"PosY TILE=" ;MACRO : x.car,y.car,"texte"
	
	rts
	ENDC
	
	
;   ___    _        _         _   
;  / _ \  | |__    (_)  ___  | |_ 
; | (_) | | '_ \   | | / -_) |  _|
;  \___/  |_.__/  _/ | \___|  \__|
;                |__/  
;
;Type_Objets
;	engin au Sol : l'objet suit le scrolling
;	engin en l'Air : l'objet suit une trajectoire
;	bouclier au sol
;	munition ennemie
;	vaisseau joueur
;	tir joueur
;	objet à récupérer

TraiterObjets:


	rts


Evenements:
	dc.w	32	;declencheur Y
	dc.l	Vaisseau_Ennemi
	dc.w	255,50	;x,y départ
	dc.l	Trajectoire1
	
	
Objets:

Vaisseau_Ennemi:
	dc.w	0	;type objet (comportement)
	dc.w	10	;vitesse pix
	dc.w	10	;points de vie init
	dc.w	20	;tempo TIR
	dc.l	Objet_Boulet
	
Objet_Boulet:
	dc.l	0	
	
	
Trajectoire1:
	dc.w	0,0
	dc.w	10,0
	dc.w	20,0
	dc.w	30,0
	dc.w	40,0
	dc.w	50,0
	dc.w	$ffff,$ffff






;DEBUG ****************************
TestAffBOB:

	move.w  #BOB_Y,d1
    move.w  #BOB_DY,d2
   
	rts



;  ___    ___    ___ 
; | _ )  / _ \  | _ )
; | _ \ | (_) | | _ \
; |___/  \___/  |___/



TestAffBob32:
	;TEST 50x BOBs 1 plan
	;50xBOB 1 plan h32 : equiv=196 (189 en 1 partie / 255 quand bob en 2 parties)
	;50xBOB 1 plan h32 : 188 en 1 partie (pas de test de tronquage)
	;10xBOB 1 plan h32*5 : 170 en 1 partie
	;Conclusion : s'orienter sur Bitplanes entrelacés
	
	BOB_X=165
	BOB_Y=150
	BOB_DX=32
	BOB_DY=32
	
	movem.l d0-d7/a0-a6,-(sp)
	lea 	$DFF000,a5

	move.l	#50,d7	
Bcl_Aff_BOB:
	move.w	#BOB_X,d0	;x.pix
	move.w	#BOB_Y,d1	;y.pix
	lea		bob_img,a0	;bob
	
	;bsr		AfficherBob32
	bsr		Copy_Blit_BOB_h32
	
	dbf		d7,Bcl_Aff_BOB
	movem.l (sp)+,d0-d7/a0-a6
		
	rts


;
;-- AFFICHER BOB x,y
;
BOB32_DX=32
BOB32_DY=32

; CMP A,B 	Entier (signé) 	Naturel(non signé)
; A >  B 		BLT 	BLO (ou BCS)
; A >= B 		BLE 	BLS
; A =  B 		BEQ 	BEQ
; A <> B 		BNE 	BNE
; A <  B 		BGT 	BHI
; A <= B 		BGE 	BHS (ou BCC)
	
AfficherBob32:
	;Entree: 
	;	d0=x.pix
	;	d1=y.pix (physical location (0,0) = upper left corner)
	;	a0=image 32x32
	;	a5= DFF000
	;Sortie:
	;	
	;Interne:
	;	d4, d5, a1=ptr screen.dest, d2=offset screen.dest
 
    add.w   AffLigneY,d1    ;D1 = BOB_Ligne_Ydeb = BOB_Y + AffLigneY
    cmp.w   #BITPLANE_DY,d1
    blo .saut1
        ;CAS 1 : BITPLANE_DY <= BOB_Ligne_Ydeb
        sub.w	#BITPLANE_DY,d1
		;deplacer en 1 bloc d0=x, d1=y
        bsr	Copy_Blit_BOB_h32 ;d0=x, d1=y, a0=adr BOB, a5=$dff000, [a1], [d2]
        rts
.saut1:
        ;BITPLANE_DY > BOB_Ligne_Ydeb
        move.w  d1,d4
        add.w   #BOB32_DY,d4  ;d4 = BOB_Ligne_YFin
        cmp.w   #BITPLANE_DY,d4
        bls     .saut2	;blo <=   bls <
            ;CAS 2 : BITPLANE_DY < BOB_Ligne_YFin
            ;deplacer en 2 blocs
            move.w  d4,d5
            move.w  #BITPLANE_DY,d4 
            sub.w   d1,d4	;d4 = DY1 = BITPLANE_DY - BOB_Ligne_Ydeb
            ;bloc 1 : d1 = Y1, d4 = DY1
            move.w	d0,d3	;sauve d0=x.pix
			bsr	Copy_Blit_BOB_hd4 ;d0=x, d1=y, d4=dy, a0=adr BOB, a5=$dff000, [a1], [d2]

			move.w	d3,d0	;restaure d0=x.pix
            moveq.l #0,d1	;y.pix = 0
            move.w  d5,d4	;restaure 
            sub.w   #BITPLANE_DY,d4 ;d4 = DY2 = BOB_Ligne_YFin - BITPLANE_DY 
            ;bloc 2 : d1 = 0, d4 = DY2
            bsr	Copy_Blit_BOB_hd4 ;d0=x, d1=y, d4=dy, a0=adr BOB, a5=$dff000, [a1], [d2] 

        rts  
.saut2:
            ;CAS 3 : BITPLANE_DY > BOB_Ligne_YFin
            ;deplacer en 1 bloc 
            ;d1 = Y1, d2 = DY
            bsr	Copy_Blit_BOB_h32 ;d0=x, d1=y, a0=adr BOB, a5=$dff000, [a1], [d2]
            
        rts





Copy_Blit_BOB_hd4:
	;-- COPY BOB AU BLITTER selon h=d4
	;ENTREE
	;	d0 = x.pix
	;	d1 = y.pix
	;	d4 = dy.pix ********************
	;	a0 = adresse bob
	;	a5 = $DFF000
	;MODIFIE
	;	d0, d1, d2, d4, a1


	move.w	d0,d2
	and.w	#$F,d0
	ror.w	#4,d0
	or.w	#%0000101111111010,d0	;4 bits AShift - 4 bits used ABCD - 8b minterms A+/aC

	lsr.w	#3,d2		;pos.x en octet
	and.b	#$FE,d2		;pos.x au mot près 16bits
	mulu	#BITPLANE_DX>>3,d1
	add.w	d1,d2
	movea.l	bitplaneB_ptr(pc),a1	;backBuffer
	lea		(a1,d2.w),a1
	
	;Calcul de size #(BOB32_DY<<6)!((BOB32_DX+16)>>4)
	lsl.w	#6,d4
	add.w	#((BOB32_DX+16)>>4),d4
	
	WAITBLIT
	move.w	d0,BLTCON0(a5)
	move.w	#$0000,BLTCON1(a5)
	move.w	#$FFFF,BLTAFWM(a5)
	move.w	#$0000,BLTALWM(a5)
	move.w	#-2,BLTAMOD(a5)
	move.w	#(BITPLANE_DX-(BOB32_DX+16))>>3,BLTCMOD(a5)
	move.w	#(BITPLANE_DX-(BOB32_DX+16))>>3,BLTDMOD(a5)
	move.l	a0,BLTAPTH(a5)
	move.l	a1,BLTCPTH(a5)
	move.l	a1,BLTDPTH(a5)
	move.w	d4,BLTSIZE(a5)

	rts	





Copy_Blit_BOB_h32:
	;-- AFFICHER BOB AU BLITTER
	;ENTREE
	;	d0 = x.pix
	;	d1 = y.pix
	;	a0 = adresse bob
	;	a5 = $DFF000
	;INTERNE
	;	a1
	;	d2

	move.w	d0,d2
	and.w	#$F,d0
	ror.w	#4,d0
	or.w	#%0000101111111010,d0	;4 bits AShift - 4 bits used ABCD - 8b minterms A+/aC

	lsr.w	#3,d2
	and.b	#$FE,d2
	mulu	#BITPLANE_DX>>3,d1
	add.w	d1,d2
	movea.l	bitplaneB_ptr(pc),a1	;backBuffer
	lea		(a1,d2.w),a1
	
	WAITBLIT
	move.w	d0,BLTCON0(a5)
	move.w	#$0000,BLTCON1(a5)
	move.w	#$FFFF,BLTAFWM(a5)
	move.w	#$0000,BLTALWM(a5)
	move.w	#-2,BLTAMOD(a5)
	move.w	#(BITPLANE_DX-(BOB32_DX+16))>>3,BLTCMOD(a5)
	move.w	#(BITPLANE_DX-(BOB32_DX+16))>>3,BLTDMOD(a5)
	move.l	a0,BLTAPTH(a5)
	move.l	a1,BLTCPTH(a5)
	move.l	a1,BLTDPTH(a5)
	move.w	#(BOB32_DY<<6)!((BOB32_DX+16)>>4),BLTSIZE(a5)

	rts
	

	
	
;--- BLITTER
; 			AREA MODE 			LINE MODE
; Bit 		BLTCON0 BLTCON1 Bit BLTCON0 BLTCON1
; 15 		ASH3 	BSH3 	15 	ASH3 	BSH3
; 14 		ASH2 	BSH2 	14 	ASH2 	BSH2
; 13 		ASH1 	BSH1 	13 	ASH1 	BSH1
; 12 		ASA0 	BSH0 	12 	ASH0 	BSH0
; 11 		USEA 	0 		11 	1 		0
; 10 		USEB 	0 		10 	0 		0
; 09 		USEC 	0 		09 	1 		0
; 08 		USED 	0 		08 	1 		0
; 07 		LF7 	DOFF 	07 	LF7 	DPFF
; 06 		LF6 	0 		06 	LF6 	SIGN
; 05 		LF5 	0 		05 	LF5 	OVF
; 04 		LF4 	EFE 	04 	LF4 	SUD
; 03 		LF3 	IFE 	03 	LF3 	SUL
; 02 		LF2 	FCI 	02 	LF2 	AUL
; 01 		LF1 	DESC 	01 	LF1 	SING
; 00 		LF0 	LINE(=0)00 	LF0 	LINE(=1)

;BLTCON0
;  bit	Minterm
;	7	 A  B  C
;	6	 A  B /c
;	5	 A /b  C
;	4	 A /b /c
;	3	/a  B  C
;	2	/a  B /c
;	1	/a /b  C
;	0	/a /b /c	
Aff_Blit_BOB32_GENERIQUE:
	;-- AFFICHER BOB AU BLITTER
	;ENTREE
	;	d0 = x.pix
	;	d1 = y.pix
	;	a0 = adresse bob
	;	a5 = $DFF000
	;INTERNE
	;	a1
	;	d2

	move.w	d0,d2
	and.w	#$F,d0
	ror.w	#4,d0
	or.w	#%0000101111111010,d0	;4 bits AShift - 4 bits used ABCD - 8b minterms A+/aC

	lsr.w	#3,d2
	and.b	#$FE,d2
	mulu	#BITPLANE_DX>>3,d1
	add.w	d1,d2
	movea.l	bitplaneB_ptr(pc),a1	;backBuffer
	lea		(a1,d2.w),a1
	
	WAITBLIT
	move.w	d0,BLTCON0(a5)
	move.w	#$0000,BLTCON1(a5)
	move.w	#$FFFF,BLTAFWM(a5)
	move.w	#$0000,BLTALWM(a5)
	move.w	#-2,BLTAMOD(a5)
	move.w	#(BITPLANE_DX-(BOB32_DX+16))>>3,BLTCMOD(a5)
	move.w	#(BITPLANE_DX-(BOB32_DX+16))>>3,BLTDMOD(a5)
	move.l	a0,BLTAPTH(a5)
	move.l	a1,BLTCPTH(a5)
	move.l	a1,BLTDPTH(a5)
	move.w	#(BOB32_DY<<6)!((BOB32_DX+16)>>4),BLTSIZE(a5)

	rts


;   ___                    _   _   _               
;  / __|  __   _ _   ___  | | | | (_)  _ _    __ _ 
;  \__ \ / _| | '_| / _ \ | | | | | | | ' \  / _` |
;  |___/ \__| |_|   \___/ |_| |_| |_| |_||_| \__, |
; 											 |___/ 
; GESTION DU SCROLLING

TraiterScrolling:
	move.w	CTR_65536,d0
	btst	#0,d0
	bne		.sauteSCroll
	;scrolling 1 fois sur 2
	bsr.w	IncrementerPosYScrolling
	bsr		IncrementerPosXScrolling
.sauteSCroll:
	bsr.w	CompterCTR31
	bsr.w	Sequenceur_SCROLL
	rts
	
	

;--- INCREMENTE POSITION Y DU BITMAP A AFFICHER
IncrementerPosYScrolling:
	;----- Incremente Position affichage
	moveq.l	#0,d1
	move.w	AffLigneY,d1
	IFEQ CST_Scroll_Sens
	;-- SENS BAS, Sens descente
	subq	#1,d1
	bge		.pasDeb	;tester si <=0 ; bge signé A <= B 
	move.w	#BITPLANE_DY-1,d1
.pasDeb:
	ELSE
	;-- SENS HAUT, Sens montée 
	addq	#1,d1
	cmp.w	#BITPLANE_DY,d1
	blo		.pasFin	;blo BITPLANE_DY > d1
	moveq.l	#0,d1
.pasFin:
	ENDC
	move.w	d1,AffLigneY
	rts

AffLigneY:	dc.w	CST_Scroll_PosYInit	;0 .. 287

;--- INCREMENT POS X DE L'AFFICHAGE
IncrementerPosXScrolling:

	movea.l	AffEcranPosX_Ptr(pc),a0
	add.l	#2,a0
	move.w	(a0),d1
	cmp.w	#$ffff,d1
	bne	.pasReset
		move.l	#AffEcranPosX_Data,a0
		move.w	(a0),d1
.pasReset:
	move.w	d1,AffEcranPosX
	movea.l	a0,AffEcranPosX_Ptr
	
	rts
	
	
AffEcranPosX:		
	dc.w	0
AffEcranPosX_Ptr:	
	dc.l 	AffEcranPosX_Data
AffEcranPosX_Data:
	;dc.w	0,0,0,0,0,0,0,0
	;dc.w	5,5,5,5,5,5,5,5
	;dc.w	5,5,5,5,5,5,5,5
	;dc.w	5,5,5,5,5,5,5,5
	;dc.w	$ffff
	dc.w	0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
	dc.w	16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
	dc.w	30,29,28,27,26,25,24,23,22,21,20,19,18,17,16
	dc.w	15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0
	dc.w	$FFFF



;---- COMPTEUR 0..65535
CompterCTR65536:
	add.w	#1,CTR_65536
	rts
CTR_65536:dc.w	0



;---- COMPTEUR 0..31
CompterCTR31:
	move.w	AffLigneY,d0
	and.w	#%11111,d0
	move.w	d0,CTR0..31
	rts
CTR0..31:	dc.w	0






;--- ACTION = f(CTR31)
Sequenceur_SCROLL:
	;31		: CALCUL POINTEUR ZONE NEW TILES
	;30 à 20: COPIER TILES du decor correspondant dans bitplane C
	;19		: copier TILES bitplane C --> A
	;18		: copier TILES bitplane C --> B

	move.w	CTR0..31,d0
	
	
	cmp.w	#31,d0
	bne		.pas31

	;CTR=31
	
	;--- calcul du pointeur zone new Tiles
	;movea.l bitplaneB_ptr(pc),a0 ;DEBUG ***************************
	move.w	AffLigneY,d1	;y
	sub.w	#31+32,d1
	bge		.pasDepasse	;bge signé : A <= B 
		;-- inf a 0 strictement
		add.w	#BITPLANE_DY,d1
.pasDepasse:
	move.w	d1,CTR_posYTile ;DEBUG**********************
	mulu	#BITPLANE_DX>>3,d1
	movea.l bitplaneC_ptr(pc),a0
	add.l	d1,a0
	movea.l	a0,bitplaneZoneNewTile_PTR
	rts

	
	
	
.pas31:
	cmp.w	#20,d0	;/!\ changer valeur plus bas aussi
	blo		.pas20	;si 20>d0
	
	;CTR=20 à 30
	;--- copier de new Tiles dans bitplane C
	and.l	#$ff,d0
	sub.w	#20,d0	;0..10
	add.w	d0,d0	;0..20 pas de 2 octets
	moveq.l	#0,d1
	move.w	d0,d1
	movea.l	Decor_Tiles_PTR(pc),a2
	move.w	(a2,d0),d0	;n° du Tile
	add.w	d1,d1		;pos X du Tile en octet
	move.l 	bitplaneZoneNewTile_PTR(pc),a0
	add.l	d1,a0
	bsr		CopyTileBlit
	rts
	
	
.pas20:
	cmp.w	#19,d0
	bne		.pas19
	
	;CTR=20
	;--- copier Bitplane zone Tiles créées C --> A
	movea.l	bitplaneZoneNewTile_PTR(pc),a0
	move.l	a0,a1
	sub.l	#TAILLE_BITPLANE*DISPLAY_DEPTH*1,a1
	Bra		.CopierBlitter


.pas19:
	cmp.w	#18,d0
	bne		pas18
	
	;CTR=19
	;--- copier Bitplane zone Tiles créées C --> B
	movea.l	bitplaneZoneNewTile_PTR(pc),a0
	move.l	a0,a1
	sub.l	#TAILLE_BITPLANE*DISPLAY_DEPTH*2,a1

.CopierBlitter:
	;rts	;DEBUG ******************************
	movem.l d0-d7/a0-a6,-(sp)
	lea 	$DFF000,a5
	
	move.w	#DISPLAY_DEPTH-1,d7
bclCopyAreaTilesBlit:

		WAITBLIT
		move.l	a0,BLTAPTH(a5)		;adresse source
		move.l	a1,BLTDPTH(a5)		;adresse dest
		move.w	#%0000100111110000,BLTCON0(a5)	;canal A et D, D=A
		move.w	#%0000000000000000,BLTCON1(a5)
		move.w	#%1000000001000000,DMACON(a5)
		move.w	#0,BLTAMOD(a5)
		move.w	#0,BLTDMOD(a5)
		move.w	#$FFFF,BLTAFWM(a5)	;Masque 1er mot de chaque ligne de A
		move.w	#$FFFF,BLTALWM(a5)	;Masque dernier mot de chaque ligne de A
		move.w	#(32<<6)!((BITPLANE_DX)>>4),BLTSIZE(a5)	;32pix de haut
		
		add.l	#TAILLE_BITPLANE,a0
		add.l	#TAILLE_BITPLANE,a1

	dbf		d7,bclCopyAreaTilesBlit
	
	movem.l (sp)+,d0-d7/a0-a6

	rts
	
	
	
pas18:
	cmp.w	#17,d0
	bne 	.pas17
	;CTR=17, incrémenter TILE_PTR
	movea.l	Decor_Tiles_PTR(pc),a0
	lea		22(a0),a0		;TODO configurer avec variables
	move.w	(a0),d1
	cmp.w	#$FFFF,d1
	bne	.pasRaz
		;raz
		lea	Decor_Tiles(pc),a0
.pasRAZ:
	move.l	a0,Decor_Tiles_PTR
.pas17:
	
FinCTR:
	rts

CTR_posYTile:	dc.w 0	;DEBUG ******************************
bitplaneZoneNewTile_PTR:	dc.l	ScreenA ;evite le bug




;---- COPIER TILES

	; move.l 	bitplaneB_ptr(pc),a0
	; moveq.l	#0,d0
	; bsr		CopyTile	; ;A0 = ptr dest, D0 = num du tile 0 à 79

	; lea 	(a0,d2.w),a2 		;12 cycles
	; lea 	BITPLANE_DX>>3(a3),a3 ;8cycles

TILES_DX = 32
TILES_DY = 32
TILES_BDD_DX = 320
TILES_BDD_DY = 256
TILES_BITPLANE_SIZE = (TILES_BDD_DX*TILES_BDD_DY)>>3


; CopyTile:
	; ;A0 = ptr destination 
	; ;D0 = numéro du tile 0 à 79
	; ;utilisé A1
	; lea 	Tiles,a1
	; and.l	#$ff,d0
	; divu	#10,d0
	; move.w	d0,d1	;n° x
	; swap 	d0		;n°y
	; and.l	#$ff,d0
	; add.w	d0,d0
	; add.w	d0,d0	;x en octet
	; mulu	#(TILES_BDD_DX>>3)*TILES_DY,d1
	; add.l	d1,d0	;offset en octet du tile
	; add.l	d0,a1	;ptr sur tile à copier
	; moveq.l	#TILES_DY-1,d0
; .bcl:
	; move.l	(a1),(a0)	;TILES_DX = 32 pixels
	; add.l	#40,a1
	; add.l	#BITPLANE_DX>>3,a0
	; dbf	d0,.bcl

	; rts


CopyTileBlit:
	movem.l d0-d7/a0-a6,-(sp)
	
	lea 	Tiles,a1
	
	and.l	#$ff,d0
	divu	#10,d0
	move.w	d0,d1	;n° x
	swap 	d0		;n°y
	and.l	#$ff,d0
	add.w	d0,d0
	add.w	d0,d0	;x en octet
	mulu	#(TILES_BDD_DX>>3)*TILES_DY,d1
	add.l	d1,d0	;offset en octet du tile
	add.l	d0,a1	;ptr sur tile à copier
	
	
	lea 	$DFF000,a5
	
	move.w	#DISPLAY_DEPTH-1,d7
bclCopyTileBlit:	
		WAITBLIT
		move.l	a1,BLTAPTH(a5)		;adresse source
		move.l	a0,BLTDPTH(a5)		;adresse dest
		move.w	#%0000100111110000,BLTCON0(a5)	;canal A et D, D=A
		move.w	#%0000000000000000,BLTCON1(a5)
		move.w	#%1000000001000000,DMACON(a5)
		move.w	#(TILES_BDD_DX-TILES_DX)>>3,BLTAMOD(a5)
		move.w	#(BITPLANE_DX-TILES_DX)>>3,BLTDMOD(a5)
		move.w	#$FFFF,BLTAFWM(a5)	;Masque 1er mot de chaque ligne de A
		move.w	#$FFFF,BLTALWM(a5)	;Masque dernier mot de chaque ligne de A
		move.w	#(TILES_DY<<6)!((TILES_DX)>>4),BLTSIZE(a5)
		
		add.l	#TILES_BITPLANE_SIZE,a1
		add.l	#TAILLE_BITPLANE,a0
	dbf		d7,bclCopyTileBlit
	
	movem.l (sp)+,d0-d7/a0-a6
	rts

Decor_Tiles_PTR: 
	dc.l	Decor_Tiles
Decor_Tiles:

	dc.w	02,01,02,03,04,05,06,07,08,09,02
	dc.w	10,11,12,13,14,15,16,17,18,01,01
	dc.w	20,21,22,23,24,25,26,27,28,29,03
	dc.w	$FFFF ;fin
	EVEN
	
	
	
	

	
;  ___  
; | _ \
; |   / 
; |_|_\ ANDOM 
; NOMBRES ALEATOIRES                     	


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
;   |_|EXTE
;
; GESTION DES AFFICHAGES TEXTUELS



;--- AFFICHER UN NOMBRE
AFficherNombre:
	;input
	;	d0.w = #nombre 9999 max à afficher
	;	a1   = adresse memoire destination
	;utilisé
	;	d0, d1, d2
	;	a0, a1, a2, a3
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
		lea 	(a0,d2.w),a2 ;12 cycles
		move.l 	a1,a3
		moveq	#8-1,d2
.timeLoopDisplayChar:
			move.b	(a2)+,(a3)
			lea 	BITPLANE_DX>>3(a3),a3 ;8cycles
		dbf 	d2,.timeLoopDisplayChar
		lea 	1(a1),a1
		lsr.l	#8,d1
	dbf	d0,.timeLoopDisplay
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

	

;   ___ 
;  / __|
; | (_ |
;  \___|ESTION ECRAN

;	
;--- PERMUTER LES BITPLANES ET CONFIGURER L'AFFICHAGE
;

PermuterBplEtConfigurerAffichage:
;----- PERMUTER LES BITPLANE
	;Permuter circulairement les bitplanes : A(à afficher) --> C(à effacer) --> B(à construire) --> A
	; move.l bitplaneA_ptr(pc),d0
	; move.l bitplaneB_ptr(pc),d1
	; move.l bitplaneC_ptr(pc),d2
	; move.l d1,bitplaneA_ptr	;Bitplane Affiché
	; move.l d2,bitplaneB_ptr	;Bitplane en construction
	; move.l d0,bitplaneC_ptr ;Bitplane en effacement
	
	;permutation A et B
	move.l bitplaneA_ptr(pc),d0
	move.l bitplaneB_ptr(pc),d1
	move.l d1,bitplaneA_ptr	;Bitplane Affiché
	move.l d0,bitplaneB_ptr	;Bitplane en construction
	; move.l d0,bitplaneC_ptr ;Bitplane decor
	
	
	
	; ;-- DECALAGE X ECRAN
	; move.w	ORI_X,d0
	; and.w	#$000f,d0
	; neg.w	d0
	; add.w	#$f,d0	;Bitplanes pairs
	; move.w	d0,d1
	; lsl.w	#4,d0	;Bitplanes impairs
	; or.w	d1,d0
	; move.w	#BPLCON1,(a0)+
	; move.w	d0,(a0)+
	
	
	
	
	
	;----- Retard X du SCROLLING
	;inverse le reste de la div par 16
	
	move.w	AffEcranPosX,d3
	not.w	d3
	add.w	#1,d3
	and.w	#$f,d3
	move.w	d3,d4
	lsl.w	#4,d4
	or.w	d3,d4	;TODO DEBUG pour 2eme plan enlever ';'
	move.w	d4,CplBPLCON1
	
	
	;-- offset.w décalage bitplane x
	moveq.l	#0,d3
	move.w	AffEcranPosX,d3
	add.w	#15,d3
	lsr.w	#3,d3	;d3 = octet décalage affichage x
	and.w	#$FFFE,d3
	sub.l	#2,d3

	;DEBUG ***************************************
	;move.w	#$00,CplBPLCON1	;decalage pixel
	;move.l	#-2,d3			;decalage Bitplane

 




	
	;d1  = bitplaneA_ptr
	move.w	AffLigneY,d0
	mulu	#BITPLANE_DX>>3,d0
	add.l	d0,d1 ;d1 = d1 + AffLigneY * (BITPLANE_DX / 8)

	;-- DECALAGE X ECRAN
	add.l	d3,d1 ;ajout du décalage x en octet
	
;----- AFFICHER BitPlaneA VIA COPPERLIST ----------
	;ecriture des adresses bitplane dans la copperlist
	movea.l	Copperlist_BitPlanes_PTR(pc),a0
aff:	
	;Bitplane1
	move.w 	d1,2(a0)
	swap 	d1
	move.w 	d1,6(a0)
	
	IFGE DISPLAY_DEPTH-2
	;Bitplane2
	swap 	d1
	add.l	#TAILLE_BITPLANE,d1
	move.w	d1,10(a0)	
	swap 	d1
	move.w	d1,14(a0)
	ENDC
	
	IFGE DISPLAY_DEPTH-3
	;Bitplane3
	swap 	d1
	add.l	#TAILLE_BITPLANE,d1
	move.w	d1,18(a0)
	swap 	d1
	move.w	d1,22(a0)
	ENDC
	
	IFGE DISPLAY_DEPTH-4
	;Bitplane4
	swap 	d1
	add.l	#TAILLE_BITPLANE,d1
	move.w	d1,26(a0)
	swap 	d1
	move.w	d1,30(a0)
	ENDC

	IFGE DISPLAY_DEPTH-5
	;Bitplane5
	swap 	d1
	add.l	#TAILLE_BITPLANE,d1
	move.w	d1,34(a0)
	swap 	d1
	move.w	d1,38(a0)
	ENDC
	
	IFGE DISPLAY_DEPTH-6
	;Bitplane6
	swap 	d1
	add.l	#TAILLE_BITPLANE,d1
	move.w	d1,42(a0)
	swap 	d1
	move.w	d1,46(a0)
	ENDC	
	
;---- Affiche partie 2 (partie basse pointant sur le début du bitplane)
	;wait ligne (BITPLANE_DY - AFFLigneY) si < DISPLAY_DY

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
	
	;-- Ecran non tronqué
	move.l	#$01FE0000,(A0)+	;Copper NOP (à la place du WAIT 255)
	move.l	#$01FE0000,(A0)+	;Copper NOP (à la place du WAIT ligne)
	move.l	#$01FE0000,(A0)+	;Copper NOP (à la place du ptr BPL 1)
	move.l	#$01FE0000,(A0)+	;Copper NOP (à la place du ptr BPL 1)
	IFGE DISPLAY_DEPTH-2
	move.l	#$01FE0000,(A0)+	;Copper NOP (à la place du ptr BPL 2)
	move.l	#$01FE0000,(A0)+	;Copper NOP (à la place du ptr BPL 2)
	ENDC
	IFGE DISPLAY_DEPTH-3
	move.l	#$01FE0000,(A0)+	;Copper NOP (à la place du ptr BPL 3)
	move.l	#$01FE0000,(A0)+	;Copper NOP (à la place du ptr BPL 3)
	ENDC
	IFGE DISPLAY_DEPTH-4
	move.l	#$01FE0000,(A0)+	;Copper NOP (à la place du ptr BPL 4)
	move.l	#$01FE0000,(A0)+	;Copper NOP (à la place du ptr BPL 4)
	ENDC
	IFGE DISPLAY_DEPTH-5
	move.l	#$01FE0000,(A0)+	;Copper NOP (à la place du ptr BPL 5)
	move.l	#$01FE0000,(A0)+	;Copper NOP (à la place du ptr BPL 5)
	ENDC
	IFGE DISPLAY_DEPTH-6
	move.l	#$01FE0000,(A0)+	;Copper NOP (à la place du ptr BPL 6)
	move.l	#$01FE0000,(A0)+	;Copper NOP (à la place du ptr BPL 6)
	ENDC
	bra		.fin
	
.EcranTronque:
	;-- Ecran trounqué
	;-- Ajout décalage position DISPLAY_Y
	add.w	#DISPLAY_Y,d1
	cmp.w	#255,d1	;on depasse ou atteint les 255
	bls		.pasWait
		;mettre un wait 255
		move.l	#$FFE1FFFE,(A0)+	;Copper WAIT 255
		sub.w	#$FF+1,d1
		bra		.FinWait
.pasWait:
		;sinon NOP
		move.l	#$01FE0000,(A0)+	;Copper NOP (à la place du WAIT 255)
.FinWait:
	;creation du wait ligne
	lsl.w	#8,d1		;(288-y) sur poid fort (V7..V0)
	add.w	#$E1,d1		;ajout de $E1 (H8...H2 1)
	move.w	d1,(a0)+	;dc.w $xxE1,$FFFE
	move.w	#$FFFE,(a0)+
	
	;pointeur début bpl
	move.l 	bitplaneA_ptr(pc),d1
	add.l	d3,d1 ;ajout du décalage x en octet
	
	;BPL1
	move.w	#BPL1PTL,(a0)+
	move.w 	d1,(a0)+
	swap 	d1
	move.w	#BPL1PTH,(a0)+
	move.w 	d1,(a0)+
	
	IFGE DISPLAY_DEPTH-2	;BPL2
	swap	d1
	add.l	#TAILLE_BITPLANE,d1
	move.w	#BPL2PTL,(a0)+
	move.w 	d1,(a0)+
	swap 	d1
	move.w	#BPL2PTH,(a0)+
	move.w 	d1,(a0)+
	ENDC
	IFGE DISPLAY_DEPTH-3	;BPL3
	swap	d1
	add.l	#TAILLE_BITPLANE,d1
	move.w	#BPL3PTL,(a0)+
	move.w 	d1,(a0)+
	swap 	d1
	move.w	#BPL3PTH,(a0)+
	move.w 	d1,(a0)+
	ENDC
	IFGE DISPLAY_DEPTH-4	;BPL4
	swap	d1
	add.l	#TAILLE_BITPLANE,d1
	move.w	#BPL4PTL,(a0)+
	move.w 	d1,(a0)+
	swap 	d1
	move.w	#BPL4PTH,(a0)+
	move.w 	d1,(a0)+
	ENDC	
	IFGE DISPLAY_DEPTH-5	;BPL5
	swap	d1
	add.l	#TAILLE_BITPLANE,d1
	move.w	#BPL5PTL,(a0)+
	move.w 	d1,(a0)+
	swap 	d1
	move.w	#BPL5PTH,(a0)+
	move.w 	d1,(a0)+
	ENDC	
	IFGE DISPLAY_DEPTH-6	;BPL6
	swap	d1
	add.l	#TAILLE_BITPLANE,d1
	move.w	#BPL6PTL,(a0)+
	move.w 	d1,(a0)+
	swap 	d1
	move.w	#BPL6PTH,(a0)+
	move.w 	d1,(a0)+
	ENDC
.fin:
	
	

	
	rts


;--- EFFACER BITPLANE C	-------------------

;position du centre objet. rayon maxi 92 pix  equ  sqr(3*53^2), coins max 53,53,53
RayonMaxi 	equ 96		;doit tre un miltiple de 8 pix, utilisé pour RAZ au blitter
offsetX 	equ 160		;min 87, maxi 232
offsetZ 	equ 100		;min 87, maxi 168  87=sqr(50^2+50^2+50^2) coin max (50,50,50)


OffsetOctetRAZBLT=(((offsetZ-RayonMaxi)*BITPLANE_DX)+(offsetX-RayonMaxi))/8

Effacer_BitPlaneC:
	;--- effacement complet (152 HBL)
	; move.w	#0,BLTDMOD(a5)
	; move.w	#$0000,BLTCON1(a5)
	; move.w	#%0000000100000000,BLTCON0(a5)
	; move.l	bitplaneC_ptr,BLTDPTH(a5)
	; move.w	#(BITPLANE_DX>>4)!(DISPLAY_DY<<6),BLTSIZE(a5)
	bsr.s		Effacer_BitPlaneC0	;(pc)
	bsr.s		Effacer_BitPlaneC1	;(pc)
	bsr.w		Effacer_BitPlaneC2	;(pc)
	rts
	
	;--- Effacement selectif = rubiks seul
	;RayonMaxi=92
	;offsetX=160
	;offsetZ=100
	;TAILLE_BITPLANE=((BITPLANE_DX*DISPLAY_DY)>>3)
	
Effacer_BitPlaneC0:
	move.l	bitplaneC_ptr(pc),a0
	WAITBLIT
	move.w	#$0000,BLTCON1(a5)
	move.w	#%0000000100000000,BLTCON0(a5)
	lea		OffsetOctetRAZBLT(a0),a0	;adresse de départ
	move.l	a0,BLTDPTH(a5)
	move.w	#(BITPLANE_DX-(RayonMAxi*2))/8,BLTDMOD(a5)
	move.w	#((RayonMaxi*2)>>4)!((RayonMaxi*2)<<6),BLTSIZE(a5)
	rts
Effacer_BitPlaneC1:	
	move.l	bitplaneC_ptr(pc),a0
	WAITBLIT
	move.w	#$0000,BLTCON1(a5)
	move.w	#%0000000100000000,BLTCON0(a5)
	lea		OffsetOctetRAZBLT+TAILLE_BITPLANE(a0),a0	;adresse de départ
	move.l	a0,BLTDPTH(a5)
	move.w	#(BITPLANE_DX-(RayonMAxi*2))/8,BLTDMOD(a5)
	move.w	#((RayonMaxi*2)>>4)!((RayonMaxi*2)<<6),BLTSIZE(a5)
	rts
Effacer_BitPlaneC2:
	move.l	bitplaneC_ptr(pc),a0
	WAITBLIT
	move.w	#$0000,BLTCON1(a5)
	move.w	#%0000000100000000,BLTCON0(a5)
	lea		OffsetOctetRAZBLT+2*TAILLE_BITPLANE(a0),a0	;adresse de départ
	move.l	a0,BLTDPTH(a5)
	move.w	#(BITPLANE_DX-(RayonMAxi*2))/8,BLTDMOD(a5)
	move.w	#((RayonMaxi*2)>>4)!((RayonMaxi*2)<<6),BLTSIZE(a5)
	rts





;  _____ 
; |_   _|
;   | |  
;   |_|  TRACER AU BLITTER
;        


;-- ROUTINE D'APPEL
	;movem.l d0-d7/a0-a6,-(sp)
	; ;--- TRACER LIGNE PLEINE AU BLITTER	
	; ;Entree (d0=x1,d1=y1,d2=x2,d3=y2, a1=adresse du bitplane)
	; move.l	bitplaneB_ptr(pc),a1
	; move.l	#100,d0
	; move.l	#100,d1
	; move.l	#200,d2
	; move.l	#200,d3
	; bsr.w	TracerLignePleine
	;movem.l (sp)+,d0-d7/a0-a6



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
	lea		(BITPLANE_DX>>3)(a2),a2	;ligne suivante
	dbf		d0,.aff8x8
	;fin de cara
	;sub.l	#(BITPLANE_DX>>3)*8-1,a2	;position car suivant
	lea     -((BITPLANE_DX>>3)*8-1)(a2),a2
	moveq.l	#0,d0
	move.b	(a3)+,d0	;on lit le caratère
	bne.s		.bcl2		;si 0 on est  la fin du texte
.fin:
	rts




;  ___ 
; / __|
; \__ \
; |___/YSTEME
; GESTION SYSTEME

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
	movea.l Font16_PTR(pc),a1
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
	move.l 	#bitplaneA_ptr,a0
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
	IFNE CST.DEBUG.CountWaitBlit
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
bitplaneA_ptr:		DC.L 	ScreenA
bitplaneB_ptr:		DC.L 	ScreenB
bitplaneC_ptr:		DC.L 	ScreenC










	section	coplist,data_c


bob_mask:
	dc.l	%00000000000000000000000000000000
	dc.l	%00000000000000000000000000000000
	dc.l	%11111000000111111111100000011111
	dc.l	%11111000000111111111100000011111
	dc.l	%10011000000000000000000000011111
	dc.l	%10011000000000000000000000011111
	dc.l	%10011000000000000000000000011111
	dc.l	%10001100000000000000000000111111
	dc.l	%10001111111111111111111111111000
	dc.l	%10001111111111111111111111111000
	dc.l	%10001111111111111111111111111000
	dc.l	%11000000000000000000000000110000
	dc.l	%01111000000000000000000000110000
	dc.l	%01111000000000000000000000110000
	dc.l	%01111000000000000000000000110000
	dc.l	%00001100000000000000000000110000
	dc.l	%00001100000000000000000000110000
	dc.l	%00010111111111111111111111111000
	dc.l	%00010111111111111111111111111000
	dc.l	%00010111111111111111111111111000
	dc.l	%00010111111111111111111111111000
	dc.l	%00101100000000000000000000111100
	dc.l	%01101000000000000000000000011110
	dc.l	%10011000000000000000000000011111
	dc.l	%10011000000000000000000000011111
	dc.l	%10010000000000000000000000001111
	dc.l	%10010000000000000000000000001111
	dc.l	%10010000000000000000000000001111
	dc.l	%11110000000000000000000000001111
	dc.l	%11110000000000000000000000001111
	dc.l	%00000000000000000000000000000000
	dc.l	%00000000000000000000000000000000

		
bob_IMG
	dc.l	%00000000000000000000000000000000
	dc.l	%00000000000000000000000000000000
	dc.l	%11111000000111111111100000011111
	dc.l	%11111000000111111111100000011111
	dc.l	%10011000000000000000000000011111
	dc.l	%10011000000000000000000000011111
	dc.l	%10011000000000000000000000011111
	dc.l	%10001100000000000000000000111111
	dc.l	%10001111111111111111111111111000
	dc.l	%10001111111111111111111111111000
	dc.l	%10001111111111111111111111111000
	dc.l	%11000000000000000000000000110000
	dc.l	%01111000000000000000000000110000
	dc.l	%01111000000000000000000000110000
	dc.l	%01111000000000000000000000110000
	dc.l	%00001100000000000000000000110000
	dc.l	%00001100000000000000000000110000
	dc.l	%00010111111111111111111111111000
	dc.l	%00010111111111111111111111111000
	dc.l	%00010111111111111111111111111000
	dc.l	%00010111111111111111111111111000
	dc.l	%00101100000000000000000000111100
	dc.l	%01101000000000000000000000011110
	dc.l	%10011000000000000000000000011111
	dc.l	%10011000000000000000000000011111
	dc.l	%10010000000000000000000000001111
	dc.l	%10010000000000000000000000001111
	dc.l	%10010000000000000000000000001111
	dc.l	%11110000000000000000000000001111
	dc.l	%11110000000000000000000000001111
	dc.l	%00000000000000000000000000000000
	dc.l	%00000000000000000000000000000000
	
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
	dc.w DIWSTRT,(DISPLAY_Y<<8)!(DISPLAY_X+DISPLAY_X_MASQUES) ;$2c81	
	dc.w DIWSTOP,((DISPLAY_Y+DISPLAY_DY-256)<<8)!(DISPLAY_X+DISPLAY_DX-256+1) ;$2cc1
	dc.w DDFSTRT,((DISPLAY_X-17)>>1)&$00FC	;$0038 ;$30
	dc.w DDFSTOP,((DISPLAY_X-17+((((DISPLAY_DX)>>4)-1)<<4))>>1)&$00FC	;$00d0 ;c8
	;Ce qui revient ((DISPLAY_X-17+DISPLAY_DX-16)>>1)&$00FC si DISPLAY_DX est multiple de 16

	
	dc.w BPLCON0,(DISPLAY_DEPTH<<12)!$0200

	dc.w BPLCON1
CplBPLCON1:
	dc.w 0
	
	dc.w BPLCON2,0
	dc.w BPL1MOD,(BITPLANE_DX-DISPLAY_DX)>>3
	dc.w BPL2MOD,(BITPLANE_DX-DISPLAY_DX)>>3

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
	dc.w 	BPL1PTL,0,BPL1PTH,0
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
;Couleurs

	IFNE CST.DEBUG.DisplayRaster
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
	

	dc.w	$0180,$0000,$0182,$0aaa,$0184,$0e00,$0186,$0a00
	dc.w	$0188,$0d80,$018a,$0fe0,$018c,$08f0,$018e,$0080
	dc.w	$0190,$00b6,$0192,$00dd,$0194,$00af,$0196,$007c
	dc.w	$0198,$000f,$019a,$070f,$019c,$0c0e,$019e,$0c08
	dc.w	$01a0,$0620,$01a2,$0e52,$01a4,$0a52,$01a6,$0fca
	dc.w	$01a8,$0333,$01aa,$0444,$01ac,$0555,$01ae,$0666
	dc.w	$01b0,$0777,$01b2,$0888,$01b4,$0999,$01b6,$0aaa
	dc.w	$01b8,$0ccc,$01ba,$0ddd,$01bc,$0eee,$01be,$0fff
	
	dc.l 	-2	
	dc.l 	-2	

;CopListDataEnd:


	

;Bitplanes

	section	screen,bss_c
	

ScreenA	
	ds.b	DISPLAY_DEPTH*TAILLE_BITPLANE
	;INCBIN "BplA.320x288x1p.bmp.bin"	;32 à 127
	;ds.b	32*BITPLANE_DX>>3
	EVEN
ScreenB 
	ds.b	DISPLAY_DEPTH*TAILLE_BITPLANE
	;INCBIN "BplB.320x288x1p.bmp.bin"	;32 à 127
	;ds.b	32*BITPLANE_DX>>3
	EVEN
ScreenC 
	ds.b	DISPLAY_DEPTH*TAILLE_BITPLANE
	;INCBIN "320x288x1p.bmp.bin"	;32 à 127
	EVEN
Tiles:
	INCBIN "Tiles320x256x32c.iff.bin" ;10x8 Tiles de 32x32 pix

	even
	
;ScreenA	ds.b	DISPLAY_DEPTH*TAILLE_BITPLANE
;ScreenB	ds.b	DISPLAY_DEPTH*TAILLE_BITPLANE
;ScreenC	ds.b	DISPLAY_DEPTH*TAILLE_BITPLANE
