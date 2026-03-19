# Neovim Keymaps Reference

## General

| Key | Mode | Action |
|-----|------|--------|
| `<Esc>` | n | Clear search highlights |
| `<Esc>` | i/v | Exit + auto-format buffer |
| `<Esc><Esc>` | n | Force format buffer |
| `<Esc><Esc>` | t | Exit terminal mode |
| `<leader>q` | n | Toggle diagnostic list (top split) |
| `<C-s>` | n | Save all and quit |
| `<C-c>` | n | Quit with save/discard prompt |
| `<leader>x` | n | Close current window |
| `<leader>[` | n | Jump back (jumplist) |
| `<leader>]` | n | Jump forward (jumplist) |

## Diagnostics

### Inline Diagnostics (Always Active)
- **Virtual text** - Error messages at end of lines (`● error message`)
- **Signs** - Gutter icons: `✘` (error), `▲` (warning), `⚑` (hint), `»` (info)
- **Underlines** - Wavy lines under problematic code
- **Floating window** - Hover on error (cursor hold) shows full diagnostic

### Diagnostic List (`<leader>q`)
Opens at top (horizontal split, 15 lines):

| Key | Action |
|-----|--------|
| `<leader>q` | Toggle diagnostic list |
| `<Enter>` | Jump to diagnostic |
| `q` | Close diagnostic list |
| `p` | Preview diagnostic |
| `j`/`k` | Navigate diagnostics |

**Auto-close:** List closes automatically when all errors are fixed.

## Replace (`<leader>r` group)

| Key | Mode | Action |
|-----|------|--------|
| `<leader>rw` | n/v | Replace word/selection (exact match) |
| `<leader>rc` | n/v | Replace word/selection (contains) |
| `<leader>rn` | n | Rename symbol (LSP) |

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
| `<leader>ca` | Code action |
| `<leader>th` | Toggle inlay hints |

## C++ Specific (`<leader>c` group)

| Key | Action |
|-----|--------|
| `gh` | Switch header ↔ source (in-place) |
| `<leader>ss` | Sync header/source split (toggle) |
| `<leader>cc` | Generate C++ definition stub |
| `<leader>cv` | Generate all missing C++ stubs |
| `<leader>c/` | Toggle comment in header + cpp |

**Stub Notes:**
- Strips linkage keywords (`static`, `extern`, `inline`, `virtual`, etc.)
- Skips `inline` functions (should be defined in header)
- Auto-places stubs after last class method

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

### Custom Surroundings

| Char | Surrounds With |
|------|----------------|
| `m` | `std::move (...)` |
| `(` | `(...)` (no spaces) |
| `)` | `(...)` (no spaces) |

### Text Object Motions

| Motion | Captures |
|--------|----------|
| `iw` | word (`layout`) |
| `iW` | WORD including dots (`layout.panel`) |
| `_` | entire line (trimmed) |
| `$` | to end of line |
| `i}` | inside `{}` block |
| `a}` | around `{}` block (includes braces) |
| `iF` | inside function definition (treesitter) |
| `aF` | around function definition (treesitter) |
| `iC` | inside class definition (treesitter) |
| `aC` | around class definition (treesitter) |
| `iL` | inside loop (treesitter) |
| `aL` | around loop (treesitter) |
| `iI` | inside if/conditional (treesitter) |
| `aI` | around if/conditional (treesitter) |
| `if` | inside function call `()` |
| `af` | around function call `()` |

### Select Scope/Function Examples

```
vi}     →  select inside {} braces
va}     →  select {} including braces
viF     →  select function body (treesitter)
vaF     →  select entire function (treesitter)
viC     →  select class body
vaC     →  select entire class
viL     →  select loop body
vaL     →  select entire loop
viI     →  select if/conditional body
vaI     →  select entire if/conditional
vaFsam  →  select function, wrap with std::move
```

### Add Surround

| Key | Action |
|-----|--------|
| `sa{motion}{char}` | Surround motion with char |
| `saiw"` | Surround word with `"` |
| `saW(` | Surround WORD with `()` → `(layout.panel)` |
| `saWm` | Surround WORD with std::move → `std::move (layout.panel)` |
| `sa_m` | Surround line with std::move |
| `sa$}` | Surround to EOL with `{}` |

**In visual mode:** select text, then `sa{char}`
- `viWsam` → select WORD, wrap with `std::move (...)`
- `Vsam` → select line, wrap with `std::move (...)`

### Examples

```
variable        + saiwm  →  std::move (variable)
layout.panel    + saWm   →  std::move (layout.panel)
whole line here + sa_m   →  std::move (whole line here)
someValue       + saW(   →  (someValue)
```

### Delete Surround

| Key | Action |
|-----|--------|
| `sd{char}` | Delete surrounding char |
| `sd"` | Delete surrounding `"` |
| `sd)` | Delete surrounding `()` |
| `sdm` | Delete surrounding `std::move (...)` |

### Replace Surround

| Key | Action |
|-----|--------|
| `sr{old}{new}` | Replace old surround with new |
| `sr"'` | Replace `"` with `'` |
| `sr)]` | Replace `()` with `[]` |
| `srm(` | Replace `std::move (x)` with `(x)` |

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

## AI Agent (99)

| Key | Mode | Action |
|-----|------|--------|
| `<leader>9f` | n | Fill function body with AI |
| `<leader>9v` | v | AI on visual selection |
| `<leader>9s` | n | Stop all AI requests |

## Snippets

### Snippet Commands

| Key | Mode | Action |
|-----|------|--------|
| `<leader>fs` | n | Find/insert snippets |
| `<C-v>` | i | Find/insert snippets |

### Available Snippets

| Trigger | Description |
|---------|-------------|
| `sep` | Separator comment `//==============` (returns to normal mode) |
| `cls` | Class with leak detector |
| `comp` | JUCE Component header declaration |
| `leak` | JUCE leak detector macro with separator |
| `juce` | Simple JUCE Component with inline implementations |
| `fn` | Function definition with noexcept |
| `loop` | Traditional for loop (int i {0}; i < N; ++i) |
| `forr` | Range-based for loop (auto& item : container) |
| `if` | If statement with braces |
| `ife` | If-else statement |
| `while` | While loop with braces |
| `switch` | Switch statement with case/default |
| `template` | Template function declaration |
| `nam` | Namespace with decorative comments |
| `sing` | Meyers Singleton complete class |
| `unp` | `std::unique_ptr<type> name` |
| `mku` | `std::make_unique<type>(args)` |
| `mks` | `std::make_shared<type>(args)` |
| `dbp` | Debug paint (magenta border) |
| `mac` | `#if JUCE_MAC ... #endif` |
| `win` | `#if JUCE_WINDOWS ... #endif` |
