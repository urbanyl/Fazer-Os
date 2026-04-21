# Build (développeurs)

## Prérequis

- `python`
- `nasm`
- (optionnel) `qemu-system-x86_64`

## Build image

```bash
make image
```

Windows (sans `make`) :

```powershell
./tools/build.ps1
```

Sortie : `build/fazer.img`.

## Lancer avec QEMU

```bash
make run
```

Windows :

```powershell
./tools/run-qemu.ps1
```

Notes :

- Le disque est exposé en IDE en VM pour coller au pilote ATA PIO.

