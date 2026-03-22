# ghostty-repl.nvim

Send Python code from Neovim to an IPython REPL running in a [Ghostty](https://ghostty.org) terminal split. A lightweight, zero-dependency alternative to [vim-slime](https://github.com/jpalardy/vim-slime) and [iron.nvim](https://github.com/Vigemus/iron.nvim) for Ghostty users on macOS.

## Features

- Send current line, visual selection, code cell (`# %%` delimited), or entire file
- Auto-creates an IPython split in Ghostty with configurable direction and size
- Multiline code sent via `%paste` (pbcopy) for correct execution
- Auto-detects conda Python environments with IPython
- Auto-closes REPL on Neovim exit
- Fully customizable keymaps with option to disable any binding

## Requirements

- **macOS** (uses AppleScript via `osascript` for Ghostty automation)
- **[Ghostty](https://ghostty.org)** terminal emulator
- **Python with IPython** installed (auto-detected from conda, or specify explicitly)

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "stellarjmr/ghostty-repl.nvim",
  enabled = vim.fn.has("mac") == 1,
  ft = "python",
  opts = {},
}
```

### With custom configuration

```lua
{
  "stellarjmr/ghostty-repl.nvim",
  enabled = vim.fn.has("mac") == 1,
  ft = "python",
  opts = {
    python_path = "~/conda/envs/myenv/bin/python",
    split_direction = "bottom",
    split_size = 30,
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

  -- Direction for the Ghostty split: "right" or "bottom"
  split_direction = "right",

  -- Number of resize keystrokes to shrink the REPL pane (~30% at 40)
  split_size = 40,

  -- Keymaps (set any key to false to disable that binding)
  keymaps = {
    send_cell = "<leader>sc",
    send_line = "<leader>sl",
    send_selection = "<leader>ss",
    send_file = "<leader>sf",
    close_repl = "<leader>rq",
  },

  -- Automatically close the REPL split on VimLeavePre
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

For inline matplotlib display in Ghostty, you can add a startup script to `~/.config/ipython/profile_default/startup/`. Create a file like `10-matplotlib.py`:

```python
from kitty_matplotlib import use_kitty_show
use_kitty_show()
print("[startup] Inline matplotlib backend loaded.")
```

And the corresponding `kitty_matplotlib.py` module in the same directory:

```python
"""
Kitty/Ghostty inline image backend for matplotlib.

Overrides plt.show() to render figures directly inside Kitty or Ghostty
terminals. Uses kitty +kitten icat for Kitty and chafa for Ghostty.
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

## How It Works

1. When you first send code, the plugin detects the current Ghostty terminal via AppleScript
2. It auto-detects a Python environment with IPython installed (from conda or a configured path)
3. A new Ghostty split is created running IPython, resized to ~30% width
4. Code is sent to the REPL: single lines via direct text input, multiline blocks via `pbcopy` + IPython's `%paste` magic
5. Focus returns to your editor terminal after each send
6. The REPL is gracefully closed on `:GhosttyReplClose` or when Neovim exits

## License

MIT
