# Removed Non-Nix Binaries → Re-add via Nix

Binaries that were installed **outside Nix** (rustup, manual installers, standalone
scripts) and removed on 2026-06-07 to keep the system purely Nix-provided. This is
the worklist for re-adding the ones we still want through `home/packages.nix`.

Goal: anything we depend on should come from Nix so it's declarative and
reproducible. Add the package to `home.packages` in `home/packages.nix`, then
`home-manager switch`.

---

## Removed — replace via Nix `home.packages` ✅ DONE

| Binary | Was at | Nix package | Notes |
|---|---|---|---|
| `ffmpeg` | `~/.local/bin/ffmpeg` (21 MB) | `ffmpeg` | added to Nix ✅ (yazi preview deps group) |
| `chafa` | `/usr/local/bin/chafa` | `chafa` | added to Nix ✅ (yazi preview deps group) |

Both are now in `home/packages.nix` under the "yazi preview dependencies" group.

---

## Removed — rustup toolchain (Rust now comes from Nix)

Removed `~/.rustup` and `~/.cargo` (~2.8 GB). Rust core (`rustc`, `cargo`,
`rustfmt`, `clippy`, `rust-analyzer`) is **already** declared in `packages.nix`,
so nothing to do for those.

But these **cargo-installed crates** are now gone and have no Nix equivalent yet.
Re-add the ones you still use:

| Crate (was in `~/.cargo/bin`) | Nix package | Keep? |
|---|---|---|
| `cargo-audit` | `cargo-audit` | security audits |
| `cargo-watch` | `cargo-watch` | rebuild-on-change |
| `trunk` | `trunk` | WASM web bundler |
| `wasm-pack` | `wasm-pack` | WASM packaging |
| `create-tauri-app` | `cargo-create-tauri-app` | Tauri scaffolding |
| `ripgrep` (`rg`) | `ripgrep` | already in Nix ✅ |
| `mini-redis` | — | tutorial crate, skip |

```nix
# home/packages.nix — add a "rust dev tools" group if you want these back:
cargo-audit
cargo-watch
trunk
wasm-pack
cargo-create-tauri-app
```

---

## Removed — redundant standalone installs (Nix already provides these)

| Binary | Was at | Already in Nix |
|---|---|---|
| `uv` | `~/.local/bin/uv` (48 MB) | yes — `uv` in packages.nix ✅ |
| `uvx` | `~/.local/bin/uvx` | yes — ships with `uv` ✅ |

No action needed — these were duplicates shadowed/superseded by the Nix copies in
`~/.nix-profile/bin`.

---

## Removed — manual `/usr/local` installers (2026-06-07)

| What | Was at | Nix package(s) to re-add | Notes |
|---|---|---|---|
| **Vulkan / shader SDK** | `/usr/local/{bin,lib,include,share}` (~35 bins) | `vulkan-tools`, `vulkan-loader`, `vulkan-validation-layers`, `shaderc`, `spirv-tools`, `glslang`, `shader-slang`, `directx-shader-compiler`, `spirv-cross`, `glm`, `gfxreconstruct`, `moltenvk` | `glslc`/`glslang`/`spirv-*`/`slang*`/`dxc`/`vulkaninfo`/`vkconfig`/`gfxrecon-*`/`MoltenVKShaderConverter` |
| **TeXLive 2025** | `/usr/local/texlive` | `texliveMedium` (or `texliveFull`) | also have MacTeX.app; multi-GB if re-added |
| **`lldb-mi`** | `~/.local/bin/lldb-mi` → `~/git/lldb-mi` | (none — local build) | only the PATH symlink removed; source repo `~/git/lldb-mi` kept |

```nix
# home/packages.nix — if you want the Vulkan/shader toolchain back via Nix:
vulkan-tools          # vulkaninfo, vkcube
vulkan-loader
vulkan-validation-layers
shaderc               # glslc
glslang               # glslangValidator
spirv-tools           # spirv-* (opt/dis/val/...)
spirv-cross
shader-slang          # slangc/slangd
directx-shader-compiler  # dxc
glm
# moltenvk / gfxreconstruct as needed
```

