# ECHO — Equivalent Canonical Harmonic Operation

ECHO keeps multiple C++/JUCE frameworks' shared **kernel** byte-identical —
modulo namespace, file prefix, and company identity — without ever tracking
sync state. Equivalence is not assumed, remembered, or marked: it is **tested**,
any time, by rendering one framework into the other's vocabulary and running a
plain `git diff`. If the diff is empty, they are in sync. If it is not, the
diff *is* the drift, already expressed in the target's own vocabulary.

There is no daemon, no database, no bookkeeping, no manual porting. The whole
system is git + CMake: one engine, one identity file per framework, and a
handful of verb scripts in this directory.

```
~/.config/echo/
├── ech              zsh front-end — `ech <verb> <args>`
├── echo.cmake       the engine (table parser, identity loader, token transform)
├── frameworks.md    name → root registry (jam, kanjut, cium)
├── verify.cmake     read-only: are A and B in sync?
├── lint.cmake       read-only: is F consistent with its own declarations?
├── diff.cmake       read-only: show A→B delta as a readable patch
├── render.cmake     MUTATES B: generate module(s) of B from A
└── self-apply.cmake MUTATES F: rebrand F to its own edited identity.md
```

---

## The core idea

Each framework declares **who it is** in one file: `lexicon/identity.md` at its
root. Namespace (`jam` / `kuassa` / `iq`), file prefix (`jam_` / `kuassa_` /
`iq_`), macro prefix, company attributes, and — critically — which of its
modules are **kernel** (shared canon) and which are **provision**
(framework-private, never synced).

From any *pair* of identities, the engine derives an ordered, bijective token
map. `jam` ↔ `kuassa`, `jam_` ↔ `kuassa_`, `JAM_` ↔ `KUASSA_`,
`JamVulkanShaderData.h` ↔ `KuassaVulkanShaderData.h`, and so on — most-specific
token first, plain literal replacement with word-boundary awareness, no regex.
The map is never authored by hand; it always falls out of the two identity
files.

**Round-trip proof:** for every text file ECHO transforms, it checks that
`inverse(forward(file)) == file`. If a file contains tokens that would not
survive the round trip (e.g. a stray `kuassa` literal inside jam source), the
verb aborts with a fatal error naming the file. This is what makes the
transform trustworthy: it is bijective or it refuses.

Binary files (`.spv`, fonts, images) carry no tokens — they are copied
byte-for-byte.

---

## Quick start

```zsh
ech verify jam kanjut      # are jam and KANJUT kernels in sync?
ech lint jam               # is jam consistent with its own identity.md?
ech diff jam kanjut        # show the drift as a readable patch
ech render jam kanjut      # OVERWRITE KANJUT's kernel from jam (full kernel)
ech render jam kanjut jam_gui   # overwrite just one module
ech self-apply jam         # apply an identity.md edit to jam's own tree
```

`ech` with no arguments presents an interactive verb menu.

Framework arguments are either **names** resolved through `frameworks.md`
(`jam`, `kanjut`, `cium`) or **literal paths** — any argument containing `/`
is treated as a root path (`~` expands). That is how you target a sandbox
copy:

```zsh
ech render jam /tmp/echo-sandbox/___lib___
ech verify jam /tmp/echo-sandbox/___lib___
```

Every verb is a plain `cmake -P` script — `ech` is only a dispatcher:

```zsh
cmake -P ~/.config/echo/verify.cmake jam kanjut    # identical to `ech verify jam kanjut`
```

---

## identity.md — the one file each framework owns

Lives at `<framework-root>/lexicon/identity.md`. Markdown pipe tables — the
same table grammar as the lexicon system. Sections:

### `## Source Identity`
The code-level tokens: `namespace`, `filePrefix`, `macroPrefix`,
`moduleVendor`, optionally `namespaceShort` (e.g. KANJUT's `ku` — banned
inside kernel scope, allowed in provision/product code; lint enforces this).

### `## Product Identity`
Company attributes: `companyName`, `companyWebsite`, `bundleDomain`,
`manufacturerCode`, URLs, etc. CMake reads these from here — identity literals
in build scripts are a lint failure. Product identity is per-framework and is
**not** part of the cross-framework token map.

### `## Modules`
Every module, classed:

| class | meaning |
|---|---|
| `kernel` | shared canon — synced, compared, rendered |
| `provision` | framework-private — invisible to every cross-framework verb |

The kernel sets of two frameworks must correspond exactly (name-transformed);
`verify` fatals on any mismatch before comparing a single file.

### `## Module Pairs`
Canonical-name ↔ local-name mappings for modules whose names differ beyond the
prefix transform (e.g. `aquatic_prime` ↔ `juwita_malam`).

### `## Generated Headers`
Generated-file names that must transform as whole tokens
(`vulkanShaderData` → `JamVulkanShaderData.h` / `KuassaVulkanShaderData.h`).
Both sides must declare a row for the transform of that name to exist.

### `## Sync Ignore`
A fenced code block in gitignore grammar. Paths matching these patterns are
excluded from sync scope even inside kernel modules. Semantics: pattern
without `/` matches basename at any depth; pattern with `/` anchors at the
repo root; `**` crosses segments; `!` re-includes; last match wins. Typical
entries: per-framework vocabulary files (`lexicon/jam_*.md`), generated output
(`jam_lexicon/generated/**`), machine-path dependency files
(`jam_vulkan/spv/*.spv.d`), paired-but-private trees (`**/aquatic_prime/**`).

---

## The verbs

### `ech lint <F>` — one framework against itself (read-only)

Six checks, each fatal with file:line on failure:

