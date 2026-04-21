# Installation / exécution (sans toolchain)

## Objectif

Exécuter Fazer OS **sans installer** d’outils de compilation (`python`, `nasm`) ni d’outil de ligne de commande VM (`qemu`).

## 1) Récupérer une image prête

Le dépôt fournit un workflow CI qui génère des images prêtes à démarrer.

- Image brute : `fazer.img`
- Image VirtualBox : `fazer.vmdk`

## 2) Démarrer avec VirtualBox

1) Créer une nouvelle VM : **Other/Unknown (64-bit)**
2) **Désactiver EFI/UEFI** (boot legacy/BIOS)
3) Stockage : ajouter le disque `fazer.vmdk` (ou convertir `fazer.img` en VDI si tu préfères)
4) Démarrer

## 3) Première utilisation

Dans le shell :

- `help`
- `mkfs`
- `write note hello`
- `ls`
- `cat note`

L’écran affiche aussi un bandeau en haut et une barre d’état (ticks et statut FS).

## Notes importantes

- Un OS ne peut pas “tourner tout seul” *dans* Windows/macOS : il faut soit une VM (VirtualBox/VMware), soit booter la machine dessus.
- Le stockage côté noyau utilise ATA PIO (pratique en VM via IDE). Sur du matériel moderne/USB, il faudrait implémenter d’autres pilotes (non inclus pour l’instant).
