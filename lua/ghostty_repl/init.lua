local M = {}

local config = require("ghostty_repl.config")
local terminal = require("ghostty_repl.terminal")
local text = require("ghostty_repl.text")

function M.send(kind)
  local code = text.get(kind)
  if code == nil then
    vim.notify("Unsupported send kind: " .. kind, vim.log.levels.ERROR)
    return
  end

  local chan_id = terminal.ensure_repl()
  if chan_id == nil then
    return
  end

  -- Change to the current file's directory before sending code
  local file_dir = vim.fn.expand("%:p:h")
  if file_dir ~= "" then
    terminal.change_dir(file_dir)
  end

  if not terminal.send(code) then
    vim.notify("Failed to send text to REPL", vim.log.levels.ERROR)
  end
end

function M.close()
  terminal.close()
end

function M.focus()
  if not terminal.focus() then
    vim.notify("No active REPL", vim.log.levels.WARN)
  end
end

function M.setup(opts)
  config.setup(opts)

  vim.api.nvim_create_user_command("GhosttyReplSend", function(cmd_opts)
    M.send(cmd_opts.args)
  end, {
    nargs = 1,
    complete = function()
      return { "line", "cell", "selection", "file" }
    end,
    desc = "Send code to IPython REPL",
  })

  vim.api.nvim_create_user_command("GhosttyReplClose", function()
    M.close()
  end, { desc = "Close IPython REPL" })

  vim.api.nvim_create_user_command("GhosttyReplFocus", function()
    M.focus()
  end, { desc = "Focus IPython REPL" })

  local km = config.options.keymaps
  if km.send_cell then
    vim.keymap.set("n", km.send_cell, function()
      M.send("cell")
    end, { desc = "Send Cell", silent = true })
  end
  if km.send_line then
    vim.keymap.set("n", km.send_line, function()
      M.send("line")
    end, { desc = "Send Line", silent = true })
  end
  if km.send_selection then
    vim.keymap.set("x", km.send_selection, function()
      M.send("selection")
    end, { desc = "Send Selection", silent = true })
  end
  if km.send_file then
    vim.keymap.set("n", km.send_file, function()
      M.send("file")
    end, { desc = "Send File", silent = true })
  end
  if km.close_repl then
    vim.keymap.set("n", km.close_repl, function()
      M.close()
    end, { desc = "Close REPL", silent = true })
  end

  if config.options.auto_close_on_exit then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        terminal.close()
      end,
    })
  end

  vim.g.slime_cell_delimiter = config.options.cell_delimiter
end

return M
