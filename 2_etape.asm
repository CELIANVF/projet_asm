; -----------------------------------------------------------
; Fonctions externes de la bibliothèque X11
; -----------------------------------------------------------
; Ces fonctions permettent de créer et manipuler une fenêtre X11.
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
%define StructureNotifyMask 131072    ; Masque pour recevoir les notifications de structure (ex: création, redimensionnement)
%define KeyPressMask         1         ; Masque pour les événements de pression de touche
%define ButtonPressMask      4         ; Masque pour les événements de clic souris
%define MapNotify           19         ; Code de l'événement MapNotify (affichage de la fenêtre)
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

; -----------------------------------------------------------
; SECTION .bss : Variables non initialisées
; -----------------------------------------------------------
section .bss

display_name:   resq 1          ; Pointeur vers le display X11
screen:         resd 1          ; Numéro de l'écran utilisé
depth:          resd 1          ; Profondeur de couleur (non utilisée dans ce code)
connection:     resd 1          ; Variable réservée (non utilisée)
window:         resq 1          ; Identifiant de la fenêtre créée
gc:             resq 1          ; Contexte graphique (Graphical Context)

distance_min:   resd 1          ; Distance minimale (au carré) entre un point et un foyer
distance_min_id:resd 1          ; Indice du foyer le plus proche du point

tableau_x_foyers: resd NB_FOYERS+1   ; Tableau contenant les coordonnées x de chaque foyer
tableau_y_foyers: resd NB_FOYERS+1   ; Tableau contenant les coordonnées y de chaque foyer
tableau_color_foyers: resd NB_FOYERS+1 ; Tableau contenant la couleur associée à chaque foyer

drawing_done:   resb 1          ; Flag indiquant si le dessin a déjà été réalisé

; -----------------------------------------------------------
; SECTION .data : Variables initialisées
; -----------------------------------------------------------
section .data

; Chaînes de format pour printf
affichage_indice db "Indice : %d", 10, 0  ; Chaîne pour afficher un indice (avec saut de ligne)
error_message   db "Erreur : indice hors limites ou accès invalide.", 0xA, 0  ; Message d'erreur avec saut de ligne

; Réserve de l'espace pour stocker un événement X11 (24 quadwords)
event:          times 24 dq 0

; Variables temporaires pour les coordonnées
x1:             dd 0    ; Coordonnée x d'un point généré
x2:             dd 0    ; Coordonnée x du foyer (destination du dessin)
y1:             dd 0    ; Coordonnée y d'un point généré
y2:             dd 0    ; Coordonnée y du foyer (destination du dessin)

; Tableau des couleurs (format 0xRRGGBB) pour les foyers
colors         dd 0x0ebeff, 0x29b0f7, 0x44a2ee, 0x5f94e5, 0x7a86dc, 0x9578d3, 0xb06ac9, 0xcb5cb0, 0xe64e97, 0xff4080
nb_colors      dd 10           ; Nombre total de couleurs disponibles

