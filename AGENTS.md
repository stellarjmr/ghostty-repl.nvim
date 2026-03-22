# Repository Guidelines

## Project Structure & Module Organization
- Core logic lives in `lua/ghostty_repl/`: `init.lua` wires commands/keymaps/autocmds, `terminal.lua` manages the Neovim terminal REPL via `chansend()`, `text.lua` extracts code from buffers, and `config.lua` merges user options with defaults.
- Neovim plugin entrypoint is `plugin/ghostty_repl.lua` (loaded by runtimepath); it contains only a load guard.
- Zero external dependencies. Uses Neovim's built-in terminal API (`termopen`, `chansend`, `jobstop`) for all REPL communication.
- Multiline code is sent using bracketed paste mode escape sequences, which IPython handles natively.

## Build, Test, and Development Commands
- No compile step; edit Lua files directly. Neovim loads `plugin/ghostty_repl.lua` automatically when the plugin is on the `runtimepath`.
- Quick manual check: open a Python file with `# %%` cells, call `:GhosttyReplSend cell` or press `<leader>sc` to verify REPL split creation and code sending.
- Test all send modes: line, cell, selection, file. Multiline code should execute as a single block via bracketed paste.
- Test REPL lifecycle: creation, reuse across sends, close via `:GhosttyReplClose`, auto-close on VimLeavePre.
- Test custom config: explicit `python_path`, `split_direction = "bottom"`, custom `split_size`, disabled keymaps.

## Coding Style & Naming Conventions
- Lua files use 2-space indentation, snake_case identifiers, and descriptive table keys (`cell_delimiter`, `split_direction`). Keep modules local-scoped unless part of the public API.
- Side effects (terminal creation, autocmds, keymaps) belong in `terminal.lua` and `init.lua`. Pure text extraction stays in `text.lua` with no system calls.
- Defaults live in `config.lua`; override via `setup()` options rather than hard-coding.
- Run `stylua` if available to format Lua; otherwise mirror surrounding formatting.

## Testing Guidelines
- No automated test harness; rely on manual validation in Neovim.
- When changing terminal interaction, test REPL lifecycle: creation, reuse, close, auto-close on exit.
- When changing text extraction, verify edge cases: empty cells, cursor on delimiter, single-line vs multiline, visual selection across partial lines.
- Verify working directory changes: open files in different directories, send code, confirm `os.getcwd()` in IPython matches the file's directory.

## Commit & Pull Request Guidelines
- Follow Conventional Commit style (e.g., `feat: ...`, `fix: ...`, `chore: ...`).
- Keep PRs focused. Update `README.md` when commands, defaults, or keymaps change.
- Include brief description of behavior changes and any compatibility notes (Neovim version requirements).
