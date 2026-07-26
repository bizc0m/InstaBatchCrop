# Changelog

## 2.4 - 2026-07-26

- Sauvegarde de la refonte V2.3 sur la branche `backup/v2.3-ux-saved`.
- Retour au design V2.0/V2.1 plus direct, sans layout trois panneaux.
- Optimisations simples: fenetre minimale plus large, colonne images plus confortable, boutons d'import avec icones, et etat vide plus lisible.
- Build autonome `dist/2.4/InstaBatch Crop V2.4.app`, signe ad hoc, ZIP et checksum generes.

## 2.3 - 2026-07-26

- Sauvegarde de l'etat public precedent sur la branche `backup/v2-current-before-2.3-ux`.
- Refonte UX macOS en trois zones redimensionnables: sidebar images, workspace preview, inspector reglages.
- Ajout toolbar macOS avec import fichiers, import dossier, actualisation apercu et export batch.
- Sidebar enrichie avec zone de drop, compteurs, liste d'images et action batch principale.
- Apercu avant/apres mis au centre avec navigation, outils de focus et corrections X/Y/Zoom.
- Reglages de formats, cadrage, export et watermark deplaces dans un inspector droit.
- Build autonome `dist/2.3/InstaBatch Crop V2.3.app`, signe ad hoc, ZIP et checksum generes.

## Documentation - 2026-07-26

- README principal traduit en anglais pour GitHub.
- Ajout d'un brouillon de post Reddit dans `docs/REDDIT_POST.md`.
- Ajout d'une structure GitHub plus lisible pour debutants.
- Ajout capture README dans `assets/screenshots/app-main.png`.
- Ajout icone lisible dans `assets/icon.png`.
- Ajout documentation `INSTALL`, `USER_GUIDE` et `RELEASES`.
- README simplifie avec lien de telechargement, lancement rapide et structure du depot.

## 2.0 - 2026-07-24

- Version validee localement a partir de v1.7.
- Interface FR/EN.
- Points et zones d'interet manuels prioritaires.
- Apercu export avec watermark visible.
- Deplacement direct dans l'aperçu apres sans bouton main.
- Corrections X/Y/Zoom auto-appliquees au batch.
- Boutons fleches visibles pour deplacement horizontal/vertical.
- Build macOS autonome `dist/2.0/InstaBatch Crop V2.0.app`.

## 1.7 - 2026-07-24

- Ajout des points d'interet manuels par photo.
- Ajout des zones d'interet manuelles par photo.
- Ajout navigation image precedente/suivante dans l'aperçu.
- Les points/zones manuels deviennent prioritaires pour l'aperçu et le traitement batch.
- Ajout overlays visuels des points/zones dans l'aperçu avant.
- Suppression du besoin d'utiliser `Appliquer correction`: X/Y/Zoom et la main sont auto-appliques au batch.
- Extension de l'amplitude X/Y/Zoom.
- Correction de l'aperçu watermark dans la zone apres.
- Remplacement des libelles X/Y par des icones fleche horizontale/verticale.
- Ajout du selecteur d'interface FR/EN.
- Ajout test de priorité des annotations manuelles.
- Build macOS autonome `dist/1.7/InstaBatch Crop V1.7.app`.

## 1.0-dev - 2026-07-23

- Ajout selection multiple dans la file d'images.
- Ajout suppression des images selectionnees sans supprimer les fichiers sources.
- Ajout bouton `Nettoyer la file`.
- Ajout outil main pour deplacer directement le cadrage dans l'apercu apres.
- Renommage du controle `JPEG` en `Compression`.
- Ajout watermark texte optionnel au rendu final.
- Ajout `WatermarkRenderer` dans le core.
- Ajout icone d'application dans le bundle macOS.
- Tests portes a 12, avec integration batch watermark.

## 0.7 - 2026-07-23

- Base MVP validee par usage local.
- Application SwiftUI macOS native.
- Detection Vision locale.
- Cadrage batch Instagram 4:5, carre et story.
- Tests moteur et integration batch valides.
- Bundle autonome `InstaBatch Crop V0.7.app` ajoute et signe ad hoc.
