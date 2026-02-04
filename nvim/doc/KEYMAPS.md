# Neovim Keymaps Reference

## General

| Key | Mode | Action |
|-----|------|--------|
| `<Esc>` | n | Clear search highlights |
| `<Esc>` | i/v | Exit + auto-format buffer |
| `<Esc><Esc>` | n | Force format buffer |
| `<Esc><Esc>` | t | Exit terminal mode |
| `<leader>q` | n | Open diagnostic quickfix list |
| `ZA` | n | Save all and quit |
| `<leader>x` | n | Close current window |
| `<leader>[` | n | Jump back (jumplist) |
| `<leader>]` | n | Jump forward (jumplist) |

## Splits (`<leader>s` group)

| Key | Action |
|-----|--------|
| `<leader>ss` | Sync header/source split (C++) |
| `<leader>s\` | Split vertical |
| `<leader>s-` | Split horizontal |
| `<leader>s=` | Equal split sizes |
| `<leader><Tab>` | Close other splits (keep current) |

## Window Navigation

| Key | Action |
|-----|--------|
| `<C-h>` | Focus left window |
| `<C-l>` | Focus right window |
| `<C-j>` | Focus lower window |
| `<C-k>` | Focus upper window |

## Finder (`<leader>f` group)

| Key | Action |
|-----|--------|
| `<leader>ff` | Find files (cmake-aware) |
| `<leader>fx` | Project explorer (cmake modules) |
| `<leader>fg` | Find by grep |
| `<leader>fb` | Find buffers |
| `<leader>fh` | Find help |
| `<leader>fk` | Find keymaps |
| `<leader>fw` | Find current word |
| `<leader>fd` | Find diagnostics |
| `<leader>fr` | Resume last find |
| `<leader>f.` | Find recent files |
| `<leader>f/` | Find in open files |
| `<leader>fn` | Find neovim config files |
| `<leader>/` | Search in current buffer |
| `<leader>\` | File explorer |

## LSP

| Key | Action |
|-----|--------|
| `gd` | Go to definition (split-aware) |
| `gr` | Go to references |
| `gI` | Go to implementation |
| `gD` | Go to declaration |
| `gh` | Switch header/source in-place (C++) |
| `K` | Hover documentation |
| `<leader>ds` | Document symbols |
| `<leader>ws` | Workspace symbols |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action |
| `<leader>th` | Toggle inlay hints |

## C++ Specific (`<leader>c` group)

| Key | Action |
|-----|--------|
| `gh` | Switch header ↔ source (in-place) |
| `<leader>cc` | Generate C++ definition stub |
| `<leader>cv` | Generate all missing C++ stubs |
| `<leader>c/` | Toggle comment in header + cpp |

## Build (`<leader>b` group)

| Key | Action |
|-----|--------|
| `<leader>br` | Build + Launch + Attach |
| `<leader>bb` | Build only (+ LSP restart) |
| `<leader>bc` | Clean build (clean + build) |
| `<leader>bk` | Clean + Reconfigure build |

## Debug (`<leader>d` group)

| Key | Action |
|-----|--------|
| `<F5>` | Configure project (show dialog) |
| `<F10>` | Step over |
| `<F11>` | Step into |
| `<F12>` | Step out |
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Conditional breakpoint |
| `<leader>dl` | Log point |
| `<leader>dc` | Continue |
| `<leader>di` | Step into |
| `<leader>do` | Step over |
| `<leader>dO` | Step out |
| `<leader>dt` | Terminate + close DAW/App |
| `<leader>dr` | Open REPL |
| `<leader>dL` | Run last |
| `<leader>du` | Toggle DAP UI |
| `<leader>de` | Evaluate expression (n/v) |

## Surround (mini.surround)

Uses default mini.surround keys. **NOT** `<leader>s`.

### Add Surround

| Key | Action |
|-----|--------|
| `sa{motion}{char}` | Surround motion with char |
| `saiw"` | Surround word with `"` |
| `saiw)` | Surround word with `()` |
| `sa$}` | Surround to EOL with `{}` |
| `sat<div>` | Surround to EOL with `<div></div>` |

**In visual mode:** select text, then `sa{char}`

### Delete Surround

| Key | Action |
|-----|--------|
| `sd{char}` | Delete surrounding char |
| `sd"` | Delete surrounding `"` |
| `sd)` | Delete surrounding `()` |

### Replace Surround

| Key | Action |
|-----|--------|
| `sr{old}{new}` | Replace old surround with new |
| `sr"'` | Replace `"` with `'` |
| `sr)]` | Replace `()` with `[]` |

## Insert Mode Helpers

| Key | Action |
|-----|--------|
| `<Tab>` | Jump out of bracket/quote (or normal tab) |
| `;` | Jump out of `)` or `}` and add `;` |

**Example:** Type `func(arg` then `;` → `func(arg);`

## Flash (Motion)

| Key | Mode | Action |
|-----|------|--------|
| `s` | n/x/o | Flash jump |
| `S` | n/x/o | Flash treesitter |
| `r` | o | Remote flash |
| `R` | o/x | Treesitter search |
| `<C-s>` | c | Toggle flash in search |

## Snippets

| Key | Mode | Action |
|-----|------|--------|
| `<leader>fs` | n | Find/insert snippets |
| `<C-s>` | i | Find/insert snippets |
