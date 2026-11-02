## Handoff to MACHINIST: One shared clangd per project — conformance on the other three machines

**From:** MACHINIST (macOS ARM, M4)
**Date:** 2026-11-02
**Status:** Blocked

### Read First
1. This file. It holds the only record of the design and of the macOS ARM test runs. No RFC exists for this subject.
2. `~/.carol/.claude-plugin/plugin.json` — the current `lspServers.clangd` entry. The agents' clangd starts from it.
3. `~/.config/nvim/lua/lsp/clangd.lua` — nvim's clangd launch (`cmd`, lines 26-50) and its `root_dir` (lines 13-20).
4. `~/.config/nvim/lua/core/clangd.lua` — writes the project `.clangd`, the user-module `.clangd`, and the root `compile_commands.json` copy (lines 69-79).
5. `~/.config/bootstrap-windows.sh` — step 4, MSYS2 packages (lines 279-317), and the `$MSYSTEM` prefix table (lines 65-80).
6. `~/.config/bootstrap-macos.sh` — the Homebrew branch (macOS ARM) and the MacPorts branch (macOS Intel), lines 47-140.

### Context

ARCHITECT reported CPU spikes and terminal freezes from clangd processes that agents start and leave running. The session measured the cause on macOS ARM and tested a fix there. The other three machines are not tested. ARCHITECT ruled that the Windows conformance work is a handoff.

The four machines (`bootstrap-macos.sh:47`, `bootstrap-windows.sh:65-80`):

| Machine | Package channel | Package prefix or path |
|---|---|---|
| macOS ARM | Homebrew | `/opt/homebrew` |
| macOS Intel | MacPorts | `/opt/local` |
| Windows x64 | MSYS2 UCRT64 | `mingw-w64-ucrt-x86_64` |
| Windows ARM64 | MSYS2 CLANGARM64 | `mingw-w64-clang-aarch64` |

clangd comes from each machine's package channel:
- macOS: `bootstrap-macos.sh:107`, `:135`, linked to `~/.local/bin/clangd` at `:347`.
- Windows: `${PKG_PREFIX}-clang-tools-extra` at `bootstrap-windows.sh:304`.

Facts measured on macOS ARM, before any change:

1. **One clangd for each Claude Code session.**
   - A Pathfinder LSP call started clangd pid 5254 at 13:43:41. Its parent was the session's `claude` process (pid 98146), not the subagent. Its working directory was the session folder, `/Users/jreng/.config`.
   - At 13:45:00, the COUNSELOR session (pid 93831) started its own clangd (pid 6661).
   - nvim's clangd (pid 95702) served the same END database at the same time.
2. **Lifetime.**
   - The clangd process outlived the subagent. pid 5254 was alive and idle at 13:44:53, at 814 MB RSS.
   - A headless `claude -p` session stopped its clangd when it exited (13:50:32).
   - An interactive session exit was not tested.
3. **Cost.** Two LSP calls (`documentSymbol` and `hover`) on `end/Source/Main.cpp` with the default plugin clangd took about 50 s of CPU at 67-284%. RSS peaked at 6.1 GB (13:43:55). END's index already existed on disk with 1485 shards. Only 24 shards (215 KB) were rewritten.
4. **Worker count.** The plugin passes no `-j`. clangd then uses one worker per physical core, and the background index uses the same count (LLVM `clangd/TUScheduler.cpp:1613-1615`, `ClangdServer.cpp:255-257`, `llvm/lib/Support/Unix/Threading.inc:436-451`). `sysctl hw.physicalcpu` = 10 on the M4. nvim passes `-j` = half of `vim.uv.available_parallelism()` (`nvim/lua/lsp/clangd.lua:31`).
5. **`--compile-commands-dir=<dir>`.** When the folder exists, clangd uses that one database for every file, also for files outside the folder (`clangd/GlobalCompilationDatabase.cpp:424-427`). It overrides a `.clangd` `CompilationDatabase` key (`ClangdMain.cpp:1010-1013`, flag provider applied last). Source: Librarian research on LLVM `main` and `release/22.x`.
6. **Plugin fields.** Claude Code `lspServers` accepts `args`, `env`, `workspaceFolder`, `initializationOptions`, `shutdownTimeout`, `restartOnCrash` (default true), and `maxRestarts`. `${CLAUDE_PROJECT_DIR}` expands in `command`, `args`, `env`, and `workspaceFolder` (code.claude.com plugins manifest reference, from WebFetch summaries).

The fix under test: lspmux 0.3.0 (`https://codeberg.org/p2502/lspmux`, crate `lspmux`). One `lspmux server` holds one clangd per project. Each client, whether a Claude Code session or nvim, connects through `lspmux client`.

### Completed

macOS ARM only. All runs were in `~/Documents/Poems/dev/end`.

