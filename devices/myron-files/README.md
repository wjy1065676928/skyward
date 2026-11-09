# What the myron's secure element chain needs, and where it comes from

[English](README.md) | [简体中文](README.zh-CN.md)

Everything below is the phone maker's or Qualcomm's, so none of it is in this
tree. Copy it from a phone you own into a folder, pass that folder to
`skyward-pack recovery --extra`, and it lands in the ramdisk at the paths
shown.

**Where they come from: almost all of them are out of a TWRP build for this
phone, not the maker's own recovery.** The maker's stock recovery is a
stripped one — 766 files, no TEE programs at all, because MIUI's
firmware-update path does not need them. A TWRP build for the same hardware
is a full running recovery and carries the vendor partition's own TEE stack,
which is where these were taken from.

Two of the files here are ours (the two scripts). The rest are byte for byte
what a TWRP build for this phone carries, and those in turn are the phone
maker's and Qualcomm's, collected into a device tree by someone else:

| what | where |
|---|---|
| the build recipe that produced the recovery these were taken out of | [wjy1065676928/myron-twrp-builder](https://github.com/wjy1065676928/myron-twrp-builder) — a build flow, no blobs of its own |
| the device tree it builds, which holds the TEE stack, the weaver and the libraries as `prebuilt/` | [MissMyTime/twrp_device_sm8850](https://github.com/MissMyTime/twrp_device_sm8850), Apache-2.0 |

That device tree is where nearly every file below actually lives, at
`device/xiaomi/myron/prebuilt/{system,vendor,odm}/`. **Go there first** — it
is a public tree with the files in place, rather than something to be dug out
of a binary. If you would rather have them from the phone itself, they are
the same files on its `vendor` and `odm` partitions.

## Programs

| into the ramdisk as | from | source |
|---|---|---|
| `system/tee/qseecomd` | `vendor/bin/qseecomd` | device tree |
| `system/tee/hlosminkdaemon` | `vendor/bin/hlosminkdaemon` | device tree |
| `system/tee/weaver-service` | `odm/bin/hw/android.hardware.weaver-service.nxp-qti` | device tree |

The maker's `weaver-service` on the odm partition is 85,992 B and aborts
after `weaver-transport-impl::87 Init Entry`; the one in its recovery
ramdisk is 69,600 B and works. Same `ese_weaver.so`, different program —
take the recovery's.

## Libraries

The recovery's linker searches `/system/lib64` only, so anything the vendor
partition's programs link against has to be there. These are the ones the
chain needs and the stock ramdisk does not carry.

| into the ramdisk as | from | source |
|---|---|---|
| `system/lib64/android.se.omapi-V1-ndk.so` | `system/lib64/android.se.omapi-V1-ndk.so` | device tree |
| `system/lib64/android.hardware.secure_element-V1-ndk.so` | `vendor/lib64/…` | device tree |
| `system/lib64/libvndksupport.so` | `system/lib64/libvndksupport.so` | device tree |
| `system/lib64/libdl_android.so` | `system/lib64/libdl_android.so` | device tree |
| `system/lib64/libdmabufheap.so` | `vendor/lib64/libdmabufheap.so` | device tree |
| `system/lib64/libssd.so` | `vendor/lib64/libssd.so` | device tree |

`libssd.so` is the one to look out for: `qseecomd` opens it by name at run
time rather than linking it, so `readelf -d` never shows it and it only
appears as

```
E ListenerMngr: Init dlopen(libssd.so, RTLD_NOW) is failed.... dlopen failed: library "libssd.so" not found
E QSEECOMD: ERROR: Failed to start listener services.
```

with `qseecomd` exiting 255 every second.

### The TEE stack, under `system/tee`

These are on the vendor partition of a running phone; the recovery's own
copy works equally well. They go in one folder together with the three
programs above so that the services' `libraries` line finds them without
touching the default namespace.

`libGPMTEEC_vendor.so`, `libGPTEE_vendor.so`, `libGPQeSE.so`,
`libQSEEComAPI.so`, `libEseUtils.so`, `libdmabufheap.so`,
`libminkdescriptor.so`, `libminksocket_vendor.so`, `libqcbor.so`,
`libqmi_cci.so`, `libqmi_common_so.so`, `libqmi_csi.so`, `libqrtr.so`,
`libesesbprovision.so`, `libssd.so`,
`vendor.xiaomi.hardware.aidl.mtdservice-V1-ndk.so`

## The two scripts

`make_dma_heap.sh` and `wait_omapi.sh` sit in this folder and are ours, not
the phone's and not the device tree's — they are the two files here that
were written for this, and they carry this repository's licence like the
rest of it. Copy them into the extra folder beside the libraries:

```sh
cp make_dma_heap.sh wait_omapi.sh extra/system/tee/
```

The first is what a recovery needs and Android's own init normally does: the
DMA-BUF heaps the element shares memory through are made by init as the
kernel announces them, and with no init nothing makes them. Without them
every applet load answers 23, "not authorized", which is what a buffer that
was never made looks like from the other side. The second holds the weaver's
start until OMAPI answers — it registers the moment its program runs but can
only name the element after connecting to it.

`vendor/etc/ueventd.rc` is out of TWRP's ramdisk, not the maker's recovery —
the maker's has no `vendor/etc/ueventd.rc` at all. It is needed for its
`/dev/dma_heap/qcom,*` line, which is what gives the element's service the
shared memory it sends applet images through.

## Where the stock recovery comes from

This is a different thing from the files above. The files above come from
the device tree; this is the *maker's* recovery partition, the one the image
is built on top of before anything else is added to it.

`[stock]` in `devices/myron.toml` names OS4.0.6.0, and `recovery` is that
build's recovery partition's SHA-256. **The `package` link there does not
work** — the maker's download server only hands the package out with a
signed query on the link, and that signature is bound to a moment, so a link
written into the configuration dies.

Take the stock recovery from somewhere else:

- the maker's download page, this build's full firmware package
- a mirror of it
- or read it straight off the phone's own recovery partition

Either way, check it against the `recovery` sum, which does not change.

## Pulling it together

```sh
mkdir -p extra/system/tee extra/system/lib64 extra/vendor/etc

# from TWRP's ramdisk for this phone
#   (mount or extract it; the paths are the ones inside the ramdisk)
...
# from the running phone
adb pull /vendor/lib64/libdmabufheap.so   extra/system/lib64/
adb pull /vendor/lib64/libssd.so          extra/system/lib64/
# ...and the TEE stack into extra/system/tee/

skyward-pack recovery ... --extra extra --out recovery.img
```

`--extra` needs the change in pull request #29. Without the weaver's
description fix (#27) the weaver still will not register; `myron.toml`
names the file outright as a stopgap.
