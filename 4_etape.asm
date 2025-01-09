; External functions from X11 library
extern XOpenDisplay
extern XDisplayName
extern XCloseDisplay
extern XCreateSimpleWindow
extern XMapWindow
extern XRootWindow
extern XSelectInput
extern XFlush
extern XCreateGC
extern XSetForeground
extern XDrawLine
extern XDrawPoint
extern XNextEvent

; External functions from stdio library (ld-linux-x86-64.so.2)    
extern printf
extern exit

%define StructureNotifyMask 131072
%define KeyPressMask         1
%define ButtonPressMask      4
%define MapNotify           19
%define KeyPress             2
%define ButtonPress          4
%define Expose              12
%define ConfigureNotify     22
%define CreateNotify        16
%define QWORD                8
%define DWORD                4
%define WORD                 2
%define BYTE                 1
%define NB_FOYERS            100
%define WIDTH                800
%define HEIGHT               800


global main

section .bss

display_name:   resq 1
screen:         resd 1
depth:          resd 1
connection:     resd 1
window:         resq 1
gc:             resq 1

distance_min:   resd 1
distance_min_id:resd 1
tableau_x_foyers: resd NB_FOYERS+1
tableau_y_foyers: resd NB_FOYERS+1
tableau_color_foyers: resd NB_FOYERS
drawing_done:   resb 1 ; Flag to indicate if drawing is done


section .data

; Format strings


affichage_indice db "Indice : %d", 10, 0 ; Format string for printf
error_message db "Erreur : indice hors limites ou accès invalide.", 0xA, 0  ; Message d'erreur avec saut de ligne

event:          times 24 dq 0


x1:             dd 0
x2:             dd 0
y1:             dd 0
y2:             dd 0
colors         dd 0x0ebeff, 0x29b0f7, 0x44a2ee, 0x5f94e5, 0x7a86dc, 0x9578d3, 0xb06ac9, 0xcb5cb0, 0xe64e97, 0xff4080
nb_colors      dd 10
nb_foyers      dd NB_FOYERS
width          dd WIDTH
height         dd HEIGHT

section .text

;##################################################
;########### PROGRAMME PRINCIPAL ##################
;##################################################

main:
    mov     byte [drawing_done], 0
    
    ; Save registers before printf
    push    rbp
    mov     rbp, rsp
    
    ; Get display name
    xor     rdi, rdi          ; NULL for default display
    call    XDisplayName
    
    ; Print display name
    test    rax, rax          ; Check if display name is NULL
    jz      closeDisplay

    ; Try to open display
    xor     rdi, rdi          ; NULL for default display
    call    XOpenDisplay
    test    rax, rax          ; Check if display opened successfully
    jz      closeDisplay
    
    ; Display opened successfully
    mov     [display_name], rax
    
    ; Restore stack frame
    mov     rsp, rbp
    pop     rbp
    
    ; Continue with the rest of your code
    mov     [display_name],rax
    mov     eax,dword[rax+0xe0]
    mov     dword[screen],eax
    
    mov rdi,qword[display_name]
    mov esi,dword[screen]
    call XRootWindow
    mov rbx,rax

    mov rdi,qword[display_name]
    mov rsi,rbx
    mov rdx,10
    mov rcx,10
    mov r8,[width]	; largeur
    mov r9,[height]	; hauteur
    push 0x000000	; background  0xRRGGBB
    push 0x00FF00
    push 1
    call XCreateSimpleWindow
    mov qword[window],rax

    mov rdi,qword[display_name]
    mov rsi,qword[window]
    mov rdx,131077 ;131072
    call XSelectInput

    mov rdi,qword[display_name]
    mov rsi,qword[window]
    call XMapWindow

    ; Create graphics context with proper error checking
    mov rdi, qword[display_name]
    test rdi, rdi
    jz closeDisplay
    
    mov rsi, qword[window]
    test rsi, rsi
    jz closeDisplay
    
    xor rdx, rdx        ; No mask
    xor rcx, rcx        ; No values
    call XCreateGC
    test rax, rax       ; Check if GC creation failed
    jz closeDisplay
    
    mov qword[gc], rax



boucle: ; Event handling loop
    mov     rdi, qword[display_name]
    mov     rsi, event
    call    XNextEvent

    cmp     dword[event], ConfigureNotify ; On window appearance
    je      foyers                        ; Jump to 'foyers' label

    cmp     dword[event], KeyPress        ; On key press
    je      closeDisplay                  ; Jump to 'closeDisplay'
    jmp     boucle

;#########################################
;# BEGIN GENERATION OF FOYERS            #
;#########################################
    

foyers:

    cmp     byte [drawing_done], 1
    je      boucle ; If drawing is done, skip the drawing process


    ; r14 est à 0 il servira de compteur
    xor r14, r14

    boucle_foyers:

        mov ecx, [width] 
        call generate_random

        ; Sauvegarder le nombre aléatoire
        mov [tableau_x_foyers + r14 * 4], r12

        mov ecx, [height] 
        call generate_random

        ; Sauvegarder le nombre aléatoire
        mov [tableau_y_foyers + r14 * 4], r12


        ;generer une couleur aleatoire
        ;choisir un nombre entre 0 et nb_colors-1
        mov ecx, [nb_colors]
        call generate_random

        ;sauvegarder la couleur
        mov r12d, [colors + r12 * 4]



        mov [tableau_color_foyers + r14 * 4], r12d


        ; Incrémenter le compteur
        inc r14

        ; Si le compteur est inférieur au nombre de foyers, on boucle
        cmp r14d, [nb_foyers]
        jl boucle_foyers

