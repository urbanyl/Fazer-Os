# Architecture (prototype)

## Vue d’ensemble

```
Disque (raw)
  LBA 0     : MBR / Stage1 (512B)
  LBA 1..N  : Stage2 (chargeur)
  LBA N+1.. : Noyau 64-bit (binaire brut)

Stage1 (16-bit) -> Stage2 (16-bit) -> Long mode -> Kernel (64-bit)
```

## Boot

- **Stage1 (MBR)** : chargé à `0x7C00` par le BIOS, lit `STAGE2_SECTORS` secteurs en mémoire et saute vers Stage2.
- **Stage2** :
  - active A20
  - lit le noyau en mémoire à `0x00100000`
  - configure GDT
  - active PAE + EFER.LME + pagination (pages 2MiB)
  - saute en long mode 64-bit vers l’entrée du noyau

## Noyau (monolithique, minimal)

- **Sortie console** : VGA texte (`0xB8000`)
- **UI texte** : bandeau (ligne 0) + barre d’état (ligne 1) + console scroll (lignes 2..24)
- **Interruptions** : IDT + PIC remappé, IRQ0 (timer PIT), IRQ1 (clavier)
- **Temps** : compteur `ticks` incrémenté à chaque interruption timer
- **Entrées** : buffer circulaire de scancodes clavier, conversion ASCII simple
- **Shell** : boucle interactive et commandes intégrées (sûres)

## Système de fichiers (prototype)

- **FazerFS (minimal)** : superbloc + table de répertoire fixe (128 entrées) + zone de données contiguë.
- **Accès disque** : pilote ATA PIO (fonctionnel en VM avec disque IDE).

## Sécurité (périmètre actuel)

Le prototype se limite volontairement à des primitives système. Les fonctionnalités d’attaque, d’anti-forensic, d’obfuscation et d’exploitation ne sont pas incluses.
