# 🚀📱

It all begins here: https://www.fastboop.win/?channel=https://cdn.rokkitpokkit.samcday.com/channels/rawhide

rokkitpokkit is an opinionated set of patches on top of vanilla Fedora, to make it usable (and maybe even *useful* someday 😅) on pocket computers. The primary focus, at present, is SDM670 + SDM845 (but patches for any other platform are more than welcome!)

## Goals

### Fedora mainline kernel

Fedora has a strict one-kernel policy. rokkitpokkit uses the official Fedora kernel.

Where feasible, additional hardware enablement is shipped via akmods.

### Try-before-you-buy installation

rokkitpokkit is intended to be tested on the device with a live-boot (via fastboop).

Once satisfied, you may install it using the on-device Anaconda installer, *from a web UI on your host device*.

The OS that is installed is precisely the same one (the same `ostree` commit) as the live-booted copy.