;#########################################
;# END GENERATION OF FOYERS              #
;#########################################

;#########################################
;# BEGIN DRAWING ZONE                    #
;#########################################

    xor r13, r13 ; r13 est à 0 il servira de compteur pour les foyers
    xor r14, r14 ; r14 est à 0 il servira de compteur pour x
    xor r15, r15 ; r15 est à 0 il servira de compteur pour y
    boucle_x:
        xor r15, r15 ; r15 est à 0 il servira de compteur pour y

        boucle_y:   
            xor r13, r13 ; r13 est à 0 il servira de compteur pour les foyers
            mov dword [distance_min], 0xffffff

            boucle_foyers_enum:

                ; énumérer les foyers
                ; sauvegarder les coordonnées du foyer le plus proche du point r14, r15
                ; sauvegarder la distance entre le point r14, r15 et le foyer le plus proche


                ; récupérer les coordonnées du point
                mov rdi, r14
                mov rsi, r15
                ; récupérer les coordonnées du foyer
                mov rdx, [tableau_x_foyers + r13 * 4]
                mov rcx, [tableau_y_foyers + r13 * 4]

                ; appel de la fonction calc_distance
                ; retourne la distance entre le point et le foyer dans r12d
                call calc_distance

                
                ; si r12d est inférieur à distance_min, on sauvegarde la distance et l'identifiant du foyer
                cmp r12d,[distance_min]
                jl sauvegarde_distance
                suit_boucle_foyers_enum:


                inc r13
                cmp r13d, [nb_foyers]
                jl boucle_foyers_enum


                ;couleur du point
                xor r13, r13
                mov r13d ,[distance_min_id]

                mov rdi,qword[display_name]
                mov rsi,qword[gc]
                mov edx,[tableau_color_foyers + r13d * 4]
                call XSetForeground
                mov rdi,qword[display_name]
                mov rsi,qword[window]
                mov rdx,qword[gc]
                mov rcx,r15	; coordonnée en x
                mov r8,r14	; coordonnée en y
                call XDrawPoint

                

            inc r15d
            cmp r15d, [width]
            jl boucle_y


        inc r14d
        cmp r14d, [height]
        jl boucle_x

        jmp flush


sauvegarde_distance:
    
    ; sauvegarder la distance et l'identifiant du foyer
    mov [distance_min], r12
    mov [distance_min_id], r13

    jmp suit_boucle_foyers_enum


; ############################
; # END DRAWING ZONE         #
; ############################

flush:
    mov     byte [drawing_done], 1
    mov rdi,qword[display_name]
    call XFlush
    jmp boucle
    mov rax,34
    syscall


closeDisplay:
    mov     rax, qword[display_name]
    mov     rdi, rax
    call    XCloseDisplay
    xor     rdi, rdi
    call    exit


int_sqrt:
    ; Calcul de la racine carrée entière de r12
    ; Entrée : r12
    ; Sortie : r12

    mov ecx, 0          ; compteur
    mov ebx, r12d       ; valeur initiale

sqrt_loop:
    inc ecx             ; incrémenter le compteur
    mov edx, ecx
    imul edx, edx       ; edx = ecx * ecx
    cmp edx, ebx        ; comparer edx avec la valeur initiale
    jg sqrt_done        ; si edx > ebx, terminer la boucle
    jmp sqrt_loop       ; sinon, continuer la boucle

sqrt_done:
    dec ecx             ; décrémenter le compteur pour obtenir la racine carrée
    mov r12d, ecx       ; stocker le résultat dans r12
    ret

erreur:
    ; Afficher l'indice de r12 
    mov    rdi, affichage_indice
    mov    rsi, r12
    xor    eax, eax
    call   printf

    mov     rdi, error_message         ; Préparer un message d'erreur
    xor     eax, eax
    call    printf                     ; Afficher l'erreur
    jmp     closeDisplay               ; Aller à la fin pour éviter d'autres instructions


generate_random:
    ; Inputs:
    ; ecx - maximum value
    ; Output:
    ; r12 - random number between 0 and r12-1

    rdrand r12d         ; genere un nombre aléatoire


    ; check si le flag de carry est à 0
    jnc generate_random

    ; r12d contient un nombre aléatoire
    ; modulo avec ecx pour obtenir un nombre entre 0 et ecx-1
    xor edx, edx        ; Clear edx
    mov eax, r12d       
    div ecx             ; eax = eax % ecx

    ; retourne le nombre aléatoire dans r12d
    mov r12d, edx

    ret

calc_distance:
    ; Inputs:
    ; rdi - x1 (coordinate of the first point)
    ; rsi - y1 (coordinate of the first point)
    ; rdx - x2 (coordinate of the second point)
    ; rcx - y2 (coordinate of the second point)
    ; Output:
    ; r12d - distance between the two points

    ; calcul de la distance en x
    mov r12, rdi
    sub r12, rdx
    imul r12, r12
    mov eax, r12d

    ; calcul de la distance en y
    mov r12, rsi
    sub r12, rcx
    imul r12, r12
    add eax, r12d

    ; calcul de la distance totale
    mov r12d, eax
    call int_sqrt

    ret