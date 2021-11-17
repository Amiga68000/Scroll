;SCROLL x,y

;-- LIBRARIES
custom		=	$dff000
execbase	=	4
Forbid = -132
OldOpenLibrary = -408
Permit = -138

;-- REGISTRES
DMACON 	equ $096
DMACONR equ $002
BPLCON0 equ $100
BPLCON1 equ $102
BPLCON2 equ $104
BPL1MOD equ $108
BPL2MOD equ $10A
DIWSTRT equ $08E
DIWSTOP equ $090
DDFSTRT equ $092
DDFSTOP equ $094
COP1LCH equ $080
COP1LC=COP1LCH
COPJMP1 equ $088
COLOR00 equ $180
COLOR=COLOR00
BPL1PTH equ $0E0
BPLPT = BPL1PTH
VPOSR 	equ $004
BLTCON0 equ $040
BLTCON1 equ $042
BLTSIZE equ $058
BLTAFWM equ $044
BLTALWM equ $046
BLTAMOD equ $064
BLTBMOD equ $062
BLTCMOD equ $060
BLTDMOD equ $066
BLTAPTH equ $050
BLTAPT = BLTAPTH
BLTDPTH equ $054
BLTDPT = BLTDPTH

;-- CONFIG
BPL_DX		=	320
BPL_DY		=	192
BPL_DEPTH	=	4
MODULO		=	2
BPL_WIDTH	=	BPL_DX/8+MODULO
BPL_SIZE	=	BPL_WIDTH*BPL_DY
SCR_SIZE	=	BPL_SIZE*BPL_DEPTH
MAP_WIDTH	=	35
MAP_HEIGHT	=	35
BLK_WIDTH	=	16
BLK_HEIGHT	=	16
SCROLL_SPEED= 1

;-- MACROS
vsync:	macro
.wait_vsync\@:
	move.l	vposr(a5),d0
	and.l	#$1ff00,d0
	cmp.l	#$11000,d0
	bne.s	.wait_vsync\@
	endm

wait_blt:	macro
	btst	#14,dmaconr(a5)
.loop_wait_blt\@:
	btst	#14,dmaconr(a5)
	bne.s	.loop_wait_blt\@
	endm

MOD:	MACRO	\1,\2		* \1 chiffre a moduler   \2 la base du modulo	
.MODULO_GO_ON\@:
	cmp.w	\2,\1
	blt.s	.MODULO_IS_FINISH\@
	sub.w	\2,\1
	bra.s	.MODULO_GO_ON\@
.MODULO_IS_FINISH\@:
	ENDM


******************************************************
**************  programme principal  *****************
******************************************************
	move.l	(execbase).w,a6
	lea	custom,a5
	jsr	Forbid(a6)
	move.w	#$03e0,dmacon(a5)	* all dma off except disk

	move.w	#(BPL_DEPTH<<12)+$200,bplcon0(a5)
	clr.w	bplcon1(a5)
	clr.w	bplcon2(a5)		
	move.w	#BPL_WIDTH*(BPL_DEPTH-1),bpl1mod(a5)
	move.w	#BPL_WIDTH*(BPL_DEPTH-1),bpl2mod(a5)

	move.w	#$2981,diwstrt(a5)	*\ 
	move.w	#$e9c0,diwstop(a5)	* > init un ecran 320*192
	move.w	#$0030,ddfstrt(a5)	* > avec un mot en plus pour
	move.w	#$00d0,ddfstop(a5)	*/  le shift

	bsr	build_coplist		
	
	move.l	coplist_adr,cop1lc(a5)	* > run my coplist
	clr.w	copjmp1(a5)		*/
	
	move.w	#$83c0,dmacon(a5)	* dma blitter,copper & plan de bits on
	
	move.w	#$f00,color+15*2(a5)
	move.w	#$0f0,color+1*2(a5)
	move.w	#$00f,color+6*2(a5)

	bsr	INIT_FIRST_SCR



