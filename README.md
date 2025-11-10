# xray.nvim

A sophisticated Neovim plugin for managing LSP diagnostic display with per-severity control, multiple display modes, and focus capabilities.


https://github.com/user-attachments/assets/8cf8ce89-f623-4a3e-8067-ec185aecee32




## Features

- **Per-severity control**: Toggle ERROR, WARN, INFO, and HINT diagnostics independently
- **Dual display modes**: Switch between virtual text (inline) and virtual lines (multiline) for each severity
- **Focus mode**: Show diagnostics only on the current cursor line
- **State persistence**: All settings automatically saved and restored across sessions
- **Which-key integration**: Intuitive menu-driven interface

## Requirements

- Neovim >= 0.8.0
- [which-key.nvim](https://github.com/folke/which-key.nvim)
- LSP server configured

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "sfn101/xray.nvim",
  dependencies = {
    "folke/which-key.nvim",
  },
  config = function()
    require("xray").setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "sfn101/xray.nvim",
  requires = { "folke/which-key.nvim" },
  config = function()
    require("xray").setup()
  end,
}
```

## Configuration

### Default Configuration

```lua
require("xray").setup({
  -- Default state file location
  state_file = vim.fn.stdpath("data") .. "/xray_state.json",
  
  -- Default keymaps prefix
  keymap_prefix = "gl",
  
  -- Auto-setup keymaps (set to false to define your own)
  setup_keymaps = true,
})
```

### Custom Keymaps

If you prefer to define your own keymaps, disable auto-setup:

```lua
require("xray").setup({
  setup_keymaps = false,
})

-- Define your own keymaps
vim.keymap.set("n", "<leader>da", require("xray").toggle_all, { desc = "Toggle all diagnostics" })
```

## Usage

### Default Keymaps

All keymaps use the `gl` prefix by default (customizable via `keymap_prefix` option).

#### Visibility Toggles

| Key | Action |
|-----|--------|
| `gla` | Toggle all diagnostics on/off |
| `gle` | Toggle ERROR diagnostics on/off |
| `glw` | Toggle WARN/INFO/HINT diagnostics on/off together |

#### Display Mode Toggles

| Key | Action |
|-----|--------|
| `glse` | Toggle ERROR display mode (virtual text ↔ virtual lines) |
| `glsw` | Toggle WARN display mode (virtual text ↔ virtual lines) |
| `glsi` | Toggle INFO display mode (virtual text ↔ virtual lines) |
| `glsh` | Toggle HINT display mode (virtual text ↔ virtual lines) |
| `glsc` | Reset all severities to virtual text mode (default) |

#### Focus Mode

| Key | Action |
|-----|--------|
| `glf` | Toggle focus mode (show diagnostics only on current line) |
| `glsf` | Toggle focus mode as default on startup (persisted) |

#### Refresh

| Key | Action |
|-----|--------|
| `glr` | Manually refresh diagnostics for current buffer |

### Display Modes Explained

**Virtual Text Mode** (default):
- Diagnostics appear inline at the end of the line
- Compact and non-intrusive
- Good for quick scanning

**Virtual Lines Mode**:
- Diagnostics appear on separate lines below the code
- More detailed and readable
- Better for long messages

### Focus Mode

Focus mode is a special display mode that:
- Shows diagnostics **only on the current cursor line**
- Updates automatically as you move the cursor
- Respects current virtual text/lines settings for each severity
- Respects enabled/disabled state for each severity
- Perfect for reducing visual noise while working

**Usage Example:**
1. Press `glf` to enter focus mode
2. Move your cursor - diagnostics follow
3. Press `glf` again to exit and see all diagnostics
4. Use `glsf` to make focus mode your default at startup

### State Persistence

All settings are automatically saved to `~/.local/share/nvim/xray_state.json` and restored when you restart Neovim. This includes:
- Display mode for each severity (text vs lines)
- Enabled/disabled state for each severity
- Focus mode default preference

## Common Workflows

### Hide All Non-Errors

1. Press `glw` to hide WARN/INFO/HINT
2. Only errors remain visible

### Use Virtual Lines for Errors Only

1. Press `glse` until errors use virtual lines
2. Keep other severities in virtual text mode

### Focus on Current Line

1. Press `glf` to enter focus mode
2. Work with minimal distraction
3. See diagnostics only where your cursor is

### Reset Everything

Press `glsc` to reset all severities to default virtual text mode

### Refresh Diagnostics

Press `glr` to manually refresh diagnostics for the current buffer. This is useful if:
- Another plugin's config is interfering with xray settings
- Diagnostics appear duplicated or glitchy
- You want to force-reapply xray's configuration

**Note**: xray automatically refreshes diagnostics when you open or switch to a buffer, so manual refresh is rarely needed.

## How It Works

### Architecture

- `lua/xray/init.lua`: Main plugin logic and keymap setup
- `lua/xray/config.lua`: Configuration management
- `lua/xray/state.lua`: State persistence (load/save JSON)
- `plugin/xray.lua`: Plugin initialization guard

### Focus Mode Implementation

Focus mode uses a custom namespace to display filtered diagnostics:
1. Global diagnostics are hidden
2. Custom namespace is configured with same display settings
3. CursorMoved/CursorMovedI autocmds update filtered diagnostics
4. Only diagnostics on current line are shown in custom namespace

### Automatic Refresh on Buffer Enter

xray automatically refreshes diagnostics when you enter a buffer to ensure:
- xray's configuration takes precedence over other plugins
- No duplicate or conflicting diagnostic displays
- Consistent behavior across all buffers

The refresh happens with a 50ms delay to allow other plugins (like LazyVim) to apply their configs first, then xray overrides with your preferred settings.

### State Management

State is serialized to JSON with descriptive labels:
```json
{
  "modes": {
    "ERROR": true,
    "WARN": true,
    "INFO": false,
    "HINT": false
  },
  "enabled": {
    "ERROR": true,
    "WARN": true,
    "INFO": true,
    "HINT": true
  },
  "focus_default": false
}
```

## Troubleshooting

### Diagnostics Not Showing

1. Check LSP is attached: `:LspInfo`
2. Reset to defaults: `glsc`
3. Check state file: `~/.local/share/nvim/xray_state.json`

### Focus Mode Not Working

- Exit and re-enter focus mode with `glf`
- Check CursorMoved autocmds: `:au CursorMoved`

### Keymaps Not Working

- Verify which-key is installed
- Check keymap prefix in setup options
- Try `:map gl` to see registered keymaps

## Contributing

Contributions welcome! Please open an issue or PR.

## License

MIT License - see LICENSE file for details

## Credits

Inspired by the need for granular diagnostic control in modern LSP workflows.
