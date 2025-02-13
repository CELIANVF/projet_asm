; -----------------------------------------------------------
; Fonctions externes de la bibliothèque X11
; -----------------------------------------------------------
; Ces fonctions permettent de créer et de manipuler une fenêtre sous X11.
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
; Fonctions externes de la bibliothèque standard (stdio)
; -----------------------------------------------------------
; Utilisées pour afficher des messages et quitter le programme.
extern printf
extern exit

; -----------------------------------------------------------
; Définitions de constantes
; -----------------------------------------------------------
%define StructureNotifyMask 131072    ; Masque pour recevoir les notifications de structure (ex : création, redimensionnement)
%define KeyPressMask         1         ; Masque pour les événements de pression de touche
%define ButtonPressMask      4         ; Masque pour les événements de clic souris
%define MapNotify           19         ; Code de l'événement MapNotify (apparition de la fenêtre)
%define KeyPress             2         ; Code de l'événement KeyPress
%define ButtonPress          4         ; Code de l'événement ButtonPress
%define Expose              12         ; Code de l'événement Expose (rendre la fenêtre visible)
%define ConfigureNotify     22         ; Code de l'événement ConfigureNotify (changement de configuration)
%define CreateNotify        16         ; Code de l'événement CreateNotify (création de la fenêtre)
%define QWORD                8          ; Taille d'un quad word (64 bits)
%define DWORD                4          ; Taille d'un double word (32 bits)
%define WORD                 2          ; Taille d'un word (16 bits)
%define BYTE                 1          ; Taille d'un octet (8 bits)
%define NB_FOYERS            200        ; Nombre total de foyers à générer
%define NB_POINTS            500000     ; Nombre total de points à traiter/dessiner
%define WIDTH                900        ; Largeur de la fenêtre
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
gc:             resq 1          ; Contexte graphique (GC)

distance_min:   resd 1          ; Distance minimale (au carré) trouvée entre un point et un foyer
distance_min_id:resd 1          ; Indice du foyer le plus proche du point

tableau_x_foyers: resd NB_FOYERS+1   ; Tableau contenant les coordonnées x de chaque foyer
tableau_y_foyers: resd NB_FOYERS+1   ; Tableau contenant les coordonnées y de chaque foyer
drawing_done:   resb 1          ; Flag indiquant si le dessin a déjà été effectué

; -----------------------------------------------------------
; SECTION .data : Variables initialisées
; -----------------------------------------------------------
section .data

; Chaînes de format pour printf
affichage_indice db "Indice : %d", 10, 0  ; Chaîne pour afficher un indice (avec saut de ligne)
error_message   db "Erreur : indice hors limites ou accès invalide.", 0xA, 0  ; Message d'erreur avec saut de ligne

; Réserve d'espace pour stocker un événement X11 (24 quadwords)
event:          times 24 dq 0

; Variables temporaires pour les coordonnées
x1:             dd 0    ; Coordonnée x d'un point généré
x2:             dd 0    ; Coordonnée x du foyer (destination pour le dessin)
y1:             dd 0    ; Coordonnée y d'un point généré
y2:             dd 0    ; Coordonnée y du foyer (destination pour le dessin)

; Tableau des couleurs (format 0xRRGGBB) utilisé pour le dessin
colors         dd 0x0ebeff, 0x29b0f7, 0x44a2ee, 0x5f94e5, 0x7a86dc, 0x9578d3, 0xb06ac9, 0xcb5cb0, 0xe64e97, 0xff4080
nb_colors      dd 10           ; Nombre de couleurs disponibles

; Autres constantes
nb_points      dd NB_POINTS    ; Nombre de points à générer
nb_foyers      dd NB_FOYERS    ; Nombre de foyers à générer
width          dd WIDTH        ; Largeur de la fenêtre (900)
height         dd HEIGHT       ; Hauteur de la fenêtre (900)

; -----------------------------------------------------------
; SECTION .text : Code exécutable
; -----------------------------------------------------------
section .text

; ###########################################################
; ########### PROGRAMME PRINCIPAL #########################
; ###########################################################

