 *-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000
START:                  ; first instruction of program

* Put program code here
        
        
   	move.w	#0,d3
    move.w  d3,d5


	not.w	d3
	add.w	#1,d3
	and.w	#$f,d3
	move.w	d3,d4
	lsl.w	#4,d4
	or.w	d3,d4	;TODO DEBUG pour 2eme plan enlever ';'

	
	
	;-- offset.w décalage bitplane x
	moveq.l	#0,d3
	move.w	d5,d3
	add.w	#15,d3
	lsr.w	#3,d3
    and.w   #$fffe,d3	
    sub.l   #2,d3
    
    
    moveq.l	#0,d2
	move.w	d5,d2
	;sub.l	#1,d2
	lsr.l	#3,d2
    and.w   #$fffe,d2	
    ;sub.l   #2,d3
    
    rts

    SIMHALT             ; halt simulator

* Put variables and constants here

    END    START        ; last line of source






*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
