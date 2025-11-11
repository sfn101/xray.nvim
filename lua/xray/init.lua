local M = {}

local state = require("xray.state")
local config = require("xray.config")

-- Focus mode state
local focus_mode = false
local focus_autocmd = nil
local focus_ns_vtext = vim.api.nvim_create_namespace("xray_focus_vtext")
local focus_ns_vline = vim.api.nvim_create_namespace("xray_focus_vline")

-- Severity name mapping
local severity_names = {
  [vim.diagnostic.severity.ERROR] = "Error",
  [vim.diagnostic.severity.WARN] = "Warn",
  [vim.diagnostic.severity.INFO] = "Info",
  [vim.diagnostic.severity.HINT] = "Hint",
}

-- Update diagnostic display based on current state
local function update_display()
  local text_severities = {}
  local line_severities = {}

  -- Build arrays based on each severity's mode and enabled state
  for severity, is_text_mode in pairs(state.severity_modes) do
    if state.severity_enabled[severity] then
      if is_text_mode then
        table.insert(text_severities, severity)
      else
        table.insert(line_severities, severity)
      end
    end
  end

  -- Get current config to preserve signs and other settings
  local current_config = vim.diagnostic.config()

  vim.diagnostic.config({
    underline = current_config.underline ~= false,
    signs = current_config.signs, -- Preserve existing signs config (icons from LazyVim)
    virtual_text = #text_severities > 0 and {
      severity = text_severities,
    } or false,
    virtual_lines = #line_severities > 0 and {
      severity = line_severities,
    } or false,
  })

  -- Refresh diagnostics for all buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      vim.diagnostic.hide(nil, bufnr)
      vim.diagnostic.show(nil, bufnr)
    end
  end
end

-- Focus mode: Show virtual text/lines only on current line using extmarks
local function update_focus_diagnostics()
  if not focus_mode then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1

  -- Clear previous extmarks from ALL buffers to prevent stuck diagnostics
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      vim.api.nvim_buf_clear_namespace(buf, focus_ns_vtext, 0, -1)
      vim.api.nvim_buf_clear_namespace(buf, focus_ns_vline, 0, -1)
      -- CRITICAL: Clear diagnostics shown via vim.diagnostic.show()
      vim.diagnostic.hide(focus_ns_vtext, buf)
      vim.diagnostic.hide(focus_ns_vline, buf)
    end
  end

  -- Get current config to preserve signs and other settings
  local current_config = vim.diagnostic.config()

  -- Configure to keep signs and underlines, but hide virtual text/lines
  vim.diagnostic.config({
    underline = current_config.underline ~= false,
    signs = current_config.signs, -- Preserve existing signs config (icons from LazyVim)
    virtual_text = false,
    virtual_lines = false,
  })

  local last_line = vim.api.nvim_buf_line_count(bufnr) - 1
  -- Collect diagnostics that intersect the current line or extend beyond EOF
  local diagnostics = {}
  local all_diags = vim.diagnostic.get(bufnr)
  for _, d in ipairs(all_diags) do
    local start_l = d.lnum or 0
    local end_l = d.end_lnum or start_l
    if (line >= start_l and line <= end_l) or (line == last_line and (start_l > last_line or end_l > last_line)) then
      table.insert(diagnostics, d)
    end
  end

  if #diagnostics == 0 and line == last_line then
    local best
    for _, d in ipairs(all_diags) do
      if state.severity_enabled[d.severity] then
        if not best or d.severity < best.severity then
          best = d
        end
      end
    end
    if best then
      table.insert(diagnostics, best)
    end
  end

  if #diagnostics == 0 then
    return
  end

  -- Separate diagnostics by mode and build virtual text table
  local vtext_diagnostics = {}
  local vline_diagnostics = {}

  for _, diagnostic in ipairs(diagnostics) do
    if state.severity_enabled[diagnostic.severity] then
      local is_text_mode = state.severity_modes[diagnostic.severity]
      local severity_name = severity_names[diagnostic.severity]
      local hl_group = "DiagnosticVirtualText" .. severity_name

      if is_text_mode then
        -- Use native diagnostic virtual_text per diagnostic for normal navigation
        local dpush = vim.tbl_deep_extend("force", {}, diagnostic)
        local was_other_line = (dpush.lnum ~= line)
        if was_other_line then
          dpush.lnum = line
          dpush.end_lnum = line
        end
        table.insert(vtext_diagnostics, dpush)
      else
        -- Preserve original column if on this line; if re-anchored, use best-effort column near code
        local dpush = vim.tbl_deep_extend("force", {}, diagnostic)
        local was_other_line = (dpush.lnum ~= line)
        if was_other_line then
          dpush.lnum = line
          dpush.end_lnum = line
        end
        local line_text = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""
        local max_col = #line_text
        local fallback_col
        local policy = (config.options and config.options.focus_fallback_column) or "first_non_ws"
        if policy == "eol" then
          fallback_col = max_col
        else
          local first_non_ws = line_text:find("[^%s]")
          fallback_col = first_non_ws and (first_non_ws - 1) or 0
        end
        if was_other_line then
          dpush.col = math.max(0, math.min(dpush.col or fallback_col, max_col))
          dpush.end_col = math.max(0, math.min(dpush.end_col or dpush.col, max_col))
        else
          dpush.col = math.max(0, math.min(dpush.col or fallback_col, max_col))
          dpush.end_col = math.max(0, math.min(dpush.end_col or dpush.col, max_col))
        end
        table.insert(vline_diagnostics, dpush)
      end
    end
  end

  -- Show virtual text diagnostics using native diagnostic system
  if #vtext_diagnostics > 0 then
    vim.diagnostic.show(focus_ns_vtext, bufnr, vtext_diagnostics, {
      virtual_text = true,
      virtual_lines = false,
      signs = false,
      underline = false,
    })
  end

  -- Show virtual line diagnostics using native diagnostic system
  if #vline_diagnostics > 0 then
    vim.diagnostic.show(focus_ns_vline, bufnr, vline_diagnostics, {
      virtual_lines = true,
    })
  end