; Autres constantes
nb_points      dd NB_POINTS    ; Nombre de points à générer
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
    mov     byte [drawing_done], 0   ; Initialise le flag de dessin à 0 (dessin non effectué)

    ; Sauvegarde du cadre de pile (utilisé pour printf et autres appels)
    push    rbp
    mov     rbp, rsp

    ; Récupère le nom du display par défaut (NULL passé pour obtenir le display par défaut)
    xor     rdi, rdi          ; rdi = 0 (NULL)
    call    XDisplayName      ; Appelle XDisplayName pour obtenir le nom du display
    test    rax, rax          ; Vérifie que le résultat n'est pas NULL
    jz      closeDisplay      ; Si NULL, quitte le programme

    ; Ouvre le display par défaut
    xor     rdi, rdi          ; rdi = 0 (NULL pour le display par défaut)
    call    XOpenDisplay      ; Appelle XOpenDisplay pour ouvrir le display
    test    rax, rax          ; Vérifie que l'ouverture a réussi
    jz      closeDisplay      ; Si échec, quitte le programme

    ; Stocke le display ouvert dans la variable globale 'display_name'
    mov     [display_name], rax

    ; Restaure le cadre de pile sauvegardé
    mov     rsp, rbp
    pop     rbp

    ; (Redondance possible) Réaffecte 'display_name' avec rax
    mov     [display_name],rax
    mov     eax,dword[rax+0xe0]   ; Récupère le numéro de l'écran (offset 0xe0 de la structure display)
    mov     dword[screen],eax     ; Stocke le numéro d'écran dans 'screen'

    ; Obtention de la fenêtre racine (root window) du display
    mov     rdi,qword[display_name]   ; Place le display dans rdi
    mov     esi,dword[screen]         ; Place le numéro d'écran dans esi
    call XRootWindow                ; Appelle XRootWindow pour obtenir la fenêtre racine
    mov     rbx,rax               ; Sauvegarde la root window dans rbx

    ; Création d'une fenêtre simple
    mov     rdi,qword[display_name]   ; Paramètre : display
    mov     rsi,rbx                   ; Paramètre : parent (root window)
    mov     rdx,10                    ; Position x de la fenêtre
    mov     rcx,10                    ; Position y de la fenêtre
    mov     r8,[width]                ; Largeur de la fenêtre
    mov     r9,[height]               ; Hauteur de la fenêtre
    push 0x000000                     ; Couleur du bord (noir, 0x000000)
    push 0x00FF00                     ; Couleur de fond (vert, 0x00FF00)
    push 1                          ; Épaisseur du bord
    call XCreateSimpleWindow        ; Appelle XCreateSimpleWindow pour créer la fenêtre
    mov qword[window],rax           ; Stocke l'identifiant de la fenêtre dans 'window'

    ; Sélectionne les événements à écouter sur la fenêtre
    mov rdi,qword[display_name]
    mov rsi,qword[window]
    mov rdx,131077                 ; Masque d'événements (ex : StructureNotifyMask + autres)
    call XSelectInput

    ; Affiche (mappe) la fenêtre
    mov rdi,qword[display_name]
    mov rsi,qword[window]
    call XMapWindow

    ; Création du contexte graphique (GC) avec vérification d'erreur
    mov rdi, qword[display_name]
    test rdi, rdi                ; Vérifie que le display est valide
    jz closeDisplay

    mov rsi, qword[window]
    test rsi, rsi                ; Vérifie que la fenêtre est valide
    jz closeDisplay

    xor rdx, rdx                 ; Aucun masque particulier
    xor rcx, rcx                 ; Aucune valeur particulière
    call XCreateGC               ; Appelle XCreateGC pour créer le contexte graphique
    test rax, rax                ; Vérifie que le GC a été créé avec succès
    jz closeDisplay              ; En cas d'échec, quitte le programme
    mov qword[gc], rax           ; Stocke le GC dans 'gc'

boucle: ; Boucle de gestion des événements
    mov     rdi, qword[display_name]
    mov     rsi, event          ; Adresse de la structure d'événement
    call    XNextEvent          ; Attend et récupère le prochain événement

    cmp     dword[event], ConfigureNotify ; Si l'événement est ConfigureNotify (apparition/redimensionnement)
    je      foyers                        ; Passe à la génération des foyers

    cmp     dword[event], KeyPress        ; Si une touche est pressée
    je      closeDisplay                  ; Quitte le programme
    jmp     boucle                        ; Sinon, retourne dans la boucle d'événements

; -----------------------------------------------------------
; GENERATION DES FOYERS
; -----------------------------------------------------------
foyers:
    cmp     byte [drawing_done], 1  ; Vérifie si le dessin a déjà été réalisé
    je      boucle                 ; Si oui, retourne à la boucle d'événements

    xor r14, r14                   ; Initialise le compteur (r14 = 0)

boucle_foyers:
        ; Génération de la coordonnée x du foyer
        mov ecx, [width]         ; Charge la largeur (maximale valeur pour x)
        call generate_random     ; Génère un nombre aléatoire dans [0, width)
        mov [tableau_x_foyers + r14 * 4], r12  ; Sauvegarde la coordonnée x dans le tableau

        ; Génération de la coordonnée y du foyer
        mov ecx, [height]        ; Charge la hauteur (maximale valeur pour y)
        call generate_random     ; Génère un nombre aléatoire dans [0, height)
        mov [tableau_y_foyers + r14 * 4], r12  ; Sauvegarde la coordonnée y dans le tableau

        ; Génération d'une couleur aléatoire pour le foyer
        ; On choisit un nombre entre 0 et (nb_colors - 1)
        mov ecx, [nb_colors]
        call generate_random     ; Génère un indice aléatoire pour la couleur
        ; Récupère la couleur correspondante dans le tableau 'colors'
        mov r12d, [colors + r12 * 4]
        ; Sauvegarde la couleur dans le tableau de couleurs des foyers
        mov [tableau_color_foyers + r14 * 4], r12d

        ; Incrémente le compteur de foyers
        inc r14
        ; Si le compteur est inférieur au nombre total de foyers, boucle
        cmp r14d, [nb_foyers]
        jl boucle_foyers
        ; Les lignes commentées suivantes semblaient destinées à ajuster nb_foyers
        ;dec r14d
        ;mov [nb_foyers], r14d

