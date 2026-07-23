# InstaBatch Crop

Application macOS native SwiftUI pour adapter des photos en lot aux formats Instagram en gardant le sujet principal dans le cadre.

## Version

1.0-dev

## Statut

Version de developpement basee sur v0.7, compilee et testee localement.

- Import fichiers, dossier et glisser-deposer.
- Analyse locale Vision: visages, corps humains, animaux quand disponible, saillance attention/objectness.
- Moteur de cadrage independant et teste.
- Exports 1080x1350, 1080x1080, 1080x1920.
- Export JPEG, PNG, WebP.
- Qualite JPEG configurable.
- Option de conservation des metadonnees.
- Secours fond floute, fond uni, image entiere ou recadrage maximal.
- Traitement batch parallele.
- Rapport final dans l'interface.
- Mode debug avec bounding boxes.
- Correction manuelle par offset/zoom sur l'image selectionnee et reappliquee au batch.
- Selection multiple dans la file, suppression des images selectionnees et nettoyage complet de la file.
- Deplacement direct du cadrage dans l'apercu apres avec outil main.
- Watermark texte optionnel applique au rendu final.
- Icône d'application intégrée dans le bundle macOS `dist/1.0-dev`.

## Compilation

Prérequis: macOS avec Xcode 26.x ou Swift 6.x.

```bash
cd /Users/JOB/Documents/Codex/2026-07-23/files-mentioned-by-the-user-cr/outputs/InstaBatchCrop
swift test
xcodebuild -scheme InstaBatchCrop -destination 'platform=macOS' build
```

Dans Xcode: `File > Open...` puis ouvrir le dossier `InstaBatchCrop` ou `Package.swift`. Choisir le scheme `InstaBatchCrop`.

## Utilisation

1. Lancer l'application autonome `dist/0.7/InstaBatch Crop V0.7.app`, depuis Xcode ou avec `swift run InstaBatchCrop`.
2. Ajouter des images avec `Choisir fichiers`, `Choisir dossier` ou glisser-deposer.
3. Choisir un ou plusieurs formats.
4. Regler mode, marge, secours, type d'export et qualite.
5. Selectionner une image et cliquer `Generer apercu`.
6. Activer l'outil main pour deplacer le cadrage directement dans l'apercu apres, ou ajuster X/Y/Zoom, puis `Appliquer correction manuelle`.
7. Cliquer `Traiter toutes les photos`.

Les sources ne sont jamais ecrasees. Un dossier `InstaBatchCrop_Export_YYYY-MM-DD_HHMMSS` est cree pres des images sources.

## Architecture

- `InstaBatchCrop`: interface SwiftUI et etat applicatif.
- `InstaBatchCropCore/Models.swift`: formats, reglages, observations, resultats.
- `VisionSubjectAnalyzer.swift`: extraction Vision locale des zones d'interet.
- `CropEngine.swift`: calcul pur du meilleur cadrage, sans dependance UI.
- `ImageRenderer.swift`: rendu Core Image, fond de secours, overlay debug, export ImageIO.
- `WatermarkRenderer.swift`: rendu local du watermark texte et calcul de placement.
- `BatchProcessor.swift`: orchestration parallele et nommage des fichiers.
- `InstaBatchCropTests`: tests unitaires et integration batch.

## Algorithme

1. Convertit les bounding boxes Vision en pixels image.
2. Fusionne les observations pertinentes.
3. Pondere les visages plus fortement que corps, animaux, objets et saillance.
4. Ajoute une marge proportionnelle.
5. Genere plusieurs rectangles compatibles avec le ratio cible.
6. Score chaque candidat: couverture sujet/visages, centrage, espace au-dessus, resolution, equilibre.
7. Utilise un fond de secours si le score est trop bas ou si le sujet serait coupe.

## Tests

Tests couverts:

- sujet unique;
- visage proche d'un bord;
- plusieurs personnes;
- sujet tres large;
- paysage vers portrait;
- image sans sujet identifiable;
- basse resolution;
- orientation EXIF cote repere pixel;
- integration batch avec ecriture et verification de dimensions.
- configuration et placement du watermark;
- integration batch avec watermark active.

Commande validee:

```bash
swift test
```

Resultat local: 12 tests passes.

## Compression

Le controle `Compression` pilote la qualite transmise a ImageIO. Il est significatif pour JPEG. PNG est sans perte et ignore cette notion de qualite avec les encodeurs systeme. WebP peut l'interpreter selon le support ImageIO disponible sur la version de macOS.

## Watermark

Le watermark est local et optionnel. La version actuelle supporte un texte, une position, une opacite, une taille et une marge. La logique est separee dans `WatermarkRenderer` pour permettre de remplacer plus tard le texte par une image ou un logo.

## Icone

L'icone source est conservee dans `assets/AppIcon.png`. Le bundle macOS utilise `AppIcon.icns` dans `dist/1.0-dev/InstaBatch Crop V1.0-dev.app/Contents/Resources/`.

## Photos de test

Le dossier `TestPhotos/` contient 5 images synthetiques generees localement.

Regeneration:

```bash
swift scripts/generate_test_photos.swift
```

## Limites connues

- Vision ne garantit pas une detection parfaite des animaux ou objets generiques selon la version de macOS et les revisions disponibles.
- La detection de "tete" hors visage visible est approximative: elle repose sur corps humain, visage et zone de saillance.
- Le mode transparent est prevu dans le modele d'extension mais non expose dans ce MVP, car JPEG ne supporte pas l'alpha et l'UX doit differencier PNG/WebP.
- L'application est livree comme package Swift Xcode-compatible, pas encore comme archive signee/notarisee `.app`.
- La correction manuelle reste volontairement simple: offset X/Y, zoom et deplacement direct du cadrage retenu.
- Le watermark texte n'integre pas encore de logo image.

## Plan d'amelioration

1. Ajouter segmentation Vision/Core ML de sujet principal pour des contours plus precis.
2. Exposer un editeur de cadrage visuel avec poignées.
3. Ajouter presets de nommage et sous-dossiers par format.
4. Ajouter notarisation, icone et distribution `.app`.
5. Ajouter support transparent uniquement quand PNG/WebP est selectionne.
6. Ajouter benchmark memoire/temps pour plusieurs centaines d'images.