;-- BOUCLE
main_loop:
	vsync
	move.w	#-1,color(a5)


	bsr	INIT_SCR_PT_ADR	;SCR_PT_ADR = ecran1 + octet décallage
	bsr	SCROLL
	bsr	build_coplist		


	bsr	CHANGE_DIRECTION_WITH_KEYBOARD


	;limitation ORI_X et ORI_Y
	tst.w	ORI_X
	bge.s	.ORI_X_NE_SORT_PAS_A_GAUCHE
	clr.w	ORI_X
.ORI_X_NE_SORT_PAS_A_GAUCHE
	cmp.w	#MAP_WIDTH*16-BPL_DX-1,ORI_X
	ble.s	.ORI_X_NE_SORT_PAS_A_DROITE
	move.w	#MAP_WIDTH*16-BPL_DX-1,ORI_X
.ORI_X_NE_SORT_PAS_A_DROITE
	tst.w	ORI_Y
	bge.s	.ORI_Y_NE_SORT_PAS_EN_HAUT
	clr.w	ORI_Y
.ORI_Y_NE_SORT_PAS_EN_HAUT
	cmp.w	#MAP_HEIGHT*16-BPL_DY-1,ORI_Y
	ble.s	.ORI_Y_NE_SORT_PAS_EN_BAS
	move.w	#MAP_HEIGHT*16-BPL_DY-1,ORI_Y
.ORI_Y_NE_SORT_PAS_EN_BAS

	
	clr.w	color(a5)
	move.b	$bfec01,d0	*\
	not	d0		* >capture the key wich is pressed
	ror.b	#1,d0		*/ and put is code RAW in d0
	cmp.b	#$45,d0		*\
	beq	init_end	*/ sort si on press sur esc
	btst	#6,$bfe001 ;ou si clic souris
	bne	main_loop
	
******** init end ***********
*	reactivation de l'old coplist
init_end:
	wait_blt
	move.l	(execbase).w,a6
	lea	GfxName(pc),a1		* nom de la library ds a1
	moveq	#0,d0			* version 0 (the last)
	;CALLEXEC	OpenLibrary	* lib graphique ouverte
	jsr	OldOpenLibrary(a6)

	move.l	d0,a4			* adr de graphicbase ds a4
	move.l	38(a4),cop1lc(a5)	* chargement de l'adr de
	clr.w	copjmp1(a5)		* l'old coplist et lancement

	move.w	#$83e0,dmacon(a5)	* activation des canaux dma necessaires
	;CALLEXEC	Permit		* multi switching autorise
	jsr	Permit(a6)
fin:	moveq	#0,d0	* flag d'erreur desactive
	rts
GfxName:		dc.b	"graphics.library",0
	even




CHANGE_DIRECTION_WITH_KEYBOARD: 
	move.b	$bfec01,d0	*\
	not	d0		* >capture the key wich is pressed
	ror.b	#1,d0		*/ and put is code RAW in d0
	ext.w	d0
	lea	TAB_DELTA_X_Y_ACOORDING_TO_KEYBOARD,a0
.TRY_ANOTHER_KEY:
	tst.w	(a0)
	blt.s	.TST_KEY_FINISH
	cmp.w	(a0),d0
	bne.s	.NOT_THIS_KEY
	move.w	2(a0),d0
	add.w	d0,ORI_X
	move.w	4(a0),d0
	add.w	d0,ORI_Y
	bra.s	.TST_KEY_FINISH
.NOT_THIS_KEY:
	addq.l	#6,a0	
	bra.s	.TRY_ANOTHER_KEY
.TST_KEY_FINISH:
	rts
s	SET	SCROLL_SPEED
TAB_DELTA_X_Y_ACOORDING_TO_KEYBOARD:
	dc.w	$3f,s,-s,$3e,0,-s,$3d,-s,-s,$2d,-s,0,$2f,s,0,$1d,-s,s
	dc.w	$1e,0,s,$1f,s,s
	dc.w	-1
