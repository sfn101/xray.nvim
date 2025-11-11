# Focus Mode Refactor - Testing Guide

## Changes Made

### Refactored Implementation
The focus mode has been completely refactored to use a **single config + extmarks approach** instead of dual namespaces. This eliminates all namespace conflicts and duplication issues.

### Key Improvements

1. **No More Duplication**: Removed the problematic `last_focus_line` check that prevented necessary updates
2. **Clean Namespace Management**: Uses only the default diagnostic namespace, with custom extmarks for focus mode
3. **Proper Clearing**: Always clears extmarks before updates to prevent stuck diagnostics
4. **Signs + Underlines Always Visible**: In focus mode, signs and underlines remain visible on all lines
5. **Virtual Text/Lines on Current Line Only**: Only shows virtual text/lines for the current cursor line
6. **Nerd Font Icons**: Diagnostic signs now use proper LazyVim nerd font icons ( , , , )
7. **Column Pointer**: Virtual lines in focus mode show a pointer (└─) indicating the exact column where the error occurs

## How It Works

### Normal Mode
- Uses standard `vim.diagnostic.config()` with your preferred settings
- All diagnostics display according to severity settings

### Focus Mode
1. Sets global config to hide virtual text/lines but keep signs/underlines
2. Uses custom extmark namespaces (`xray_focus_vtext` and `xray_focus_vline`) to manually display virtual text/lines only on current line
3. Updates dynamically on cursor movement via `CursorMoved` autocmd
4. Clears extmarks on every update to prevent duplication

### Visual Example

**Normal Mode (all diagnostics visible):**
```
  1  │ function hello() {
  2  │   const x = undefined;  Error: 'undefined' is not defined
  3  │   return x.toString();  Error: Cannot read property 'toString' of undefined
```

**Focus Mode (cursor on line 2):**
```
  1  │ function hello() {
  2  │ > const x = undefined;  Error: 'undefined' is not defined
        └─────────^
        └─ 'undefined' is not defined
  3  │   return x.toString();
```

Note: Signs () and underlines remain visible on line 3, only virtual text/lines are hidden.

## Testing Instructions

### Manual Testing
1. Open a file with multiple errors on different lines
2. Enter focus mode with `glf`
3. Test the following scenarios:

#### Test 1: No Duplication on Same Line
- Move cursor on a line with errors
- Move cursor within the same line (different columns)
- **Expected**: Virtual text should NOT duplicate

#### Test 2: No Duplication on Toggle
- Position cursor on a line with errors
- Toggle focus mode off (`glf`)
- Toggle focus mode on (`glf`)
- **Expected**: Virtual text should NOT duplicate

#### Test 3: Signs/Underlines Always Visible
- In focus mode, observe lines with errors/warnings
- **Expected**: Signs in gutter and underlines should be visible on ALL lines, not just current line

#### Test 4: Clean Refresh
- In focus mode with stuck diagnostics
- Run refresh command (`glr`)
- **Expected**: All stuck diagnostics cleared, including current line

#### Test 5: Cursor Movement
- Move cursor between lines with errors
- **Expected**: Virtual text should smoothly move to follow cursor, no duplicates left behind

### Expected Behavior Summary
- ✅ Signs visible on all diagnostic lines with nerd font icons
- ✅ Underlines visible on all diagnostic lines
- ✅ Virtual text/lines ONLY on current cursor line
- ✅ Virtual lines show column pointer (└─) at error position
- ✅ No duplication when moving on same line
- ✅ No duplication when toggling focus mode
- ✅ Refresh clears all stuck diagnostics
- ✅ Smooth transition between lines

## Technical Details

### Diagnostic Sign Icons
Icons are set using `vim.fn.sign_define()` during setup:
- Error:  ` ` (nerd font icon)
- Warn:  ` ` (nerd font icon)
- Info:  ` ` (nerd font icon)
- Hint:  ` ` (nerd font icon)

### Extmark Namespaces
- `xray_focus_vtext`: For virtual text display (end of line)
- `xray_focus_vline`: For virtual lines display (below line with column pointer)

### Virtual Line Column Pointer
Format: `string.rep(" ", col) .. "└─ " .. diagnostic.message`
- Spaces pad to the exact column of the diagnostic
- `└─` character points to the error position
- Followed by the diagnostic message

### Update Cycle
```
1. Clear extmarks → 2. Update config → 3. Hide/show → 4. Set new extmarks
```

### Why This Works
- **Single source of truth**: Diagnostics stay in default namespace
- **Manual display**: Extmarks give us precise control over what shows where
- **Always clear first**: Prevents accumulation of stale displays
- **Config separation**: Global config doesn't interfere with extmarks
- **Column-aware pointer**: Uses diagnostic.col to position the arrow accurately