; -----------------------------------------------------------
; FIN DE LA GENERATION DES FOYERS
; -----------------------------------------------------------

; -----------------------------------------------------------
; ZONE DE DESSIN
; -----------------------------------------------------------
    xor r14, r14              ; Réinitialise le compteur de points
    jmp boucle_points         ; Passe à la génération et au traitement des points

; Boucle de génération et traitement des points
boucle_points:
    ; Génère une coordonnée x aléatoire pour le point
    mov ecx, [width]
    call generate_random
    mov [x1], r12d            ; Sauvegarde la coordonnée x dans x1

    ; Génère une coordonnée y aléatoire pour le point
    mov ecx, [height]
    call generate_random
    mov [y1], r12             ; Sauvegarde la coordonnée y dans y1

    ; Recherche du foyer le plus proche pour ce point
    xor r15d, r15d            ; Initialise l'indice du foyer (r15d = 0)
    mov dword [distance_min], 0xffffff  ; Initialise la distance minimale à une valeur très élevée

boucle_foyers_point:
        ; Calcule la distance au carré entre le point (x1, y1) et le foyer courant
        mov rdi, [tableau_x_foyers + r15d * 4]  ; Charge la coordonnée x du foyer courant
        mov rsi, [tableau_y_foyers + r15d * 4]  ; Charge la coordonnée y du foyer courant
        mov rdx, [x1]                           ; Charge la coordonnée x du point
        mov rcx, [y1]                           ; Charge la coordonnée y du point
        call calc_squared_distance              ; Calcule (x1-x2)²+(y1-y2)², résultat dans r12d

        ; Si la distance calculée est inférieure à la distance minimale enregistrée, sauvegarde-la
        cmp r12d,[distance_min]
        jl sauvegarde_distance

suite_boucle_foyers_point:
        ; Passe au foyer suivant
        inc r15d
        cmp r15d, [nb_foyers]    ; Si tous les foyers n'ont pas été examinés, boucle
        jl boucle_foyers_point

    ; Une fois le foyer le plus proche trouvé, dessine la ligne reliant le point à ce foyer
    ; L'indice du foyer le plus proche est stocké dans 'distance_min_id'
    mov rbp, [distance_min_id]   ; Stocke temporairement l'indice du foyer dans rbp

    ; Récupère l'indice du foyer le plus proche
    mov r12d, [distance_min_id]
    ; Vérifie que l'indice est valide
    cmp r12d, [nb_foyers]
    jg erreur

    ; Définition de la couleur du trait pour ce point : on récupère la couleur du foyer associé
    mov rdi,qword[display_name]
    mov rsi,qword[gc]
    mov edx,[tableau_color_foyers + r12d * 4]  ; Récupère la couleur associée au foyer
    call XSetForeground

    ; Vérifie à nouveau que l'indice est dans les limites
    cmp r12d, [nb_foyers]
    jg erreur

    mov r12d, [distance_min_id]
    cmp r12d, [nb_foyers]       ; Vérifie que l'indice est bien dans les limites
    jae erreur                ; Si indice invalide, saute à l'étiquette 'erreur'

    ; Calcule l'offset pour accéder aux coordonnées du foyer
    imul r12d, 4                ; Multiplie l'indice par 4 (taille d'un DWORD)
    mov eax, [tableau_x_foyers + r12]  ; Récupère la coordonnée x du foyer
    mov dword[x2], eax               ; Sauvegarde la coordonnée x dans x2
    mov eax, [tableau_y_foyers + r12]  ; Récupère la coordonnée y du foyer
    mov dword[y2], eax               ; Sauvegarde la coordonnée y dans y2

    ; Dessin de la ligne reliant le point (x1,y1) au foyer (x2,y2)
    mov rdi, qword[display_name]  ; Paramètre : display
    test rdi, rdi                 ; Vérifie que display n'est pas NULL
    jz closeDisplay

    mov rsi,qword[window]         ; Paramètre : fenêtre
    test rsi, rsi                 ; Vérifie que window n'est pas NULL
    jz closeDisplay

    mov rdx,qword[gc]             ; Paramètre : contexte graphique (GC)
    test rdx, rdx                ; Vérifie que gc n'est pas NULL
    jz closeDisplay

    mov ecx,dword[x1]            ; Coordonnée x de départ (point)
    mov r8d,dword[y1]            ; Coordonnée y de départ (point)
    mov r9d,dword[x2]            ; Coordonnée x d'arrivée (foyer)
    sub rsp, 16                 ; Alloue 16 octets sur la pile pour passer y2
    mov eax, dword[y2]
    mov [rsp], rax              ; Pousse la coordonnée y d'arrivée sur la pile

    call XDrawLine              ; Appelle XDrawLine pour dessiner la ligne

    ; Incrémente le compteur de points traités
    inc r14
    cmp r14d, [nb_points]       ; Si tous les points n'ont pas été traités, boucle
    jl boucle_points
    jmp flush                 ; Sinon, passe à l'étape de rafraîchissement

