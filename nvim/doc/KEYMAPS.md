# Neovim Keymaps

**This file is the single source of truth for every static keybinding.**

`cast` generates `nvim/lua/core/keymaps.lua` from the tables below.

Never edit the generated file. It carries the CAST banner, and `cast` writes it on every run.

## How the System Works

```
nvim/doc/KEYMAPS.md            (data: you edit THIS)
nvim/cast/keymaps.cast         (shapes: the Lua text of each generated line)
nvim/cast/spell.md             (manifest: one wiring row per generated function)
        │
        │  cast nvim/cast/spell.md
        ▼
nvim/lua/core/keymaps.lua      (generated, committed, read-only)
        │  called by
        ▼
init.lua / LspAttach / plugin setup tails / FileType-qf autocmd
        │  rows reference behavior in
        ▼
core/actions.lua (actions.*)   core/build.lua (build.*)
                 (hand-written function bodies)
```

**Division of responsibility — bindings are vocabulary, bodies are behavior:**

- A _binding_ (key, mode, action, description, options) is a row in `## keys`. To change a key,
  remap it, or describe it again, edit this file only.
- A _behavior_ is a Lua function body. It lives in one of two modules:

  - `core/actions.lua` — editor actions.
  - `core/build.lua` — build and DAP orchestration.
- For new behavior, write the function in its module first.
- Then reference it in a row as `actions.name` or `build.name`.

### When Regeneration Happens

1. **On save of this file.** A `BufWritePost` autocmd runs `cast` and shows a notice.
2. The autocmd is in `core/autocommands.lua`.
3. **Manually.** Run `cast ~/.config/nvim/cast/spell.md`.

`keymaps.lua` is committed. `cast` output is deterministic, thus a pull from another machine brings
the tables and the generated file together.

### Failure Contract

A `cast` failure is fatal and names the file, the line, and the column. `cast` then writes no
output, thus the last good `keymaps.lua` stays and nvim always starts with working keymaps. The
notice shows the `cast` error line. Correct the reported cell, save, and the run repeats.

## Tables

Three tables feed the generator: `## index`, `## requires`, and `## keys`. Each other heading and
paragraph in this file is human documentation. `cast` formats this file to canonical markdown on
each run.

### The index table

Aliases that `## keys` rows reference: the indents, the buffer scope, and the description prefixes.

### The requires table

`group | require`. Each row renders one `local <require>` line at the top of its group's function.

### The keys table

| column    | meaning                                                                               |
| --------- | ------------------------------------------------------------------------------------- |
| `group`   | The function that the row belongs to. `nvim/cast/spell.md` selects rows by this cell. |
| `indent`  | `@two` in a function body, `@four` inside an LSP guard.                               |
| `lhs`     | The key, as a Lua string literal: `'<leader>ff'`.                                     |
| `mode`    | The mode, as Lua: `'n'`, or `{ 'n', 'x' }` for more than one mode.                    |
| `action`  | The right-hand side, as Lua, verbatim (see below).                                    |
| `buffer`  | `@buffer` for a group that takes an `event` argument. The map is then buffer-local.   |
| `prefix`  | The description prefix of the group: `@lsp`, `@dap`, `@ai`. Empty for no prefix.      |
| `desc`    | The description.                                                                      |
| `options` | `, expr = true` or `, silent = true`. Empty for no option.                            |

The `action` cell holds one of these forms:

| form                  | example                                                           |
| --------------------- | ----------------------------------------------------------------- |
| string literal        | `'<cmd>nohlsearch<CR>'`                                           |
| function reference    | `actions.smart_quit`, `dap.step_over`, `vim.lsp.buf.hover`        |
| call in a closure     | `function() require('core.tui').cake() end`                       |
| split sync, then call | `function() actions.splitSyncOnce(); Snacks.picker.buffers() end` |

A function reference needs its local in `## requires` (`actions`, `build`, `dap`), or a global root
(`vim`, `Snacks`). A wrong name fails at nvim startup, when `vim.keymap.set` receives `nil`.

