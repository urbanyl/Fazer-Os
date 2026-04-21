SHELL := /bin/sh

NASM ?= nasm
PY ?= python
QEMU ?= qemu-system-x86_64

BUILD_DIR := build
SRC_DIR := src

STAGE2_SECTORS ?= 32
IMG_SIZE_MIB ?= 16

.PHONY: all clean image run

all: image

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/mbr.bin: $(SRC_DIR)/boot/mbr.asm | $(BUILD_DIR)
	$(NASM) -f bin -DSTAGE2_SECTORS=$(STAGE2_SECTORS) $< -o $@

$(BUILD_DIR)/stage2.bin: $(SRC_DIR)/boot/stage2.asm | $(BUILD_DIR)
	$(NASM) -f bin -DSTAGE2_SECTORS=$(STAGE2_SECTORS) $< -o $@

$(BUILD_DIR)/kernel.bin: $(SRC_DIR)/kernel/kernel.asm | $(BUILD_DIR)
	$(NASM) -f bin $< -o $@

image: $(BUILD_DIR)/mbr.bin $(BUILD_DIR)/stage2.bin $(BUILD_DIR)/kernel.bin
	$(PY) tools/mkimage.py \
		--mbr $(BUILD_DIR)/mbr.bin \
		--stage2 $(BUILD_DIR)/stage2.bin \
		--kernel $(BUILD_DIR)/kernel.bin \
		--out $(BUILD_DIR)/fazer.img \
		--stage2-sectors $(STAGE2_SECTORS) \
		--size-mib $(IMG_SIZE_MIB)

run: image
	$(QEMU) -m 256M -drive format=raw,file=$(BUILD_DIR)/fazer.img,if=ide,index=0,media=disk -serial stdio

clean:
	@rm -rf $(BUILD_DIR)

