# flakepi

```
nix build .#images.sempfberry
zstdcat result/sd-image/nixos-sd-image-*.img.zst | sudo dd of=/dev/mmcblk0 status=progress bs=4096 conv=fsync
```