end

-- Internal refresh function (skips focus mode for auto-refresh)
local function refresh_diagnostics_internal(bufnr)
  -- Skip if in focus mode (auto-refresh shouldn't interfere)
  if focus_mode then
    return
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Only refresh if buffer is valid and loaded
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  -- Reapply the diagnostic config
  local text_severities = {}
  local line_severities = {}

  for severity, is_text_mode in pairs(state.severity_modes) do
    if state.severity_enabled[severity] then
      if is_text_mode then
        table.insert(text_severities, severity)
      else
        table.insert(line_severities, severity)
      end
    end
  end

  -- Get current config to preserve signs and other settings
  local current_config = vim.diagnostic.config()

  vim.diagnostic.config({
    underline = current_config.underline ~= false,
    signs = current_config.signs, -- Preserve existing signs config
    virtual_text = #text_severities > 0 and {
      severity = text_severities,
    } or false,
    virtual_lines = #line_severities > 0 and {
      severity = line_severities,
    } or false,
  })

  -- Refresh the specific buffer
  vim.diagnostic.hide(nil, bufnr)
  vim.diagnostic.show(nil, bufnr)
end

-- Public refresh function (works in focus mode too)
local function refresh_diagnostics(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Only refresh if buffer is valid and loaded
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  -- Clear extmarks first to prevent stuck diagnostics
  vim.api.nvim_buf_clear_namespace(bufnr, focus_ns_vtext, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, focus_ns_vline, 0, -1)
  -- CRITICAL: Hide diagnostics shown via vim.diagnostic.show()
  vim.diagnostic.hide(focus_ns_vtext, bufnr)
  vim.diagnostic.hide(focus_ns_vline, bufnr)

  -- If in focus mode, refresh the focus display
  if focus_mode then
    update_focus_diagnostics()
    print("Refreshed focus mode diagnostics")
    return
  end

  -- Otherwise do normal refresh
  refresh_diagnostics_internal(bufnr)
  print("Refreshed diagnostics for buffer " .. bufnr)
end

-- Focus mode functions
local function exit_focus_mode()
  if not focus_mode then
    return
  end

  focus_mode = false

  -- Remove autocmd
  if focus_autocmd then
    vim.api.nvim_del_autocmd(focus_autocmd)
    focus_autocmd = nil
  end

  -- Clear extmarks for all buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, focus_ns_vtext, 0, -1)
      vim.api.nvim_buf_clear_namespace(bufnr, focus_ns_vline, 0, -1)
      -- CRITICAL: Hide diagnostics shown via vim.diagnostic.show()
      vim.diagnostic.hide(focus_ns_vtext, bufnr)
      vim.diagnostic.hide(focus_ns_vline, bufnr)
    end
  end

  -- Restore normal display
  update_display()
end

local function toggle_focus_mode()
  if focus_mode then
    -- Currently ON, turn OFF
    exit_focus_mode()
    print("Focus mode: OFF")
  else
    -- Currently OFF, turn ON
    focus_mode = true
    print("Focus mode: ON (showing diagnostics only on current line)")

    -- Create autocmd to update on cursor movement
    focus_autocmd = vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "DiagnosticChanged" }, {
      callback = update_focus_diagnostics,
    })

    -- Initial update
    update_focus_diagnostics()
  end
end

local function toggle_focus_default()
  state.focus_default = not state.focus_default
  print(string.format("Focus mode default: %s (will apply on next startup)", state.focus_default and "ON" or "OFF"))
  state.save()
end

local function toggle_severity(severity, name)
  return function()
    -- Exit focus mode if active
    exit_focus_mode()

    -- If hidden, show it first before toggling mode
    if not state.severity_enabled[severity] then
      state.severity_enabled[severity] = true
      print(string.format("Showing %s", name))
    end
    state.severity_modes[severity] = not state.severity_modes[severity]
    print(string.format("Toggled %s, text_mode = %s", name, tostring(state.severity_modes[severity])))
    state.save()
    update_display()
  end
end