main:
    mov     byte [drawing_done], 0   ; Initialise le flag de dessin à 0 (dessin non effectué)

    ; Sauvegarde du registre de base pour les appels ultérieurs (par exemple printf)
    push    rbp
    mov     rbp, rsp

    ; Récupère le nom du display par défaut (en passant NULL)
    xor     rdi, rdi          ; Met rdi à 0 (NULL)
    call    XDisplayName      ; Appelle XDisplayName pour obtenir le nom du display
    test    rax, rax          ; Vérifie si le résultat est NULL
    jz      closeDisplay      ; Si NULL, ferme le display et quitte

    ; Ouvre le display par défaut
    xor     rdi, rdi          ; rdi = 0 (utilise le display par défaut)
    call    XOpenDisplay      ; Appelle XOpenDisplay pour ouvrir le display
    test    rax, rax          ; Vérifie si l'ouverture a réussi
    jz      closeDisplay      ; Si échec, quitte le programme

    ; Stocke le display ouvert dans la variable globale "display_name"
    mov     [display_name], rax

    ; Restaure le cadre de pile sauvegardé
    mov     rsp, rbp
    pop     rbp

    ; (Redondance possible) Réaffecte "display_name" avec rax
    mov     [display_name], rax
    mov     eax, dword [rax+0xe0]  ; Récupère le numéro de l'écran à partir de la structure display (offset 0xe0)
    mov     dword [screen], eax    ; Stocke le numéro d'écran dans "screen"

    ; Obtention de la fenêtre racine (root window) du display
    mov     rdi, qword [display_name]   ; Place le display dans rdi
    mov     esi, dword [screen]         ; Place le numéro d'écran dans esi
    call    XRootWindow          ; Appelle XRootWindow pour obtenir la fenêtre racine
    mov     rbx, rax             ; Sauvegarde la fenêtre racine dans rbx

    ; Création d'une fenêtre simple
    mov     rdi, qword [display_name]   ; Paramètre : display
    mov     rsi, rbx                   ; Paramètre : parent (root window)
    mov     rdx, 10                    ; Position x de la fenêtre
    mov     rcx, 10                    ; Position y de la fenêtre
    mov     r8, [width]                ; Largeur de la fenêtre
    mov     r9, [height]               ; Hauteur de la fenêtre
    push    0x000000                   ; Couleur du bord (noir, 0x000000)
    push    0x00FF00                   ; Couleur de fond (vert, 0x00FF00)
    push    1                        ; Épaisseur du bord
    call    XCreateSimpleWindow      ; Appelle XCreateSimpleWindow pour créer la fenêtre
    mov     qword [window], rax      ; Stocke l'identifiant de la fenêtre dans "window"

    ; Sélection des événements à écouter sur la fenêtre
    mov     rdi, qword [display_name]
    mov     rsi, qword [window]
    mov     rdx, 131077             ; Masque d'événements (ex : StructureNotifyMask + autres)
    call    XSelectInput

    ; Affichage (mapping) de la fenêtre
    mov     rdi, qword [display_name]
    mov     rsi, qword [window]
    call    XMapWindow

    ; Création du contexte graphique (GC) avec vérification d'erreur
    mov     rdi, qword [display_name]
    test    rdi, rdi              ; Vérifie que le display n'est pas NULL
    jz      closeDisplay

    mov     rsi, qword [window]
    test    rsi, rsi              ; Vérifie que la fenêtre n'est pas NULL
    jz      closeDisplay

    xor     rdx, rdx              ; Aucun masque particulier
    xor     rcx, rcx              ; Aucune valeur particulière
    call    XCreateGC             ; Appelle XCreateGC pour créer le contexte graphique
    test    rax, rax              ; Vérifie que la création du GC a réussi
    jz      closeDisplay          ; En cas d'échec, quitte le programme
    mov     qword [gc], rax       ; Stocke le GC dans "gc"

boucle: ; Boucle de gestion des événements
    mov     rdi, qword [display_name]
    mov     rsi, event           ; Adresse de la structure d'événement
    call    XNextEvent           ; Attend et récupère le prochain événement

    cmp     dword [event], ConfigureNotify ; Si l'événement est ConfigureNotify (apparition/redimensionnement)
    je      foyers                         ; Passe à la génération des foyers

    cmp     dword [event], KeyPress         ; Si une touche est pressée
    je      closeDisplay                   ; Quitte le programme
    jmp     boucle                         ; Sinon, retourne dans la boucle d'événements

; -----------------------------------------------------------
; GENERATION DES FOYERS
; -----------------------------------------------------------
foyers:
    cmp     byte [drawing_done], 1  ; Vérifie si le dessin a déjà été effectué
    je      boucle                 ; Si oui, retourne à la boucle d'événements

    xor     r14, r14               ; Initialise le compteur de foyers (r14 = 0)