**************************************** END_CHANGE_DIRECTION_WITH_KEYBOARD



;-- Offset.w décalage x
INIT_SCR_PT_ADR: 
	move.l	LOG_SCR_ADR,a0	;ecran1
	move.w	ORI_X,d0		;coordonnée x
	and.w	#$fff0,d0		;modulo /16
	lsr.w	#3,d0			;*2 (pas = mot)
	lea	(a0,d0.w),a0	
	move.l	a0,SCR_PT_ADR 	;SCR_PT_ADR = ecran1 + octet décallage
	rts


;-- Scrolling
SCROLL: 
	move.w	ORI_Y,d0
	move.w	#BPL_DY+BLK_HEIGHT,d1
	MOD	d0,d1
	move.w	d0,START_FIRST_PART
	neg.w	d0
	add.w	#BPL_DY+BLK_HEIGHT,d0
	cmp.w	#BPL_DY,d0
	ble.s	.FIRST_PART_SIZE_NOT_BIGGER_THAN_SCREEN
	move.w	#BPL_DY,d0
.FIRST_PART_SIZE_NOT_BIGGER_THAN_SCREEN
	move.w	d0,FIRST_PART_SIZE


	move.w	ORI_Y,d0
	add.w	#BPL_DY,d0
	move.w	#BPL_DY+BLK_HEIGHT,d1
	MOD	d0,d1	;d0 = d0 MOD d1
	move.w	d0,END_SECOND_PART
	
	
	;-- MAP_PTR = MAP(ORI_X,ORI_Y)
	lea	MAP,a0
	move.w	ORI_X,d0
	lsr.w	#4,d0
	lea	(a0,d0.w),a0
	move.w	ORI_Y,d0
	lsr.w	#4,d0
	mulu	#MAP_WIDTH,d0
	add.l	d0,a0
	move.l	a0,MAP_PTR

;--- BLITTER
; 		AREA MODE
; Bit 	BLTCON0 BLTCON1 
; 15 	ASH3 	BSH3
; 14 	ASH2 	BSH2
; 13 	ASH1 	BSH1
; 12 	ASA0 	BSH0
; 11 	USEA 	0
; 10 	USEB 	0
; 09 	USEC 	0
; 08 	USED 	0
; 07 	LF7 	DOFF
; 06 	LF6 	0
; 05 	LF5 	0
; 04 	LF4 	EFE
; 03 	LF3 	IFE
; 02 	LF2 	FCI
; 01 	LF1 	DESC
; 00 	LF0 	LINE(=0)

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

* on init les registres blitter qui resteront ainsi durant toute la routine
	WAIT_BLT
	move.w	#%0000100111110000,BLTCON0(a5)	;$09f0; D=A
	clr.w	BLTCON1(a5)
	move.w	#-1,BLTAFWM(a5)	;Blitter first-word mask for source A
	move.w	#-1,BLTALWM(a5)	;Blitter last-word mask for source A
	move.w	#BPL_WIDTH-2,BLTDMOD(a5)
	clr.w	BLTAMOD(a5)


* maintenant on affiche les blk pour le scroll en x
	move.w	ORI_X,d0
	cmp.w	OLD_ORI_X,d0
	ble.s	.DONT_SCROLL_TOWARD_RIGHT ;saute si pas de modif Y
	;les positions ont changé
	move.w	OLD_ORI_X,d0
	add.w	#BPL_DX-1,d0
	and.w	#$fff0,d0
	move.w	ORI_X,d1
	add.w	#BPL_DX-1,d1
	and.w	#$fff0,d1
	cmp.w	d0,d1
	beq.s	.DONT_SCROLL_TOWARD_RIGHT	;saute si en butée Y
	;on n'est pas en butée Y
	move.l	SCR_PT_ADR,a0
	move.w	START_FIRST_PART,d0
	and.w	#$fff0,d0
	mulu	#BPL_WIDTH*BPL_DEPTH,d0
	add.l	d0,a0
	lea	BPL_WIDTH-MODULO(a0),a0
	move.l	MAP_PTR,a1
	add.l	#BPL_DX/16,a1
	bsr	AFF_A_COLUMM_OF_BLK
