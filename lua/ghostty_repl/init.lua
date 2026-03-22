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

  local source_id = terminal.current_terminal_id()
  if source_id == nil then
    vim.notify("Could not determine the focused Ghostty terminal", vim.log.levels.ERROR)
    return
  end

  local repl_id = terminal.ensure_repl(source_id)
  if repl_id == nil then
    return
  end

  local ok, err = terminal.send_text_and_refocus(source_id, repl_id, code)
  if not ok then
    vim.notify("Failed to send text to Ghostty REPL: " .. (err or ""), vim.log.levels.ERROR)
  end
end

function M.close()
  terminal.exit_and_close_repl()
end

function M.focus()
  local repl_id = terminal.get_repl_id()
  if repl_id and terminal.terminal_exists(repl_id) then
    terminal.focus_terminal(repl_id)
  else
    vim.notify("No active Ghostty REPL", vim.log.levels.WARN)
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
    desc = "Send code to Ghostty IPython REPL",
  })

  vim.api.nvim_create_user_command("GhosttyReplClose", function()
    M.close()
  end, { desc = "Close Ghostty IPython REPL" })

  vim.api.nvim_create_user_command("GhosttyReplFocus", function()
    M.focus()
  end, { desc = "Focus Ghostty IPython REPL" })

  local km = config.options.keymaps
  if km.send_cell then
    vim.keymap.set("n", km.send_cell, function()
      M.send("cell")
    end, { desc = "Ghostty Send Cell", silent = true })
  end
  if km.send_line then
    vim.keymap.set("n", km.send_line, function()
      M.send("line")
    end, { desc = "Ghostty Send Line", silent = true })
  end
  if km.send_selection then
    vim.keymap.set("x", km.send_selection, function()
      M.send("selection")
    end, { desc = "Ghostty Send Selection", silent = true })
  end
  if km.send_file then
    vim.keymap.set("n", km.send_file, function()
      M.send("file")
    end, { desc = "Ghostty Send File", silent = true })
  end
  if km.close_repl then
    vim.keymap.set("n", km.close_repl, function()
      M.close()
    end, { desc = "Close Ghostty REPL", silent = true })
  end

  if config.options.auto_close_on_exit then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        terminal.exit_and_close_repl()
      end,
    })
  end

  vim.g.slime_cell_delimiter = config.options.cell_delimiter
end

return M
