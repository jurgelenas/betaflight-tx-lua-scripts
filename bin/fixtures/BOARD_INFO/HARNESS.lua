-- Stand-in for the BOARD_INFO/<mcuId>.lua that board_info.lua downloads from a
-- flight controller. Only bin/layout_dump.lua reads it; nothing ships.
--
-- pwm.lua (apiVersion >= 1.44) reads gyroSampleRateHz and nothing else, but the
-- rest of the shape is kept so the fixture stays a faithful sample of what the
-- writer at board_info.lua:109 emits.
return {
    boardIdentifier = "S405",
    hardwareRevision = 0,
    boardType = 2,
    targetCapabilities = 255,
    targetName = "STM32F405",
    boardName = "HARNESS",
    manufacturerId = "TEST",
    signature = {},
    mcuTypeId = 1,
    configurationState = 2,
    gyroSampleRateHz = 8000,
    configurationProblems = 0,
    spiRegisteredDeviceCount = 3,
    i2cRegisteredDeviceCount = 1,
}
