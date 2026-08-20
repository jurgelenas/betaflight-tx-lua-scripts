-- Layout-parity harness.
--
-- Dumps, for every (resolution, apiVersion, page) the tool can produce, the
-- geometry each page file builds and the sequence of draws ui.lua would make
-- from it. Refactoring the B&W renderer is only safe if this output does not
-- move, so the dump is committed as bin/layout.golden.csv and `make
-- layout-check` diffs against it.
--
-- Run it through the simulator:
--
--   edgetx-cli dev simulator --radio gx12 --headless --script bin/layout_dump.lua
--
-- ...but note it does NOT touch the radio. `--script` is a host-side Lua 5.4
-- with an unrestricted io/loadfile, which is the only Lua interpreter on the
-- machine; the pages are loaded straight out of src/. Driving the real
-- firmware instead would mean navigating a Tools menu whose row order is not
-- ours to pin, for arithmetic that is identical either way.
--
-- Two places where host Lua is not radio Lua, both handled here rather than
-- assumed away:
--
--   * EdgeTX builds Lua 5.3 with LUA_FLOORN2I=1, so a fractional coordinate
--     reaching lcd.drawText is floored by the C API rather than rejected.
--     rates.lua leans on this (lineSpacing*0.4, tableSpacing.row*1.5). Draw
--     records therefore floor on emit while the on-screen test keeps the
--     unfloored value, exactly as the firmware does.
--   * B&W EdgeTX ships no `table` library at all (linit.c gates tablib on
--     COLORLCD) and no bit32 on the host. The sandbox below omits `table` so
--     a stray table.insert fails here the way it would on a 128x64 radio, and
--     supplies bit32 in pure Lua.
--
-- The full dump is ~21 MB, too much to keep in git, so what gets committed is
-- one summary row per (resolution, apiVersion, page) carrying the counts and an
-- FNV-1a of the rows behind them. A summary mismatch names the config; re-run
-- with BF_ONLY set to see the rows themselves.
--
-- Environment:
--   BF_SRC   source tree to read (default "src")
--   BF_OUT   full CSV to write (default "obj/layout.csv")
--   BF_SUM   summary CSV to write (default "obj/layout.sum.csv")
--   BF_CMP   summary to compare against; mismatch exits 1
--   BF_ONLY  restrict the run to configs whose "res,api,page" contains this

local SRC = os.getenv("BF_SRC") or "src"
local OUT = os.getenv("BF_OUT") or "obj/layout.csv"
local SUM = os.getenv("BF_SUM") or "obj/layout.sum.csv"
local CMP = os.getenv("BF_CMP")
local ONLY = os.getenv("BF_ONLY")

local BF = SRC .. "/SCRIPTS/BF/"
local FIXTURES = "bin/fixtures/"

-- The three radios.lua entries with no highRes flag.
local MONO = { ["128x64"] = true, ["128x96"] = true, ["212x64"] = true }

-- Every resolution radios.lua knows about.
local RESOLUTIONS = {
    { 128, 64 },
    { 128, 96 },
    { 212, 64 },
    { 320, 240 },
    { 320, 480 },
    { 480, 272 },
    { 480, 320 },
    { 800, 480 },
}

-- Every apiVersion the sources branch on, plus a value below the first
-- threshold, one above the last, and a midpoint wherever two thresholds are
-- more than 0.01 apart. Those midpoints are the ones that catch an inverted
-- comparison; the thresholds themselves only catch an off-by-one.
local API_VERSIONS = {
    1.15,
    1.16,
    1.18,
    1.20,
    1.21,
    1.26,
    1.31,
    1.33,
    1.35,
    1.36,
    1.37,
    1.38,
    1.39,
    1.40,
    1.41,
    1.42,
    1.43,
    1.44,
    1.45,
    1.46,
    1.47,
    1.48,
    1.49,
}

