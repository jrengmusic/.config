# .config

Personal dev environment. One config repo for all machines.

| Machine | OS | Terminal | Shell |
|---|---|---|---|
| iMac 5K 2015 | macOS Monterey | kitty | zsh |
| iMac 5K 2015 | Windows 10 | END | zsh |
| MBP M4 | macOS | kitty | zsh |
| MBP M4 | Windows 11 UTM | END | zsh |

## Windows Setup

```sh
curl -fsSL https://raw.githubusercontent.com/jrengmusic/.config/main/install.sh | bash
```

Run from **MSYS2 CLANGARM64** (ARM64) or **MSYS2 MINGW64** (x64). No Administrator needed — the script auto-elevates for the parts that require it.

See [WINDOWS-SETUP.md](WINDOWS-SETUP.md) for full details.
