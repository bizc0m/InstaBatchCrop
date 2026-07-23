# InstaBatch Crop

Application macOS native SwiftUI pour adapter des photos en lot aux formats Instagram en gardant le sujet principal dans le cadre.

## Version

0.7

## Statut

MVP fonctionnel compile et teste localement.

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

## Compilation

Prérequis: macOS avec Xcode 26.x ou Swift 6.x.

```bash
cd /Users/JOB/Documents/Codex/2026-07-23/files-mentioned-by-the-user-cr/outputs/InstaBatchCrop
swift test
xcodebuild -scheme InstaBatchCrop -destination 'platform=macOS' build
```

Dans Xcode: `File > Open...` puis ouvrir le dossier `InstaBatchCrop` ou `Package.swift`. Choisir le scheme `InstaBatchCrop`.

## Utilisation

1. Lancer l'application depuis Xcode ou avec `swift run InstaBatchCrop`.
2. Ajouter des images avec `Choisir fichiers`, `Choisir dossier` ou glisser-deposer.
3. Choisir un ou plusieurs formats.
4. Regler mode, marge, secours, type d'export et qualite.
5. Selectionner une image et cliquer `Generer apercu`.
6. Ajuster X/Y/Zoom si necessaire, puis `Appliquer correction manuelle`.
7. Cliquer `Traiter toutes les photos`.

Les sources ne sont jamais ecrasees. Un dossier `InstaBatchCrop_Export_YYYY-MM-DD_HHMMSS` est cree pres des images sources.

## Architecture

- `InstaBatchCrop`: interface SwiftUI et etat applicatif.
- `InstaBatchCropCore/Models.swift`: formats, reglages, observations, resultats.
- `VisionSubjectAnalyzer.swift`: extraction Vision locale des zones d'interet.
- `CropEngine.swift`: calcul pur du meilleur cadrage, sans dependance UI.
- `ImageRenderer.swift`: rendu Core Image, fond de secours, overlay debug, export ImageIO.
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

Commande validee:

```bash
swift test
```

Resultat local: 9 tests passes.

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
- La correction manuelle est volontairement simple: offset X/Y et zoom du cadrage retenu.

## Plan d'amelioration

1. Ajouter segmentation Vision/Core ML de sujet principal pour des contours plus precis.
2. Exposer un editeur de cadrage visuel avec poignées.
3. Ajouter presets de nommage et sous-dossiers par format.
4. Ajouter notarisation, icone et distribution `.app`.
5. Ajouter support transparent uniquement quand PNG/WebP est selectionne.
6. Ajouter benchmark memoire/temps pour plusieurs centaines d'images.
