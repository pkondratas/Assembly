;programoje nuskaitome po viena failo varda, ji isnagrinejame ir tada skaitome kita(taip kol nebra command line elementu
.model small
.stack 100h

.data
	lowerCLetters dw 0
	capitalLetters dw 0
	symbolCount dw 0
	wordCount dw 1
	help_msg db "Programa, kuri atspausdina pateiktu failu simboliu, zodziu, mazuju ir didziuju raidziu skaiciu$", 10, 13
	file_error db "Nepavyko atidaryti failo$"
	msg_lowerCLetters db "Lower case letters: $"
	msg_upperCLetters db "Upper case letters: $"
	msg_symbolCount db "Symbol count: $"
	msg_wordCount db "Word count: $"
	newline	db 13, 10, "$"
	handle dw 0
	buff db 255 dup(?)
	fileName db 255 dup(0)
	fileNameSize db 0 
	currentSymbol db ?
.code
start:
	
	mov ax, @data
	mov ds, ax
	
	call needHelp
	
	mov bx, 82h		;isirasome pirmo simbolio adresa
	mov si, offset fileName		;pirmojo masyvo elemento adresas
	
	cmp byte ptr es:[80h], 0		;tikriname ar yra argumentu komandineje eiluteje
	mov cl, byte ptr es:[80h]		;persikeliame is anksto ilgi nors ir jis gali buti 0
	jne getFileNames				;jie ne nulis, sokam i getFileNames
	jmp closeProgram
getFileNames:
	l2:									;loopas gauti visu failo vardu pavadinimus(po viena), ieskant tarpu 
		cmp byte ptr es:[bx], 32		;lyginame simboli bx vietoje(82, 83, 84 ir t.t) su tarpo ASCII
		je openFile						;jei tarpas, sokam atidaryti failo
		cmp byte ptr es:[bx], 13		;jei pabaiga eilutes(cia gal negerai) tai irgi atidarom iki enterio)
		je openFile						;jei kita eilute, sokam atidaryt failo
		mov dl, byte ptr es:[bx]		;jei niekur nesokom, reiskias tai yra kitas simbolis ir ji irasom i dl ir
		mov [si], dl					;persikeliam i si, kur yra musu bufferis filo vardo, pilnas nuliu(kad atidarytume faila)
		
		inc si							;padidiname si kitam simboliui
		inc fileNameSize				;failo vardo ilgi padidiname vienu
		jmp sameName					;jei vis dar skaitome ta pati varda, sokam i sameName
		
		continue:						;vieta, kai griztame is failo nuskaitymo
		pop bx							;popinam dabartine vieta komandineje eiluteje(kadangi naudojome bx kitur)
		pop cx							;popinam cx, kad gautume kiek dar liko skaityti komandines eilutes
		sameName:
		inc bx							;didiname vienu kad skaitytume kita elementa
	loop l2
	jmp closeProgram	;uzdarome programa nuskaicius visus failus ir cmd line

openFile:
	push cx		;veliau reikes skaiciaus kiek dar reikia skaityti cmd line
	push bx		;veliau reikes esamos pozicijos cmd line
	
	mov dx, offset fileName
	mov ax, 3d00h	;atidarome faila(nereikia gale vardo ideti nulio, nes visas masyvas pilnas nuliu)
	int 21h
	jc ifFileWasNotOpened			;jei nepavyko atidaryti tai iseinam
	
	mov [handle], ax
	mov bx, ax
	
	reading:		;skaitymas
		mov ah,3fh
		mov cx,100h
		mov dx, offset buff
		int 21h ; Skaityti faila
		jc exit
		or ax,ax
		jz exit ; EOF - failo pabaiga
		call countLowerCaseLetters		;nuskaitome mazasias raides
		call countCapitalLetters		;nuskaitome didziasias raides
		call countWords					;skaiciuojame zodzius
		call countSymbols				;skaiciuojam simbolius
		jmp reading						;skaitom kol visi simboliai nuskaityti(po 65k kazkiek buna overflow)

exit:		;kai nuskaitome visa faila isprintiname rezultatus
	call printFileName		;failo vardas
	call printLowerCaseLetters		;mazosios raides
	call printUpperCaseLetters		;didziosios raides
	call printWordCount				;zodziu skaicius
	call printSymbolCount			;simboliu skaicius
	ifFileWasNotOpened:
	mov bx,[Handle]
	or bx,bx
	jz closeProgram		;jei klaida uzdarome programa
	mov ah,3Eh			;close file
	int 21h
	
resetToPrimary:		;resetinam reiksmes, kur yra failo vardas i 0, kad vel visas masyvas butu pilnas 0  ir irasytume grize i cmd line skaityma kitus simbolius
	resetLoop:
		mov dl, 48		;i dl irasom 0
		mov [si], dl	;i bufferio si vieta irasom nuli(si yra paskutine buvusi vieta pries tai paimta)
		cmp fileNameSize, 0	;jei failo ilgis lygus nuliui,
		je continue		;griztam i continue, kuris yra cmd line skaitymo vietoje l2(getFileNames)
		dec fileNameSize ;mazinam ir failo vardo dydi, kad butu 0, kadangi irgi bus nuajas
		dec si
	jmp resetLoop
	
closeProgram:
	mov ax,04C00h
	int 21h 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ieskoma ar buvo ivestas '/?' iki kitu kabliataskiu