.DONT_SCROLL_TOWARD_RIGHT:	
	move.w	ORI_X,d0
	cmp.w	OLD_ORI_X,d0
	bge.s	.DONT_SCROLL_TOWARD_LEFT	
	move.w	OLD_ORI_X,d0
	and.w	#$fff0,d0
	move.w	ORI_X,d1
	and.w	#$fff0,d1
	cmp.w	d0,d1
	beq.s	.DONT_SCROLL_TOWARD_LEFT
	move.l	SCR_PT_ADR,a0
	move.w	START_FIRST_PART,d0
	and.w	#$fff0,d0
	mulu	#BPL_WIDTH*BPL_DEPTH,d0
	add.l	d0,a0
	move.l	MAP_PTR,a1
	bsr	AFF_A_COLUMM_OF_BLK
.DONT_SCROLL_TOWARD_LEFT:	



* maintenant on affiche les blk pour le scroll en y
	move.w	ORI_Y,d0
	cmp.w	OLD_ORI_Y,d0
	ble.s	.DONT_SCROLL_TOWARD_DOWN	
	move.w	OLD_ORI_Y,d0
	add.w	#BPL_DY-1,d0
	and.w	#$fff0,d0
	move.w	ORI_Y,d1
	add.w	#BPL_DY-1,d1
	and.w	#$fff0,d1
	cmp.w	d0,d1
	beq.s	.DONT_SCROLL_TOWARD_DOWN
	move.l	SCR_PT_ADR,a0
	move.w	END_SECOND_PART,d0
	and.w	#$fff0,d0
	mulu	#BPL_WIDTH*BPL_DEPTH,d0
	add.l	d0,a0
	move.l	MAP_PTR,a1
	add.l	#(BPL_DY/16)*MAP_WIDTH,a1
	bsr	AFF_A_LINE_OF_BLK
.DONT_SCROLL_TOWARD_DOWN:	
	move.w	ORI_Y,d0
	cmp.w	OLD_ORI_Y,d0
	bge.s	.DONT_SCROLL_TOWARD_UP	
	move.w	OLD_ORI_Y,d0
	and.w	#$fff0,d0
	move.w	ORI_Y,d1
	and.w	#$fff0,d1
	cmp.w	d0,d1
	beq.s	.DONT_SCROLL_TOWARD_UP
	move.l	SCR_PT_ADR,a0
	move.w	START_FIRST_PART,d0
	and.w	#$fff0,d0
	mulu	#BPL_WIDTH*BPL_DEPTH,d0
	add.l	d0,a0
	move.l	MAP_PTR,a1
	bsr	AFF_A_LINE_OF_BLK
.DONT_SCROLL_TOWARD_UP:	

	
	
	move.w	ORI_X,OLD_ORI_X
	move.w	ORI_Y,OLD_ORI_Y
	rts
	
ORI_X:	 	ds.w	1		*\ coor du coin en haut a gauche
ORI_Y:		ds.w	1		*/
OLD_ORI_X:	ds.w	1
OLD_ORI_Y:	ds.w	1
START_FIRST_PART:	ds.w	1
END_SECOND_PART:	ds.w	1
FIRST_PART_SIZE:	ds.w	1
MAP_PTR:			ds.l	1





AFF_A_COLUMM_OF_BLK:  
* IN: a0= adr ou on va poser les blk
*     a1= adr de la map ou on va chercher quel blk afficher
* OUT: rien
	lea	TAB_ADR_BLK_GFX,a2
	moveq	#0,d2
	move.w	#BPL_DY/16-1+1,d0
