 *-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000
START:                  ; first instruction of program

* Put program code here
    
BOB32_Y equ 150
BOB32_DY equ 32
BITPLANE_DY equ 256+64 
     
    
    move.w  #BOB32_Y,d1
    move.w  #BOB32_DY,d2
    
    
    
    
    add.w   AffLigneY,d1    ;D1 = BOB_Ligne_Ydeb = BOB_Y + AffLigneY
    cmp.w   #BITPLANE_DY,d1
    blo .saut1
        ;CAS 1 : BITPLANE_DY <= BOB_Ligne_Ydeb
        sub.w	#BITPLANE_DY,d1
		;deplacer en 1 bloc d0=x, d1=y
        bsr	Copy_Blit_BOB_h32 ;d0=x, d1=y, a0=adr BOB, a5=$dff000, [a1], [d2]
        rts
.saut1:
        ;BITPLANE_DY => BOB_Ligne_Ydeb
        move.w  d1,d4
        add.w   #BOB32_DY,d4  ;d4 = BOB_Ligne_YFin
        cmp.w   #BITPLANE_DY,d4
        blo     .saut2
            ;CAS 2 : BITPLANE_DY <= BOB_Ligne_YFin
            ;deplacer en 2 blocs
            move.w  d4,d5
            move.w  #BITPLANE_DY,d4 ;BITPLANE_DY - 1 - BOB_Ligne_Ydeb
            sub.w   d1,d4
            ;bloc 1 : d1 = Y1, d4 = DY
            move.w	d0,d3	;sauve d0=x.pix
			bsr	Copy_Blit_BOB_hd4 ;d0=x, d1=y, a0=adr BOB, a5=$dff000, [a1], [d2]

			move.w	d3,d0	;restaure d0=x.pix
            moveq.l #0,d1
            move.w  d5,d4
            sub.w   #BITPLANE_DY,d4 ;d4 = BOB_Ligne_YFin - BITPLANE_DY 
            ;bloc 2 : d1 = Y1, d4 = DY
            bsr	Copy_Blit_BOB_hd4 ;d0=x, d1=y, a0=adr BOB, a5=$dff000, [a1], [d2] 

        rts  
.saut2:
            ;CAS 3 : BITPLANE_DY > BOB_Ligne_YFin
            ;deplacer en 1 bloc 
            ;d1 = Y1, d2 = DY
            bsr	Copy_Blit_BOB_h32 ;d0=x, d1=y, a0=adr BOB, a5=$dff000, [a1], [d2]
            
        rts
        
Copy_Blit_BOB_h32:
    rts
Copy_Blit_BOB_hd4:
    rts    
        
        
        
        
        
AffLigneY: dc.w    138


    SIMHALT             ; halt simulator

* Put variables and constants here

    END    START        ; last line of source




*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
