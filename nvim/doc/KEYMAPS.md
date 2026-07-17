# Neovim Keymaps Lexicon

**This file is the single source of truth for every static keybinding.**
It generates `nvim/lua/core/keymaps.lua`. Never edit the generated file —
it carries a `GENERATED CODE — READ ONLY` banner and is overwritten
wholesale on every regeneration.

## How the System Works

```
nvim/doc/KEYMAPS.md            (SSOT — you edit THIS)
        │
        │  core/keymaps-generator.lua
        │  parse → validate → emit
        ▼
nvim/lua/core/keymaps.lua      (generated, committed, read-only)
        │                       banner carries sha256 of this file
        │  called by
        ▼
init.lua / LspAttach / plugin setup tails / FileType-qf autocmd
        │  rows reference behavior in
        ▼
core/actions.lua (@actions.*)   core/build.lua (@build.*)
                 (hand-written function bodies)
```

**Division of responsibility — bindings are vocabulary, bodies are behavior:**
- A *binding* (key, mode, action reference, description, options) lives here,
  as a table row. Changing keys, remapping, re-describing = edit this file only.
- A *behavior* (a Lua function body) lives in `core/actions.lua` (editor
  actions) or `core/build.lua` (build/DAP orchestration). New behavior = write
  the function there first, then reference it here as `@actions.name` /
  `@build.name`.

### When Regeneration Happens

1. **On save of this file** — `BufWritePost` autocmd
   (`core/autocommands.lua`) runs the generator immediately and notifies.
2. **At nvim launch** — `init.lua` calls
   `require('core.keymaps-generator').verify()` before the first
   `require('core.keymaps')`. It computes `sha256` of this file and compares
   it against the `-- LEXICON: sha256:<hash>` line in the generated banner.
   Match → no-op (<1ms). Mismatch (e.g. after `git pull` from another
   machine) → regenerate.
3. **Manually** — `:lua require('core.keymaps-generator').verify()`.

### Failure Contract

Validation failure (unknown group, duplicate key+mode, bad `@ref`, invalid
token) **never destroys the generated file**: the generator emits a loud
`vim.notify` error naming the offending KEYMAPS.md line and keeps the
last-good `keymaps.lua`. Nvim always starts with working keymaps. Fix the
reported line, save, regeneration retries.

### Contract vs Prose

The generator consumes **only** two section shapes:
- `## groups` — the group registry (exactly one)
- `## keys: <group>` — binding rows for a declared group

Every other heading and paragraph in this document — including everything
below the `# Reference` divider — is human documentation, ignored by the
parser. Prose may use tables freely; only tables under contract headings are
parsed.

## Schema Reference

### `## groups` columns

| column | meaning | emitted as |
|---|---|---|
| `group` | unique id, referenced by `## keys: <group>` headers and `parent` | — |
| `function` | public function name on the module | `function M.<name>(...)` — call sites live in init.lua / plugin tails / autocmds. Empty for subgroups (they emit inside their parent). |
| `invocation` | `init` = called once from init.lua · `plugin` = called from a plugin's setup tail · `event` = takes an `event` argument; every row becomes buffer-local (`buffer = event.buf`) | `event` adds the parameter and buffer scoping |
| `prefix` | prepended (with a space) to every row's desc | `desc = 'DAP: Step over'` |
| `requires` | comma list of modules required at function top. `module as alias` renames the local (needed when the module path's last segment isn't a valid/wanted Lua name). Row action roots matching an alias resolve against that local instead of a lazy `require`. | `local dap = require('dap')` |
| `parent` | makes this a subgroup: its rows emit inside the parent's function, under `guard` | — |
| `guard` | subgroup condition. Vocabulary: `client=<name>` → `client.name == '<name>'` · `supports=inlayHint` → `client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint)` | `if client and <condition> then … end` |

### `## keys:` columns

| column | meaning |
|---|---|
| `key` | LHS, backtick-wrapped. Written as the *actual* key notation — the generator handles Lua string escaping (`` `<C-\><C-n>` `` emits `'<C-\\><C-n>'`). |
| `mode` | single mode or comma list: `n` · `n,x` · `x,o` |
| `action` | one of the four kinds below |
| `opts` | comma list of tokens: `sync` · `expr` · `silent` (empty allowed) |
| `desc` | human description; group prefix is prepended; empty allowed |

