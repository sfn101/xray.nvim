local M = {}

M.defaults = {
  -- Default state file location
  state_file = vim.fn.stdpath("data") .. "/xray_state.json",
  
  -- Default keymaps prefix
  keymap_prefix = "gl",
  
  -- Auto-setup keymaps (set to false to define your own)
  setup_keymaps = true,
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