1. **Install.** `brew install lspmux` installed 0.3.0 (bottled). `lspmux config` defaults: `instance_timeout` 300, `gc_interval` 10, listen and connect `127.0.0.1:27631`, config file `~/Library/Application Support/lspmux/config.toml` (absent).
2. **Argument rule.**
   - Without a separator, `lspmux client --server-path clangd --background-index` fails with `Error: unexpected argument '--background-index' found`. Claude Code reported that as a clangd crash with exit code 2.
   - The clangd flags need `--` after `--server-path clangd`.
3. **Two Claude Code sessions share one clangd.**
   - Two `claude -p` sessions ran at the same time with the test plugin below.
   - Both got LSP results: 29 and 25 symbols, and the hover `cascadeLookAndFeelChange`.
   - Only one clangd ran: pid 11896, parent `lspmux server` (pid 11274). Peak 125.5% CPU, 1.1-1.4 GB RSS.
   - `lspmux status` showed one instance: `path: "/Users/jreng/Documents/Poems/dev/end"`, `server: "clangd" [...]`.
4. **nvim shares the same clangd.** The nvim test script below connected to the same instance (pid 11896), with `root=/Users/jreng/Documents/Poems/dev/end`, and got `symbols=22 err=nil`. `lspmux status` listed the nvim client.
5. **Idle stop.** The last client left at 13:52:49. clangd pid 11896 exited at 13:57:59, which is 310 s later: `instance_timeout` 300 plus `gc_interval` 10.
6. **Instance key.** `lspmux status` shows each instance with its `server` arguments and its `path`. nvim and the agents share an instance only when both pass identical clangd arguments and the same project path. Today nvim passes `--clang-tidy`, `--header-insertion=never`, `--completion-style=detailed`, and `--header-insertion-decorators=false` (`nvim/lua/lsp/clangd.lua:33-45`). The plugin does not pass them (`~/.carol/.claude-plugin/plugin.json`).
7. **Clean-up after the tests.** The test `lspmux server` is stopped. The test plugin was only in the session scratchpad. lspmux stays installed through Homebrew.

Test plugin, used as `--plugin-dir <dir>` with this content at `<dir>/.claude-plugin/plugin.json`:

```json
{
  "name": "muxtest",
  "version": "0.0.1",
  "lspServers": {
    "clangd": {
      "command": "lspmux",
      "args": ["client", "--server-path", "clangd", "--", "--background-index", "--background-index-priority=low", "--log=error", "-j=5"],
      "extensionToLanguage": { ".h": "cpp", ".cpp": "cpp", ".mm": "objective-cpp" },
      "diagnostics": false
    }
  }
}
```

nvim test script, run as `nvim --headless --clean -c "luafile <script>"` from the project root:

```lua
vim.lsp.config('mux', {
  cmd = { 'lspmux', 'client', '--server-path', 'clangd', '--', '--background-index', '--background-index-priority=low', '--log=error', '-j=5' },
  filetypes = { 'cpp' },
  root_markers = { '.git' },
})
vim.lsp.enable('mux')
vim.cmd('edit Source/Main.cpp')
vim.defer_fn(function()
  local client = vim.lsp.get_clients({ name = 'mux' })[1]
  io.stdout:write('client=', tostring(client and client.id), ' root=', tostring(client and client.root_dir), '\n')
  local result = client and client:request_sync('textDocument/documentSymbol', { textDocument = vim.lsp.util.make_text_document_params(0) }, 20000, 0)
  io.stdout:write('symbols=', tostring(result and result.result and #result.result), ' err=', vim.inspect(result and result.err), '\n')
  io.stdout:write(vim.fn.system('lspmux status 2>/dev/null'), '\n')
  vim.cmd('qa!')
end, 3000)
```

### Remaining

In order. The owner of each step is MACHINIST on that machine, unless the step says ARCHITECT. Use a cast project that has a `compile_commands.json` at its root, for example END after a build. The commands are for an MSYS2 shell on Windows and zsh on macOS.

1. **lspmux availability.** Run the line for the machine. Record which channel gives lspmux, and its version.
   - Windows x64: `pacman -Ss lspmux`
   - Windows ARM64: `pacman -Ss lspmux`
   - Fallback on Windows, when pacman has no package: `pacman -S --noconfirm ${PKG_PREFIX}-rust`, then `cargo install lspmux`. `${PKG_PREFIX}` comes from `bootstrap-windows.sh:65-80`.
   - macOS Intel: `port search lspmux`. Fallback: `cargo install lspmux`.