boucle_foyers:
        ; Génération de la coordonnée x du foyer
        mov     ecx, [width]          ; Charge la largeur (valeur maximale pour x)
        call    generate_random       ; Génère un nombre aléatoire entre 0 et (width - 1)
        mov     [tableau_x_foyers + r14 * DWORD], r12  ; Sauvegarde la coordonnée x dans le tableau

        ; Génération de la coordonnée y du foyer
        mov     ecx, [height]         ; Charge la hauteur (valeur maximale pour y)
        call    generate_random       ; Génère un nombre aléatoire entre 0 et (height - 1)
        mov     [tableau_y_foyers + r14 * DWORD], r12  ; Sauvegarde la coordonnée y dans le tableau

        ; Incrémente le compteur de foyers
        inc     r14
        ; Si le compteur est inférieur au nombre total de foyers, boucle
        cmp     r14d, [nb_foyers]
        jl      boucle_foyers
        ; (Les lignes commentées ci-dessous semblaient destinées à ajuster nb_foyers)
        ;dec r14d
        ;mov [nb_foyers], r14d

; -----------------------------------------------------------
; FIN DE LA GENERATION DES FOYERS
; -----------------------------------------------------------

; -----------------------------------------------------------
; ZONE DE DESSIN
; -----------------------------------------------------------
    xor     r14, r14          ; Réinitialise le compteur de points (r14 = 0)
    jmp     boucle_points     ; Passe à la boucle de génération et de traitement des points

; Boucle de génération et de traitement des points
boucle_points:
    ; Génère une coordonnée x aléatoire pour le point
    mov     ecx, [width]
    call    generate_random
    mov     [x1], r12d         ; Sauvegarde la coordonnée x dans x1

    ; Génère une coordonnée y aléatoire pour le point
    mov     ecx, [height]
    call    generate_random
    mov     [y1], r12          ; Sauvegarde la coordonnée y dans y1

    ; Recherche du foyer le plus proche pour ce point
    xor     r15d, r15d         ; Initialise l'indice de parcours des foyers (r15d = 0)
    mov     dword [distance_min], 0xffffff   ; Initialise la distance minimale à une valeur très élevée

boucle_foyers_point:
        ; Calcule la distance au carré entre le point (x1, y1) et le foyer courant
        mov     rdi, [tableau_x_foyers + r15d * DWORD]  ; Charge la coordonnée x du foyer courant
        mov     rsi, [tableau_y_foyers + r15d * DWORD]  ; Charge la coordonnée y du foyer courant
        mov     rdx, [x1]                               ; Charge la coordonnée x du point
        mov     rcx, [y1]                               ; Charge la coordonnée y du point
        call    calc_squared_distance                  ; Calcule (x1-x2)²+(y1-y2)², résultat dans r12d

        ; Si la distance calculée est inférieure à la distance minimale enregistrée, sauvegarde-la
        cmp     r12d, [distance_min]
        jl      sauvegarde_distance

suite_boucle_foyers_point:
        ; Incrémente l'indice du foyer
        inc     r15d
        cmp     r15d, [nb_foyers]   ; Si tous les foyers n'ont pas été examinés, boucle
        jl      boucle_foyers_point

    ; Une fois le foyer le plus proche trouvé, on passe au dessin de la ligne
    ; L'indice du foyer le plus proche est stocké dans "distance_min_id"
    mov     rbp, [distance_min_id]   ; Sauvegarde temporaire de l'indice (utilisé ici pour vérification)

    ; Choix d'une couleur pour la ligne :
    ; On génère un nombre aléatoire entre 0 et (nb_colors - 1)
    mov     ecx, [nb_colors]
    call    generate_random
    ; La couleur est récupérée dans le tableau "colors"
    ; et utilisée pour définir la couleur du trait
    mov     rdi, qword [display_name]
    mov     rsi, qword [gc]
    mov     edx, [colors + r12 * DWORD]   ; Récupère la couleur correspondante
    call    XSetForeground

    ; Récupère à nouveau l'indice du foyer le plus proche
    mov     r12d, [distance_min_id]
    ; Vérifie que l'indice est valide (inférieur à nb_foyers)
    cmp     r12d, [nb_foyers]
    jg      erreur

    mov     r12d, [distance_min_id]
    cmp     r12d, [nb_foyers]      ; Vérifie que l'indice est dans les limites
    jae     erreur               ; Si l'indice dépasse nb_foyers, saute à l'étiquette "erreur"

    ; Calcule l'offset pour accéder aux coordonnées du foyer dans les tableaux
    imul    r12d, 4              ; Multiplie l'indice par 4 (taille d'un DWORD)
    mov     eax, [tableau_x_foyers + r12]  ; Récupère la coordonnée x du foyer
    mov     dword [x2], eax      ; Stocke cette coordonnée dans x2
    mov     eax, [tableau_y_foyers + r12]  ; Récupère la coordonnée y du foyer
    mov     dword [y2], eax      ; Stocke cette coordonnée dans y2

    ; Dessin de la ligne reliant le point (x1, y1) au foyer (x2, y2)
    mov     rdi, qword [display_name]  ; Paramètre : display
    test    rdi, rdi             ; Vérifie que le display n'est pas NULL
    jz      closeDisplay

    mov     rsi, qword [window]  ; Paramètre : fenêtre
    test    rsi, rsi             ; Vérifie que la fenêtre n'est pas NULL
    jz      closeDisplay

    mov     rdx, qword [gc]      ; Paramètre : contexte graphique (GC)
    test    rdx, rdx             ; Vérifie que le GC n'est pas NULL
    jz      closeDisplay

    mov     ecx, dword [x1]      ; Coordonnée x de départ (point)
    mov     r8d, dword [y1]      ; Coordonnée y de départ (point)
    mov     r9d, dword [x2]      ; Coordonnée x d'arrivée (foyer)
    sub     rsp, 16            ; Alloue 16 octets sur la pile pour passer y2 en argument
    mov     eax, dword [y2]
    mov     [rsp], rax         ; Pousse la coordonnée y d'arrivée sur la pile

    call    XDrawLine          ; Appelle XDrawLine pour dessiner la ligne

    ; Incrémente le compteur de points traités
    inc     r14
    cmp     r14d, [nb_points]    ; Si tous les points n'ont pas été traités, boucle
    jl      boucle_points
    jmp     flush              ; Sinon, passe à l'étape de rafraîchissement

