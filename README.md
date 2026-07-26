# InstaBatch Crop

Application macOS native pour recadrer automatiquement des images aux formats Instagram, en gardant les sujets importants dans le cadre.

![Apercu de l'application](assets/screenshots/app-main.png)

## Telecharger

- Version stable: [v2.0](https://github.com/bizc0m/InstaBatchCrop/releases/tag/v2.0)
- Application compilee dans le repo: `dist/2.0/InstaBatch Crop V2.0.app`
- Archive ZIP: `dist/2.0/InstaBatch-Crop-V2.0.app.zip`

## Lancer l'application

1. Ouvrir `dist/2.0/InstaBatch Crop V2.0.app`.
2. Si macOS bloque l'ouverture: clic droit sur l'app, puis `Ouvrir`.
3. Glisser-deposer des photos dans la zone de gauche.
4. Choisir les formats Instagram.
5. Cliquer `Traiter toutes les photos`.

Les fichiers sources ne sont jamais modifies. L'application cree un dossier d'export a cote des images.

## Fonctionnalites

- Formats Instagram: portrait 4:5, carre 1:1, story 9:16.
- Import par fichiers, dossier ou glisser-deposer.
- File d'images avec selection, suppression et nettoyage complet.
- Analyse locale Vision: visages, corps humains, animaux si disponibles, saillance.
- Points et zones d'interet manuels par photo.
- Apercu avant / apres.
- Deplacement direct du cadrage dans l'aperçu apres.
- Reglages de cadrage avec fleches et zoom.
- Export JPEG, PNG et WebP.
- Reglage `Compression` pour JPEG.
- Watermark texte optionnel: couleur, position, opacite, taille, marge.
- Watermark image/logo transparent optionnel.
- Interface FR / EN.
- Application autonome signee ad hoc.

## Documentation

- [Installation](docs/INSTALL.md)
- [Guide utilisateur](docs/USER_GUIDE.md)
- [Versions et releases](docs/RELEASES.md)
- [Changelog](CHANGELOG.md)

## Structure du depot

```text
InstaBatchCrop/
├── InstaBatchCrop/          # Interface SwiftUI
├── InstaBatchCropCore/      # Moteur de cadrage, export, watermark
├── InstaBatchCropTests/     # Tests unitaires et integration
├── assets/
│   ├── icon.png             # Icone lisible pour GitHub
│   ├── AppIcon.png          # Source de l'icone app
│   ├── AppIcon.icns         # Icone macOS
│   └── screenshots/         # Captures README
├── dist/
│   ├── 0.7/                 # Ancienne version preservee
│   ├── 1.54/
│   └── 2.0/                 # Version stable actuelle
├── docs/
└── logs/
```

## Compiler depuis les sources

Prerequis: macOS avec Xcode 26.x ou Swift 6.x.

```bash
cd /Users/JOB/#DEV/02-apps/InstaBatchCrop
swift test
xcodebuild -scheme InstaBatchCrop -destination 'platform=macOS' build
```

Dans Xcode: ouvrir `Package.swift`, puis lancer le scheme `InstaBatchCrop`.

## Tests

Commande validee localement:

```bash
swift test
```

Resultat connu pour v2.0: 19 tests passes.

## Notes techniques

- `Compression` est significatif pour JPEG.
- PNG est sans perte et ignore la compression qualite ImageIO.
- WebP peut interpreter cette valeur selon le support ImageIO disponible sur macOS.
- Le watermark est rendu localement, sans service externe.
- L'application est signee ad hoc localement, mais pas notarisee Apple.
