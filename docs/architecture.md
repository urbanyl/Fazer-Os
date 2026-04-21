# Architecture (résumé)

## Boot

- BIOS charge le MBR (stage1) à `0x7C00`
- Stage1 charge Stage2 en mémoire
- Stage2 passe en long mode, charge le noyau à `0x00100000`, puis saute au noyau 64-bit

## Noyau

- UI texte VGA : bandeau (ligne 0) + barre d’état (ligne 1) + console scroll (lignes 2..24)
- Interruptions : IDT (256 vecteurs), PIC remappé, PIT (ticks), clavier PS/2
- Debug : sortie série COM1 (visible dans QEMU avec `-serial stdio`)

## Stockage / FS (prototype)

- Accès disque : ATA PIO (pratique en VM IDE)
- FS : superbloc + répertoire fixe (128 entrées) + données contiguës (prototype)

