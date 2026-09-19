# AC8 v5 8 MiB flash layout

The original Tenda AC8 v5 boot log confirms the flash layout is:

| Offset | End | Partition |
|---:|---:|---|
| `0x000000` | `0x008000` | `spl-loader` |
| `0x008000` | `0x06f000` | `u-boot` |
| `0x06f000` | `0x070000` | `u-boot-env` |
| `0x070000` | `0x080000` | `factory` |
| `0x080000` | `0x7c0000` | `firmware` |
| `0x7c0000` | `0x7d0000` | `CFM` |
| `0x7d0000` | `0x7e0000` | `CFM_BACKUP` |
| `0x7e0000` | `0x7f0000` | `CFG` |
| `0x7f0000` | `0x800000` | reserved |

Important notes:
- This target is 8 MiB SPI-NOR and not a 4 MiB or 16 MiB layout.
- There is no valid PCBA partition in the user-visible flash map.
- The firmware must start at 0x80000.
- Do not overwrite CFM/CFG or the last 256 KiB region.

Build and validate:
```sh
cd image_maker_8M
chmod +x sf-makeimage.sh validate-ac8v5-image.sh
./sf-makeimage.sh tenda_ac8-v5 8 factory_default.bin
./validate-ac8v5-image.sh tenda_ac8-v5_ac8v5_8m_*.bin
```