**Markdown escaping.** Cells follow markdown backslash escapes. Write a literal backslash as two
backslashes, and a literal pipe as a backslash and a pipe.

### Recipes

**Remap or describe a key again.** Edit its row. Save.

**Add a binding.** Add one row. Copy `group`, `indent`, `buffer`, and `prefix` from a row of the
same group.

**Add a binding that needs new behavior.** Write the function in `core/actions.lua` first. Then add
a row with `actions.<name>` as the action. The group needs `actions` in `## requires`.

**Add a group.**

1. Add its rows to `## requires` and `## keys`.
2. Add one wiring row to `nvim/cast/spell.md`.
3. Call the new function from init.lua, a plugin setup tail, or an autocmd.

### Out of Scope (by design)

Runtime buffer-local maps that behavior creates — the build terminal's abort-`<Esc>` and failure-`q`
— belong to `core/build.lua`, not to this file. Plugin-internal mappings configured through plugin
APIs (nvim-cmp's `<Tab>`, mini.surround's `sa`/`sd`/`sr`) live in their plugin specs, and the
Reference section below documents them.

## index

| alias   | symbol                    | format   |
| ------- | ------------------------- | -------- |
| @two    | U+0020U+0020              | fromUTF8 |
| @four   | U+0020U+0020U+0020U+0020  | fromUTF8 |
| @buffer | buffer = event.buf,U+0020 | fromUTF8 |
| @lsp    | LSP:U+0020                | fromUTF8 |
| @dap    | DAP:U+0020                | fromUTF8 |
| @ai     | 99:U+0020                 | fromUTF8 |

## requires

| group       | require                                                |
| ----------- | ------------------------------------------------------ |
| general     | actions = require('core.actions')                      |
| lsp         | actions = require('core.actions')                      |
| dap         | actions = require('core.actions')                      |
| dap         | build = require('core.build')                          |
| dap         | dap = require('dap')                                   |
| dap         | dapui = require('dapui')                               |
| minipairs   | actions = require('core.actions')                      |
| textobjects | select = require('nvim-treesitter-textobjects.select') |
| snippets    | actions = require('core.actions')                      |
| snippets    | snacks = require('snacks')                             |

## keys