1. `identity.md` parses (Source Identity, Product Identity, Modules present)
2. module classes coherent against the actual tree
3. Tier-1 identity-literal scan clean (no company literals outside identity.md)
4. Sync Ignore patterns are relative
5. `namespaceShort` alias (`ku::`) absent from kernel scope
6. register truth (declared tokens match reality)

Run this first, on each side, before any cross-framework verb.

### `ech verify <A> <B>` — are two frameworks in sync? (read-only)

1. Loads both identities; fatals if kernel module sets don't correspond.
2. Scope = `git ls-files` (tracked ∪ untracked-not-ignored) under each kernel module ∩ not Sync-Ignored.
3. Exports A into a temp tree, transforming **paths and content** A→B
   (round-trip enforced per file); exports B raw.
4. `git diff --no-index` between the two temp trees.

Empty diff → `✓ in sync`. Non-empty → `--stat` summary + fatal. A red verify
is a **measurement, not a failure** — it tells you exactly what drifted.

> **Scope is tracked ∪ untracked-not-ignored.** A freshly rendered file is
> visible to B's scope without staging, as long as it isn't matched by a
> Sync Ignore pattern — no `git add` needed before verifying.

### `ech diff <A> <B>` — the drift, readable (read-only)

Same machinery as verify, but outputs the actual patch instead of pass/fail.
The delta is expressed in **B's vocabulary** — one `git apply` away from
convergence.

### `ech render <A> <B> [module]` — generate B from A (MUTATES B)

The mutation verb. Two modes:

- **Full kernel** (no module argument): every kernel module of A is
  transformed and written into B. Each target module directory in B is
  deleted and replaced wholesale.
- **Single module** (`ech render jam kanjut jam_gui`): just that module. The
  module must be kernel-classed in A.

Before writing anything, render runs a **dependency-closure gate**: every
`#include` in scope that points under a declared A-module directory must
resolve to a kernel-classed module. One provision include inside kernel scope
and render refuses — all violations listed with file:line, **zero files
written**. Promotion is fully mechanical or loudly refused; there is no
half-render.

The round-trip check runs per file during export, same as verify.

Direction matters: `render A B` reads A, writes B. It also works in reverse
(`ech render kanjut jam kuassa_dsp` absorbs a KANJUT module into jam).

### `ech self-apply <F>` — rebrand a framework in place (MUTATES F)

For when a framework's **own** identity changes (rename, new prefix, changed
vendor string). Compares the committed `lexicon/identity.md` at `HEAD` with
the edited working-tree copy; if Source Identity / Module Pairs / Generated
Headers changed, transforms the whole tree old→new — contents and filenames —
with the same refusal gate and round-trip proof. `✓ nothing to apply` when
the identity is unchanged.

Workflow: edit `lexicon/identity.md`, run `ech self-apply F`, review, commit.

### `ech apply` — not yet implemented

Listed in the front-end, script pending. Will transform a git patch from A's
vocabulary to B's and `git apply --3way` it — targeted fix propagation
without a full render.

---

## Typical workflows

**Health check (any time):**
```zsh
ech lint jam && ech lint kanjut && ech verify jam kanjut
```

**Preview a render without touching the live target (sandbox rehearsal):**
```zsh
cp -R ~/Documents/Poems/kuassa/___lib___ /tmp/echo-sandbox/___lib___
ech render jam /tmp/echo-sandbox/___lib___
ech verify jam /tmp/echo-sandbox/___lib___           # must be green
git diff --no-index ~/Documents/Poems/kuassa/___lib___ /tmp/echo-sandbox/___lib___
```
The last diff is the exact change a live render would make.

**Absorb a module from another framework (reverse render):**
```zsh
# 1. class the module `kernel` in the source framework's identity.md
# 2. render it across:
ech render kanjut jam kuassa_dsp
```

**Bootstrap a whole framework:** author its `lexicon/identity.md`, then
`ech render jam <path>` — the entire kernel arrives by construction.

---

## Safety model

- `lint`, `verify`, `diff` are **read-only** — temp trees under
  `$TMPDIR/echo/`, live repos never written.
- `render` and `self-apply` mutate, but refuse **before** the first byte is
  written when the closure gate or round-trip proof fails.
- ECHO never runs `git add`, `git commit`, or `git push`. It reads git
  (`ls-files`, `show`, `diff --no-index`) only. Staging and committing render
  output is always a human act.
- Provision modules and Sync-Ignored paths are untouchable by construction —
  they are simply outside every verb's scope.

---

## Errors you will actually see

| message | meaning | fix |
|---|---|---|
| `kernel module sets diverge` | A's kernel list ≠ B's (transformed) | align the `## Modules` tables |
| `dependency closure violated, zero files written` | kernel code includes a provision module | promote the dependency or decouple it |
| round-trip mismatch (fatal naming a file) | file contains the *other* framework's tokens | remove the contaminating literal |
| `out of sync` + `--stat` | verify found drift | read it — that's the census; render or fix, then re-verify |
| pure deletions for files you just rendered | rendered path matches a Sync Ignore pattern — still invisible regardless of staging | adjust the Sync Ignore pattern if the path should be in scope |
| `resolved root does not exist` | bad name/path argument | check `frameworks.md` or the literal path |

---

## Design invariants (why it works)

- **One engine** (`echo.cmake`) owns all table parsing and the transform; the
  verbs are thin scripts that only call engine API. No inline regex anywhere.
- **Identity is declared once** per framework and derived everywhere else —
  the token map is computed, never authored.
- **Sync state is never stored** — no markers, no timestamps, no manifest of
  "what was synced." The only truth is the byte-diff, recomputed on demand.
- **Bijective or refused** — every transform must round-trip, every render
  must close its dependencies, or nothing happens at all.
