; External functions from X11 library
; -------------------------------------
; Déclaration des fonctions externes de la bibliothèque X11 utilisées pour créer et manipuler la fenêtre.
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
; ------------------------------------------------------------------
; Déclaration des fonctions externes de la bibliothèque standard (printf et exit).
extern printf
extern exit

; Définitions de constantes
; -------------------------
%define StructureNotifyMask 131072    ; Masque pour recevoir les notifications de changement de structure (ex: création, redimensionnement)
%define KeyPressMask         1         ; Masque pour recevoir les événements de pression de touche
%define ButtonPressMask      4         ; Masque pour recevoir les événements de pression de bouton de souris
%define MapNotify           19         ; Code de l'événement MapNotify
%define KeyPress             2         ; Code de l'événement KeyPress
%define ButtonPress          4         ; Code de l'événement ButtonPress
%define Expose              12         ; Code de l'événement Expose (rendre visible une fenêtre)
%define ConfigureNotify     22         ; Code de l'événement ConfigureNotify (modification de configuration)
%define CreateNotify        16         ; Code de l'événement CreateNotify (création d'une fenêtre)
%define QWORD                8          ; Taille d'un quad mot (64 bits)
%define DWORD                4          ; Taille d'un double mot (32 bits)
%define WORD                 2          ; Taille d'un mot (16 bits)
%define BYTE                 1          ; Taille d'un octet (8 bits)
%define NB_FOYERS            100        ; Nombre total de foyers à générer
%define NB_POINTS            500000     ; Nombre total de points à traiter/dessiner
%define WIDTH                800        ; Largeur de la fenêtre
%define HEIGHT               800        ; Hauteur de la fenêtre

global main   ; Point d'entrée du programme

; --------------------------------------------------------------------
; SECTION .bss : Variables non initialisées (espace réservé en mémoire)
; --------------------------------------------------------------------
section .bss

display_name:   resq 1          ; Pointeur vers le display (X11)
screen:         resd 1          ; Numéro de l'écran utilisé
depth:          resd 1          ; Profondeur de couleur (non utilisée ici)
connection:     resd 1          ; (Variable réservée, non utilisée dans ce code)
window:         resq 1          ; Identifiant de la fenêtre créée
gc:             resq 1          ; Contexte graphique (Graphical Context)

distance_min:   resd 1          ; Distance minimale (au carré) trouvée pour un point
distance_min_id:resd 1          ; Indice du foyer le plus proche du point

tableau_x_foyers: resd NB_FOYERS+1   ; Tableau contenant les coordonnées x des foyers
tableau_y_foyers: resd NB_FOYERS+1   ; Tableau contenant les coordonnées y des foyers
drawing_done:   resb 1          ; Flag indiquant si le dessin a déjà été réalisé

; --------------------------------------------------------------------
; SECTION .data : Variables initialisées
; --------------------------------------------------------------------
section .data

; Chaînes de format pour printf
affichage_indice db "Indice : %d", 10, 0     ; Format pour afficher un indice (avec saut de ligne)
error_message   db "Erreur : indice hors limites ou accès invalide.", 0xA, 0  ; Message d'erreur avec saut de ligne

; Réservation d'espace pour stocker un événement X11 (24 quadwords)
event:          times 24 dq 0

; Définition des dimensions et nombres
width          dd WIDTH        ; Largeur de la fenêtre (800)
height         dd HEIGHT       ; Hauteur de la fenêtre (800)
nb_points      dd NB_POINTS    ; Nombre de points à dessiner
nb_foyers      dd NB_FOYERS    ; Nombre de foyers à générer

; Variables temporaires pour stocker des coordonnées
x1:             dd 0            ; Coordonnée x d'un point
x2:             dd 0            ; Coordonnée x d'un foyer (destination pour le dessin)
y1:             dd 0            ; Coordonnée y d'un point
y2:             dd 0            ; Coordonnée y d'un foyer (destination pour le dessin)

; --------------------------------------------------------------------
; SECTION .text : Code exécutable
; --------------------------------------------------------------------
section .text