| group       | indent | lhs             | mode              | action                                                                                              | buffer  | prefix | desc                                | options         |
| ----------- | ------ | --------------- | ----------------- | --------------------------------------------------------------------------------------------------- | ------- | ------ | ----------------------------------- | --------------- |
| general     | @two   | '<Esc>'         | 'n'               | '<cmd>nohlsearch<CR>'                                                                               |         |        | Clear search highlights             |                 |
| general     | @two   | '<leader>q'     | 'n'               | actions.toggleDiagnosticList                                                                        |         |        | Toggle diagnostic list              |                 |
| general     | @two   | '<C-s>'         | 'n'               | actions.saveAllAndQuit                                                                              |         |        | Save all and quit                   |                 |
| general     | @two   | '<C-c>'         | 'n'               | actions.smart_quit                                                                                  |         |        | Quit with save/discard prompt       |                 |
| general     | @two   | '<leader>tc'    | 'n'               | function() require('core.tui').cake() end                                                           |         |        | Open Cake TUI                       |                 |
| general     | @two   | '<leader>bd'    | 'n'               | function() require('core.doxygen').build() end                                                      |         |        | Build doxygen docs                  |                 |
| general     | @two   | '<Esc><Esc>'    | 't'               | '<C-\\\\><C-n>'                                                                                     |         |        | Exit terminal mode                  |                 |
| general     | @two   | '<leader>tx'    | 'n'               | actions.closeAllTerminals                                                                           |         |        | Close all terminal windows          |                 |
| general     | @two   | '<leader>rw'    | 'n'               | ':%s/\\\\<<C-r><C-w>\\\\>/<C-r><C-w>/gI<Left><Left><Left>'                                          |         |        | Replace word (exact)                |                 |
| general     | @two   | '<leader>rw'    | 'v'               | '"hy:%s/\\\\<<C-r>h\\\\>/<C-r>h/gI<Left><Left><Left>'                                               |         |        | Replace selection (exact)           |                 |
| general     | @two   | '<leader>rc'    | 'n'               | ':%s/<C-r><C-w>/<C-r><C-w>/gI<Left><Left><Left>'                                                    |         |        | Replace word (contains)             |                 |
| general     | @two   | '<leader>rc'    | 'v'               | '"hy:%s/<C-r>h/<C-r>h/gI<Left><Left><Left>'                                                         |         |        | Replace selection (contains)        |                 |
| general     | @two   | '<leader>ss'    | 'n'               | function() require('lsp.header-source').syncSplit() end                                             |         |        | Sync header/source split            |                 |
| general     | @two   | '<leader>s\\\\' | 'n'               | '<C-w>v'                                                                                            |         |        | Split vertical                      |                 |
| general     | @two   | '<leader>s-'    | 'n'               | '<C-w>s'                                                                                            |         |        | Split horizontal                    |                 |
| general     | @two   | '<leader>s='    | 'n'               | '<C-w>='                                                                                            |         |        | Equal split sizes                   |                 |
| general     | @two   | '<leader><Tab>' | 'n'               | '<C-w>o'                                                                                            |         |        | Close other splits                  |                 |
| general     | @two   | '<C-h>'         | 'n'               | '<C-w><C-h>'                                                                                        |         |        | Focus left window                   |                 |
| general     | @two   | '<C-l>'         | 'n'               | '<C-w><C-l>'                                                                                        |         |        | Focus right window                  |                 |
| general     | @two   | '<C-j>'         | 'n'               | '<C-w><C-j>'                                                                                        |         |        | Focus lower window                  |                 |
| general     | @two   | '<C-k>'         | 'n'               | '<C-w><C-k>'                                                                                        |         |        | Focus upper window                  |                 |
| general     | @two   | '<leader>x'     | 'n'               | '<C-w>q'                                                                                            |         |        | Close window                        |                 |
| general     | @two   | '<leader>['     | 'n'               | actions.jumpBackSynced                                                                              |         |        | Jump back (sync split)              |                 |
| general     | @two   | '<leader>]'     | 'n'               | actions.jumpForwardSynced                                                                           |         |        | Jump forward (sync split)           |                 |
| general     | @two   | '<leader>p'     | 'n'               | ':pu<CR>'                                                                                           |         |        | Paste below on new line             |                 |
| general     | @two   | '<leader>P'     | 'n'               | ':pu!<CR>'                                                                                          |         |        | Paste above on new line             |                 |
| general     | @two   | '<Esc>'         | 'i'               | actions.formatOnEsc                                                                                 |         |        | Format on exit insert mode          | , expr = true   |
| general     | @two   | '<Esc>'         | 'v'               | actions.formatOnEsc                                                                                 |         |        | Format on exit visual mode          | , expr = true   |
| general     | @two   | '<Esc><Esc>'    | 'n'               | actions.formatBufferByFiletype                                                                      |         |        | Format buffer                       |                 |
| general     | @two   | '<leader>ff'    | 'n'               | function() require('core.navigator').files() end                                                    |         |        | Find files (project)                |                 |
| general     | @two   | '<leader>fx'    | 'n'               | function() require('core.navigator').open_explorer() end                                            |         |        | Project explorer (project)          |                 |
| general     | @two   | '<leader>fg'    | 'n'               | function() require('core.navigator').grep() end                                                     |         |        | Find by grep (project)              |                 |
| general     | @two   | '<leader>fr'    | 'n'               | function() require('core.navigator').replace_grep() end                                             |         |        | Project grep+replace (project)      |                 |
| general     | @two   | '<leader>rg'    | 'n'               | function() require('core.navigator').replace() end                                                  |         |        | Project replace (project)           |                 |
| general     | @two   | '<leader>rg'    | 'v'               | '"zy<Cmd>lua require("core.navigator").replace(vim.fn.getreg("z"))<CR>'                             |         |        | Project replace selection (project) |                 |
| general     | @two   | '<leader>fb'    | 'n'               | function() actions.splitSyncOnce(); Snacks.picker.buffers() end                                     |         |        | Find buffers                        |                 |
| general     | @two   | '<leader>fh'    | 'n'               | function() actions.splitSyncOnce(); Snacks.picker.help() end                                        |         |        | Find help                           |                 |
| general     | @two   | '<leader>\\\\'  | 'n'               | function() Snacks.explorer.reveal() end                                                             |         |        | File explorer                       |                 |
| general     | @two   | '<leader>fk'    | 'n'               | function() Snacks.picker.keymaps() end                                                              |         |        | Find keymaps                        |                 |
| general     | @two   | '<leader>fw'    | 'n'               | function() actions.splitSyncOnce(); Snacks.picker.grep_word() end                                   |         |        | Find current word                   |                 |
| general     | @two   | '<leader>fd'    | 'n'               | function() actions.splitSyncOnce(); Snacks.picker.diagnostics() end                                 |         |        | Find diagnostics                    |                 |
| general     | @two   | '<leader>fR'    | 'n'               | function() actions.splitSyncOnce(); Snacks.picker.resume() end                                      |         |        | Find resume                         |                 |
| general     | @two   | '<leader>f.'    | 'n'               | function() actions.splitSyncOnce(); Snacks.picker.recent() end                                      |         |        | Find recent files                   |                 |
| general     | @two   | '<leader>/'     | 'n'               | function() Snacks.picker.lines() end                                                                |         |        | Search in buffer                    |                 |
| general     | @two   | '<leader>f/'    | 'n'               | function() actions.splitSyncOnce(); Snacks.picker.grep_buffers() end                                |         |        | Find in open files                  |                 |
| general     | @two   | '<leader>fn'    | 'n'               | function() actions.splitSyncOnce(); Snacks.picker.files({ cwd = vim.fn.stdpath('config') }) end     |         |        | Find neovim files                   |                 |
| lsp         | @two   | 'gd'            | 'n'               | function() require('lsp.header-source').smartDefinitionJump() end                                   | @buffer | @lsp   | Go to definition                    |                 |
| lsp         | @two   | 'gr'            | 'n'               | function() actions.splitSyncOnce(); Snacks.picker.lsp_references() end                              | @buffer | @lsp   | Go to references                    |                 |
| lsp         | @two   | 'gI'            | 'n'               | function() actions.splitSyncOnce(); Snacks.picker.lsp_implementations() end                         | @buffer | @lsp   | Go to implementation                |                 |
| lsp         | @two   | 'gD'            | 'n'               | function() actions.splitSyncOnce(); vim.lsp.buf.declaration() end                                   | @buffer | @lsp   | Go to declaration                   |                 |
| lsp         | @two   | 'K'             | 'n'               | vim.lsp.buf.hover                                                                                   | @buffer | @lsp   | Hover documentation                 |                 |
| lsp         | @two   | '<leader>ds'    | 'n'               | function() actions.splitSyncOnce(); Snacks.picker.lsp_symbols() end                                 | @buffer | @lsp   | Document symbols                    |                 |
| lsp         | @two   | '<leader>ws'    | 'n'               | function() actions.splitSyncOnce(); Snacks.picker.lsp_workspace_symbols() end                       | @buffer | @lsp   | Workspace symbols                   |                 |
| lsp         | @two   | '<leader>rn'    | 'n'               | vim.lsp.buf.rename                                                                                  | @buffer | @lsp   | Rename symbol                       |                 |
| lsp         | @two   | '<leader>ca'    | { 'n', 'x' }      | vim.lsp.buf.code_action                                                                             | @buffer | @lsp   | Code action                         |                 |
| lsp         | @two   | '<leader>ls'    | 'n'               | function() require('lsp.clangd').restart() end                                                      | @buffer | @lsp   | Force clangd reindex + restart      |                 |
| lsp-clangd  | @four  | 'gh'            | 'n'               | '<cmd>ClangdSwitchSourceHeader<CR>'                                                                 | @buffer | @lsp   | Switch header/source                |                 |
| lsp-clangd  | @four  | '<leader>cc'    | 'n'               | function() require('lsp.cpp-stub').generateStub() end                                               | @buffer | @lsp   | Generate C++ definition stub        |                 |
| lsp-clangd  | @four  | '<leader>cv'    | 'n'               | function() require('lsp.cpp-stub').generateAllStubs() end                                           | @buffer | @lsp   | Generate all missing C++ stubs      |                 |
| lsp-clangd  | @four  | '<leader>c/'    | 'n'               | function() require('lsp.cpp-stub').toggleCommentPair() end                                          | @buffer | @lsp   | Toggle comment in header + cpp      |                 |
| lsp-inlay   | @four  | '<leader>th'    | 'n'               | function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })) end          | @buffer | @lsp   | Toggle inlay hints                  |                 |
| dap         | @two   | '<F5>'          | 'n'               | build.configureProject                                                                              |         | @dap   | Configure project                   |                 |
| dap         | @two   | '<F10>'         | 'n'               | dap.step_over                                                                                       |         | @dap   | Step over                           |                 |
| dap         | @two   | '<F11>'         | 'n'               | dap.step_into                                                                                       |         | @dap   | Step into                           |                 |
| dap         | @two   | '<F12>'         | 'n'               | dap.step_out                                                                                        |         | @dap   | Step out                            |                 |
| dap         | @two   | '<leader>db'    | 'n'               | function() actions.splitSyncOnce(); dap.toggle_breakpoint() end                                     |         | @dap   | Toggle breakpoint                   |                 |
| dap         | @two   | '<leader>dB'    | 'n'               | function() actions.splitSyncOnce(); dap.set_breakpoint(vim.fn.input('Condition: ')) end             |         | @dap   | Conditional breakpoint              |                 |
| dap         | @two   | '<leader>dl'    | 'n'               | function() actions.splitSyncOnce(); dap.set_breakpoint(nil, nil, vim.fn.input('Log message: ')) end |         | @dap   | Log point                           |                 |
| dap         | @two   | '<leader>dc'    | 'n'               | dap.continue                                                                                        |         | @dap   | Continue                            |                 |
| dap         | @two   | '<leader>di'    | 'n'               | dap.step_into                                                                                       |         | @dap   | Step into                           |                 |
| dap         | @two   | '<leader>do'    | 'n'               | dap.step_over                                                                                       |         | @dap   | Step over                           |                 |
| dap         | @two   | '<leader>dx'    | 'n'               | dap.step_out                                                                                        |         | @dap   | Step out                            |                 |
| dap         | @two   | '<leader>dp'    | 'n'               | dap.pause                                                                                           |         | @dap   | Pause                               |                 |
| dap         | @two   | '<leader>dr'    | 'n'               | function() dap.repl.open() end                                                                      |         | @dap   | Open REPL                           |                 |
| dap         | @two   | '<leader>dL'    | 'n'               | dap.run_last                                                                                        |         | @dap   | Run last                            |                 |
| dap         | @two   | '<leader>du'    | 'n'               | dapui.toggle                                                                                        |         | @dap   | Toggle UI                           |                 |
| dap         | @two   | '<leader>de'    | 'n'               | dapui.eval                                                                                          |         | @dap   | Evaluate expression                 |                 |
| dap         | @two   | '<leader>de'    | 'v'               | dapui.eval                                                                                          |         | @dap   | Evaluate selection                  |                 |
| dap         | @two   | '<leader>dt'    | 'n'               | build.terminateAndNotify                                                                            |         | @dap   | Terminate + close host/app          |                 |
| dap         | @two   | '<leader>br'    | 'n'               | build.buildReleaseAndRun                                                                            |         | @dap   | Build release + run                 |                 |
| dap         | @two   | '<leader>bb'    | 'n'               | build.buildDebugAndRun                                                                              |         | @dap   | Build debug + run                   |                 |
| dap         | @two   | '<leader>bR'    | 'n'               | build.buildReleaseOnly                                                                              |         | @dap   | Build release only (no run)         |                 |
| dap         | @two   | '<leader>bn'    | 'n'               | build.buildDebugOnly                                                                                |         | @dap   | Build debug only (no run)           |                 |
| dap         | @two   | '<leader>bc'    | 'n'               | build.cleanBuild                                                                                    |         | @dap   | Clean build                         |                 |
| dap         | @two   | '<leader>bk'    | 'n'               | build.cleanOnly                                                                                     |         | @dap   | Clean                               |                 |
| minipairs   | @two   | ';'             | 'i'               | actions.jumpOutSemicolon                                                                            |         |        | Jump out of )/} and add ;           | , expr = true   |
| flash       | @two   | 's'             | { 'n', 'x', 'o' } | function() require('flash').jump() end                                                              |         |        | Flash                               |                 |
| flash       | @two   | 'S'             | { 'n', 'x', 'o' } | function() require('flash').treesitter() end                                                        |         |        | Flash Treesitter                    |                 |
| flash       | @two   | 'r'             | 'o'               | function() require('flash').remote() end                                                            |         |        | Remote Flash                        |                 |
| flash       | @two   | 'R'             | { 'o', 'x' }      | function() require('flash').treesitter_search() end                                                 |         |        | Treesitter Search                   |                 |
| flash       | @two   | '<c-s>'         | 'c'               | function() require('flash').toggle() end                                                            |         |        | Toggle Flash Search                 |                 |
| textobjects | @two   | 'aF'            | { 'x', 'o' }      | function() select.select_textobject('@function.outer', 'textobjects') end                           |         |        | around function                     |                 |
| textobjects | @two   | 'iF'            | { 'x', 'o' }      | function() select.select_textobject('@function.inner', 'textobjects') end                           |         |        | inside function                     |                 |
| textobjects | @two   | 'aC'            | { 'x', 'o' }      | function() select.select_textobject('@class.outer', 'textobjects') end                              |         |        | around class                        |                 |
| textobjects | @two   | 'iC'            | { 'x', 'o' }      | function() select.select_textobject('@class.inner', 'textobjects') end                              |         |        | inside class                        |                 |
| textobjects | @two   | 'aL'            | { 'x', 'o' }      | function() select.select_textobject('@loop.outer', 'textobjects') end                               |         |        | around loop                         |                 |
| textobjects | @two   | 'iL'            | { 'x', 'o' }      | function() select.select_textobject('@loop.inner', 'textobjects') end                               |         |        | inside loop                         |                 |
| textobjects | @two   | 'aI'            | { 'x', 'o' }      | function() select.select_textobject('@conditional.outer', 'textobjects') end                        |         |        | around if/conditional               |                 |
| textobjects | @two   | 'iI'            | { 'x', 'o' }      | function() select.select_textobject('@conditional.inner', 'textobjects') end                        |         |        | inside if/conditional               |                 |
| snippets    | @two   | '<C-l>'         | 'i'               | function() require('luasnip').jump(1) end                                                           |         |        | Snippet jump forward                | , silent = true |
| snippets    | @two   | '<C-h>'         | 'i'               | function() require('luasnip').jump(-1) end                                                          |         |        | Snippet jump back                   | , silent = true |
| snippets    | @two   | '<C-e>'         | 'i'               | actions.cycleSnippetChoice                                                                          |         |        | Cycle snippet choice                | , silent = true |
| snippets    | @two   | '<leader>fs'    | 'n'               | function() snacks.picker.snippets() end                                                             |         |        | Snippet picker                      |                 |
| snippets    | @two   | '<C-v>'         | 'i'               | function() snacks.picker.snippets() end                                                             |         |        | Snippet picker (insert mode)        |                 |
| 99          | @two   | '<leader>9f'    | 'n'               | function() require('99').fill_in_function() end                                                     |         | @ai    | Fill function                       |                 |
| 99          | @two   | '<leader>9v'    | 'v'               | function() require('99').visual() end                                                               |         | @ai    | Visual AI                           |                 |
| 99          | @two   | '<leader>9s'    | 'n'               | function() require('99').stop_all_requests() end                                                    |         | @ai    | Stop requests                       |                 |
| qf          | @two   | '<CR>'          | 'n'               | '<CR>'                                                                                              | @buffer |        | Jump to diagnostic                  | , silent = true |
| qf          | @two   | 'q'             | 'n'               | '<cmd>lclose<CR>'                                                                                   | @buffer |        | Close diagnostic list               | , silent = true |
| qf          | @two   | 'p'             | 'n'               | '<CR><C-w>p'                                                                                        | @buffer |        | Preview diagnostic                  | , silent = true |

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

