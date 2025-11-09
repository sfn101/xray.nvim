local M = {}

local config = require("xray.config")

-- State variables
M.severity_modes = {}
M.severity_enabled = {}
M.focus_default = false

-- Helper to safely get boolean value with default, supports both old numeric keys and new string labels
local function get_bool(table, key, numeric_key, default)
  if table then
    if table[key] ~= nil then
      return table[key]
    end
    if table[tostring(numeric_key)] ~= nil then
      return table[tostring(numeric_key)]
    end
  end
  return default
end

-- Load saved state from disk
function M.load()
  local state_file = config.options.state_file or (vim.fn.stdpath("data") .. "/xray_state.json")
  local file = io.open(state_file, "r")
  local loaded_state = {}
  
  if file then
    local content = file:read("*all")
    file:close()
    local ok, state = pcall(vim.json.decode, content)
    if ok and state then
      loaded_state = state
    end
  end
  
  -- Default: all severities enabled and in text mode, focus mode off
  if not loaded_state.modes then
    loaded_state = {
      modes = {
        ERROR = true,
        WARN = true,
        INFO = true,
        HINT = true,
      },
      enabled = {
        ERROR = true,
        WARN = true,
        INFO = true,
        HINT = true,
      },
      focus_default = false,
    }
  end
  
  -- Track display mode for each severity: true = text, false = lines
  M.severity_modes = {
    [vim.diagnostic.severity.ERROR] = get_bool(loaded_state.modes, "ERROR", vim.diagnostic.severity.ERROR, get_bool(loaded_state, "ERROR", vim.diagnostic.severity.ERROR, true)),
    [vim.diagnostic.severity.WARN] = get_bool(loaded_state.modes, "WARN", vim.diagnostic.severity.WARN, get_bool(loaded_state, "WARN", vim.diagnostic.severity.WARN, true)),
    [vim.diagnostic.severity.INFO] = get_bool(loaded_state.modes, "INFO", vim.diagnostic.severity.INFO, get_bool(loaded_state, "INFO", vim.diagnostic.severity.INFO, true)),
    [vim.diagnostic.severity.HINT] = get_bool(loaded_state.modes, "HINT", vim.diagnostic.severity.HINT, get_bool(loaded_state, "HINT", vim.diagnostic.severity.HINT, true)),
  }
  
  -- Track whether each severity is enabled: true = shown, false = hidden
  M.severity_enabled = {
    [vim.diagnostic.severity.ERROR] = get_bool(loaded_state.enabled, "ERROR", vim.diagnostic.severity.ERROR, true),
    [vim.diagnostic.severity.WARN] = get_bool(loaded_state.enabled, "WARN", vim.diagnostic.severity.WARN, true),
    [vim.diagnostic.severity.INFO] = get_bool(loaded_state.enabled, "INFO", vim.diagnostic.severity.INFO, true),
    [vim.diagnostic.severity.HINT] = get_bool(loaded_state.enabled, "HINT", vim.diagnostic.severity.HINT, true),
  }
  
  M.focus_default = loaded_state.focus_default or false
end

-- Save current state to disk
function M.save()
  local state_file = config.options.state_file or (vim.fn.stdpath("data") .. "/xray_state.json")
  
  -- Use descriptive labels instead of numeric codes
  local state = {
    modes = {
      ERROR = M.severity_modes[vim.diagnostic.severity.ERROR],
      WARN = M.severity_modes[vim.diagnostic.severity.WARN],
      INFO = M.severity_modes[vim.diagnostic.severity.INFO],
      HINT = M.severity_modes[vim.diagnostic.severity.HINT],
    },
    enabled = {
      ERROR = M.severity_enabled[vim.diagnostic.severity.ERROR],
      WARN = M.severity_enabled[vim.diagnostic.severity.WARN],
      INFO = M.severity_enabled[vim.diagnostic.severity.INFO],
      HINT = M.severity_enabled[vim.diagnostic.severity.HINT],
    },
    focus_default = M.focus_default,
  }
  
  local file = io.open(state_file, "w")
  if file then
    file:write(vim.json.encode(state))
    file:close()
  end
end

return M
