# Installation / exécution (VM)

## Option 1 (recommandé) : utiliser une image déjà construite

Télécharge une image prête à démarrer depuis les artefacts du workflow GitHub `build-image` :

- `fazer.vmdk` (Le plus simple si tu l'ajoutes comme disque dur IDE)
- `fazer.img` (image disque brute)

### VirtualBox

1) Crée une VM : **Other/Unknown (64-bit)**
2) **Désactive EFI/UEFI** (boot legacy/BIOS)
3) Disque : attache `fazer.vmdk` comme disque dur.
4) Démarre

## Option 2 : convertir une image brute sans QEMU

Si tu as `fazer.img`, VirtualBox fournit `VBoxManage` qui peut convertir une image brute en VDI/VMDK.

```powershell
./tools/vbox-make-disk.ps1 -RawImage .\fazer.img -OutDisk .\build\fazer.vdi -Format VDI
```

Optionnel : créer automatiquement la VM + attacher le disque :

```powershell
./tools/vbox-createvm.ps1 -Name FazerOS -DiskPath .\build\fazer.vdi
```

## Première utilisation

Dans le shell :

- `help`
- `mkfs`
- `write note hello`
- `ls`
- `cat note`

L’écran affiche aussi un bandeau en haut et une barre d’état (ticks et statut FS).