| Char | Surrounds With      |
| ---- | ------------------- |
| `m`  | `std::move (...)`   |
| `(`  | `(...)` (no spaces) |
| `)`  | `(...)` (no spaces) |

### Text Object Motions (mini.ai)

| Motion | Captures                             |
| ------ | ------------------------------------ |
| `iw`   | word (`layout`)                      |
| `iW`   | WORD including dots (`layout.panel`) |
| `_`    | entire line (trimmed)                |
| `$`    | to end of line                       |
| `i}`   | inside `{}` block                    |
| `a}`   | around `{}` block (includes braces)  |
| `if`   | inside function call `()`            |
| `af`   | around function call `()`            |

Treesitter textobjects are rows of group `textobjects` in the keys table.

Their keys: `iF`, `aF`, `iC`, `aC`, `iL`, `aL`, `iI`, `aI`.

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

| Key                | Action                                                    |
| ------------------ | --------------------------------------------------------- |
| `sa{motion}{char}` | Surround motion with char                                 |
| `saiw"`            | Surround word with `"`                                    |
| `saW(`             | Surround WORD with `()` → `(layout.panel)`                |
| `saWm`             | Surround WORD with std::move → `std::move (layout.panel)` |
| `sa_m`             | Surround line with std::move                              |
| `sa$}`             | Surround to EOL with `{}`                                 |