.LOOP_AFF_EACH_BLK:
	move.b	(a1),d1
	lea	MAP_WIDTH(a1),a1
	ext.w	d1
	lsl.w	#2,d1
	move.l	(a2,d1.w),d1
	WAIT_BLT
	move.l	a0,BLTDPT(a5)
	move.l	d1,BLTAPT(a5)
	move.w	#BLK_HEIGHT*BPL_DEPTH*64+BLK_WIDTH/16,BLTSIZE(a5)
	lea	BLK_HEIGHT*BPL_WIDTH*BPL_DEPTH(a0),a0
	tst.w	d2
	bne.s	.SECOND_PART_ALREADY_BEGIN	
	move.l	SCR_PT_ADR,a3
	add.l	#(BPL_DY+BLK_HEIGHT-1)*BPL_WIDTH*BPL_DEPTH,a3
	cmp.l	a3,a0
	ble.s	.FIRST_PART_NOT_TOTALLY_PRINT
	sub.l	#(BPL_DY+BLK_HEIGHT)*BPL_WIDTH*BPL_DEPTH,a0
	moveq	#-1,d2
.SECOND_PART_ALREADY_BEGIN	
.FIRST_PART_NOT_TOTALLY_PRINT:

	dbf	d0,.LOOP_AFF_EACH_BLK
	
	rts




AFF_A_LINE_OF_BLK:  
* IN: a0= adr ou on va poser les blk
*     a1= adr de la map ou on va chercher quel blk afficher
* OUT: rien
	lea	TAB_ADR_BLK_GFX,a2
	moveq	#BPL_WIDTH/2-1,d0
.LOOP_AFF_EACH_BLK:
	move.b	(a1)+,d1
	ext.w	d1
	lsl.w	#2,d1
	move.l	(a2,d1.w),d1
	WAIT_BLT
	move.l	a0,BLTDPT(a5)
	move.l	d1,BLTAPT(a5)
	move.w	#BLK_HEIGHT*BPL_DEPTH*64+BLK_WIDTH/16,BLTSIZE(a5)
	addq.l	#BLK_WIDTH/8,a0
	dbf	d0,.LOOP_AFF_EACH_BLK
	rts





INIT_FIRST_SCR: 
	clr.w	ORI_X
	clr.w	ORI_Y
	clr.w	OLD_ORI_X
	clr.w	OLD_ORI_Y
* on init les registres blitter qui resteront ainsi durant toute la routine
	WAIT_BLT
	move.w	#$09f0,BLTCON0(a5)
	clr.w	BLTCON1(a5)
	move.w	#-1,BLTAFWM(a5)
	move.w	#-1,BLTALWM(a5)
	move.w	#BPL_WIDTH-2,BLTDMOD(a5)
	clr.w	BLTAMOD(a5)

* maintenant on affiche le premier ecran
	move.l	LOG_SCR_ADR,a0
	move.l	PHY_SCR_ADR,a3
	lea	MAP,a1
	lea	TAB_ADR_BLK_GFX,a2
	moveq	#BPL_DY/16+1-1,d2
.LOOP_AFF_EACH_LINE:
		move.w	#BPL_WIDTH/2-1,d0
.LOOP_AFF_EACH_BLK:
			move.b	(a1)+,d1
			ext.w	d1
			lsl.w	#2,d1
			move.l	(a2,d1.w),d1
			WAIT_BLT
			move.l	a0,BLTDPT(a5)
			move.l	d1,BLTAPT(a5)
			move.w	#16*BPL_DEPTH*64+1,BLTSIZE(a5)
			addq.l	#2,a0
			WAIT_BLT
			move.l	a3,BLTDPT(a5)
			move.l	d1,BLTAPT(a5)
			move.w	#16*BPL_DEPTH*64+1,BLTSIZE(a5)
			addq.l	#2,a3
		dbf	d0,.LOOP_AFF_EACH_BLK
		lea	16*BPL_WIDTH*BPL_DEPTH-BPL_WIDTH(a0),a0
		lea	16*BPL_WIDTH*BPL_DEPTH-BPL_WIDTH(a3),a3
		lea	MAP_WIDTH-BPL_WIDTH/2(a1),a1
	dbf	d2,.LOOP_AFF_EACH_LINE
	rts






