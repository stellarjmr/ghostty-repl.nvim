# Repository Guidelines

## Project Structure & Module Organization
- Core logic lives in `lua/ghostty_repl/`: `init.lua` wires commands/keymaps/autocmds, `terminal.lua` handles all AppleScript/Ghostty interaction, `text.lua` extracts code from buffers, and `config.lua` merges user options with defaults.
- Neovim plugin entrypoint is `plugin/ghostty_repl.lua` (loaded by runtimepath); it contains only a load guard.
- macOS only; all terminal interaction uses `osascript` to control Ghostty via AppleScript.
- Zero external dependencies. Uses bracketed paste mode for multiline code (no clipboard interference).

## Build, Test, and Development Commands
- No compile step; edit Lua files directly. Neovim loads `plugin/ghostty_repl.lua` automatically when the plugin is on the `runtimepath`.
- Quick manual check: open a Python file with `# %%` cells in Ghostty, call `:GhosttyReplSend cell` or press `<leader>sc` to verify REPL split creation and code sending.
- Test all send modes: line, cell, selection, file. Multiline code uses bracketed paste via AppleScript `input text`.
- Test REPL lifecycle: creation, reuse across sends, close via `:GhosttyReplClose`, auto-close on VimLeavePre.
- Test working directory sync: open files in different directories, send code, verify `os.getcwd()` in IPython.
- Test custom config: explicit `python_path`, `split_direction = "bottom"`, custom `split_size`, disabled keymaps.

## Coding Style & Naming Conventions
- Lua files use 2-space indentation, snake_case identifiers, and descriptive table keys (`cell_delimiter`, `split_direction`). Keep modules local-scoped unless part of the public API.
- Side effects (osascript calls, autocmds, keymaps) belong in `terminal.lua` and `init.lua`. Pure text extraction stays in `text.lua` with no system calls.
- Defaults live in `config.lua`; override via `setup()` options rather than hard-coding.
- Run `stylua` if available to format Lua; otherwise mirror surrounding formatting.

## Testing Guidelines
- No automated test harness; rely on manual validation in Ghostty on macOS.
- When changing AppleScript templates or terminal interaction, test REPL lifecycle: creation, reuse, close, and auto-close on exit.
- When changing text extraction, verify edge cases: empty cells, cursor on delimiter, single-line vs multiline, visual selection.
- Verify working directory changes: open files in different directories, send code, confirm `os.getcwd()` in IPython matches.

## Commit & Pull Request Guidelines
- Follow Conventional Commit style (e.g., `feat: ...`, `fix: ...`, `chore: ...`).
- Keep PRs focused. Update `README.md` when commands, defaults, or keymaps change.
- Include brief description of behavior changes and any compatibility notes (macOS version, Ghostty version).
