-- Stand-in for the VTX_TABLES/<mcuId>.lua that vtx_tables.lua downloads from a
-- flight controller. Only bin/layout_dump.lua reads it; nothing ships.
--
-- Same five bands as VTX_TABLES/vtx_defaults.lua, plus the powerTable that only
-- the downloaded form carries -- vtx.lua takes a different branch for each
-- (vtx.lua:273), so the harness needs the richer one to reach both.
return {
    frequencyTable = {
        { 5865, 5845, 5825, 5805, 5785, 5765, 5745, 5725 },
        { 5733, 5752, 5771, 5790, 5809, 5828, 5847, 5866 },
        { 5705, 5685, 5665, 5645, 5885, 5905, 5925, 5945 },
        { 5740, 5760, 5780, 5800, 5820, 5840, 5860, 5880 },
        { 5658, 5695, 5732, 5769, 5806, 5843, 5880, 5917 },
    },
    frequenciesPerBand = 8,
    bandTable = { [0] = "U", "A", "B", "E", "F", "R" },
    powerTable = { "25", "100", "200", "400", "600" },
}
