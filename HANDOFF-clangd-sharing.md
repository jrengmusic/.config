## Handoff to MACHINIST: One shared clangd per project, killed when idle — conformance on the other three machines

**From:** MACHINIST (macOS ARM, M4)
**Date:** 2026-11-10
**Status:** In Progress

### Read First
1. This file. It holds the only record of the design and of the macOS ARM test runs. No RFC exists for this subject.
2. `~/.carol/bin/carol-clangd.js` — the proxy. It holds the clangd arguments, the idle timeout, and the pipe path.
3. `~/.carol/.claude-plugin/plugin.json` — `lspServers.clangd` starts the proxy in client mode.
4. `~/.config/bootstrap-windows.sh` — step 4, MSYS2 packages (lines 279-317). It installs `${PKG_PREFIX}-nodejs` and `${PKG_PREFIX}-clang-tools-extra`.
5. `~/.config/bootstrap-macos.sh` — Homebrew list (`go`, `node` at lines 86-87, `llvm` at line 102) and MacPorts list (`go`, `nodejs22` at lines 115-116).

### Context

ARCHITECT reported clangd processes that use many GB of memory for hours and freeze the terminal. Two parallel sessions always froze it.

Facts measured on macOS ARM before the change:

1. Claude Code starts one clangd for each session. The clangd lives as long as the session. Subagents run in the session process and share its clangd. Evidence: `ps` showed clangd 79286 with parent `claude … --agent COUNSELOR` (78019), and clangd 90607 with parent `claude … --agent ORACLE` (78602).
2. Claude Code 2.1.322 keeps up to 50 documents open for each server, and sends `didClose` only on eviction. Evidence: the binary holds `var pYs=50` and `LSP: Sending didClose for evicted document`.
3. jam's `.clangd` force-includes 13 JUCE module headers. One file builds a 145 MB preamble: `clangd --check=jam_core/jam_core.cpp` logged `Built preamble of size 145462636` and peaked at 1358512128 bytes RSS.
4. With `--pch-storage=disk`, RSS does not grow with each open file. 20 open jam headers with `--background-index=false` gave 1.6-2.1 GB RSS. With the background index on (the clangd default), 8 headers gave 2.3 GB. clangd's own `$/memoryUsage` count was 174 MB and 711 MB. The rest is allocator memory that macOS malloc keeps. `--malloc-trim` exists only for Linux glibc.
5. An idle clangd exits on stdin EOF. Test: `(sleep 3) | clangd --log=error --background-index` printed `Transport error: Input/output error` and exited.
6. lspmux (the design of the 2026-11-02 handoff) cannot run on all four machines. MSYS2 has no package (`packages.msys2.org/api/search?query=lspmux` → `"exact":{}`). MacPorts has no port (`ports.macports.org/api/v1/ports/?search=lspmux` → `"count":0`). It ships only as a crates.io crate, and no bootstrap script installs Rust. lspmux also stops an instance only when no client is connected (README: "a … server instance with no clients connected will get killed"). An interactive session stays connected, so lspmux cannot kill clangd during an idle session.

The fix: `~/.carol/bin/carol-clangd.js`, Node only. Node is in every bootstrap package list (Read First, items 4-5).

- **Client mode** is the plugin `command`, one per session. It connects to the server over `\\.\pipe\carol-clangd-<username>` on Windows, or `<os.tmpdir()>/carol-clangd-<uid>.sock` on macOS. If no server answers, it starts one detached, then tries again: 50 attempts, 100 ms apart. After the connection, it pipes stdin and stdout.
- **Server mode** runs one per machine and starts on demand.
  1. It keeps one clangd per project root (the `rootUri` of `initialize`). It sends `initialize` one time per clangd and gives the kept result to each client.
  2. It maps request ids per client. It opens a document upstream (text from disk) on the first request that names it. It sends `didClose` when the last client closes it. It sends `didChange` and `didSave` upstream as full text from disk.
  3. It answers clangd's requests itself (`workspace/configuration` → one `null` per item, others → `null`). It drops clangd's notifications.
  4. It kills a clangd 30 s after its last reply, when no request is pending. The next request starts a new one.
  5. It kills a project's clangd when the last client of that project disconnects. It exits when no project is left.
  6. It sets clangd to `os.constants.priority.PRIORITY_LOW` (19). This replaces `nice -n 19`, which has no cross-platform equivalent in a plugin `command`.

### Completed

macOS ARM only. Runs were in `~/Documents/Poems/dev/jam`.

1. **Sharing, with two direct LSP clients.** Two scratch probe clients ran in parallel through client mode. One clangd ran (pid 3817, parent server 3770). Both clients got results. After both exited, no server and no clangd remained.
2. **Idle kill.** One client stayed connected and did nothing for 40 s. At t=8 s, clangd 4096 ran under server 4094. At t=33 s, the server still ran, with no clangd. A request at about t=42 s started a new clangd and got its answer. After the client exited, no server remained (t=45 s).
3. **No orphans.**
   - `kill -9` on the client: the server and clangd were gone 2 s later.
   - `kill -9` on the server: clangd was gone 3 s later.