local function reset_to_default()
  -- Exit focus mode if active
  exit_focus_mode()

  -- Reset all severities to virtual text mode (default)
  state.severity_modes[vim.diagnostic.severity.ERROR] = true
  state.severity_modes[vim.diagnostic.severity.WARN] = true
  state.severity_modes[vim.diagnostic.severity.INFO] = true
  state.severity_modes[vim.diagnostic.severity.HINT] = true
  state.severity_enabled[vim.diagnostic.severity.ERROR] = true
  state.severity_enabled[vim.diagnostic.severity.WARN] = true
  state.severity_enabled[vim.diagnostic.severity.INFO] = true
  state.severity_enabled[vim.diagnostic.severity.HINT] = true
  print("Reset all severities to virtual text mode")
  state.save()
  update_display()
end

local function toggle_error()
  -- Exit focus mode if active
  exit_focus_mode()

  state.severity_enabled[vim.diagnostic.severity.ERROR] = not state.severity_enabled[vim.diagnostic.severity.ERROR]
  print(string.format("Error diagnostics: %s", state.severity_enabled[vim.diagnostic.severity.ERROR] and "ON" or "OFF"))
  state.save()
  update_display()
end

local function toggle_warnings()
  -- Exit focus mode if active
  exit_focus_mode()

  local new_state = not state.severity_enabled[vim.diagnostic.severity.WARN]
  state.severity_enabled[vim.diagnostic.severity.WARN] = new_state
  state.severity_enabled[vim.diagnostic.severity.INFO] = new_state
  state.severity_enabled[vim.diagnostic.severity.HINT] = new_state
  print(string.format("Warn/Info/Hint diagnostics: %s", new_state and "ON" or "OFF"))
  state.save()
  update_display()
end

local function toggle_all()
  -- If focus mode is active, exit and show everything first
  if focus_mode then
    exit_focus_mode()
    state.severity_enabled[vim.diagnostic.severity.ERROR] = true
    state.severity_enabled[vim.diagnostic.severity.WARN] = true
    state.severity_enabled[vim.diagnostic.severity.INFO] = true
    state.severity_enabled[vim.diagnostic.severity.HINT] = true
    print("All diagnostics: ON")
    state.save()
    update_display()
    return
  end

  -- Exit focus mode if active (shouldn't happen but safety check)
  exit_focus_mode()

  -- Check if all enabled states are equal
  local all_same = state.severity_enabled[vim.diagnostic.severity.ERROR]
      == state.severity_enabled[vim.diagnostic.severity.WARN]
    and state.severity_enabled[vim.diagnostic.severity.WARN] == state.severity_enabled[vim.diagnostic.severity.INFO]
    and state.severity_enabled[vim.diagnostic.severity.INFO] == state.severity_enabled[vim.diagnostic.severity.HINT]

  local new_state
  if all_same then
    -- All are equal, toggle them
    new_state = not state.severity_enabled[vim.diagnostic.severity.ERROR]
  else
    -- Not all equal, make them all on first
    new_state = true
  end

  state.severity_enabled[vim.diagnostic.severity.ERROR] = new_state
  state.severity_enabled[vim.diagnostic.severity.WARN] = new_state
  state.severity_enabled[vim.diagnostic.severity.INFO] = new_state
  state.severity_enabled[vim.diagnostic.severity.HINT] = new_state
  print(string.format("All diagnostics: %s", new_state and "ON" or "OFF"))
  state.save()
  update_display()
end

-- Setup function
function M.setup(opts)
  config.setup(opts)
  state.load()

  -- Apply loaded state immediately to prevent other plugins from overriding
  if state.focus_default then
    toggle_focus_mode()
  else
    update_display()
  end

  -- Setup autocmd to refresh diagnostics when entering buffers
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    callback = function(args)
      -- Small delay to ensure other plugins have applied their configs first
      vim.defer_fn(function()
        refresh_diagnostics_internal(args.buf)
      end, 50)
    end,
    desc = "Refresh xray diagnostics on buffer enter",
  })

  -- Setup keymaps
  local wk = require("which-key")
  wk.add({
    { "gl", group = "diagnostics" },
    { "gla", toggle_all, desc = "Toggle all diagnostics on/off" },
    { "gle", toggle_error, desc = "Toggle error on/off" },
    { "glw", toggle_warnings, desc = "Toggle warn/info/hint on/off" },
    { "glf", toggle_focus_mode, desc = "Toggle focus mode (current line only)" },
    { "glse", toggle_severity(vim.diagnostic.severity.ERROR, "ERROR"), desc = "Toggle error display mode" },
    { "glsw", toggle_severity(vim.diagnostic.severity.WARN, "WARN"), desc = "Toggle warn display mode" },
    { "glsi", toggle_severity(vim.diagnostic.severity.INFO, "INFO"), desc = "Toggle info display mode" },
    { "glsh", toggle_severity(vim.diagnostic.severity.HINT, "HINT"), desc = "Toggle hint display mode" },
    { "glsc", reset_to_default, desc = "Reset all to virtual text" },
    { "glsf", toggle_focus_default, desc = "Toggle focus mode as default on startup" },
    {
      "glr",
      function()
        refresh_diagnostics()
      end,
      desc = "Refresh diagnostics for current buffer",
    },
  })
end

return M
