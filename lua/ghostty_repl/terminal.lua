local M = {}

local config = require("ghostty_repl.config")

local state = {
  bufnr = nil,
  chan_id = nil,
  python = nil,
}

local function cmd_ok(argv)
  vim.fn.system(argv)
  return vim.v.shell_error == 0
end

local function detect_ipython_python()
  if state.python then
    return state.python
  end

  local opts = config.options

  if opts.python_path then
    local py = vim.fn.expand(opts.python_path)
    if vim.fn.executable(py) == 1 and cmd_ok({ py, "-c", "import IPython" }) then
      state.python = py
      return py
    end
    return nil
  end

  local conda_base = vim.fn.expand(opts.conda_base)
  local candidates = { conda_base .. "/bin/python" }
  local envs_dir = conda_base .. "/envs"

  if vim.fn.isdirectory(envs_dir) == 1 then
    for _, name in ipairs(vim.fn.readdir(envs_dir)) do
      table.insert(candidates, envs_dir .. "/" .. name .. "/bin/python")
    end
  end

  for _, py in ipairs(candidates) do
    if vim.fn.executable(py) == 1 and cmd_ok({ py, "-c", "import IPython" }) then
      state.python = py
      return py
    end
  end

  return nil
end

function M.is_alive()
  if not state.chan_id then
    return false
  end
  local result = vim.fn.jobwait({ state.chan_id }, 0)
  -- jobwait returns -1 if job is still running
  return result[1] == -1
end

function M.get_repl_win()
  if not state.bufnr or not vim.api.nvim_buf_is_valid(state.bufnr) then
    return nil
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == state.bufnr then
      return win
    end
  end
  return nil
end

function M.ensure_repl()
  if M.is_alive() then
    return state.chan_id
  end

  local python = detect_ipython_python()
  if not python then
    vim.notify("No Python with IPython found", vim.log.levels.ERROR)
    return nil
  end

  local file_dir = vim.fn.expand("%:p:h")
  local src_win = vim.api.nvim_get_current_win()

  -- Create split
  local direction = config.options.split_direction
  local size = config.options.split_size
  if direction == "bottom" then
    vim.cmd("botright " .. size .. "split")
  else
    vim.cmd("botright " .. size .. "vsplit")
  end

  -- Start IPython in the new split
  local cmd = python .. " -m IPython"
  if file_dir ~= "" then
    cmd = "cd " .. vim.fn.shellescape(file_dir) .. " && " .. cmd
  end

  local chan_id = vim.fn.termopen(cmd, {
    on_exit = function()
      state.bufnr = nil
      state.chan_id = nil
    end,
  })

  if chan_id <= 0 then
    vim.notify("Failed to start IPython", vim.log.levels.ERROR)
    vim.cmd("close")
    return nil
  end

  state.bufnr = vim.api.nvim_get_current_buf()
  state.chan_id = chan_id

  -- Return focus to the source window
  vim.api.nvim_set_current_win(src_win)

  return chan_id
end

function M.send(text)
  if not M.is_alive() then
    return false
  end

  -- Count non-empty lines to detect multiline
  local line_count = 0
  for line in text:gmatch("[^\n]+") do
    if line:match("%S") then
      line_count = line_count + 1
    end
  end

  if line_count > 1 then
    -- Bracketed paste mode: IPython treats entire block as one input
    local payload = "\x1b[200~" .. text .. "\x1b[201~"
    vim.fn.chansend(state.chan_id, payload)
    -- Send enter after bracketed paste to execute
    vim.fn.chansend(state.chan_id, "\r")
  else
    -- Single line: strip trailing newline and send with CR
    local line = text:gsub("\n+$", "")
    vim.fn.chansend(state.chan_id, line .. "\r")
  end

  return true
end

function M.change_dir(dir)
  if not M.is_alive() or not dir or dir == "" then
    return
  end
  -- Use Python os.chdir to avoid IPython %cd output noise
  local escaped = dir:gsub("'", "\\'")
  vim.fn.chansend(state.chan_id, "import os; os.chdir('" .. escaped .. "')\r")
end

function M.close()
  if not M.is_alive() then
    state.bufnr = nil
    state.chan_id = nil
    return
  end

  vim.fn.chansend(state.chan_id, "exit()\r")

  -- Wait for IPython to exit
  local exited = vim.wait(1500, function()
    return not M.is_alive()
  end, 50)

  if not exited and state.chan_id then
    pcall(vim.fn.jobstop, state.chan_id)
  end

  -- Close the REPL window if it's still open
  local win = M.get_repl_win()
  if win then
    pcall(vim.api.nvim_win_close, win, true)
  end

  -- Delete the buffer
  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    pcall(vim.api.nvim_buf_delete, state.bufnr, { force = true })
  end

  state.bufnr = nil
  state.chan_id = nil
end

function M.focus()
  local win = M.get_repl_win()
  if win then
    vim.api.nvim_set_current_win(win)
    return true
  end
  return false
end

return M