;##################################################
;########### PROGRAMME PRINCIPAL ##################
;##################################################
main:
    mov     byte [drawing_done], 0   ; Initialise le flag de dessin à 0 (dessin non encore effectué)

    ; Sauvegarde du registre de base pour préparer les appels à printf
    push    rbp
    mov     rbp, rsp

    ; Récupère le nom du display par défaut (en passant NULL)
    xor     rdi, rdi          ; rdi = 0 (NULL)
    call    XDisplayName      ; Appel de la fonction XDisplayName
    ; Vérifie si le display est valide
    test    rax, rax          ; Teste si rax est NULL
    jz      closeDisplay      ; Si NULL, ferme le display et quitte

    ; Ouvre le display par défaut
    xor     rdi, rdi          ; rdi = 0 (NULL pour le display par défaut)
    call    XOpenDisplay      ; Appel de XOpenDisplay
    test    rax, rax          ; Vérifie si l'ouverture a réussi
    jz      closeDisplay      ; Si échec, ferme le display et quitte

    ; Stocke le display ouvert dans la variable globale display_name
    mov     [display_name], rax

    ; Restaure le cadre de pile sauvegardé
    mov     rsp, rbp
    pop     rbp

    ; (Redondance possible) Réaffecte display_name avec rax
    mov     [display_name],rax
    mov     eax,dword[rax+0xe0]   ; Récupère le numéro de l'écran à partir de la structure display (offset 0xe0)
    mov     dword[screen],eax     ; Stocke ce numéro dans la variable screen

    ; Récupère la fenêtre racine (root window) du display
    mov     rdi,qword[display_name]   ; Place le display dans rdi
    mov     esi,dword[screen]         ; Place le numéro d'écran dans esi
    call XRootWindow                ; Appel de XRootWindow pour obtenir la fenêtre racine
    mov     rbx,rax               ; Stocke la root window dans rbx

    ; Création d'une fenêtre simple
    mov     rdi,qword[display_name]   ; display
    mov     rsi,rbx                   ; parent = root window
    mov     rdx,10                    ; position x de la fenêtre
    mov     rcx,10                    ; position y de la fenêtre
    mov     r8,[width]                ; largeur de la fenêtre
    mov     r9,[height]               ; hauteur de la fenêtre
    push 0x000000                     ; couleur du bord (noir, 0x000000)
    push 0x00FF00                     ; couleur de fond (vert, 0x00FF00)
    push 1                          ; épaisseur du bord
    call XCreateSimpleWindow        ; Appel de XCreateSimpleWindow
    mov qword[window],rax           ; Stocke l'identifiant de la fenêtre créée dans window

    ; Sélection des événements à écouter sur la fenêtre
    mov rdi,qword[display_name]
    mov rsi,qword[window]
    mov rdx,131077                 ; Masque d'événements (ex. StructureNotifyMask + autres)
    call XSelectInput

    ; Affichage (mapping) de la fenêtre
    mov rdi,qword[display_name]
    mov rsi,qword[window]
    call XMapWindow

    ; Création du contexte graphique (GC) avec vérification d'erreur
    mov rdi, qword[display_name]
    test rdi, rdi                ; Vérifie que display n'est pas NULL
    jz closeDisplay

    mov rsi, qword[window]
    test rsi, rsi                ; Vérifie que window n'est pas NULL
    jz closeDisplay

    xor rdx, rdx                 ; Aucun masque particulier
    xor rcx, rcx                 ; Aucune valeur particulière
    call XCreateGC               ; Appel de XCreateGC pour créer le contexte graphique
    test rax, rax                ; Vérifie la création du GC
    jz closeDisplay              ; Si échec, quitte
    mov qword[gc], rax           ; Stocke le GC dans la variable gc

boucle: ; Boucle de gestion des événements
    mov     rdi, qword[display_name]
    cmp     rdi, 0              ; Vérifie que le display est toujours valide
    je      closeDisplay        ; Si non, quitte
    mov     rsi, event          ; Passe l'adresse de la structure d'événement
    call    XNextEvent          ; Attend et récupère le prochain événement

    cmp     dword[event], ConfigureNotify ; Si l'événement est ConfigureNotify (ex: redimensionnement)
    je      foyers                        ; Passe à la génération des foyers

    cmp     dword[event], KeyPress        ; Si une touche est pressée
    je      closeDisplay                  ; Quitte le programme
    jmp     boucle                        ; Sinon, recommence la boucle

;#########################################
;# BEGIN GENERATION OF FOYERS            #
;#########################################

foyers:
    cmp     byte [drawing_done], 1  ; Vérifie si le dessin est déjà terminé
    je      boucle                 ; Si oui, retourne à la boucle d'événements

    ; Initialise le compteur de foyers (r14 = 0)
    xor r14, r14

