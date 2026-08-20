local schema = assert(loadScript("schema.lua"))()

return schema.page({
    read = 32, -- MSP_BATTERY_CONFIG
    write = 33, -- MSP_SET_BATTERY_CONFIG
    title = "Battery",
    reboot = true,
    eepromWrite = true,
    minBytes = 13,
    rows = {
        { head = "Voltage Settings" },
        { name = "minCell", t = "Minimum Cell", indent = 1, min = 0, max = 500, vals = { 8, 9 }, scale = 100 },
        { name = "maxCell", t = "Maximum Cell", indent = 1, min = 0, max = 500, vals = { 10, 11 }, scale = 100 },
        { name = "warnCell", t = "Warning Cell", indent = 1, min = 0, max = 500, vals = { 12, 13 }, scale = 100 },

        { head = "Capacity Settings" },
        { name = "capacity", t = "Battery Capacity", indent = 1, min = 0, max = 20000, mult = 25, vals = { 4, 5 } },
    },
})
