local M = {}

local config = require("ghostty_repl.config")

function M.get_line()
  return vim.api.nvim_get_current_line() .. "\n"
end

function M.get_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_row = start_pos[2]
  local start_col = start_pos[3]
  local end_row = end_pos[2]
  local end_col = end_pos[3]

  if start_row == 0 or end_row == 0 then
    return nil
  end

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  if #lines == 0 then
    return ""
  end

  lines[1] = string.sub(lines[1], start_col)
  lines[#lines] = string.sub(lines[#lines], 1, end_col)
  return table.concat(lines, "\n") .. "\n"
end

function M.get_cell()
  local delimiter = config.options.cell_delimiter
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
  local start_row = 1
  local end_row = #lines

  if vim.startswith(lines[cursor_row], delimiter) then
    start_row = cursor_row + 1
    for row = cursor_row + 1, #lines do
      if vim.startswith(lines[row], delimiter) then
        end_row = row - 1
        break
      end
    end
  else
    for row = cursor_row - 1, 1, -1 do
      if vim.startswith(lines[row], delimiter) then
        start_row = row + 1
        break
      end
    end

    for row = cursor_row + 1, #lines do
      if vim.startswith(lines[row], delimiter) then
        end_row = row - 1
        break
      end
    end
  end

  if end_row < start_row then
    return ""
  end

  return table.concat(vim.list_slice(lines, start_row, end_row), "\n") .. "\n"
end

function M.get_file()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  return table.concat(lines, "\n") .. "\n"
end

function M.get(kind)
  if kind == "line" then
    return M.get_line()
  elseif kind == "selection" then
    return M.get_selection()
  elseif kind == "cell" then
    return M.get_cell()
  elseif kind == "file" then
    return M.get_file()
  end
  return nil
end

return M
