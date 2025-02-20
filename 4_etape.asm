; -----------------------------------------------------------
; Fonctions externes de la bibliothèque X11
; -----------------------------------------------------------
; Ces fonctions permettent de créer, manipuler et gérer une fenêtre X11.
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

; -----------------------------------------------------------
; Fonctions externes de la bibliothèque stdio (ld-linux-x86-64.so.2)
; -----------------------------------------------------------
; Utilisées pour afficher des messages et pour quitter le programme.
extern printf
extern exit

; -----------------------------------------------------------
; Définitions de constantes
; -----------------------------------------------------------
%define StructureNotifyMask 131072    ; Masque pour recevoir les notifications de structure
%define KeyPressMask         1         ; Masque pour les événements de pression de touche
%define ButtonPressMask      4         ; Masque pour les événements de clic souris
%define MapNotify           19         ; Code de l'événement MapNotify (affichage de la fenêtre)
%define KeyPress             2         ; Code de l'événement KeyPress
%define ButtonPress          4         ; Code de l'événement ButtonPress
%define Expose              12         ; Code de l'événement Expose (redessin de la fenêtre)
%define ConfigureNotify     22         ; Code de l'événement ConfigureNotify (redimensionnement)
%define CreateNotify        16         ; Code de l'événement CreateNotify (création d'une fenêtre)
%define QWORD                8          ; Taille d'un quad word (64 bits)
%define DWORD                4          ; Taille d'un double word (32 bits)
%define WORD                 2          ; Taille d'un word (16 bits)
%define BYTE                 1          ; Taille d'un octet (8 bits)
%define NB_FOYERS            1000        ; Nombre de foyers à générer
%define WIDTH                1600        ; Largeur de la fenêtre
%define HEIGHT               900        ; Hauteur de la fenêtre

global main   ; Point d'entrée du programme

; -----------------------------------------------------------
; SECTION .bss : Variables non initialisées
; -----------------------------------------------------------
section .bss

display_name:   resq 1          ; Pointeur vers le display X11
screen:         resd 1          ; Numéro de l'écran utilisé
depth:          resd 1          ; Profondeur de couleur (non utilisée ici)
connection:     resd 1          ; Variable réservée (non utilisée)
window:         resq 1          ; Identifiant de la fenêtre créée
gc:             resq 1          ; Contexte graphique (Graphical Context)

distance_min:   resd 1          ; Distance minimale (au carré) trouvée entre un point et un foyer
distance_min_id:resd 1          ; Indice du foyer le plus proche du point

tableau_x_foyers: resd NB_FOYERS+1   ; Tableau contenant les coordonnées x de chaque foyer
tableau_y_foyers: resd NB_FOYERS+1   ; Tableau contenant les coordonnées y de chaque foyer
tableau_color_foyers: resd NB_FOYERS  ; Tableau contenant la couleur associée à chaque foyer
drawing_done:   resb 1          ; Flag indiquant si le dessin a déjà été réalisé

; -----------------------------------------------------------
; SECTION .data : Variables initialisées
; -----------------------------------------------------------
section .data

; Chaînes de format pour printf
affichage_indice db "Indice : %d", 10, 0    ; Format pour afficher un indice (avec saut de ligne)
error_message   db "Erreur : indice hors limites ou accès invalide.", 0xA, 0  ; Message d'erreur

; Réservation d'espace pour stocker un événement X11 (24 quadwords)
event:          times 24 dq 0

; Variables temporaires pour les coordonnées
x1:             dd 0      ; Coordonnée x d'un point
x2:             dd 0      ; Coordonnée x d'un foyer (pour le dessin)
y1:             dd 0      ; Coordonnée y d'un point
y2:             dd 0      ; Coordonnée y d'un foyer (pour le dessin)

; Tableau des couleurs (format 0xRRGGBB) pour les foyers
colors         dd 0x0ebeff, 0x29b0f7, 0x44a2ee, 0x5f94e5, 0x7a86dc, 0x9578d3, 0xb06ac9, 0xcb5cb0, 0xe64e97, 0xff4080
nb_colors      dd 10           ; Nombre de couleurs disponibles

