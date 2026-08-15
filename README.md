# OpenAIP Map — Application Garmin Connect IQ

Application de cartographie aéronautique pour Garmin D2 Air X10 affichant la position GPS en temps réel sur les tuiles OpenAIP.

## Fonctionnalités

- Position GPS temps réel centrée à l'écran
- Tuiles cartographiques OpenAIP (ou tout serveur XYZ compatible)
- Buffer de tuiles paramétrable (taille configurable via Garmin Connect Mobile)
- Zoom par boutons physiques ou tap écran (tiers haut = zoom in, tiers bas = zoom out)
- HUD superposé : altitude (ft), vitesse (kt), cap, niveau de zoom, taille du cache
- Marqueur de position orienté selon le cap
- Éviction intelligente par distance (les tuiles les plus éloignées sont libérées en premier)
- Téléchargement priorisé (les tuiles proches du centre sont chargées en premier)

## Prérequis

1. **Connect IQ SDK** ≥ 4.2 — [developer.garmin.com/connect-iq/sdk](https://developer.garmin.com/connect-iq/sdk/)
2. **Compte OpenAIP** et clé API — [www.openaip.net](https://www.openaip.net/)
3. **Device profile** D2 Air X10 installé dans le SDK Manager

## Build

```bash
# Depuis le répertoire du projet
monkeyc -d d2airx10 -f monkey.jungle -o bin/OpenAipMap.prg -y /path/to/developer_key.der
```

Ou via l'extension VS Code Connect IQ (recommandé).

## Configuration (Garmin Connect Mobile)

Après installation sur la montre, ouvrir les paramètres de l'app dans Garmin Connect Mobile :

| Paramètre | Description | Défaut |
|-----------|-------------|--------|
| Clé API OpenAIP | Clé obtenue sur openaip.net | *(vide)* |
| Taille buffer | Nombre max de tuiles en cache (4-36) | 16 |
| Zoom par défaut | Niveau de zoom initial (5-15) | 10 |
| URL template tuiles | URL avec placeholders `{z}`, `{x}`, `{y}`, `{k}` | URL OpenAIP |

### URL templates alternatives

```
# OpenAIP (défaut)
https://api.tiles.openaip.net/api/data/openaip/{z}/{x}/{y}.png?apiKey={k}

# OpenStreetMap (base map sans aéro)
https://tile.openstreetmap.org/{z}/{x}/{y}.png

# OpenTopoMap
https://tile.opentopomap.org/{z}/{x}/{y}.png
```

## Commandes en vol

| Action | Entrée |
|--------|--------|
| Zoom + | Bouton haut / tap tiers supérieur |
| Zoom − | Bouton bas / tap tiers inférieur |
| Quitter | Bouton back |

## Architecture

```
source/
├── OpenAipApp.mc     # Entry point, GPS lifecycle
├── MapView.mc        # Rendu carte + HUD
├── MapDelegate.mc    # Gestion entrées utilisateur
├── TileManager.mc    # Download queue, cache, éviction
└── TileUtils.mc      # Conversion GPS ↔ tuiles (Web Mercator)
```

## Compiler sans PC (GitHub Actions)

Tout se fait depuis l'app **GitHub Mobile** (iOS/Android) :

### 1. Créer le repo
- Ouvrir GitHub Mobile → `+` → New Repository → `openaip-garmin`
- Uploader le contenu du `.tar.gz` (ou utiliser `git push` depuis Termux/iSH)

### 2. Build automatique
Deux workflows sont fournis dans `.github/workflows/` :
- **`build.yml`** — télécharge le SDK à chaque run (autonome, mais l'URL du SDK peut changer)
- **`build-docker.yml`** — utilise l'image Docker `ghcr.io/matco/connectiq-tester` (plus fiable)

Le build se déclenche à chaque push sur `main`, ou manuellement via **Actions → workflow → Run workflow**.

### 3. Récupérer le .prg
GitHub Mobile → Actions → dernier run vert → **Artifacts** → `openaip-map-garmin` → télécharger.

### 4. Sideloader sur la montre
Copier le `.prg` dans `GARMIN/APPS/` sur la montre via USB, ou utiliser l'app Garmin Connect si supporté.

### Clé développeur persistante (optionnel)
Pour du sideloading stable, générer une clé une fois :
```bash
openssl genrsa -out dev_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in dev_key.pem -out developer_key.der -nocrypt
base64 developer_key.der | pbcopy  # ou xclip
```
Puis l'ajouter en secret GitHub : Settings → Secrets → `GARMIN_DEV_KEY` (contenu base64).

## Limitations connues

- Le téléchargement des tuiles passe par le BLE vers le téléphone ; sans connexion, seul le cache est disponible
- `makeImageRequest` traite une requête à la fois → temps de chargement initial notable
- La mémoire disponible sur la montre limite le buffer effectif (ajuster si crash OOM)
- Pas de déclinaison magnétique intégrée — le cap affiché est le cap GPS (track)
- Le product ID `d2airx10` dans le manifest est à vérifier dans le SDK Manager

## Évolutions possibles

- Double layer : OSM base + overlay OpenAIP
- Mode North-up / Track-up
- Affichage des espaces aériens en overlay vectoriel
- Waypoints et route planning
- Cache persistant (Storage API)
