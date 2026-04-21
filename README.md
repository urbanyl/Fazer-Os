# Fazer OS (prototype)

OS x86_64 bare metal écrit en assembleur : boot BIOS (MBR + stage2 + long mode), noyau 64-bit, shell et mini système de fichiers.

## Installation (le plus simple)

Tu ne peux pas “lancer un OS” directement dans Windows/macOS : il faut soit une **VM**, soit démarrer la machine dessus.

### Option A — Sans installer d’outils (recommandé)

1) Télécharge une image prête à démarrer (artefacts du workflow GitHub `build-image`) :
- `fazer.iso` (Image CD/DVD bootable - le plus universel pour les VM)
- `fazer.vmdk` (VirtualBox / VMware)
- `fazer.img` (image disque brute)

2) Démarre dans VirtualBox :
- VM : **Other/Unknown (64-bit)**
- **EFI/UEFI désactivé** (boot legacy/BIOS)
- Disque : attacher `fazer.vmdk` comme disque dur IDE, OU `fazer.iso` dans le lecteur CD optique.

Conversion `fazer.img` → disque VirtualBox (sans Python/NASM/QEMU) :

```powershell
./tools/vbox-make-disk.ps1 -RawImage .\fazer.img -OutDisk .\build\fazer.vdi -Format VDI
```

Créer automatiquement une VM VirtualBox et y attacher le disque :

```powershell
./tools/vbox-createvm.ps1 -Name FazerOS -DiskPath .\build\fazer.vdi
```

### Option B — Build local (développeurs)

Prérequis :
- `python`
- `nasm`
- (optionnel) `qemu-system-x86_64`

Build :

```bash
make image
```

Windows (sans `make`) :

```powershell
./tools/build.ps1
```

Lancer en VM (QEMU) :

```bash
make run
```

Windows :

```powershell
./tools/run-qemu.ps1
```

## Première utilisation

Commandes utiles :
- `help`
- `mkfs`
- `write note hello`
- `ls`
- `cat note`
- `rm note`

## Fonctionnalités (actuel)

- Boot BIOS x86_64 : MBR (stage1) → stage2 → long mode
- Noyau 64-bit : UI texte VGA (bandeau + barre d’état + console), IDT, IRQ timer (PIT), clavier (PS/2)
- Debug VM : sortie série COM1 (visible avec `-serial stdio`)
- Stockage : pilote ATA PIO (VM IDE) + mini FS persistant (prototype)

## Boot USB

`build/fazer.img` est bootable BIOS (legacy) et peut être écrit sur une clé USB.
Attention : sur du matériel réel, l’accès disque côté noyau est prévu pour ATA (pas USB mass storage).

## Documentation

- [install.md](docs/install.md)
- [build.md](docs/build.md)
- [architecture.md](docs/architecture.md)