; Autres constantes
nb_foyers      dd NB_FOYERS    ; Nombre de foyers à générer
width          dd WIDTH        ; Largeur de la fenêtre
height         dd HEIGHT       ; Hauteur de la fenêtre

; -----------------------------------------------------------
; SECTION .text : Code exécutable
; -----------------------------------------------------------
section .text

; ###########################################################
; ########### PROGRAMME PRINCIPAL #########################
; ###########################################################

main:
    mov     byte [drawing_done], 0   ; Indique que le dessin n'est pas encore effectué

    ; Sauvegarde du cadre de pile (pour printf et autres appels)
    push    rbp
    mov     rbp, rsp

    ; Récupère le nom du display par défaut (NULL passé en argument)
    xor     rdi, rdi          ; rdi = 0 (NULL)
    call    XDisplayName      ; Appelle XDisplayName
    test    rax, rax          ; Vérifie si le display est valide
    jz      closeDisplay      ; Si NULL, quitte

    ; Ouvre le display par défaut
    xor     rdi, rdi          ; rdi = 0
    call    XOpenDisplay      ; Appelle XOpenDisplay
    test    rax, rax          ; Vérifie si l'ouverture a réussi
    jz      closeDisplay      ; Si échec, quitte

    ; Stocke le display ouvert dans la variable globale
    mov     [display_name], rax

    ; Restaure le cadre de pile sauvegardé
    mov     rsp, rbp
    pop     rbp

    ; (Redondant) Réaffecte display_name avec rax
    mov     [display_name], rax
    mov     eax, dword [rax+0xe0]  ; Récupère le numéro de l'écran (offset 0xe0)
    mov     dword [screen], eax    ; Stocke le numéro d'écran

    ; Obtention de la fenêtre racine du display
    mov     rdi, qword [display_name]   ; Place le display dans rdi
    mov     esi, dword [screen]         ; Place le numéro d'écran dans esi
    call    XRootWindow          ; Appelle XRootWindow pour obtenir la fenêtre racine
    mov     rbx, rax             ; Sauvegarde la root window dans rbx

    ; Création d'une fenêtre simple
    mov     rdi, qword [display_name]   ; Paramètre : display
    mov     rsi, rbx                   ; Paramètre : parent = root window
    mov     rdx, 10                    ; Position x de la fenêtre
    mov     rcx, 10                    ; Position y de la fenêtre
    mov     r8, [width]                ; Largeur de la fenêtre
    mov     r9, [height]               ; Hauteur de la fenêtre
    push    0x000000                   ; Couleur du bord (noir)
    push    0x00FF00                   ; Couleur de fond (vert)
    push    1                        ; Épaisseur du bord
    call    XCreateSimpleWindow      ; Appelle XCreateSimpleWindow pour créer la fenêtre
    mov     qword [window], rax      ; Stocke l'identifiant de la fenêtre

    ; Sélection des événements à écouter sur la fenêtre
    mov     rdi, qword [display_name]
    mov     rsi, qword [window]
    mov     rdx, 131077             ; Masque d'événements (ex. StructureNotifyMask + autres)
    call    XSelectInput

    ; Affichage (mapping) de la fenêtre
    mov     rdi, qword [display_name]
    mov     rsi, qword [window]
    call    XMapWindow

    ; Création du contexte graphique (GC) avec vérification
    mov     rdi, qword [display_name]
    test    rdi, rdi              ; Vérifie que display n'est pas NULL
    jz      closeDisplay
    mov     rsi, qword [window]
    test    rsi, rsi              ; Vérifie que window n'est pas NULL
    jz      closeDisplay
    xor     rdx, rdx              ; Aucun masque
    xor     rcx, rcx              ; Aucune valeur particulière
    call    XCreateGC             ; Appelle XCreateGC pour créer le GC
    test    rax, rax              ; Vérifie que le GC a été créé
    jz      closeDisplay          ; Si échec, quitte
    mov     qword [gc], rax       ; Stocke le GC

boucle: ; Boucle de gestion des événements
    mov     rdi, qword [display_name]
    mov     rsi, event           ; Adresse de la structure d'événement
    call    XNextEvent           ; Attend et récupère le prochain événement
    cmp     dword [event], ConfigureNotify ; Si événement ConfigureNotify (apparition/redimensionnement)
    je      foyers             ; Passe à la génération des foyers
    cmp     dword [event], KeyPress         ; Si une touche est pressée
    je      closeDisplay       ; Quitte le programme
    jmp     boucle             ; Sinon, retourne dans la boucle

