# flakepi

## Flash SD

```
nix build .#images.sempfberry
zstdcat result/sd-image/nixos-sd-image-*.img.zst | sudo dd of=/dev/mmcblk0 status=progress bs=4096 conv=fsync
```


## Online update

```
nixos-rebuild --target-host root@sempfberry --flake ./. switch
```
