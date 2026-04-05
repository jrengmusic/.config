# .config

One config repo. 3 machines. 4 OS. Identical DX everywhere.

Change on any machine, push, pull everywhere. No daemon, no subscription, no black box — git is the sync layer and shell scripts are the installer. Own the whole stack.

| Machine | OS | Terminal | Shell |
|---|---|---|---|
| iMac 5K 2015 | macOS Monterey | END | zsh |
| iMac 5K 2015 | Windows 10 | END | zsh |
| MBP M4 | macOS | END | zsh |
| MBP M4 | Windows 11 UTM | END | zsh |

## Windows Setup

```sh
curl -fsSL https://raw.githubusercontent.com/jrengmusic/.config/main/install.sh | bash
```

Run from **MSYS2 CLANGARM64** (ARM64) or **MSYS2 MINGW64** (x64). No Administrator needed — the script auto-elevates for the parts that require it.

See [WINDOWS-SETUP.md](WINDOWS-SETUP.md) for full details.
