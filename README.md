# Projet d'Architecture Matérielle et Assembleur - Diagramme de Voronoï

## Description

Ce projet consiste à implémenter l'algorithme du diagramme de Voronoï en langage assembleur NASM (x86-64) sous Linux. L'objectif est de générer aléatoirement des foyers et des points, puis pour chaque point de déterminer le foyer le plus proche et de le relier graphiquement. Plusieurs étapes sont prévues :

1. **Génération des foyers et points**  
   - Générer des coordonnées aléatoires pour un certain nombre de foyers et de points.
   - Pour chaque point, déterminer le foyer le plus proche en calculant la distance au carré.

2. **Coloration**  
   - Appliquer une couleur unique par foyer (sélectionnée aléatoirement dans un tableau de couleurs).
   - Colorer graphiquement les points ou les traits reliant les points à leur foyer.

3. **Affichage graphique**  
   - Utilisation de la bibliothèque X11 pour la création de la fenêtre, la gestion des événements et le dessin.

## Fonctionnalités

- **Génération aléatoire** : Utilisation de l'instruction `RDRAND` pour obtenir des nombres aléatoires.
- **Calcul de distance** : Calcul de la distance au carré entre deux points pour éviter le calcul coûteux d'une racine carrée.
- **Affichage graphique** : Création et gestion d'une fenêtre X11, dessin de points et de lignes, gestion des événements (apparition, redimensionnement, pression de touche, etc.).
- **Coloration** : Application de couleurs issues d'une palette prédéfinie pour distinguer les foyers et les éléments graphiques.

## Prérequis

- **Système** : Linux (ou WSL sous Windows)
- **Outils** :
  - NASM (assembleur x86-64)
  - GCC (pour l’édition de lien)
  - Bibliothèque X11 (libX11)

## Structure du Projet

Le répertoire du projet contient les fichiers suivants :

```plaintext
.
├── 1_etape.asm
├── 2_etape.asm
├── 3_etape.asm
├── 4_etape.asm
└── Enoncé détaillé du projet.pdf