4. **Claude Code, two parallel sessions.** I ran this command two times in parallel from `jam`:
   `claude -p "Use the LSP tool documentSymbol on jam_terminal/buffers/jam_TerminalBuffer.h at line 1 character 1. Reply with the symbol count and the first symbol name only." --plugin-dir ~/.carol --model haiku --allowedTools LSP < /dev/null`
   - Both replied 71 symbols, first symbol `jam`. Direct clangd gave `71 jam` for the same file.
   - `ps` showed two clients (6743, 6752), one server (6744), and one clangd (6746) whose parent was 6744.
5. **Not tested on macOS ARM.** I did not test an interactive session left idle for more than 30 s, followed by a new LSP call. The probe in item 2 tested the same server path.

### Remaining

In order, on each of: Windows x64 (MSYS2 UCRT64), Windows ARM64 (MSYS2 CLANGARM64), macOS Intel (MacPorts). The owner is MACHINIST on that machine. Use a project that has a `compile_commands.json`, for example END after a build. The commands are for an MSYS2 shell on Windows and zsh on macOS.

1. **Tools.** Run `node --version` and `command -v clangd`. Pass: both print a value.
2. **Sync.** Run `cd ~/.carol && git pull`. Pass: `bin/carol-clangd.js` exists, and `.claude-plugin/plugin.json` has `"command": "node"`.
3. **Two parallel sessions.** From the project root, run the Completed item 4 command two times in parallel, with a header of that project. During the run, list the processes:
   - macOS: `ps -axo pid,ppid,command | grep -E "[c]langd|[c]arol-clangd"`
   - Windows: `powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { \$_.Name -in 'clangd.exe','node.exe' } | Select-Object ProcessId,ParentProcessId,CommandLine"`
   - Pass: both replies give the same symbol count, and exactly one clangd runs, whose parent is the `carol-clangd.js server` process.
   - On Windows, record whether Claude Code starts `node` by name. Also record whether Node starts `clangd` by name (the libuv lookup of `.exe`).
4. **Idle kill.** Start an interactive `claude --plugin-dir ~/.carol` in the project root. Ask for one LSP `documentSymbol` call. Wait 35 s and run the step 3 process command. Pass: the server runs and no clangd runs. Ask for a second LSP call. Pass: it returns symbols.
5. **No orphans.** With the step 4 session open after an LSP call, kill the server: `pkill -9 -f "carol-clangd.js server"` on macOS, or `taskkill //F //PID <server pid>` on Windows. Pass: no clangd remains after 5 s.
6. **Report.** Write the results of steps 1-5 for each machine into this file, under `Completed`, with command output.

### Key Decisions

- ARCHITECT: "we need more deterministic way to make it never ever bloat memory. 7GB per session is unacceptable. 2 sessions in parallel guaranteed my terminal frozen"
- ARCHITECT: "i mean why everything must be loaded into memory for the exact same read? this is fucking garbage. it doesnt matter 3gb, 7gb, all garbage. 3gb, 4 parallel agent already 12gb instantly without guarantee those instance killed"
- ARCHITECT, on the option list (one shared clangd per project with idle kill; one per session with idle kill; one per query): "1. timeout 30s"
- ARCHITECT: "must be crossplatform"
- ARCHITECT, on the plan for `bin/carol-clangd.js`, the plugin change, and this handoff: "go"
- ARCHITECT, 2026-11-02: "windows conformance should be written as handoff."
- ARCHITECT, on the unused lspmux 0.3.0 from Homebrew: "lspmux uninstalled."

### Files Modified
- `~/.carol/bin/carol-clangd.js` — new. The client and server modes described in Context.
- `~/.carol/.claude-plugin/plugin.json` — `lspServers.clangd` `command` is `node`, and `args` is `["${CLAUDE_PLUGIN_ROOT}/bin/carol-clangd.js", "client"]`. The clangd arguments moved into the script's `CLANGD_ARGS`.
- `~/.config/HANDOFF-clangd-sharing.md` — this file. It replaces the lspmux handoff of 2026-11-02.

### Open Questions

Each item is ARCHITECT's decision.

1. **nvim.** nvim still starts its own clangd (`~/.config/nvim/lua/lsp/clangd.lua`). Its arguments differ from `CLANGD_ARGS`. Should nvim connect through `carol-clangd.js client` too?
2. **Compile database per project.** This is open from the 2026-11-02 handoff. The framework `.clangd` points at the project that nvim loaded last (`~/.config/nvim/lua/core/clangd.lua`).

### Next Steps

- Trigger: ARCHITECT opens a MACHINIST session on a Windows machine or on the macOS Intel machine, and points it at this file.
- That session runs `Remaining` steps 1-6 on its machine.
- Sessions that were open before the change still use the old plugin entry. Each picks up `carol-clangd.js` when it starts again.
