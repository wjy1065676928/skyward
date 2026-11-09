# myron 的安全元件链路需要什么，从哪来

[English](README.md) | [简体中文](README.zh-CN.md)

下面全是手机厂商或高通的程序，所以都不在这个仓库里。从你自己的手机上把它们
取出来放进一个文件夹，传给 `skyward-pack recovery --extra`，它们就会按表中
的路径进到 ramdisk 里。

**这些东西几乎全部来自为这部手机编的 TWRP，不是厂商官方 recovery。** 官方 rec
是精简过的 —— 766 个文件，一个 TEE 程序都没有，因为 MIUI 的固件更新流程用不到
它们。同一套硬件的 TWRP 才是能跑起来的完整 recovery，里面带着 vendor 分区自己
的那套 TEE 程序，这些就是从那里面取的。

这里只有两个文件是我们自己写的（两个脚本）。其余逐字节就是为这部手机编的
TWRP 里带的那些，而那些又是厂商和高通的，由别人收进了一个设备树：

| 是什么 | 在哪 |
|---|---|
| 编出这份 recovery 的构建流程，我们从它产出的镜像里取的 | [wjy1065676928/myron-twrp-builder](https://github.com/wjy1065676928/myron-twrp-builder)，只是构建流程，自己不带二进制 |
| 它构建的设备树，TEE 那一套、weaver 和各库就以 `prebuilt/` 的形式在里面 | [MissMyTime/twrp_device_sm8850](https://github.com/MissMyTime/twrp_device_sm8850)，Apache-2.0 |

下面几乎每个文件实际都在那个设备树的
`device/xiaomi/myron/prebuilt/{system,vendor,odm}/` 下。**先去那里拿** —— 那是
个公开的树，文件就摆在那里，不用从二进制镜像里翻。想从手机本身取也行，它们和
手机 `vendor` 与 `odm` 分区上是同一批文件。

## 程序

| 进 ramdisk 后叫 | 来自 | 出处 |
|---|---|---|
| `system/tee/qseecomd` | `vendor/bin/qseecomd` | device tree |
| `system/tee/hlosminkdaemon` | `vendor/bin/hlosminkdaemon` | device tree |
| `system/tee/weaver-service` | `odm/bin/hw/android.hardware.weaver-service.nxp-qti` | device tree |

这里要特别注意 `weaver-service`。手机 odm 分区上厂商自己那个是 85,992 字节，
会在 `weaver-transport-impl::87 Init Entry` 之后 abort；设备树 `prebuilt/` 里
那个是 69,600 字节，能正常跑。`ese_weaver.so` 是同一个，程序不同 —— 要取
设备树里的那个。

## 库

recovery 的链接器只搜 `/system/lib64` 一个目录，所以 vendor 分区上那些程序
链接的库都得放在这里。下面这些是这条链路需要、而原厂 ramdisk 没有带的。

| 进 ramdisk 后叫 | 来自 | 出处 |
|---|---|---|
| `system/lib64/android.se.omapi-V1-ndk.so` | `system/lib64/android.se.omapi-V1-ndk.so` | device tree |
| `system/lib64/android.hardware.secure_element-V1-ndk.so` | `vendor/lib64/…` | device tree |
| `system/lib64/libvndksupport.so` | `system/lib64/libvndksupport.so` | device tree |
| `system/lib64/libdl_android.so` | `system/lib64/libdl_android.so` | device tree |
| `system/lib64/libdmabufheap.so` | `vendor/lib64/libdmabufheap.so` | device tree |
| `system/lib64/libssd.so` | `vendor/lib64/libssd.so` | device tree |

`libssd.so` 是最容易漏掉的一个：`qseecomd` 是运行时按名字打开它，不是链接
依赖，所以 `readelf -d` 永远看不到它，它只会以这样的形式出现

```
E ListenerMngr: Init dlopen(libssd.so, RTLD_NOW) is failed.... dlopen failed: library "libssd.so" not found
E QSEECOMD: ERROR: Failed to start listener services.
```

然后 `qseecomd` 每秒退出一次，返回 255。

### TEE 那一套，放在 `system/tee`

这些设备树 `prebuilt/{system,vendor,odm}/lib64` 下都有，手机上 vendor 分区
也是同一批。它们和上面三个程序一起放进同一个文件夹，这样服务的 `libraries`
一行就能找到它们，不用去动默认 namespace。

`libGPMTEEC_vendor.so`、`libGPTEE_vendor.so`、`libGPQeSE.so`、
`libQSEEComAPI.so`、`libEseUtils.so`、`libdmabufheap.so`、
`libminkdescriptor.so`、`libminksocket_vendor.so`、`libqcbor.so`、
`libqmi_cci.so`、`libqmi_common_so.so`、`libqmi_csi.so`、`libqrtr.so`、
`libesesbprovision.so`、`libssd.so`、
`vendor.xiaomi.hardware.aidl.mtdservice-V1-ndk.so`

## 两个脚本

`make_dma_heap.sh` 和 `wait_omapi.sh` 在这个文件夹里，是我们写的 —— 不是手机
上的，也不是那个设备树的。这是这里仅有的两个为此新写的文件，许可跟随本仓库。
把它们一起拷进 extra 文件夹：

```sh
cp make_dma_heap.sh wait_omapi.sh extra/system/tee/
```

第一个做的是 Android 自己的 init 平时做的事：安全元件和安全世界之间共享内存
用的那些 DMA-BUF heap，是 init 在内核通告它们时创建的，recovery 不跑 init，
就没人创建。缺了它们，每次加载 applet 都返回 23，"not authorized" —— 那就是
一个从没被创建过的缓冲区，从对面看起来的样子。

第二个拖住 weaver 的启动，等 OMAPI 真的能应答。OMAPI 的程序一跑起来就注册
了，但要连上安全元件之后才能报出它的名字，在那个空档里来问的 weaver 会被
拒绝然后退出。没有它，大约五次启动只有一次能成。

`vendor/etc/ueventd.rc` 来自 TWRP 的 ramdisk，不是官方 recovery 的 —— 官方
那个里根本没有 `vendor/etc/ueventd.rc`。需要它是因为 TWRP 那份里有
`/dev/dma_heap/qcom,*` 这一行，正是它让安全元件服务拿到发送 applet 镜像用的
那块共享内存。

## 官方 recovery 从哪来

这和上面那些文件不是一回事。上面那些来自设备树；这里说的是
**厂商的** recovery 分区，也就是镜像的底座 —— 在往里加任何 TWRP 的东西之前，
先得有它。

`devices/myron.toml` 里 `[stock]` 那段填的是 OS4.0.6.0，`recovery` 是这一版
recovery 分区的 SHA-256。**但 `package` 那个下载链接用不了** —— 厂商的下载
服务器要求链接上带签名参数，而签名绑定在某个时刻，写死在配置里迟早会失效。

所以官方 recovery 请从别处取：

- 厂商的下载页面上这一版的完整固件包
- 别的镜像站
- 或者直接从手机自己的 recovery 分区读出来

拿到之后核对一下 `recovery` 字段里的 SHA-256，这个值不会变。

## 拼起来

```sh
mkdir -p extra/system/tee extra/system/lib64 extra/vendor/etc

# 从 TWRP 的 ramdisk 里取（解开后按上面的路径找）
...
# 从运行中的手机取
adb pull /vendor/lib64/libdmabufheap.so   extra/system/lib64/
adb pull /vendor/lib64/libssd.so          extra/system/lib64/
# ……TEE 那一套放进 extra/system/tee/

skyward-pack recovery ... --extra extra --out recovery.img
```

`--extra` 依赖 PR #29。如果 weaver 的 description 修复（PR #27）还没合入，
weaver 仍然注册不上；`myron.toml` 里暂时直接写明了那个文件的名字。