-- PAGES/INIT/* are preconditions returning a script path, not pages, so they
-- carry no geometry and are not listed.
local PAGES = {
    "CONFIRM/acc_cal.lua",
    "CONFIRM/pwm.lua",
    "CONFIRM/vtx_tables.lua",
    "PAGES/acc_trim.lua",
    "PAGES/battery.lua",
    "PAGES/failsafe.lua",
    "PAGES/filters1.lua",
    "PAGES/filters2.lua",
    "PAGES/gpspids.lua",
    "PAGES/pid_advanced.lua",
    "PAGES/pids1.lua",
    "PAGES/pids2.lua",
    "PAGES/pos_osd.lua",
    "PAGES/profiles.lua",
    "PAGES/pwm.lua",
    "PAGES/rates.lua",
    "PAGES/rescue.lua",
    "PAGES/rx.lua",
    "PAGES/simplified_tuning.lua",
    "PAGES/vtx.lua",
}

--------------------------------------------------------------------------------
-- Drawing flags
--------------------------------------------------------------------------------

-- ui.lua composes attributes with `+`, not `|`, so the only property that
-- matters is that no two flags share a bit -- otherwise a carry would let two
-- different attribute sets collapse to one number and hide a regression.
-- These are distinct powers of two rather than EdgeTX's real bitmasks: the
-- attr column is a symbolic composite, and pinning it to firmware values
-- would only make the golden churn when EdgeTX renumbers a font.
local FLAG = {
    SMLSIZE = 1,
    MIDSIZE = 2,
    DBLSIZE = 4,
    BOLD = 8,
    INVERS = 16,
    BLINK = 32,
    FORCE = 64,
    ERASE = 128,
    SOLID = 256,
    COLOR_THEME_PRIMARY2 = 512,
    COLOR_THEME_PRIMARY3 = 1024,
    COLOR_THEME_SECONDARY1 = 2048,
    COLOR_THEME_SECONDARY3 = 4096,
}

--------------------------------------------------------------------------------
-- bit32, in pure Lua
--------------------------------------------------------------------------------

-- Built on 5.3's native operators, masked back to 32 bits: bit32 is unsigned
-- 32-bit while Lua integers are signed 64-bit, so every result needs trimming
-- and every right shift needs its operand trimmed first to stay logical.
local MASK = 0xFFFFFFFF

local bit32 = {}

local function trim(x)
    return math.floor(x) & MASK
end

function bit32.band(a, b, ...)
    local r = trim(a) & trim(b)
    if select("#", ...) > 0 then
        return bit32.band(r, ...)
    end
    return r
end

function bit32.bor(a, b, ...)
    local r = trim(a) | trim(b)
    if select("#", ...) > 0 then
        return bit32.bor(r, ...)
    end
    return r
end

function bit32.bxor(a, b, ...)
    local r = trim(a) ~ trim(b)
    if select("#", ...) > 0 then
        return bit32.bxor(r, ...)
    end
    return r
end

function bit32.lshift(a, n)
    if n >= 32 or n <= -32 then
        return 0
    end
    if n < 0 then
        return bit32.rshift(a, -n)
    end
    return (trim(a) << n) & MASK
end

function bit32.rshift(a, n)
    if n >= 32 or n <= -32 then
        return 0
    end
    if n < 0 then
        return bit32.lshift(a, -n)
    end
    return trim(a) >> n
end

function bit32.btest(a, b)
    return (trim(a) & trim(b)) ~= 0
end

function bit32.extract(a, pos, width)
    width = width or 1
    return (trim(a) >> pos) & ((1 << width) - 1)
end

function bit32.replace(a, v, pos, width)
    width = width or 1
    local mask = (((1 << width) - 1) << pos) & MASK
    return ((trim(a) & ~mask) | ((trim(v) << pos) & mask)) & MASK
end

--------------------------------------------------------------------------------
-- Serialisation
--------------------------------------------------------------------------------

local function csv(v)
    if v == nil then
        return ""
    end
    if type(v) == "boolean" then
        return v and "1" or "0"
    end
    if type(v) == "number" then
        -- %.14g keeps 37.5 as "37.5" and 12 as "12", and never lets a float
        -- that happens to be integral print as "12.0" on one run and "12" on
        -- another.
        return string.format("%.14g", v)
    end
    v = tostring(v)
    if v:find('[,"\n\r]') then
        return '"' .. v:gsub('"', '""') .. '"'
    end
    return v
end

local function row(out, ...)
    local n = select("#", ...)
    local parts = {}
    for i = 1, n do
        parts[i] = csv((select(i, ...)))
    end
    out[#out + 1] = table.concat(parts, ",")
end

-- Array joined with ";" -- vals is always a dense list of byte offsets.
local function joinVals(t)
    if type(t) ~= "table" then
        return nil
    end
    local parts = {}
    for i = 1, #t do
        parts[i] = csv(t[i])
    end
    return table.concat(parts, ";")
end

-- Value tables are keyed by the raw setting value, often from 0. Sort so the
-- dump does not inherit pairs() order.
local function joinTable(t)
    if type(t) ~= "table" then
        return nil
    end
    local keys = {}
    for k in pairs(t) do
        if type(k) == "number" then
            keys[#keys + 1] = k
        end
    end
    table.sort(keys)
    local parts = {}
    for i = 1, #keys do
        parts[i] = csv(keys[i]) .. "=" .. tostring(t[keys[i]])
    end
    return table.concat(parts, ";")
end

--------------------------------------------------------------------------------
-- Sandbox
--------------------------------------------------------------------------------

local function buildEnv(w, h, api)
    local env = {}

    -- Only what EdgeTX actually exposes. `table` is deliberately absent.
    env.assert = assert
    env.error = error
    env.ipairs = ipairs
    env.math = math
    env.next = next
    env.pairs = pairs
    env.pcall = pcall
    env.rawget = rawget
    env.rawset = rawset
    env.select = select
    env.setmetatable = setmetatable
    env.string = string
    env.tonumber = tonumber
    env.tostring = tostring
    env.type = type
    env.bit32 = bit32
    env.collectgarbage = function() end
    env._G = env

    env.LCD_W = w
    env.LCD_H = h

    for name, value in pairs(FLAG) do
        env[name] = value
    end
    -- The theme colours only exist on colour hardware. radios.lua and ui.lua
    -- both fall back through `COLOR_THEME_x or TEXT_COLOR or 0`, and that
    -- fallback is part of what we are pinning, so B&W resolutions must see nil.
    -- Mono is exactly the three entries radios.lua leaves without highRes;
    -- 320x240 is a colour radio despite being the smallest of them.
    if MONO[w .. "x" .. h] then
        env.COLOR_THEME_PRIMARY2 = nil
        env.COLOR_THEME_PRIMARY3 = nil
        env.COLOR_THEME_SECONDARY1 = nil
        env.COLOR_THEME_SECONDARY3 = nil
    end
    env.TEXT_COLOR = nil
    env.TEXT_BGCOLOR = nil
    env.LINE_COLOR = nil
    env.TITLE_BGCOLOR = nil
    env.MENU_TITLE_COLOR = nil

    env.EVT_VIRTUAL_ENTER = 0x0102
    env.EVT_VIRTUAL_INC = 0x0103

    env.apiVersion = api
    -- Matches the fixtures under bin/fixtures/. vtx.lua and pwm.lua assert on
    -- a per-MCU file the flight controller normally supplies; without one they
    -- fail to build and half the interesting geometry never gets dumped.
    env.mcuId = "HARNESS"
    env.features = { vtx = true, gps = true, osdSD = true }
    env.getTime = function()
        return 0
    end
    env.getRSSI = function()
        return 100
    end
    env.protocol = {
        mspRead = function() end,
        mspWrite = function() end,
        push = function() end,
    }
    env.mspProcessTxQ = function() end
    env.mspPollReply = function() end
    env.processMspReply = function() end
    env.mspSendRequest = function() end
    -- ui.lua defines clipValue as a global for vtx.lua's benefit; keep the
    -- same shape here so a page that calls it behaves identically.
    env.clipValue = function(val, min, max)
        if val < min then
            val = min
        elseif val > max then
            val = max
        end
        return val
    end
    env.io = {
        open = function()
            return nil
        end,
        write = function() end,
        close = function() end,
    }

    -- Falls back to bin/fixtures for the two directories a flight controller
    -- fills in at runtime (BOARD_INFO, VTX_TABLES). Returns nil rather than
    -- raising when a file is absent, which is what EdgeTX's loadScript does and
    -- what PAGES/INIT/* tests for.
    env.loadScript = function(path, _mode)
        return loadfile(BF .. path, "t", env) or loadfile(FIXTURES .. path, "t", env)
    end

    return env
end

--------------------------------------------------------------------------------
-- One (resolution, apiVersion, page)
--------------------------------------------------------------------------------

-- Deterministic stand-in for an MSP reply, built per page so every field lands
-- inside its own declared range. Feeding arbitrary bytes instead looks more
-- adversarial but is less useful: pages index tables and branch on exact values
-- (pwm.lua:194 only builds its rate tables for values[9] of 0 or 1), so an
-- out-of-range byte makes postLoad throw and no geometry downstream of it ever
-- gets walked. A mis-indexed `vals` is caught by the F records, which carry the
-- offsets verbatim, so the payload does not have to catch it too.
--
-- A third of the way up each range: repeatable, and never a boundary, so a
-- clamp that starts firing one step early still shows up.
local function cannedValues(Page)
    -- Bytes no field claims stay 0. They are not dead: pwm.lua:194 reads
    -- values[9] even on the API versions where no field maps to it, and any
    -- non-zero default sends it down a branch that leaves its rate tables
    -- empty. 0 is what a freshly-defaulted flight controller would send.
    local values = {}
    for i = 1, 128 do
        values[i] = 0
    end
    for i = 1, #Page.fields do
        local f = Page.fields[i]
        if f.vals then
            local lo = f.min or 0
            local hi = f.max or 255
            local raw = math.floor(lo + (hi - lo) / 3)
            for idx = 1, #f.vals do
                values[f.vals[idx]] = bit32.band(bit32.rshift(raw, (idx - 1) * 8), 0xFF)
            end
        end
    end
    return values
end

local function decodeFields(env, Page)
    if not Page.minBytes or #Page.values < Page.minBytes then
        return
    end
    for i = 1, #Page.fields do
        local f = Page.fields[i]
        if f.vals then
            f.value = 0
            for idx = 1, #f.vals do
                local raw = Page.values[f.vals[idx]] or 0
                raw = bit32.lshift(raw, (idx - 1) * 8)
                f.value = bit32.bor(f.value, raw)
            end
            local bits = #f.vals * 8
            if f.min and f.min < 0 and bit32.btest(f.value, bit32.lshift(1, bits - 1)) then
                f.value = f.value - (2 ^ bits)
            end
            f.value = f.value / (f.scale or 1)
        end
    end
end

local function dumpConfig(out, res, api, pagePath)
    local w, h = res[1], res[2]
    local resName = w .. "x" .. h
    local env = buildEnv(w, h, api)

    local radioChunk = loadfile(BF .. "radios.lua", "t", env)
    if not radioChunk then
        row(out, resName, api, pagePath, "E", "radios", "unreadable")
        return
    end
    local okRadio, radioAll = pcall(radioChunk)
    if not okRadio then
        row(out, resName, api, pagePath, "E", "radios", radioAll)
        return
    end
    local radio = radioAll.msp
    env.radio = radio

    local chunk = loadfile(BF .. pagePath, "t", env)
    if not chunk then
        row(out, resName, api, pagePath, "E", "load", "unreadable")
        return
    end
    local ok, Page = pcall(chunk)
    if not ok then
        row(out, resName, api, pagePath, "E", "build", Page)
        return
    end
    if type(Page) ~= "table" then
        row(out, resName, api, pagePath, "E", "build", "not a table")
        return
    end

    Page.labels = Page.labels or {}
    Page.fields = Page.fields or {}

    for i = 1, #Page.labels do
        local f = Page.labels[i]
        row(out, resName, api, pagePath, "L", i, f.x, f.y, f.t)
    end
    for i = 1, #Page.fields do
        local f = Page.fields[i]
        row(
            out,
            resName,
            api,
            pagePath,
            "F",
            i,
            f.x,
            f.y,
            f.sp,
            f.t,
            f.min,
            f.max,
            f.scale,
            f.mult,
            f.ro,
            joinVals(f.vals),
            joinTable(f.table)
        )
    end

    -- Feed a reply through, so the draw records carry real values and exercise
    -- postLoad. A postLoad that throws is recorded rather than swallowed: if a
    -- refactor changes which pages throw, that is a diff worth seeing.
    Page.values = cannedValues(Page)
    decodeFields(env, Page)
    if Page.postLoad then
        local okPost, errPost = pcall(Page.postLoad, Page)
        if not okPost then
            row(out, resName, api, pagePath, "E", "postLoad", errPost)
        end
    end

    if #Page.fields == 0 then
        return
    end

    -- ui.lua's drawScreen, verbatim in behaviour. pageScrollY is deliberately
    -- carried across iterations: it is an upvalue there too, so where the view
    -- lands depends on the order fields were visited.
    local yMinLim = radio.yMinLimit
    local yMaxLim = radio.yMaxLimit
    local globalTextOptions = env.COLOR_THEME_SECONDARY1 or env.TEXT_COLOR or 0
    local pageScrollY = 0

    for currentField = 1, #Page.fields do
        local currentFieldY = Page.fields[currentField].y
        local textOptions = radio.textSize + globalTextOptions
        if currentFieldY <= Page.fields[1].y then
            pageScrollY = 0
        elseif currentFieldY - pageScrollY <= yMinLim then
            pageScrollY = currentFieldY - yMinLim
        elseif currentFieldY - pageScrollY >= yMaxLim then
            pageScrollY = currentFieldY - yMaxLim
        end

        local seq = 0
        for i = 1, #Page.labels do
            local f = Page.labels[i]
            local y = f.y - pageScrollY
            if y >= 0 and y <= h then
                seq = seq + 1
                row(out, resName, api, pagePath, "D", currentField, seq, f.x, math.floor(y), f.t, textOptions)
            end
        end

        -- Hoisted exactly as ui.lua hoists it: a field with no .value redraws
        -- the previous field's value. Visible on API 1.36, where vtx.lua makes
        -- a Frequency field with no vals.
        local val = "---"
        for i = 1, #Page.fields do
            local f = Page.fields[i]
            local valueOptions = textOptions
            if i == currentField then
                valueOptions = valueOptions + FLAG.INVERS
            end
            if f.value then
                if f.upd and Page.values then
                    local okUpd, errUpd = pcall(f.upd, Page)
                    if not okUpd then
                        row(out, resName, api, pagePath, "E", "upd", errUpd)
                    end
                end
                val = f.value
                if f.table and f.table[f.value] then
                    val = f.table[f.value]
                end
            end
            local y = f.y - pageScrollY
            if y >= 0 and y <= h then
                if f.t then
                    seq = seq + 1
                    row(out, resName, api, pagePath, "D", currentField, seq, f.x, math.floor(y), f.t, textOptions)
                end
                seq = seq + 1
                row(out, resName, api, pagePath, "D", currentField, seq, f.sp or f.x, math.floor(y), val, valueOptions)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Main
--------------------------------------------------------------------------------

local function fnv1a(s)
    local h = 0x811C9DC5
    for i = 1, #s do
        h = (h ~ s:byte(i)) & MASK
        h = (h * 0x01000193) & MASK
    end
    return string.format("%08x", h)
end

local full = { "resolution,api,page,kind,a,b,c,d,e,f,g,h,i,j,k,l" }
local summary = { "resolution,api,page,labels,fields,draws,errors,geomsum,drawsum" }

for _, res in ipairs(RESOLUTIONS) do
    local resName = res[1] .. "x" .. res[2]
    for _, api in ipairs(API_VERSIONS) do
        for _, page in ipairs(PAGES) do
            local key = string.format("%s,%.14g,%s", resName, api, page)
            if not ONLY or key:find(ONLY, 1, true) then
                local rows = {}
                dumpConfig(rows, res, api, page)

                -- Geometry and draws are summed apart so a mismatch says
                -- whether the page moved or only the render walked it
                -- differently -- the two fail for very different reasons.
                local geom, draws = {}, {}
                local nL, nF, nD, nE = 0, 0, 0, 0
                for i = 1, #rows do
                    local kind = rows[i]:match("^[^,]*,[^,]*,[^,]*,([^,]*)")
                    if kind == "D" then
                        nD = nD + 1
                        draws[#draws + 1] = rows[i]
                    else
                        if kind == "L" then
                            nL = nL + 1
                        elseif kind == "F" then
                            nF = nF + 1
                        else
                            nE = nE + 1
                        end
                        geom[#geom + 1] = rows[i]
                    end
                    full[#full + 1] = rows[i]
                end

                summary[#summary + 1] = string.format(
                    "%s,%d,%d,%d,%d,%s,%s",
                    key,
                    nL,
                    nF,
                    nD,
                    nE,
                    fnv1a(table.concat(geom, "\n")),
                    fnv1a(table.concat(draws, "\n"))
                )
            end
        end
    end
end

local fullText = table.concat(full, "\n") .. "\n"
local summaryText = table.concat(summary, "\n") .. "\n"

local fh = assert(io.open(OUT, "w"))
fh:write(fullText)
fh:close()

fh = assert(io.open(SUM, "w"))
fh:write(summaryText)
fh:close()

print(string.format("layout_dump: %d configs, %d rows -> %s, %s", #summary - 1, #full - 1, OUT, SUM))

if CMP then
    local golden = io.open(CMP, "r")
    if not golden then
        print("layout_dump: no golden at " .. CMP)
        exit(1)
    end
    local want = golden:read("a")
    golden:close()
    if want ~= summaryText then
        print("layout_dump: MISMATCH -- diff " .. CMP .. " " .. SUM)
        print("layout_dump: then re-run with BF_ONLY=<resolution,api,page> for the rows")
        exit(1)
    end
    print("layout_dump: matches " .. CMP)
end

exit(0)