boucle_foyers:
        mov ecx, [width]         ; Charge la largeur pour générer une coordonnée x aléatoire
        call generate_random     ; Appel de generate_random pour obtenir un nombre aléatoire
        ; Sauvegarde la coordonnée x générée dans le tableau des foyers
        mov [tableau_x_foyers + r14 * 4], r12

        mov ecx, [height]        ; Charge la hauteur pour générer une coordonnée y aléatoire
        call generate_random     ; Appel de generate_random pour obtenir un nombre aléatoire
        ; Sauvegarde la coordonnée y générée dans le tableau des foyers
        mov [tableau_y_foyers + r14 * 4], r12

        ; Incrémente le compteur de foyers
        inc r14

        ; Si le compteur est inférieur au nombre total de foyers, boucle
        cmp r14d, [nb_foyers]
        jl boucle_foyers
        ; Les lignes commentées suivantes semblent destinées à ajuster nb_foyers
        ;dec r14d
        ;mov [nb_foyers], r14d

;#########################################
;# END GENERATION OF FOYERS              #
;#########################################

;#########################################
;# BEGIN DRAWING ZONE                    #
;#########################################

    xor r14, r14              ; Réinitialise le compteur de points
    jmp boucle_points         ; Passe à la génération et au traitement des points

; Boucle de traitement des points
; Chaque point est généré aléatoirement et relié au foyer le plus proche
boucle_points:

    mov ecx, [width]          ; Charge la largeur pour générer x du point
    call generate_random      ; Génère une coordonnée x aléatoire
    ; Sauvegarde x dans x1
    mov [x1], r12d

    mov ecx, [height]         ; Charge la hauteur pour générer y du point
    call generate_random      ; Génère une coordonnée y aléatoire
    ; Sauvegarde y dans y1
    mov [y1], r12

    ; Recherche du foyer le plus proche pour ce point
    xor r15d, r15d            ; Initialise l'indice de parcours des foyers (r15d = 0)
    mov dword [distance_min], 0xffffff  ; Initialise distance_min à une valeur très élevée

boucle_foyers_point:
        ; Calcule la distance au carré entre le point (x1, y1) et le foyer courant
        ; Récupère la coordonnée x du foyer courant
        mov rdi, [tableau_x_foyers + r15d * 4]
        ; Récupère la coordonnée y du foyer courant
        mov rsi, [tableau_y_foyers + r15d * 4]
        ; Charge x du point
        mov rdx, [x1]
        ; Charge y du point
        mov rcx, [y1]
        call calc_squared_distance   ; Appel de calc_squared_distance (résultat dans r12d)

        ; Compare la distance calculée avec la distance minimale actuelle
        cmp r12d,[distance_min]
        jl sauvegarde_distance       ; Si la nouvelle distance est plus petite, sauvegarde-la

