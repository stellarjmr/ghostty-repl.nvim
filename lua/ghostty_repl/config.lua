local M = {}

M.defaults = {
  -- Python executable path. nil = auto-detect from conda.
  python_path = nil,

  -- Base path to conda installation for auto-detection
  conda_base = vim.fn.expand("~/conda"),

  -- Cell delimiter string used to identify code cells
  cell_delimiter = "# %%",

  -- Direction for the REPL split: "right" or "bottom"
  split_direction = "right",

  -- REPL window size: columns (right) or rows (bottom)
  split_size = 80,

  -- Keymaps (set a key to false to disable that binding)
  keymaps = {
    send_cell = "<leader>sc",
    send_line = "<leader>sl",
    send_selection = "<leader>ss",
    send_file = "<leader>sf",
    close_repl = "<leader>rq",
  },

  -- Automatically close the REPL on VimLeavePre
  auto_close_on_exit = true,
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
