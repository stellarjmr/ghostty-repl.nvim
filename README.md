# ghostty-repl.nvim

Send Python code from Neovim to an IPython REPL. A lightweight, zero-dependency alternative to [vim-slime](https://github.com/jpalardy/vim-slime) and [iron.nvim](https://github.com/Vigemus/iron.nvim), designed for Ghostty users but works in any terminal.

## Features

- Send current line, visual selection, code cell (`# %%` delimited), or entire file
- REPL runs in a Neovim terminal split via `chansend()` -- direct, reliable communication
- Multiline code sent using bracketed paste mode -- no clipboard interference
- Auto-detects conda Python environments with IPython
- Automatically changes working directory to match the current file
- Auto-closes REPL on Neovim exit
- Fully customizable keymaps, split direction, and split size

## Requirements

- **Neovim** >= 0.9
- **Python with IPython** installed (auto-detected from conda, or specify explicitly)

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "stellarjmr/ghostty-repl.nvim",
  ft = "python",
  opts = {},
}
```

### With custom configuration

```lua
{
  "stellarjmr/ghostty-repl.nvim",
  ft = "python",
  opts = {
    python_path = "~/conda/envs/myenv/bin/python",
    split_direction = "bottom",
    split_size = 15,
    keymaps = {
      send_cell = "<leader>sc",
      send_line = "<leader>sl",
      send_selection = "<leader>ss",
      send_file = "<leader>sf",
      close_repl = "<leader>rq",
    },
  },
}
```

## Configuration

All options with their defaults:

```lua
require("ghostty_repl").setup({
  -- Python executable path. nil = auto-detect from conda.
  python_path = nil,

  -- Base path to conda installation for auto-detection
  conda_base = "~/conda",

  -- Cell delimiter string used to identify code cells
  cell_delimiter = "# %%",

  -- Direction for the REPL split: "right" or "bottom"
  split_direction = "right",

  -- REPL window size: columns (right) or rows (bottom)
  split_size = 80,

  -- Keymaps (set any key to false to disable that binding)
  keymaps = {
    send_cell = "<leader>sc",
    send_line = "<leader>sl",
    send_selection = "<leader>ss",
    send_file = "<leader>sf",
    close_repl = "<leader>rq",
  },

  -- Automatically close the REPL on VimLeavePre
  auto_close_on_exit = true,
})
```

## Keymaps

| Key | Mode | Action |
|---|---|---|
| `<leader>sc` | Normal | Send current cell |
| `<leader>sl` | Normal | Send current line |
| `<leader>ss` | Visual | Send selection |
| `<leader>sf` | Normal | Send entire file |
| `<leader>rq` | Normal | Close REPL |

All keymaps can be customized or disabled (set to `false`) via the `keymaps` option.

## Commands

| Command | Description |
|---|---|
| `:GhosttyReplSend line` | Send current line to REPL |
| `:GhosttyReplSend cell` | Send current cell to REPL |
| `:GhosttyReplSend selection` | Send visual selection to REPL |
| `:GhosttyReplSend file` | Send entire file to REPL |
| `:GhosttyReplClose` | Close the REPL terminal |
| `:GhosttyReplFocus` | Focus the REPL terminal |

## Code Cells

Code cells are delimited by `# %%` comments (configurable via `cell_delimiter`):

```python
# %% Data loading
import pandas as pd
df = pd.read_csv("data.csv")

# %% Analysis
print(df.describe())
df.plot()
```

Press `<leader>sc` with the cursor in any cell to send just that cell to IPython.

## IPython Startup Configuration

For inline matplotlib display in terminals that support the kitty graphics protocol (Kitty, Ghostty), add startup scripts to `~/.config/ipython/profile_default/startup/`.

Create `kitty_matplotlib.py`:

```python
"""
Kitty/Ghostty inline image backend for matplotlib.

Overrides plt.show() to render figures directly inside terminals
that support the kitty graphics protocol or chafa for fallback.
"""

import os
import subprocess
import matplotlib.pyplot as plt

_original_show = plt.show
_CACHE_PATH = os.path.expanduser("~/.cache/kitty_matplotlib.png")
os.makedirs(os.path.dirname(_CACHE_PATH), exist_ok=True)


def kitty_show(*args, **kwargs):
    term = os.environ.get("TERM", "")
    in_kitty = term.startswith("xterm-kitty")
    in_ghostty = term == "xterm-ghostty"

    if not (in_kitty or in_ghostty):
        return _original_show(*args, **kwargs)

    fig = plt.gcf()
    if not fig.get_axes():
        return _original_show(*args, **kwargs)

    plt.savefig(_CACHE_PATH, dpi=150, bbox_inches="tight")

    if in_kitty:
        subprocess.run(["kitty", "+kitten", "icat", _CACHE_PATH])
    elif in_ghostty:
        columns = os.environ.get("COLUMNS")
        lines = os.environ.get("LINES")
        chafa_cmd = ["chafa"]
        if columns and lines:
            chafa_cmd.append(f"--size={columns}x{lines}")
        chafa_cmd.append(_CACHE_PATH)
        try:
            subprocess.run(chafa_cmd)
        except FileNotFoundError:
            return _original_show(*args, **kwargs)


def use_kitty_show():
    plt.show = kitty_show


def use_default_show():
    plt.show = _original_show
```

Then create `10-matplotlib.py` to load it on startup:

```python
from kitty_matplotlib import use_kitty_show
use_kitty_show()
print("[startup] Inline matplotlib backend loaded.")
```

## How It Works

1. When you first send code, the plugin auto-detects a Python environment with IPython
2. A Neovim terminal split is created running IPython, sized according to your config
3. Before each send, the REPL's working directory is synced to the current file's directory
4. Code is sent directly via `vim.fn.chansend()`:
   - Single lines are sent with a carriage return
   - Multiline blocks use bracketed paste mode (`ESC[200~...ESC[201~`) so IPython executes them as a single unit
5. The REPL is gracefully closed on `:GhosttyReplClose` or when Neovim exits

## License

MIT