; -----------------------------------------------------------
; GENERATION DES FOYERS
; -----------------------------------------------------------
foyers:
    cmp     byte [drawing_done], 1  ; Si le dessin est déjà terminé
    je      boucle             ; retourne à la boucle d'événements
    xor     r14, r14           ; Initialise le compteur de foyers (r14 = 0)

boucle_foyers:
        ; Génération de la coordonnée x du foyer
        mov     ecx, [height]         ; Charge la largeur (max pour x)
        call    generate_random      ; Génère un nombre aléatoire entre 0 et (width - 1)
        mov     [tableau_x_foyers + r14 * 4], r12  ; Sauvegarde dans le tableau

        ; Génération de la coordonnée y du foyer
        mov     ecx, [width]        ; Charge la hauteur (max pour y)
        call    generate_random      ; Génère un nombre aléatoire entre 0 et (height - 1)
        mov     [tableau_y_foyers + r14 * 4], r12  ; Sauvegarde dans le tableau

        ; Génération d'une couleur aléatoire pour le foyer
        ; Choisit un indice entre 0 et (nb_colors - 1)
        mov     ecx, [nb_colors]
        call    generate_random      ; Génère un indice aléatoire
        mov     r12d, [colors + r12 * 4]  ; Récupère la couleur correspondante
        mov     [tableau_color_foyers + r14 * 4], r12d  ; Sauvegarde la couleur

        ; Incrémente le compteur de foyers
        inc     r14
        cmp     r14d, [nb_foyers]    ; Tant que r14 < nb_foyers, boucle
        jl      boucle_foyers

; -----------------------------------------------------------
; FIN DE LA GENERATION DES FOYERS
; -----------------------------------------------------------

; -----------------------------------------------------------
; ZONE DE DESSIN
; -----------------------------------------------------------
    ; Initialisation des compteurs pour l'énumération de tous les points
    xor     r13, r13       ; r13 servira de compteur pour les foyers dans l'énumération
    xor     r14, r14       ; r14 servira de compteur pour la coordonnée x du point
    xor     r15, r15       ; r15 servira de compteur pour la coordonnée y du point

boucle_x:
        ; Pour chaque valeur de x (de 0 à width-1)
        xor     r15, r15   ; Réinitialise r15 pour la boucle sur y
boucle_y:
            ; Pour chaque valeur de y (de 0 à height-1)
            xor     r13, r13   ; Réinitialise r13 pour parcourir tous les foyers
            mov     dword [distance_min], 0xffffff  ; Initialise la distance minimale à une très grande valeur

boucle_foyers_enum:
                ; Énumération de tous les foyers pour trouver le plus proche du point (r14, r15)
                ; Récupère les coordonnées du foyer courant
                mov     rdi, r14        ; Coordonnée x du point (passée via rdi)
                mov     rsi, r15        ; Coordonnée y du point (passée via rsi)
                mov     rdx, [tableau_x_foyers + r13 * 4]  ; Coordonnée x du foyer courant
                mov     rcx, [tableau_y_foyers + r13 * 4]  ; Coordonnée y du foyer courant
                call    calc_squared_distance  ; Calcule la distance au carré entre le point et le foyer
                ; Si la distance calculée est inférieure à la distance minimale enregistrée...
                cmp     r12d, [distance_min]
                jl      sauvegarde_distance  ; ...alors, sauvegarde cette distance et l'indice du foyer
