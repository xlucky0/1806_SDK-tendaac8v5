#!/bin/sh
# Validate a complete AC8 v5 8 MiB image.
# This checks the exact flash layout described by the original Tenda boot log.

set -eu

IMAGE=${1:-}
[ -n "$IMAGE" ] || {
    echo "Usage: $0 <image.bin>" >&2
    exit 2
}

[ -f "$IMAGE" ] || {
    echo "Image not found: $IMAGE" >&2
    exit 1
}

SIZE=$(wc -c < "$IMAGE" | tr -d ' ')
EXPECTED=$((0x800000))
[ "$SIZE" -eq "$EXPECTED" ] || {
    echo "Expected exactly $EXPECTED bytes (8 MiB), got $SIZE" >&2
    exit 1
}

# Check that reserved region remains intact.
RESERVED_OFFSET=$((0x7c0000))
RESERVED_SIZE=$((0x40000))
if dd if="$IMAGE" bs=1 skip="$RESERVED_OFFSET" count="$RESERVED_SIZE" status=none | LC_ALL=C tr -d '\377' | grep -q .; then
    echo "Reserved region 0x7c0000..0x800000 is not erased (contains non-0xff bytes)." >&2
    exit 1
fi

# Show a compact sanity check for U-Boot magic.
MAGIC=$(dd if="$IMAGE" bs=1 count=4 status=none | od -An -tx1 | tr -d ' \n')
printf 'U-Boot header magic (big-endian): %s\n' "$MAGIC"
printf 'Validated AC8 v5 image: %s\n' "$IMAGE"
sha256sum "$IMAGE"
