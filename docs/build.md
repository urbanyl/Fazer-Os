# Build & exécution (Windows)

## Toolchain

Le build nécessite uniquement :

- `python`
- `nasm`

Une option simple sous Windows est **MSYS2**.

Dans un shell MSYS2 (UCRT64), installer :

- `make`
- `python`
- `nasm`
- `mingw-w64-ucrt-x86_64-qemu` (optionnel pour exécuter)
- un toolchain cross `x86_64-elf-*` (souvent via paquet MSYS2 dédié ou toolchain tiers)

Le dépôt fournit aussi `tools/build.ps1` si tu n’utilises pas `make`.

## Générer l’image disque

Depuis la racine du dépôt :

```bash
make image
```

Ou :

```powershell
./tools/build.ps1
```

Sortie : `build/fazer.img`.

## Lancer en VM

```bash
make run
```

Ou :

```powershell
./tools/run-qemu.ps1
```

### VirtualBox (option)

- Créer une VM **Other/Unknown (64-bit)**
- Activer **EFI: désactivé** (boot legacy)
- Ajouter `build/fazer.img` comme disque dur via un **contrôleur IDE**

## Écrire sur une clé USB (boot BIOS/Legacy)

1) Générer l’image : `make image`
2) Écrire `build/fazer.img` sur la clé USB avec un outil type Rufus (mode image brute) ou un équivalent `dd`.

## Limites actuelles

- Le boot est BIOS (legacy). Le support UEFI n’est pas encore implémenté.
- Le stockage en VM est prévu en IDE (ATA PIO). Pour VirtualBox, utiliser un contrôleur IDE.

## Notes

- Le prototype vise le démarrage + console + IRQ de base. Il ne fournit pas encore de système de fichiers, pile réseau, multiprocesseur ou chiffrement.