suit_boucle_foyers_enum:
                inc     r13            ; Passe au foyer suivant
                cmp     r13d, [nb_foyers]
                jl      boucle_foyers_enum  ; Continue tant que tous les foyers n'ont pas été parcourus

            ; Une fois le foyer le plus proche trouvé, on dessine le point avec la couleur du foyer
            xor     r13, r13
            mov     r13d, [distance_min_id]  ; Récupère l'indice du foyer le plus proche
            mov     rdi, qword [display_name]
            mov     rsi, qword [gc]
            mov     edx, [tableau_color_foyers + r13d * 4]  ; Récupère la couleur associée
            call    XSetForeground       ; Définit la couleur du dessin
            mov     rdi, qword [display_name]
            mov     rsi, qword [window]
            mov     rdx, qword [gc]
            mov     rcx, r15            ; Coordonnée y du point
            mov     r8, r14             ; Coordonnée x du point
            call    XDrawPoint          ; Dessine le point

            inc     r15d              ; Passe au point suivant sur l'axe y
            cmp     r15d, [width]     ; Continue tant que r15 < width
            jl      boucle_y

        inc     r14d                  ; Passe à la ligne suivante sur l'axe x
        cmp     r14d, [height]        ; Continue tant que r14 < height
        jl      boucle_x

        jmp     flush                ; Après avoir dessiné tous les points, passe au rafraîchissement

sauvegarde_distance:
    ; Sauvegarde la distance minimale trouvée et l'indice du foyer correspondant
    mov     [distance_min], r12
    mov     [distance_min_id], r13
    jmp     suit_boucle_foyers_enum

; -----------------------------------------------------------
; FIN DE LA ZONE DE DESSIN
; -----------------------------------------------------------
flush:
    mov     byte [drawing_done], 1    ; Marque que le dessin est terminé
    mov     rdi, qword [display_name]
    call    XFlush           ; Rafraîchit l'affichage pour mettre à jour la fenêtre
    jmp     boucle           ; Retourne à la boucle de gestion des événements
    mov     rax, 34          ; Code mort (instruction jamais exécutée)
    syscall

closeDisplay:
    ; Ferme le display et quitte le programme
    mov     rax, qword [display_name]
    mov     rdi, rax
    call    XCloseDisplay    ; Ferme la connexion au display X11
    xor     rdi, rdi
    call    exit             ; Quitte le programme

erreur:
    ; -----------------------------------------------------------
    ; Gestion d'erreur : Affichage d'un message d'erreur et sortie
    ; -----------------------------------------------------------
    mov     rdi, affichage_indice  ; Prépare la chaîne de format pour l'indice
    mov     rsi, r12             ; Passe l'indice problématique
    xor     eax, eax
    call    printf             ; Affiche l'indice
    mov     rdi, error_message ; Prépare le message d'erreur
    xor     eax, eax
    call    printf             ; Affiche le message d'erreur
    jmp     closeDisplay       ; Ferme le display et quitte

; -----------------------------------------------------------
; Fonction generate_random
; -----------------------------------------------------------
; Génère un nombre aléatoire dans l'intervalle [0, ecx - 1] en utilisant RDRAND.
; Entrée : ecx contient la valeur maximale (non incluse)
; Sortie : r12d contient le nombre aléatoire généré
generate_random:
    rdrand r12d         ; Génère un nombre aléatoire dans r12d
    jnc     generate_random  ; Si l'instruction échoue (flag CF non levé), recommence
    xor     edx, edx         ; Efface edx pour la division
    mov     eax, r12d
    div     ecx              ; Divise eax par ecx, le reste est en edx
    mov     r12d, edx        ; Stocke le reste (résultat modulo ecx) dans r12d
    ret

; -----------------------------------------------------------
; Fonction calc_squared_distance
; -----------------------------------------------------------
; Calcule la distance au carré entre deux points pour éviter le calcul d'une racine carrée.
; Entrées :
;   rdi : x1 (coordonnée x du premier point)
;   rsi : y1 (coordonnée y du premier point)
;   rdx : x2 (coordonnée x du second point)
;   rcx : y2 (coordonnée y du second point)
; Sortie :
;   r12d : (x1 - x2)² + (y1 - y2)²
calc_squared_distance:
    sub     rdi, rdx        ; Calcule (x1 - x2)
    imul    rdi, rdi        ; Élève au carré : (x1 - x2)²
    sub     rsi, rcx        ; Calcule (y1 - y2)
    imul    rsi, rsi        ; Élève au carré : (y1 - y2)²
    add     rdi, rsi        ; Additionne : (x1 - x2)² + (y1 - y2)²
    mov     r12d, edi       ; Stocke le résultat dans r12d
    ret