**In visual mode:** select text, then `sa{char}`

- `viWsam` → select WORD, wrap with `std::move (...)`
- `Vsam` → select line, wrap with `std::move (...)`

### Delete / Replace Surround

| Key            | Action                                        |
| -------------- | --------------------------------------------- |
| `sd{char}`     | Delete surrounding char (`sd"`, `sd)`, `sdm`) |
| `sr{old}{new}` | Replace surround (`sr"'`, `sr)]`, `srm(`)     |

## Insert Mode Helpers

| Key     | Owner                               | Action                               |
| ------- | ----------------------------------- | ------------------------------------ |
| `<Tab>` | nvim-cmp (`plugins/completion.lua`) | Completion navigation / fallback tab |
| `;`     | contract row (`## keys: minipairs`) | Jump out of `)` or `}` and add `;`   |

**Example:** Type `func(arg` then `;` → `func(arg);`

## Snippets — Available Triggers

| Trigger    | Description                                                   |
| ---------- | ------------------------------------------------------------- |
| `sep`      | Separator comment `//==============` (returns to normal mode) |
| `cls`      | Class with leak detector                                      |
| `comp`     | JUCE Component header declaration                             |
| `leak`     | JUCE leak detector macro with separator                       |
| `juce`     | Simple JUCE Component with inline implementations             |
| `fn`       | Function definition with noexcept                             |
| `loop`     | Traditional for loop (int i {0}; i < N; ++i)                  |
| `forr`     | Range-based for loop (auto& item : container)                 |
| `if`       | If statement with braces                                      |
| `ife`      | If-else statement                                             |
| `while`    | While loop with braces                                        |
| `switch`   | Switch statement with case/default                            |
| `template` | Template function declaration                                 |
| `nam`      | Namespace with decorative comments                            |
| `sing`     | Meyers Singleton complete class                               |
| `unp`      | `std::unique_ptr<type> name`                                  |
| `mku`      | `std::make_unique<type>(args)`                                |
| `mks`      | `std::make_shared<type>(args)`                                |
| `dbp`      | Debug paint (magenta border)                                  |
| `mac`      | `#if JUCE_MAC ... #endif`                                     |
| `win`      | `#if JUCE_WINDOWS ... #endif`                                 |