sauvegarde_distance:
    ; Sauvegarde la distance minimale trouvée et l'indice du foyer correspondant
    mov     [distance_min], r12
    mov     [distance_min_id], r15d
    jmp     suite_boucle_foyers_point

; -----------------------------------------------------------
; FIN DE LA ZONE DE DESSIN
; -----------------------------------------------------------
flush:
    mov     byte [drawing_done], 1   ; Marque que le dessin est terminé
    mov     rdi, qword [display_name]
    call    XFlush           ; Rafraîchit l'affichage pour mettre à jour la fenêtre
    jmp     boucle           ; Retourne à la boucle de gestion des événements
    mov     rax, 34          ; Code mort (instruction jamais exécutée)
    syscall

closeDisplay:
    ; Ferme le display et quitte le programme
    mov     rax, qword [display_name]
    mov     rdi, rax
    call    XCloseDisplay    ; Ferme la connexion X11
    xor     rdi, rdi
    call    exit             ; Quitte le programme

; -----------------------------------------------------------
; Gestion d'erreur : Affichage d'un message d'erreur et sortie
; -----------------------------------------------------------
erreur:
    ; Affiche l'indice problématique via printf
    mov     rdi, affichage_indice
    mov     rsi, r12
    xor     eax, eax
    call    printf

    ; Affiche un message d'erreur explicatif
    mov     rdi, error_message
    xor     eax, eax
    call    printf
    jmp     closeDisplay     ; Quitte le programme après l'affichage de l'erreur

; -----------------------------------------------------------
; Fonction generate_random
; -----------------------------------------------------------
; Génère un nombre aléatoire dans l'intervalle [0, ecx - 1] en utilisant l'instruction RDRAND.
; Entrée : ecx contient la valeur maximale (non incluse)
; Sortie : r12d contient le nombre aléatoire généré
generate_random:
    rdrand r12d         ; Génère un nombre aléatoire et le stocke dans r12d
    jnc     generate_random  ; Si l'instruction échoue (flag CF non levé), recommence
    xor     edx, edx         ; Efface edx pour préparer la division
    mov     eax, r12d
    div     ecx              ; Effectue la division, le reste (edx) sera le résultat modulo ecx
    mov     r12d, edx        ; Stocke le reste dans r12d
    ret

; -----------------------------------------------------------
; Fonction calc_squared_distance
; -----------------------------------------------------------
; Calcule la distance au carré entre deux points (évite de calculer la racine carrée)
; Entrées :
;   rdi : x1 (coordonnée x du premier point)
;   rsi : y1 (coordonnée y du premier point)
;   rdx : x2 (coordonnée x du second point)
;   rcx : y2 (coordonnée y du second point)
; Sortie :
;   r12d : distance au carré = (x1 - x2)² + (y1 - y2)²
calc_squared_distance:
    ; Calcul de (x1 - x2)²
    sub     rdi, rdx        ; rdi = x1 - x2
    imul    rdi, rdi        ; rdi = (x1 - x2)²

    ; Calcul de (y1 - y2)²
    sub     rsi, rcx        ; rsi = y1 - y2
    imul    rsi, rsi        ; rsi = (y1 - y2)²

    ; Additionne les deux résultats
    add     rdi, rsi        ; rdi = (x1 - x2)² + (y1 - y2)²
    mov     r12d, edi       ; Stocke le résultat dans r12d
    ret
