local schema = assert(loadScript("schema.lua"))()

return schema.page({
    read = 240, -- MSP_ACC_TRIM
    write = 239, -- MSP_SET_ACC_TRIM
    title = "Acc",
    reboot = false,
    eepromWrite = true,
    minBytes = 4,
    rows = {
        { head = "Trim Accelerometer" },
        { name = "pitch", t = "Pitch", indent = 1, min = -300, max = 300, vals = { 1, 2 } },
        { name = "roll", t = "Roll", indent = 1, min = -300, max = 300, vals = { 3, 4 } },
    },
})
