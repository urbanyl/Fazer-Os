import argparse
import os


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate Fazer OS build artifacts")
    ap.add_argument("--mbr", required=True)
    ap.add_argument("--stage2", required=True)
    ap.add_argument("--kernel", required=True)
    ap.add_argument("--stage2-sectors", type=int, required=True)
    args = ap.parse_args()

    with open(args.mbr, "rb") as f:
        mbr = f.read()
    if len(mbr) != 512:
        raise SystemExit(f"MBR must be 512 bytes, got {len(mbr)}")
    if mbr[510:512] != b"\x55\xAA":
        raise SystemExit("MBR missing 0x55AA signature")

    with open(args.stage2, "rb") as f:
        stage2 = f.read()
    if len(stage2) > args.stage2_sectors * 512:
        raise SystemExit("Stage2 exceeds reserved sector budget")
    if stage2.find((0xCAFEBABE).to_bytes(4, "little")) == -1:
        raise SystemExit("Stage2 is missing kernel sector placeholder")

    with open(args.kernel, "rb") as f:
        kernel = f.read()
    if len(kernel) == 0:
        raise SystemExit("Kernel is empty")

    print(
        f"OK: mbr=512B, stage2={len(stage2)}B (<= {args.stage2_sectors*512}B), kernel={len(kernel)}B"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