### Action Kinds — exact resolution rules

| # | you write | generator emits | rule |
|---|---|---|---|
| 1 | `` `<cmd>nohlsearch<CR>` `` | `'<cmd>nohlsearch<CR>'` | Backtick = literal RHS string, passed verbatim (escaped for Lua). |
| 2 | `dap.step_over` | `dap.step_over` | Bare dotted (no parens) = direct function reference. Root **must** be a group `requires` alias or a known global (`vim`, `Snacks`) — anything else fails validation. |
| 3a | `core.tui.tit()` | `function() require('core.tui').tit() end` | Call with non-required, non-global root: everything before the last dot is the module, lazily required inside a closure. |
| 3b | `dap.repl.open()` | `function() dap.repl.open() end` | Call with a required root: field access on the already-required local. |
| 3c | `Snacks.picker.buffers()` | `function() Snacks.picker.buffers() end` | Call with a global root: referenced directly, no require. |
| 3d | `luasnip.jump(1)` | `function() require('luasnip').jump(1) end` | Arguments pass through verbatim — any Lua expression is legal (`vim.fn.input('Condition: ')`, `{ cwd = vim.fn.stdpath('config') }`). |
| 4 | `@actions.smart_quit` | `actions.smart_quit` (+ auto `local actions = require('core.actions')`) | `@actions.*` / `@build.*` reference hand-written functions in `core/actions.lua` / `core/build.lua`. Existence is statically validated at generation — a typo fails loudly with the md line number. |

### Opts Tokens

| token | effect |
|---|---|
| `sync` | wraps the action in a closure prepended with `actions.splitSyncOnce()` — re-syncs the C++ header/source split after the jump lands |
| `expr` | `expr = true` (action must return the keys to feed, e.g. `@actions.formatOnEsc`) |
| `silent` | `silent = true` |

### Validation (generation fails loudly on any of these)

- `## keys:` header naming an undeclared group
- duplicate key+mode within one group
- `invocation`, `opts`, or `guard` token outside the fixed vocabularies
- bare-dotted action whose root is neither required nor a known global
- `@ref` naming a function that does not exist in its module
- subgroup `parent` naming an undeclared group

### Recipes

**Remap or re-describe a key** — edit its row. Save. Done.

**Add a binding to something that already exists** — one new row:
```markdown
| `<leader>xy` | n | Snacks.picker.commands() | sync | Find commands |
```

**Add a binding needing new behavior** — write the body first, then the row:
```lua
-- core/actions.lua
function M.rotateColorscheme()
  ...
end
```
```markdown
| `<leader>xz` | n | @actions.rotateColorscheme | | Rotate colorscheme |
```

