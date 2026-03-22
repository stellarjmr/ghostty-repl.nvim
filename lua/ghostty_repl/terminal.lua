local M = {}

local config = require("ghostty_repl.config")

local state = {
  repl_id = nil,
  python = nil,
}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function run_osascript(script, args)
  local cmd = { "osascript", "-" }
  for _, arg in ipairs(args or {}) do
    table.insert(cmd, arg)
  end
  local output = vim.fn.system(cmd, script)
  local ok = vim.v.shell_error == 0
  return ok, trim(output)
end

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

function M.current_terminal_id()
  local ok, output = run_osascript([[
tell application "Ghostty"
  return id of focused terminal of selected tab of front window
end tell
]])
  if not ok or output == "" then
    return nil
  end
  return output
end

function M.terminal_exists(terminal_id)
  if not terminal_id or terminal_id == "" then
    return false
  end

  local ok, output = run_osascript([[
on run argv
  set targetId to item 1 of argv
  tell application "Ghostty"
    try
      set targetTerm to first terminal whose id is targetId
      return "1"
    on error
      return "0"
    end try
  end tell
end run
]], { terminal_id })
  return ok and output == "1"
end

function M.focus_terminal(terminal_id)
  if not terminal_id or terminal_id == "" then
    return false
  end
  return run_osascript([[
on run argv
  set targetId to item 1 of argv
  tell application "Ghostty"
    focus (first terminal whose id is targetId)
  end tell
end run
]], { terminal_id })
end

function M.close_terminal(terminal_id)
  if not terminal_id or terminal_id == "" then
    return false
  end
  return run_osascript([[
on run argv
  set targetId to item 1 of argv
  tell application "Ghostty"
    close (first terminal whose id is targetId)
  end tell
end run
]], { terminal_id })
end

function M.ensure_repl(source_terminal_id)
  if M.terminal_exists(state.repl_id) then
    return state.repl_id
  end

  if not source_terminal_id or source_terminal_id == "" then
    vim.notify("Ghostty source terminal is unavailable", vim.log.levels.ERROR)
    return nil
  end

  local python = detect_ipython_python()
  if not python then
    vim.notify("No Python with IPython found", vim.log.levels.ERROR)
    return nil
  end

  local cwd = vim.fn.expand("%:p:h")
  local init_text = "exec " .. vim.fn.shellescape(python) .. " -m IPython\n"

  local direction = config.options.split_direction
  if direction == "bottom" then
    direction = "down"
  end

  local ok, output = run_osascript([[
on run argv
  set sourceId to item 1 of argv
  set workingDir to item 2 of argv
  set initialInputValue to item 3 of argv
  set splitDir to item 4 of argv
  tell application "Ghostty"
    set cfg to new surface configuration
    set initial working directory of cfg to workingDir
    set initial input of cfg to initialInputValue
    set sourceTerm to first terminal whose id is sourceId
    if splitDir is "down" then
      set replTerm to split sourceTerm direction down with configuration cfg
    else
      set replTerm to split sourceTerm direction right with configuration cfg
    end if
    return id of replTerm
  end tell
end run
]], { source_terminal_id, cwd, init_text, direction })

  if not ok or output == "" then
    vim.notify("Failed to create Ghostty REPL split: " .. output, vim.log.levels.ERROR)
    return nil
  end

  state.repl_id = output
  M.focus_terminal(source_terminal_id)

  -- Resize the REPL pane
  local split_size = config.options.split_size
  if split_size > 0 then
    run_osascript([[
on run argv
  tell application "Ghostty"
    set t to first terminal whose id is (item 1 of argv)
    repeat ]] .. split_size .. [[ times
      send key "minus" modifiers "option" to t
    end repeat
  end tell
end run
]], { source_terminal_id })
  end

  return output
end

--- Send text to the REPL using bracketed paste mode.
--- Prepends os.chdir() to sync working directory atomically.
--- No clipboard involvement.
function M.send_text(source_id, repl_id, text, file_dir)
  -- Prepend os.chdir to sync working directory
  local payload = text
  if file_dir and file_dir ~= "" then
    local escaped_dir = file_dir:gsub("'", "\\'")
    payload = "import os; os.chdir('" .. escaped_dir .. "')\n" .. payload
  end

  -- Use bracketed paste via AppleScript input text.
  -- ESC[200~ starts bracketed paste, ESC[201~ ends it.
  -- IPython handles this natively and executes the block as one unit.
  local ok, err = run_osascript([[
on run argv
  set sourceId to item 1 of argv
  set replId to item 2 of argv
  set payload to item 3 of argv
  set escChar to ASCII character 27
  set bracketStart to escChar & "[200~"
  set bracketEnd to escChar & "[201~"
  tell application "Ghostty"
    set replTerm to first terminal whose id is replId
    input text (bracketStart & payload & bracketEnd) to replTerm
    send key "enter" to replTerm
    focus (first terminal whose id is sourceId)
  end tell
end run
]], { source_id, repl_id, payload })

  return ok, err
end

function M.exit_and_close_repl()
  local terminal_id = state.repl_id
  if not terminal_id or terminal_id == "" then
    return false
  end

  if not M.terminal_exists(terminal_id) then
    state.repl_id = nil
    return true
  end

  local source_id = M.current_terminal_id()

  run_osascript([[
on run argv
  set targetId to item 1 of argv
  tell application "Ghostty"
    set t to first terminal whose id is targetId
    input text "exit()" to t
    send key "enter" to t
  end tell
end run
]], { terminal_id })

  local exited = vim.wait(1500, function()
    return not M.terminal_exists(terminal_id)
  end, 50)

  if not exited then
    M.close_terminal(terminal_id)
  end

  state.repl_id = nil

  if source_id then
    M.focus_terminal(source_id)
  end

  return true
end

function M.get_repl_id()
  return state.repl_id
end

return M
