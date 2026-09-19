#!/bin/sh
# Build a complete 8 MiB SF19A28/AC28S SPI-NOR image.
# Layout verified from the original Tenda AC8 v5 boot log:
#   0x000000-0x008000  SPL
#   0x008000-0x06f000  U-Boot
#   0x06f000-0x070000  U-Boot environment
#   0x070000-0x080000  factory
#   0x080000-0x7c0000  firmware
#   0x7c0000-0x7d0000  CFM
#   0x7d0000-0x7e0000  CFM_BACKUP
#   0x7e0000-0x7f0000  CFG
#   0x7f0000-0x800000  reserved
#
# Usage: ./sf-makeimage.sh <project> 8 [factory.bin]
# The optional third argument replaces the factory partition.  No PCBA image
# is written: the target's last 256 KiB are CFM/CFG, not a PCBA partition.

set -eu

usage() {
    echo "Usage: $0 <project> 8 [factory.bin]" >&2
    exit 2
}

[ "$#" -ge 2 ] || usage
PROJECT=$1
FLASH_MB=$2
FACTORY_IMAGE=${3:-factory_default.bin}
[ "$FLASH_MB" = 8 ] || { echo "Only the Tenda AC8 v5 8 MiB layout is supported" >&2; exit 2; }

SPL_UBOOT_END=$((0x6f000))
FACTORY_OFFSET=$((0x70000))
FACTORY_END=$((0x80000))
FIRMWARE_OFFSET=$((0x80000))
FIRMWARE_END=$((0x7c0000))
FLASH_SIZE=$((0x800000))

find_one() {
    pattern=$1
    set -- ./*
    found=
    for file do
        [ -f "$file" ] || continue
        case "$(basename "$file")" in
            *"$pattern"*"$PROJECT"*)
                [ -z "$found" ] || { echo "More than one $pattern image found" >&2; exit 1; }
                found=$file ;;
        esac
    done
    [ -n "$found" ] || { echo "$pattern image for $PROJECT not found" >&2; exit 1; }
    printf '%s\n' "$found"
}

UBOOT_IMAGE=$(find_one uboot)
FIRMWARE_IMAGE=$(find_one openwrt)
[ -f "$FACTORY_IMAGE" ] || { echo "Factory image not found: $FACTORY_IMAGE" >&2; exit 1; }

size() { wc -c < "$1" | tr -d ' '; }
UBOOT_SIZE=$(size "$UBOOT_IMAGE")
FIRMWARE_SIZE=$(size "$FIRMWARE_IMAGE")
FACTORY_SIZE=$(size "$FACTORY_IMAGE")

[ "$UBOOT_SIZE" -le "$SPL_UBOOT_END" ] || { echo "U-Boot exceeds 0x6f000" >&2; exit 1; }
[ "$FACTORY_SIZE" -le $((FACTORY_END - FACTORY_OFFSET)) ] || { echo "Factory image exceeds 64 KiB" >&2; exit 1; }
[ "$FIRMWARE_SIZE" -le $((FIRMWARE_END - FIRMWARE_OFFSET)) ] || { echo "Firmware exceeds 0x740000 bytes" >&2; exit 1; }

OUTPUT=${PROJECT}_ac8v5_8m_$(date +%Y%m%d).bin
rm -f "$OUTPUT"
# Use 0xff, matching erased NOR flash and the original factory defaults.
dd if=/dev/zero bs=1 count="$FLASH_SIZE" 2>/dev/null | tr '\000' '\377' > "$OUTPUT"
dd if="$UBOOT_IMAGE" of="$OUTPUT" bs=1 seek=0 conv=notrunc status=none
dd if="$FACTORY_IMAGE" of="$OUTPUT" bs=1 seek="$FACTORY_OFFSET" conv=notrunc status=none
dd if="$FIRMWARE_IMAGE" of="$OUTPUT" bs=1 seek="$FIRMWARE_OFFSET" conv=notrunc status=none

[ "$(size "$OUTPUT")" -eq "$FLASH_SIZE" ] || { echo "Output size is not 8 MiB" >&2; exit 1; }
printf 'Created %s\n' "$OUTPUT"
printf '  uboot:   offset 0x000000, size %s\n' "$UBOOT_SIZE"
printf '  factory: offset 0x070000, size %s\n' "$FACTORY_SIZE"
printf '  firmware: offset 0x080000, size %s\n' "$FIRMWARE_SIZE"
printf '  CFM/CFG: left erased at 0x7c0000-0x800000\n'
sha256sum "$OUTPUT"