**Add a whole new group** — one row in `## groups` (pick `invocation`; for
`plugin`, add the `require('core.keymaps').<function>()` call at the owning
plugin's setup tail), then its `## keys: <name>` section.

### Out of Scope (by design)

Runtime buffer-local maps spawned by behavior — the build-terminal's
abort-`<Esc>` and failure-`q` — belong to `core/build.lua`, not this lexicon.
Plugin-internal mappings configured through plugin APIs (nvim-cmp's `<Tab>`,
mini.surround's `sa`/`sd`/`sr`) live in their plugin specs and are documented
in the Reference section below.

## groups

| group | function | invocation | prefix | requires | parent | guard |
|---|---|---|---|---|---|---|
| general | setup | init | | | | |
| lsp | setupLsp | event | LSP: | | | |
| lsp-clangd | | event | LSP: | | lsp | client=clangd |
| lsp-inlay | | event | LSP: | | lsp | supports=inlayHint |
| dap | setupDap | plugin | DAP: | dap,dapui | | |
| minipairs | setupMiniPairs | plugin | | | | |
| flash | setupFlash | plugin | | | | |
| textobjects | setupTextobjects | plugin | | nvim-treesitter-textobjects.select as select | | |
| snippets | setupSnippets | plugin | | snacks | | |
| 99 | setup99 | plugin | 99: | | | |
| qf | setupDiagnosticsQf | event | | | | |

## keys: general

| key | mode | action | opts | desc |
|---|---|---|---|---|
| `<Esc>` | n | `<cmd>nohlsearch<CR>` | | Clear search highlights |
| `<leader>q` | n | @actions.toggleDiagnosticList | | Toggle diagnostic list |
| `<C-s>` | n | @actions.saveAllAndQuit | | Save all and quit |
| `<C-c>` | n | @actions.smart_quit | | Quit with save/discard prompt |
| `<leader>tt` | n | core.tui.tit() | | Open TIT (git TUI) |
| `<leader>tc` | n | core.tui.cake() | | Open Cake TUI |
| `<leader>bd` | n | core.doxygen.build() | | Build doxygen docs |
| `<Esc><Esc>` | t | `<C-\><C-n>` | | Exit terminal mode |
| `<leader>tx` | n | @actions.closeAllTerminals | | Close all terminal windows |
| `<leader>rw` | n | `:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>` | | Replace word (exact) |
| `<leader>rw` | v | `"hy:%s/\<<C-r>h\>/<C-r>h/gI<Left><Left><Left>` | | Replace selection (exact) |
| `<leader>rc` | n | `:%s/<C-r><C-w>/<C-r><C-w>/gI<Left><Left><Left>` | | Replace word (contains) |
| `<leader>rc` | v | `"hy:%s/<C-r>h/<C-r>h/gI<Left><Left><Left>` | | Replace selection (contains) |
| `<leader>ss` | n | lsp.header-source.syncSplit() | | Sync header/source split |
| `<leader>s\` | n | `<C-w>v` | | Split vertical |
| `<leader>s-` | n | `<C-w>s` | | Split horizontal |
| `<leader>s=` | n | `<C-w>=` | | Equal split sizes |
| `<leader><Tab>` | n | `<C-w>o` | | Close other splits |
| `<C-h>` | n | `<C-w><C-h>` | | Focus left window |
| `<C-l>` | n | `<C-w><C-l>` | | Focus right window |
| `<C-j>` | n | `<C-w><C-j>` | | Focus lower window |
| `<C-k>` | n | `<C-w><C-k>` | | Focus upper window |
| `<leader>x` | n | `<C-w>q` | | Close window |
| `<leader>[` | n | @actions.jumpBackSynced | | Jump back (sync split) |
| `<leader>]` | n | @actions.jumpForwardSynced | | Jump forward (sync split) |
| `<leader>p` | n | `:pu<CR>` | | Paste below on new line |
| `<leader>P` | n | `:pu!<CR>` | | Paste above on new line |
| `<Esc>` | i | @actions.formatOnEsc | expr | Format on exit insert mode |
| `<Esc>` | v | @actions.formatOnEsc | expr | Format on exit visual mode |
| `<Esc><Esc>` | n | @actions.formatBufferByFiletype | | Format buffer |
| `<leader>ff` | n | core.cmake-picker.files() | | Find files (cmake) |
| `<leader>fx` | n | core.cmake-picker.open_explorer() | | Project explorer (cmake) |
| `<leader>fg` | n | core.cmake-picker.grep() | | Find by grep (cmake) |
| `<leader>fr` | n | core.cmake-picker.replace_grep() | | Project grep+replace (cmake) |
| `<leader>rg` | n | core.cmake-picker.replace() | | Project replace (cmake) |
| `<leader>rg` | v | `"zy<Cmd>lua require("core.cmake-picker").replace(vim.fn.getreg("z"))<CR>` | | Project replace selection (cmake) |
| `<leader>fb` | n | Snacks.picker.buffers() | sync | Find buffers |
| `<leader>fh` | n | Snacks.picker.help() | sync | Find help |
| `<leader>\` | n | Snacks.explorer.reveal() | | File explorer |
| `<leader>fk` | n | Snacks.picker.keymaps() | | Find keymaps |
| `<leader>fw` | n | Snacks.picker.grep_word() | sync | Find current word |
| `<leader>fd` | n | Snacks.picker.diagnostics() | sync | Find diagnostics |
| `<leader>fR` | n | Snacks.picker.resume() | sync | Find resume |
| `<leader>f.` | n | Snacks.picker.recent() | sync | Find recent files |
| `<leader>/` | n | Snacks.picker.lines() | | Search in buffer |
| `<leader>f/` | n | Snacks.picker.grep_buffers() | sync | Find in open files |
| `<leader>fn` | n | Snacks.picker.files({ cwd = vim.fn.stdpath('config') }) | sync | Find neovim files |

## keys: lsp

| key | mode | action | opts | desc |
|---|---|---|---|---|
| `gd` | n | lsp.header-source.smartDefinitionJump() | | Go to definition |
| `gr` | n | Snacks.picker.lsp_references() | sync | Go to references |
| `gI` | n | Snacks.picker.lsp_implementations() | sync | Go to implementation |
| `gD` | n | vim.lsp.buf.declaration() | sync | Go to declaration |
| `K` | n | vim.lsp.buf.hover | | Hover documentation |
| `<leader>ds` | n | Snacks.picker.lsp_symbols() | sync | Document symbols |
| `<leader>ws` | n | Snacks.picker.lsp_workspace_symbols() | sync | Workspace symbols |
| `<leader>rn` | n | vim.lsp.buf.rename | | Rename symbol |
| `<leader>ca` | n,x | vim.lsp.buf.code_action | | Code action |

## keys: lsp-clangd

| key | mode | action | opts | desc |
|---|---|---|---|---|
| `gh` | n | `<cmd>ClangdSwitchSourceHeader<CR>` | | Switch header/source |
| `<leader>cc` | n | lsp.cpp-stub.generateStub() | | Generate C++ definition stub |
| `<leader>cv` | n | lsp.cpp-stub.generateAllStubs() | | Generate all missing C++ stubs |
| `<leader>c/` | n | lsp.cpp-stub.toggleCommentPair() | | Toggle comment in header + cpp |

## keys: lsp-inlay

| key | mode | action | opts | desc |
|---|---|---|---|---|
| `<leader>th` | n | vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })) | | Toggle inlay hints |

## keys: dap

| key | mode | action | opts | desc |
|---|---|---|---|---|
| `<F5>` | n | @build.configureProject | | Configure project |
| `<F10>` | n | dap.step_over | | Step over |
| `<F11>` | n | dap.step_into | | Step into |
| `<F12>` | n | dap.step_out | | Step out |
| `<leader>db` | n | dap.toggle_breakpoint() | sync | Toggle breakpoint |
| `<leader>dB` | n | dap.set_breakpoint(vim.fn.input('Condition: ')) | sync | Conditional breakpoint |
| `<leader>dl` | n | dap.set_breakpoint(nil, nil, vim.fn.input('Log message: ')) | sync | Log point |
| `<leader>dc` | n | dap.continue | | Continue |
| `<leader>di` | n | dap.step_into | | Step into |
| `<leader>do` | n | dap.step_over | | Step over |
| `<leader>dx` | n | dap.step_out | | Step out |
| `<leader>dp` | n | dap.pause | | Pause |
| `<leader>dr` | n | dap.repl.open() | | Open REPL |
| `<leader>dL` | n | dap.run_last | | Run last |
| `<leader>du` | n | dapui.toggle | | Toggle UI |
| `<leader>de` | n | dapui.eval | | Evaluate expression |
| `<leader>de` | v | dapui.eval | | Evaluate selection |
| `<leader>dt` | n | @build.terminateAndNotify | | Terminate + close DAW/App |
| `<leader>br` | n | @build.buildReleaseAndRun | | Build release + run |
| `<leader>bb` | n | @build.buildDebugAndRun | | Build debug + run |
| `<leader>bR` | n | @build.buildReleaseOnly | | Build release only (no run) |
| `<leader>bB` | n | @build.buildDebugOnly | | Build debug only (no run) |
| `<leader>bc` | n | @build.cleanBuild | | Clean build |
| `<leader>bk` | n | @build.cleanOnly | | Clean |

## keys: minipairs

| key | mode | action | opts | desc |
|---|---|---|---|---|
| `;` | i | @actions.jumpOutSemicolon | expr | Jump out of )/} and add ; |

## keys: flash

| key | mode | action | opts | desc |
|---|---|---|---|---|
| `s` | n,x,o | flash.jump() | | Flash |
| `S` | n,x,o | flash.treesitter() | | Flash Treesitter |
| `r` | o | flash.remote() | | Remote Flash |
| `R` | o,x | flash.treesitter_search() | | Treesitter Search |
| `<c-s>` | c | flash.toggle() | | Toggle Flash Search |

## keys: textobjects

| key | mode | action | opts | desc |
|---|---|---|---|---|
| `aF` | x,o | select.select_textobject('@function.outer', 'textobjects') | | around function |
| `iF` | x,o | select.select_textobject('@function.inner', 'textobjects') | | inside function |
| `aC` | x,o | select.select_textobject('@class.outer', 'textobjects') | | around class |
| `iC` | x,o | select.select_textobject('@class.inner', 'textobjects') | | inside class |
| `aL` | x,o | select.select_textobject('@loop.outer', 'textobjects') | | around loop |
| `iL` | x,o | select.select_textobject('@loop.inner', 'textobjects') | | inside loop |
| `aI` | x,o | select.select_textobject('@conditional.outer', 'textobjects') | | around if/conditional |
| `iI` | x,o | select.select_textobject('@conditional.inner', 'textobjects') | | inside if/conditional |

## keys: snippets

| key | mode | action | opts | desc |
|---|---|---|---|---|
| `<C-l>` | i | luasnip.jump(1) | silent | Snippet jump forward |
| `<C-h>` | i | luasnip.jump(-1) | silent | Snippet jump back |
| `<C-e>` | i | @actions.cycleSnippetChoice | silent | Cycle snippet choice |
| `<leader>fs` | n | snacks.picker.snippets() | | Snippet picker |
| `<C-v>` | i | snacks.picker.snippets() | | Snippet picker (insert mode) |

## keys: 99

| key | mode | action | opts | desc |
|---|---|---|---|---|
| `<leader>9f` | n | 99.fill_in_function() | | Fill function |
| `<leader>9v` | v | 99.visual() | | Visual AI |
| `<leader>9s` | n | 99.stop_all_requests() | | Stop requests |

## keys: qf

| key | mode | action | opts | desc |
|---|---|---|---|---|
| `<CR>` | n | `<CR>` | silent | Jump to diagnostic |
| `q` | n | `<cmd>lclose<CR>` | silent | Close diagnostic list |
| `p` | n | `<CR><C-w>p` | silent | Preview diagnostic |

---

# Reference (prose — not part of the generation contract)

## Diagnostics

### Inline Diagnostics (Always Active)
- **Virtual text** - Error messages at end of lines (`● error message`)
- **Signs** - Gutter icons: `✘` (error), `▲` (warning), `⚑` (hint), `»` (info)
- **Underlines** - Wavy lines under problematic code
- **Floating window** - Hover on error (cursor hold) shows full diagnostic

**Auto-close:** Diagnostic list closes automatically when all errors are fixed.

## C++ Stub Notes (`<leader>cc` / `<leader>cv`)

- Strips linkage keywords (`static`, `extern`, `inline`, `virtual`, etc.)
- Skips `inline` functions (should be defined in header)
- Auto-places stubs after last class method

## Surround (mini.surround)

Uses default mini.surround keys. **NOT** `<leader>s`.

### Custom Surroundings

| Char | Surrounds With |
|------|----------------|
| `m` | `std::move (...)` |
| `(` | `(...)` (no spaces) |
| `)` | `(...)` (no spaces) |

### Text Object Motions (mini.ai)

| Motion | Captures |
|--------|----------|
| `iw` | word (`layout`) |
| `iW` | WORD including dots (`layout.panel`) |
| `_` | entire line (trimmed) |
| `$` | to end of line |
| `i}` | inside `{}` block |
| `a}` | around `{}` block (includes braces) |
| `if` | inside function call `()` |
| `af` | around function call `()` |

Treesitter textobjects (`iF`/`aF`/`iC`/`aC`/`iL`/`aL`/`iI`/`aI`) are contract
rows — see `## keys: textobjects`.

### Select Scope/Function Examples

```
vi}     →  select inside {} braces
va}     →  select {} including braces
viF     →  select function body (treesitter)
vaF     →  select entire function (treesitter)
viC     →  select class body
vaC     →  select entire class
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

### Delete / Replace Surround

| Key | Action |
|-----|--------|
| `sd{char}` | Delete surrounding char (`sd"`, `sd)`, `sdm`) |
| `sr{old}{new}` | Replace surround (`sr"'`, `sr)]`, `srm(`) |

## Insert Mode Helpers

| Key | Owner | Action |
|-----|-------|--------|
| `<Tab>` | nvim-cmp (`plugins/completion.lua`) | Completion navigation / fallback tab |
| `;` | contract row (`## keys: minipairs`) | Jump out of `)` or `}` and add `;` |

**Example:** Type `func(arg` then `;` → `func(arg);`

## Snippets — Available Triggers

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