;-- CREATION DE LA COPPERLIST
build_coplist: 
	move.l	COPLIST_ADR(pc),a0
	
	;-- DECALAGE X ECRAN
	move.w	ORI_X,d0
	and.w	#$000f,d0
	neg.w	d0
	add.w	#$f,d0	;Bitplanes pairs
	move.w	d0,d1
	lsl.w	#4,d0	;Bitplanes impairs
	or.w	d1,d0
	move.w	#BPLCON1,(a0)+
	move.w	d0,(a0)+

	;-- REGISTRES BITPLANES
	move.l	SCR_PT_ADR,d2
	move.w	START_FIRST_PART,d0
	mulu	#BPL_WIDTH*BPL_DEPTH,d0
	add.l	d0,d2
	moveq	#BPL_DEPTH-1,d0
	move.w	#bplpt,d1
.loop_init_BPL_in_clist
	move.w	d1,(a0)+	;Reg BPLxPTH
	addq.l	#2,d1
	swap	d2
	move.w	d2,(a0)+	;adr BPLxPTH
	swap	d2
	move.w	d1,(a0)+	;reg BPLxPTL
	addq.l	#2,d1
	move.w	d2,(a0)+	;adr BPLxPTL
	add.l	#BPL_WIDTH,d2
	dbf	d0,.loop_init_BPL_in_clist


	;-- WAIT ECRAN SPLIT ?
	moveq	#$29,d0
	add.w	FIRST_PART_SIZE,d0
	lsl.w	#8,d0
	or.w	#$0001,d0
	move.w	d0,(a0)+
	move.w	#$fffe,(a0)+

	;-- REGISTRES BITPLANES
	move.l	SCR_PT_ADR,d2
	moveq	#BPL_DEPTH-1,d0
	move.w	#bplpt,d1
.loop_init_BPL_in_clist1
	move.w	d1,(a0)+
	addq.l	#2,d1
	swap	d2
	move.w	d2,(a0)+
	swap	d2
	move.w	d1,(a0)+
	addq.l	#2,d1
	move.w	d2,(a0)+
	add.l	#BPL_WIDTH,d2
	dbf	d0,.loop_init_BPL_in_clist1

	
	move.l	#$fffffffe,(a0)+	* montre la fin de la clist
	rts
********************************************************* END_build_coplist