sauvegarde_distance:
    ; Sauvegarde la distance minimale trouvée et l'indice du foyer correspondant
    mov [distance_min], r12
    mov [distance_min_id], r15d
    jmp suite_boucle_foyers_point

; -----------------------------------------------------------
; FIN DE LA ZONE DE DESSIN
; -----------------------------------------------------------
flush:
    mov     byte [drawing_done], 1   ; Marque que le dessin est terminé
    mov rdi,qword[display_name]
    call XFlush                  ; Rafraîchit l'affichage (affiche le dessin)
    jmp boucle                   ; Retourne à la boucle d'événements
    mov rax,34                  ; Code mort (ne sera jamais exécuté)
    syscall

closeDisplay:
    ; Ferme le display et quitte le programme
    mov     rax, qword[display_name]
    mov     rdi, rax
    call    XCloseDisplay        ; Ferme la connexion au display X11
    xor     rdi, rdi
    call    exit                 ; Quitte le programme

; -----------------------------------------------------------
; Gestion d'erreur : affiche un message d'erreur et quitte
; -----------------------------------------------------------
erreur:
    ; Affiche l'indice problématique via printf
    mov    rdi, affichage_indice
    mov    rsi, r12
    xor    eax, eax
    call   printf

    ; Affiche un message d'erreur explicatif
    mov     rdi, error_message
    xor     eax, eax
    call    printf
    jmp     closeDisplay         ; Quitte le programme après l'affichage de l'erreur

; -----------------------------------------------------------
; Fonction generate_random
; -----------------------------------------------------------
; Génère un nombre aléatoire dans l'intervalle [0, ecx - 1] à l'aide de l'instruction RDRAND.
; Entrée : ecx contient la valeur maximale (non incluse)
; Sortie : r12d contient le nombre aléatoire généré
generate_random:
    rdrand r12d         ; Génère un nombre aléatoire et le stocke dans r12d
    jnc generate_random ; Si l'instruction échoue (flag CF non levé), recommence
    xor edx, edx        ; Efface edx pour la division
    mov eax, r12d
    div ecx             ; Effectue la division : eax = quotient, edx = reste
    mov r12d, edx       ; Le reste (edx) est le résultat modulo ecx
    ret

; -----------------------------------------------------------
; Fonction calc_squared_distance
; -----------------------------------------------------------
; Calcule la distance au carré entre deux points (évite de calculer la racine carrée pour la comparaison)
; Entrées :
;   rdi : x1 (coordonnée x du premier point)
;   rsi : y1 (coordonnée y du premier point)
;   rdx : x2 (coordonnée x du second point)
;   rcx : y2 (coordonnée y du second point)
; Sortie :
;   r12d : distance au carré = (x1 - x2)² + (y1 - y2)²
calc_squared_distance:
    ; Calcul de (x1 - x2)²
    sub rdi, rdx        ; rdi = x1 - x2
    imul rdi, rdi       ; rdi = (x1 - x2)²

    ; Calcul de (y1 - y2)²
    sub rsi, rcx        ; rsi = y1 - y2
    imul rsi, rsi       ; rsi = (y1 - y2)²

    ; Addition des deux carrés
    add rdi, rsi        ; rdi = (x1 - x2)² + (y1 - y2)²
    mov r12d, edi       ; Stocke le résultat dans r12d
    ret
