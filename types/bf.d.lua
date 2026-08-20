---@meta

-- Definitions lua-language-server needs but edgetx-lua-stdlib does not carry.
-- Nothing here ships: edgetx.yml sets `source_dir: src`, and this file lives
-- outside it purely so `make typecheck` has something to resolve against.

--------------------------------------------------------------------------------
-- EdgeTX globals missing from edgetx-lua-stdlib
--------------------------------------------------------------------------------

-- The stdlib only models `dir.chdir`. EdgeTX also merges the filesystem rotable
-- (radio/src/lua/api_filesystem.cpp:256) into _G, which is the form the Lua
-- reference guide documents and the form every entry script here uses.

--- Change the working directory.
--- @since 2.3.0
---@param directory string
function chdir(directory) end

--------------------------------------------------------------------------------
-- OpenTX-era colour constants
--------------------------------------------------------------------------------

-- These were dropped when EdgeTX moved to themes; no COLOR2FLAGS entry for any
-- of them survives in api_colorlcd.cpp. They evaluate to nil on every EdgeTX
-- release, so the colour lcd.* path draws with default flags today. Typed as
-- optional to keep that honest rather than pretending they resolve -- the
-- colour radios that matter get ui/lvgl.lua instead, and the rest keep the
-- rendering they have shipped with for years.

---@type integer?
TEXT_COLOR = nil
---@type integer?
TEXT_BGCOLOR = nil
---@type integer?
LINE_COLOR = nil
---@type integer?
TITLE_BGCOLOR = nil
---@type integer?
MENU_TITLE_COLOR = nil