suite_boucle_foyers_point:
        ; Incrémente l'indice du foyer
        inc r15d
        ; Si tous les foyers n'ont pas été traités, boucle
        cmp r15d, [nb_foyers]
        jl boucle_foyers_point

    ; Après avoir trouvé le foyer le plus proche, dessine la ligne reliant le point et le foyer
    ; L'indice du foyer le plus proche est dans distance_min_id
    mov rbp, [distance_min_id]   ; Stocke temporairement l'indice du foyer dans rbp

    ; Définit la couleur du trait à violet (0xFF00FF)
    mov rdi,qword[display_name]
    mov rsi,qword[gc]
    mov edx,0xFF00FF             ; Couleur (violet)
    call XSetForeground

    ; Récupère l'indice du foyer le plus proche
    mov r12d, [distance_min_id]

    ; Vérifie que l'indice est bien dans les limites autorisées
    cmp r12d, [nb_foyers]
    jg erreur

    mov r12d, [distance_min_id]
    cmp r12d, [nb_foyers]       ; Vérifie à nouveau que l'indice est valide
    jae erreur                ; Si l'indice dépasse nb_foyers, saute à l'erreur

    ; Calcule l'offset dans le tableau en multipliant l'indice par 4 (taille d'un dword)
    imul r12d, 4
    mov eax, [tableau_x_foyers + r12]  ; Récupère la coordonnée x du foyer
    mov dword[x2], eax               ; Stocke la coordonnée x dans x2
    mov eax, [tableau_y_foyers + r12]  ; Récupère la coordonnée y du foyer
    mov dword[y2], eax               ; Stocke la coordonnée y dans y2

    ; Dessine une ligne entre le point (x1, y1) et le foyer (x2, y2)
    mov rdi, qword[display_name]  ; display
    test rdi, rdi                 ; Vérifie que display n'est pas NULL
    jz closeDisplay

    mov rsi,qword[window]         ; window
    test rsi, rsi                 ; Vérifie que window n'est pas NULL
    jz closeDisplay

    mov rdx,qword[gc]             ; Contexte graphique
    test rdx, rdx                ; Vérifie que gc n'est pas NULL
    jz closeDisplay

    mov ecx,dword[x1]            ; Coordonnée x de départ
    mov r8d,dword[y1]            ; Coordonnée y de départ
    mov r9d,dword[x2]            ; Coordonnée x d'arrivée
    sub rsp, 16                 ; Alloue 16 octets sur la pile pour passer y2
    mov eax, dword[y2]
    mov [rsp], rax              ; Pousse y2 sur la pile

    call XDrawLine              ; Appel de XDrawLine pour dessiner la ligne

    ; Incrémente le compteur de points traités
    inc r14

    ; Si tous les points n'ont pas été traités, boucle
    cmp r14d, [nb_points]
    jl boucle_points
    jmp flush                 ; Sinon, passe au rafraîchissement de l'affichage

sauvegarde_distance:
    ; Sauvegarde la distance minimale et l'indice du foyer correspondant
    mov [distance_min], r12
    mov [distance_min_id], r15d
    jmp suite_boucle_foyers_point

; ############################
; # END DRAWING ZONE         #
; ############################

flush:
    mov     byte [drawing_done], 1   ; Indique que le dessin est terminé
    mov rdi,qword[display_name]
    call XFlush                 ; Rafraîchit l'affichage pour mettre à jour la fenêtre
    jmp boucle                  ; Retourne à la boucle d'événements
    mov rax,34                 ; Code mort (ne sera jamais exécuté)
    syscall

closeDisplay:
    mov     rax, qword[display_name]
    mov     rdi, rax
    call    XCloseDisplay       ; Ferme le display X11
    xor     rdi, rdi
    call    exit                ; Quitte le programme

; --------------------------------------------------------------------------------
; Gestion d'erreur : affiche un message et quitte
; --------------------------------------------------------------------------------
erreur:
    ; Affiche l'indice problématique via printf
    mov    rdi, affichage_indice
    mov    rsi, r12
    xor    eax, eax
    call   printf

    ; Affiche un message d'erreur
    mov     rdi, error_message
    xor     eax, eax
    call    printf
    jmp     closeDisplay        ; Quitte le programme en fermant le display

; --------------------------------------------------------------------------------
; Fonction generate_random
; --------------------------------------------------------------------------------
; Génère un nombre aléatoire entre 0 et (ecx - 1) en utilisant l'instruction RDRAND.
; Entrée : ecx contient la valeur maximale (non incluse)
; Sortie : r12d contient le nombre aléatoire généré
generate_random:
    rdrand r12d         ; Génère un nombre aléatoire dans r12d
    jnc generate_random ; Si l'opération échoue (flag de carry non levé), recommence
    xor edx, edx        ; Efface edx pour la division
    mov eax, r12d
    div ecx             ; Effectue la division, le reste (edx) sera le résultat modulo ecx
    mov r12d, edx       ; Stocke le résultat dans r12d
    ret

; --------------------------------------------------------------------------------
; Fonction calc_squared_distance
; --------------------------------------------------------------------------------
; Calcule la distance au carré entre deux points.
; Entrées :
;   rdi : x1 (coordonnée x du premier point)
;   rsi : y1 (coordonnée y du premier point)
;   rdx : x2 (coordonnée x du second point)
;   rcx : y2 (coordonnée y du second point)
; Sortie :
;   r12d : distance au carré, c'est-à-dire (x1 - x2)² + (y1 - y2)²
calc_squared_distance:
    ; Calcule (x1 - x2)²
    sub rdi, rdx        ; rdi = x1 - x2
    imul rdi, rdi       ; rdi = (x1 - x2)²

    ; Calcule (y1 - y2)²
    sub rsi, rcx        ; rsi = y1 - y2
    imul rsi, rsi       ; rsi = (y1 - y2)²

    ; Additionne les deux carrés
    add rdi, rsi        ; rdi = (x1 - x2)² + (y1 - y2)²
    mov r12d, edi       ; Stocke le résultat dans r12d
    ret