******** datas
*	variables
TAB_ADR_BLK_GFX:	dc.l	BLK0_GFX,BLK1_GFX,BLK2_GFX
SCR_PT_ADR:	ds.l	1
LOG_SCR_ADR:	dc.l	ecran1
PHY_SCR_ADR:	dc.l	ecran2
COPLIST_ADR:	dc.l	coplist
MAP:	
 dc.b 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
 dc.b 0,0,0,1,1,1,0,0,0,1,0,0,0,0,0,1,0,1,1,1,1,1,1,1,0,0,0,0,0,1,1,0,0,0,0
 dc.b 0,0,1,0,0,0,1,0,0,1,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,1,1,1,1,0,0,0
 dc.b 0,0,1,0,0,0,1,0,0,1,0,1,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,1,1,0,0,0,0
 dc.b 0,0,1,1,1,1,1,0,0,1,0,0,1,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,1,1,0,0,0,0
 dc.b 0,0,1,0,0,0,1,0,0,1,0,0,0,1,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 dc.b 0,0,1,0,0,0,1,0,0,1,0,0,0,0,1,1,0,0,0,0,1,0,0,0,0,0,0,0,0,1,1,0,0,0,0
 dc.b 0,0,1,0,0,0,1,0,0,1,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,1,1,0,0,0,0
 dc.b 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 dc.b 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 dc.b 0,0,1,1,1,1,0,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0,1,0,0,0,1,1,0,1,0,0,0,1,0
 dc.b 0,0,1,0,0,0,0,1,0,0,1,0,1,0,0,0,1,0,0,0,0,1,0,1,0,1,0,0,0,1,1,0,1,1,0
 dc.b 0,0,1,1,1,0,0,1,0,0,1,0,1,0,0,0,1,0,1,1,0,1,0,1,0,0,1,0,0,1,0,1,0,1,0
 dc.b 0,0,1,0,0,0,0,1,0,0,1,0,1,0,0,0,1,0,0,0,0,1,1,1,0,0,0,1,0,1,0,0,0,1,0
 dc.b 0,0,1,0,0,0,0,0,1,1,0,0,1,1,1,0,1,1,1,0,0,1,0,1,0,1,1,0,0,1,0,0,0,1,0
 dc.b 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 dc.b 0,0,0,0,0,0,0,0,0,0,1,1,0,0,1,0,1,0,1,1,1,0,1,1,1,0,0,0,0,0,0,0,0,0,0
 dc.b 0,0,0,0,0,0,0,0,0,1,0,0,1,0,1,0,1,0,0,1,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0
 dc.b 0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,1,1,0,0,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0
 dc.b 0,0,0,0,0,0,0,0,0,1,0,0,1,0,1,0,1,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0
 dc.b 0,0,0,0,0,0,0,0,0,0,1,1,0,0,1,0,1,0,1,1,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0
 dc.b 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
 dc.b 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 dc.b 0,0,1,1,1,1,0,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0,1,0,0,0,1,1,0,1,0,0,0,1,0
 dc.b 0,0,1,0,0,0,0,1,0,0,1,0,1,0,0,0,1,0,0,0,0,1,0,1,0,1,0,0,0,1,1,0,1,1,0
 dc.b 0,0,1,1,1,0,0,1,0,0,1,0,1,0,0,0,1,0,2,2,0,1,0,1,0,0,1,0,0,1,0,1,0,1,0
 dc.b 0,0,1,0,0,0,0,1,0,0,1,0,1,0,0,0,1,0,0,0,0,1,1,1,0,0,0,1,0,1,0,0,0,1,0
 dc.b 0,0,1,0,0,0,0,0,1,1,0,0,1,1,1,0,1,1,1,0,0,1,0,1,0,1,1,0,0,1,0,0,0,1,0
 dc.b 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 dc.b 0,0,0,0,0,0,0,0,0,0,1,1,0,0,1,0,1,0,1,1,1,0,1,1,1,0,0,0,0,0,0,0,0,0,0
 dc.b 0,0,0,0,0,0,0,0,0,1,0,0,1,0,1,0,1,0,0,1,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0
 dc.b 0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,1,1,0,0,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0
 dc.b 0,0,0,0,0,0,0,0,0,1,0,0,1,0,1,0,1,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0
 dc.b 0,0,0,0,0,0,0,0,0,0,1,1,0,0,1,0,1,0,1,1,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0
 dc.b 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1

	section	GFX,DATA_C
BLK0_GFX:	REPT	16
		dc.w	-1,-1,-1,-1
		ENDR
BLK1_GFX:	REPT	16
		dc.w	-1,0,0,0
		ENDR
BLK2_GFX:	REPT	16
		dc.w	0,-1,-1,0
		ENDR

	section	ZONE_CHIP,BSS_C
		ds.l	1
ecran1:		ds.l	(scr_size*2)/4
ecran2:		ds.l	(scr_size*2)/4
coplist:	ds.l	1000*4	* taiile inconnue donc on prevoit gros
	end