needHelp proc
    
    mov ch, 0
    mov cl, es:[0080h]
    cmp cx, 0
    je exitFindHelp
    mov bx, 0081h

findHelp:
    mov dx, es:[bx]
    cmp dx, '?/'

    je foundHelp
    inc bx
    loop findHelp

    jmp exitFindHelp

foundHelp:
    mov ah, 9
    mov dx, offset help_msg
    int 21h
    jmp closeProgram

exitFindHelp:
    ret
       
needHelp endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
printFileName proc	;failo vardo spausdinimas
	mov dl, 36
	mov [si], dl
	mov ah, 09h
	mov dx, offset newLine
	int 21h
	mov ah, 09h
	mov dx, offset fileName
	int 21h
	mov ah, 09h
	mov dx, offset newLine
	int 21h
	mov dl, 48
	mov [si], dl
	ret
printFileName endp
countLowerCaseLetters proc		;skaiciuojam mazasias raides
	push ax
	push bx
	push cx
		
		mov cx, ax
		
		xor bx, bx
		countingLowerLetters:
			mov al, [buff + bx]
			cmp al, 'a'
			jb skip1
			cmp al, 'z'
			ja skip1
			
			;jei yra rezyje tarp a ir z tai padidinam skaiciu vienu
			inc lowerCLetters
			
			skip1:
			inc bx
		loop countingLowerLetters
		
    pop cx
    pop bx
	pop ax
	ret

countLowerCaseLetters ENDP
countCapitalLetters proc			;skaiciuojam didziasias raides
	push ax
	push bx
	push cx
		
		mov cx, ax
		
		xor bx, bx
		countingUpperLetters:
			mov al, [buff + bx]
			cmp al, 'A'
			jb skip2
			cmp al, 'Z'
			ja skip2
			
			;jei yra rezyje tarp A ir Z tai padidinam skaiciu vienu
			inc capitalLetters
			
			skip2:
			inc bx
		loop countingUpperLetters
				
    pop cx
    pop bx
	pop ax
	ret 
countCapitalLetters endp
countWords proc		;skaicuojam zodzius(nera tobula)
	push ax
	push bx
	push cx
		
		mov cx, ax
		
		xor bx, bx
		countingWords:
			mov al, [buff + bx]
			cmp al, 32	;jei tarpas, tai nauajas zodis
			je newWord
			cmp al, 13	;jei carriage return tai naujas zodis
			je newWord
			jmp skip3	;jei nei to nei to nebuvo, sokam iki skip3 ir
			newWord:
			inc wordCount

			skip3:
			inc bx	;padidinam bx vienu kad skaitytume kita elementa
		loop countingWords		
				
    pop cx
    pop bx
	pop ax
	ret 
countWords endp
countSymbols proc		;skaiciuojam simboliu skaiciu
	push ax
	push bx
	push cx

		
		mov cx, ax
		xor bx, bx
		countSymbolsLoop:	
			mov al, [buff + bx]
			cmp al, 10		;jie nera nauja eilute arba
			je skip4
			cmp al, 13		;carriage return
			je skip4
			inc symbolCount	;pridedam prie simboliu skaiciaus viena
			skip4:
			inc bx		;padidinam bx vienu kad skaitytume kita elementa
		loop countSymbolsLoop

    pop cx
	pop bx
	pop ax
	ret 
countSymbols endp
print proc		;printinimas vienazenkliu ir keleziankliu skaiciu
	mov dx, 0
	mov cx, 0
	
	cmp ax, 9	;jei skaicius vieno skaitmens
	mov dx, ax
	ja division
	add dx, 48
	mov ah, 02h
	int 21h
	jmp exitPrinting
	
	;jei keliu skaitmenu, atlliekam veiksmus kad ji isspausdint
	division:
		xor dx, dx
		cmp ax, 0
		je printing
		mov bx, 10
		div bx
		
		push dx
		inc cx
	jmp division
	
	printing:	;jo spausdinimas
		cmp cx, 0
		je exitPrinting
		
		pop dx
		mov ah, 02h
		add dx, 48
		int 21h
		
		dec cx
		jmp printing
	
	exitPrinting:
	mov ah, 09h
	mov dx, offset newline
	int 21h
	ret
print endp
;toliau eina didziuju, mazuju raidziu ir simboliu bei zodiu skaiciai
printLowerCaseLetters proc	
	push ax
	mov ah, 09h
	mov dx, offset msg_lowerCLetters
	int 21h
	mov ax, lowerCLetters
	call print
	pop ax
	ret
printLowerCaseLetters endp
printUpperCaseLetters proc
	push ax
	mov ah, 09h
	mov dx, offset msg_upperCLetters
	int 21h
	mov ax, capitalLetters
	call print
	pop ax
	ret
printUpperCaseLetters endp
printWordCount proc
	push ax
	mov ah, 09h
	mov dx, offset msg_wordCount
	int 21h
	mov ax, wordCount
	call print
	pop ax
	ret
printWordCount endp
printSymbolCount proc
	push ax
	mov ah, 09h
	mov dx, offset msg_symbolCount
	int 21h
	mov ax, symbolCount
	call print
	pop ax
	mov lowerCLetters, 0
	mov capitalLetters, 0
	mov symbolCount, 0
	mov wordCount, 1
	
	ret
printSymbolCount endp
end start