2. **Server start.** Run `lspmux server` in one terminal. In a second terminal, `lspmux status` must answer without `Connection refused`.
3. **Argument rule.** `lspmux client --server-path clangd -- --background-index < /dev/null` must not print `unexpected argument`.
4. **Claude Code starts `lspmux` as an LSP `command`.**
   - Write the test plugin above to a scratch folder.
   - Windows only: replace `"-j=5"` with the half-core value of that machine.
   - Run two sessions at the same time from the project root:
     `claude -p "Use the LSP tool documentSymbol on Source/Main.cpp at line 1 character 1, then hover at line 4 character 15. Reply with the symbol count and the hovered function name only." --plugin-dir <scratch> --model haiku --allowedTools LSP < /dev/null`
   - Pass: both reply with a symbol count, and `lspmux status` shows one instance whose `path` is the project root.
   - On Windows, record whether Claude Code starts `lspmux.exe` by name from `PATH`. This is the open Windows question of the session. A native binary needs no bash wrapper.
5. **Process count.**
   - macOS: `ps -axo pid,ppid,command | grep "[c]langd"`
   - Windows: `tasklist //FI "IMAGENAME eq clangd.exe"`
   - Pass: one clangd for the project, whose parent is the `lspmux server` process.
6. **nvim joins.** Run the nvim test script above from the project root. Pass: `err=nil`, a symbol count, and the same instance pid in `lspmux status`. On Windows, record the `root=` value. Its path form must match the `path` that the Claude Code clients registered, or the two get separate instances.
7. **Idle stop.** After the last client exits, wait 310 s. Then run the step-5 command. Pass: the instance's clangd is gone.
8. **Session-exit check without lspmux.** Run one `claude -p` LSP call with `--plugin-dir ~/.carol` (the current plugin). After it exits, run the step-5 command. Pass: no clangd remains from that session. This repeats the macOS ARM result of 13:50:32.
9. **Clean-up.** Stop the test `lspmux server`. Delete the scratch plugin folder.
10. **Report.** Write the results of steps 1-8 for each machine into this file, under `Completed`, with command output. Then ARCHITECT decides the open questions below.

### Key Decisions

- ARCHITECT: "stop it. how to prevent claude code, or any harness using and leaving unnecessary clangd usage? by protocol? with carol skill? exact instruction? exact parameterised script?"
- ARCHITECT, on the proposal to run the session-exit, lspmux, and Windows tests first: "go"
- ARCHITECT: "windows conformance should be written as handoff."

### Files Modified
- `/opt/homebrew` (macOS ARM) — `brew install lspmux` added lspmux 0.3.0.
- `/Users/jreng/.config/HANDOFF-clangd-sharing.md` — this file.

No file in `~/.carol` or `~/.config/nvim` changed for this subject.

### Open Questions

Each item is ARCHITECT's decision.

1. **Adopt lspmux** on all four machines, after the Remaining steps pass. If yes: add it to `bootstrap-macos.sh` (Homebrew and MacPorts branches) and `bootstrap-windows.sh` step 4, through the channel that step 1 finds. Also decide how `lspmux server` runs: `brew services start lspmux` on macOS ARM (the formula prints this command), or another service on each platform.
2. **One clangd argument set** for nvim and the agents, so they share an instance (Completed, item 6). Which flags stay: `--clang-tidy`, `--header-insertion=never`, `--completion-style=detailed`, `--header-insertion-decorators=false`, and the `--query-driver` list?
3. **`-j` value.** A fixed number in `plugin.json` is the same on all four machines. The half-core rule that nvim uses (`nvim/lua/lsp/clangd.lua:31`) needs a computed value, which a plugin `args` entry cannot compute. Options: one fixed number; or a launch subcommand in `~/.carol/bin/carol` (bash) that computes it. The second option depends on Remaining step 4 on Windows.
4. **Compile database per project.** Add `--compile-commands-dir=${CLAUDE_PROJECT_DIR}` to the plugin arguments, and `--compile-commands-dir=<project root>` to nvim's arguments. Then stop writing the user-module `.clangd` (`nvim/lua/core/clangd.lua:78`), and give framework headers explicit entries in the root `compile_commands.json` copy. The flag value is part of the lspmux instance key, so it is also a sharing question.
5. **Interactive session exit.** Test it, or rely on lspmux's idle stop alone.

### Next Steps

- Trigger: ARCHITECT opens a MACHINIST session on a Windows machine, or on the macOS Intel machine, and points it at this file.
- That session runs `Remaining` steps 1-10 on its machine, then reports.
- When all three machines report, ARCHITECT settles `Open Questions` 1-5. MACHINIST then plans the change to `plugin.json`, `nvim/lua/lsp/clangd.lua`, `nvim/lua/core/clangd.lua`, and both bootstrap scripts.
- Separate subject, not in this file: the nvim clean-up of `core/markdown-table.lua` with `cast --tables`. cast 0.1.0 (2a616a2) now prints `--tables` (`cast --help`).
