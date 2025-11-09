local M = {}

local state = require("xray.state")
local config = require("xray.config")

-- Focus mode state
local focus_mode = false
local focus_namespace = vim.api.nvim_create_namespace('diagnostic_focus')
local focus_autocmd = nil

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

  vim.diagnostic.config({
    underline = true,
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

-- Focus mode functions
local function update_focus_diagnostics()
  if not focus_mode then
    return
  end
  
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1
  
  -- Get all diagnostics for current buffer
  local all_diagnostics = vim.diagnostic.get(bufnr)
  
  -- Filter diagnostics for current line only, respecting enabled state
  local line_diagnostics = {}
  for _, diagnostic in ipairs(all_diagnostics) do
    if diagnostic.lnum == line and state.severity_enabled[diagnostic.severity] then
      table.insert(line_diagnostics, diagnostic)
    end
  end
  
  -- Clear previous focus diagnostics and show only current line
  vim.diagnostic.reset(focus_namespace, bufnr)
  if #line_diagnostics > 0 then
    vim.diagnostic.set(focus_namespace, bufnr, line_diagnostics, {})
  end
end

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
  
  -- Clear focus namespace
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      vim.diagnostic.reset(focus_namespace, bufnr)
    end
  end
end

local function toggle_focus_mode()
  focus_mode = not focus_mode
  
  if focus_mode then
    -- Enable focus mode
    -- Build config respecting current severity modes
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
    
    -- Hide global diagnostics completely
    vim.diagnostic.config({
      underline = true,
      virtual_text = false,
      virtual_lines = false,
    })
    
    -- Set up focus namespace with the same text/line settings
    vim.diagnostic.config({
      underline = true,
      virtual_text = #text_severities > 0 and {
        severity = text_severities,
      } or false,
      virtual_lines = #line_severities > 0 and {
        severity = line_severities,
      } or false,
    }, focus_namespace)
    
    -- Create autocmd to update on cursor movement
    focus_autocmd = vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {
      callback = update_focus_diagnostics,
    })
    
    -- Initial update
    update_focus_diagnostics()
    print("Focus mode: ON (showing diagnostics only on current line)")
  else
    -- Disable focus mode
    exit_focus_mode()
    
    -- Restore normal display
    update_display()
    print("Focus mode: OFF")
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
  local all_same = state.severity_enabled[vim.diagnostic.severity.ERROR] == state.severity_enabled[vim.diagnostic.severity.WARN]
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
  
  -- Apply loaded state on startup with delay to ensure LSP is ready
  vim.defer_fn(function()
    if state.focus_default then
      toggle_focus_mode()
    else
      update_display()
    end
  end, 100) -- 100ms delay
  
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
  })
end

return M
