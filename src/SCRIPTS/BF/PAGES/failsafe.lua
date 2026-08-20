local schema = assert(loadScript("schema.lua"))()

local procedure = { [0] = "Land", "Drop" }
if apiVersion >= 1.39 then
    procedure[#procedure + 1] = "Rescue"
end

local rows = {}

if apiVersion >= 1.39 then
    rows[#rows + 1] = { head = "Failsafe Switch" }
    rows[#rows + 1] = {
        name = "action",
        t = "Action",
        indent = 1,
        min = 0,
        max = 2,
        vals = { 5 },
        table = { [0] = "Stage 1", "Kill", "Stage 2" },
    }
else
    -- No heading above it, so it sits at the left margin rather than indented
    -- under one.
    rows[#rows + 1] = {
        name = "killSwitch",
        t = "Kill switch",
        min = 0,
        max = 1,
        vals = { 5 },
        table = { [0] = "OFF", "ON" },
    }
end

rows[#rows + 1] = { head = "Stage 2 Settings" }
rows[#rows + 1] =
    { name = "procedure", t = "Procedure", indent = 1, min = 0, max = #procedure, vals = { 8 }, table = procedure }
rows[#rows + 1] = { name = "guardTime", t = "Guard Time", indent = 1, min = 0, max = 200, vals = { 1 }, scale = 10 }
rows[#rows + 1] =
    { name = "throttleLowDelay", t = "Thrl Low Delay", indent = 1, min = 0, max = 300, vals = { 6, 7 }, scale = 10 }

rows[#rows + 1] = { head = "Stage 2 Land Settings" }
rows[#rows + 1] = { name = "landThrottle", t = "Thrl Land Value", indent = 1, min = 750, max = 2250, vals = { 3, 4 } }
rows[#rows + 1] =
    { name = "motorOffDelay", t = "Motor Off Delay", indent = 1, min = 0, max = 200, vals = { 2 }, scale = 10 }

return schema.page({
    read = 75, -- MSP_FAILSAFE_CONFIG
    write = 76, -- MSP_SET_FAILSAFE_CONFIG
    title = "Failsafe",
    reboot = true,
    eepromWrite = true,
    minBytes = 8,
    rows = rows,
})
