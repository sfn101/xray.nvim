-- Plugin loader for xray.nvim
-- This file is automatically sourced by Neovim

if vim.fn.has("nvim-0.8.0") == 0 then
  vim.api.nvim_err_writeln("xray.nvim requires Neovim >= 0.8.0")
  return
end

-- Don't load if already loaded
if vim.g.loaded_xray then
  return
end

vim.g.loaded_xray = true