---

## Removed — Homebrew formulae (Homebrew itself uninstalled)

Homebrew is gone (`/opt/homebrew` and `/usr/local/Cellar` both absent; `brew` no
longer on PATH). Reconstructed from shell history — these were `brew install`ed
and went away with it. Several are **yazi preview dependencies**, so re-add those
together or file previews break (chafa/ffmpeg are already tracked at the top).

| Formula | Nix package | Keep? / Notes |
|---|---|---|
| `coreutils` | `coreutils` | already in Nix ✅ |
| `fzf` | (via `programs.fzf`) | already in Nix ✅ |
| `zoxide` | (via `programs.zoxide`) | already in Nix ✅ |
| `fd` | `fd` | already in Nix ✅ |
| `ripgrep` | `ripgrep` | already in Nix ✅ |
| `yazi` | (own program module) | already in Nix ✅ |
| `ffmpeg` / `ffmpeg-full` | `ffmpeg` | added to Nix ✅ (yazi video previews) |
| `jq` | `jq` | added to Nix ✅ |
| `poppler` | `poppler-utils` | added to Nix ✅ (yazi PDF previews, `pdftoppm`) |
| `sevenzip` | `_7zz` | added to Nix ✅ (yazi archive previews, `7zz`) |
| `resvg` | `resvg` | added to Nix ✅ (yazi SVG previews) |
| `imagemagick-full` | `imagemagick` | added to Nix ✅ (yazi image previews / `convert`) |
| `font-symbols-only-nerd-font` | `nerd-fonts.symbols-only` | added to Nix ✅ (prompt/yazi glyphs) |
| `llvm` | `llvm` | extra LLVM tools (have `clang`/`clang-tools`); add only if needed |
| `copilot-cli` | `github-copilot-cli` | GitHub Copilot CLI; skip unless still used |
| `chmlib` | `chmlib` | CHM reader lib; niche, skip unless needed |
| `tmuxpack/tpack/tpack` | — | tap-only tmux plugin manager; no Nix pkg, skip |

The yazi previewer deps are now in `home/packages.nix` (group "yazi preview
dependencies"): `ffmpeg`, `jq`, `poppler-utils`, `_7zz`, `resvg`, `imagemagick`,
`chafa`, `nerd-fonts.symbols-only`. ✅

Still optional, add individually only if you still use them: `llvm`,
`github-copilot-cli`, `chmlib`.

---

## NOT removed — kept outside Nix on purpose

- **`claude`** (`~/.local/bin/claude`) — Claude Code CLI. **Kept out of Nix
  deliberately.** Why: under Nix the binary lives in the read-only `/nix/store`,
  so Claude Code's built-in auto-updater **cannot write to it and disables
  itself**. Updating would then require `nix flake update` + `home-manager
  switch`, and nixpkgs lags the official release by days–weeks. The native
  installer keeps Claude Code self-updating to the latest version instantly,
  which is the better tradeoff for a fast-moving tool. If you ever prefer fully
  declarative pinning over instant updates, switch to `pkgs.claude-code` and
  accept manual version bumps.

> General rule this illustrates: tools whose value depends on frequent
> self-updates (and that aren't config-critical) are often better left on their
> native installer even on an otherwise all-Nix setup.

---

_Removal log: rustup (`~/.rustup`, `~/.cargo`), `ffmpeg`, `uv`, `uvx` removed
2026-06-07. Vulkan/shader SDK, `chafa`, TeXLive 2025 removed 2026-06-07 (root-owned,
required `sudo`). `lldb-mi` PATH symlink removed (source repo kept). Homebrew
uninstalled (formulae incl. yazi preview deps: `jq`, `poppler`, `sevenzip`,
`resvg`, `imagemagick-full`, nerd-font symbols). `claude` kept._
