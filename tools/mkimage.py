import argparse
import math
import os


def read_file(path: str) -> bytes:
    with open(path, "rb") as f:
        return f.read()


def write_file(path: str, data: bytes) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


def ceil_div(a: int, b: int) -> int:
    return (a + b - 1) // b


def main() -> int:
    ap = argparse.ArgumentParser(description="Build raw disk image for Fazer OS")
    ap.add_argument("--mbr", required=True)
    ap.add_argument("--stage2", required=True)
    ap.add_argument("--kernel", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--stage2-sectors", type=int, required=True)
    ap.add_argument("--size-mib", type=int, default=16)
    args = ap.parse_args()

    sector_size = 512
    img_size = args.size_mib * 1024 * 1024
    if img_size % sector_size != 0:
        raise SystemExit("Image size must be multiple of 512 bytes")

    mbr = read_file(args.mbr)
    stage2 = read_file(args.stage2)
    kernel = read_file(args.kernel)

    if len(mbr) != 512:
        raise SystemExit(f"MBR must be 512 bytes, got {len(mbr)}")
    if mbr[510:512] != b"\x55\xAA":
        raise SystemExit("MBR missing 0x55AA signature")

    max_stage2_bytes = args.stage2_sectors * sector_size
    if len(stage2) > max_stage2_bytes:
        raise SystemExit(
            f"Stage2 too large: {len(stage2)} bytes > {max_stage2_bytes} bytes"
        )

    kernel_sectors = ceil_div(len(kernel), sector_size)

    placeholder = (0xCAFEBABE).to_bytes(4, "little")
    repl = kernel_sectors.to_bytes(4, "little")
    idx = stage2.find(placeholder)
    if idx == -1:
        raise SystemExit("Stage2 placeholder 0xCAFEBABE not found")
    stage2 = stage2[:idx] + repl + stage2[idx + 4 :]

    total_needed = 1 + args.stage2_sectors + kernel_sectors
    if total_needed * sector_size > img_size:
        raise SystemExit("Image too small for payload")

    img = bytearray(img_size)
    img[0:512] = mbr

    stage2_off = 1 * sector_size
    img[stage2_off : stage2_off + len(stage2)] = stage2

    kernel_lba = 1 + args.stage2_sectors
    kernel_off = kernel_lba * sector_size
    img[kernel_off : kernel_off + len(kernel)] = kernel

    write_file(args.out, bytes(img))
    print(
        f"Wrote {args.out}: stage2={len(stage2)} bytes, kernel={len(kernel)} bytes ({kernel_sectors} sectors)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

