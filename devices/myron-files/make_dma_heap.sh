#!/system/bin/sh
# Give the secure element's service the DMA-BUF heaps it shares memory with
# the secure world through. Android's own init makes these as the kernel's
# dma_heap driver announces them; a recovery runs no init, and the nodes the
# kernel announces are not in the ramdisk, so they are made here, with the
# numbers the driver gives them, and owned as the phone's own init owns them.
set -e
DIR=/dev/dma_heap
mkdir -p "$DIR"
# The driver's minor numbers on this phone, as its own recovery has them.
mknod -m 0444 "$DIR/qcom,qseecom"     c 248 5 2>/dev/null || true
mknod -m 0444 "$DIR/qcom,qseecom-ta"  c 248 6 2>/dev/null || true
mknod -m 0444 "$DIR/qcom,system"      c 248 0 2>/dev/null || true
mknod -m 0444 "$DIR/system"           c 248 1 2>/dev/null || true
mknod -m 0444 "$DIR/qcom,secure-pixel"     c 248 2 2>/dev/null || true
mknod -m 0444 "$DIR/qcom,secure-non-pixel" c 248 3 2>/dev/null || true
mknod -m 0444 "$DIR/qcom,display"     c 248 4 2>/dev/null || true
mknod -m 0444 "$DIR/qcom,sp-hlos"     c 248 7 2>/dev/null || true
chown system:system "$DIR"/qcom,* "$DIR"/system "$DIR"/system-* 2>/dev/null || true
chmod 0444 "$DIR"/* 2>/dev/null || true
# The node the secure world is reached through, which vendor's own ueventd
# rules give to system and drmrpc.
[ -e /dev/smcinvoke ] || mknod -m 0660 /dev/smcinvoke c 494 0 2>/dev/null || true
chown system:drmrpc /dev/smcinvoke 2>/dev/null || true
chmod 0660 /dev/smcinvoke 2>/dev/null || true
ls -l "$DIR" >/dev/null 2>&1 || true
