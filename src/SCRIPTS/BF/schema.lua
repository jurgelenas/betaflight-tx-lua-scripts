-- Turns a list of rows into the labels/fields arrays the renderers consume.
--
-- Every page used to compute its own coordinates, which meant ~20 copies of the
-- same margin/indent/lineSpacing arithmetic and an `inc.y` closure, and it
-- meant reading a page to find out what settings it has. A row here says what
-- it is; where it lands is this file's problem.
--
-- The coordinates it emits are exactly the ones the hand-written version
-- produced -- bin/layout.golden.csv is what holds that true, across all eight
-- resolutions and every API version the pages branch on.
--
-- Rows are reused in place as the label or field object rather than copied, so
-- a page costs one array of tables plus two index arrays, not two of each. That
-- matters on a 128x64 radio, where the whole Lua heap is around 40 KB.
--
-- A row is a label when it has `head`, and a field otherwise:
--
--   { head = "Gyro Lowpass 1" }                         a heading
--   { t = "Cutoff", indent = 1, min = 0, max = 1000, vals = { 1, 2 } }
--   { t = "Type", indent = 1, min = 0, max = 1,
--     vals = { 3 }, table = { [0] = "PT1", "BIQUAD" } }
--
-- `indent` is in indent steps, not pixels. `name` is optional and puts the row
-- in Page.byName, which is what a postLoad or preSave should reach for instead
-- of counting its way along self.fields.

local template = assert(loadScript(radio.template))()

local schema = {}

--- Lay out a page definition. `def.rows` is consumed and replaced by `labels`,
--- `fields` and `byName`; everything else on `def` (read, write, title,
--- minBytes, postLoad, ...) is passed through untouched.
function schema.page(def)
    local margin = template.margin
    local indentWidth = template.indent
    local lineSpacing = template.lineSpacing
    local valueColumn = margin + template.listSpacing.field

    -- One line per row, starting one line above the first so the first
    -- increment lands on it -- the same walk every page did by hand.
    local y = radio.yMinLimit - lineSpacing

    local labels = {}
    local fields = {}
    local byName = {}

    local rows = def.rows
    for i = 1, #rows do
        local row = rows[i]
        y = y + lineSpacing
        row.y = y
        row.x = margin + (row.indent or 0) * indentWidth
        row.indent = nil

        if row.head then
            row.t = row.head
            row.head = nil
            labels[#labels + 1] = row
        else
            row.sp = valueColumn
            fields[#fields + 1] = row
            if row.name then
                byName[row.name] = row
            end
        end
    end

    def.rows = nil
    def.labels = labels
    def.fields = fields
    def.byName = byName
    return def
end

return schema
