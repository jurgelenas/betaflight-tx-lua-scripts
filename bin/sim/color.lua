-- The colour counterpart to bw.lua, on a 480x272 TX16S. Screenshots land in
-- obj/sim-color/.
--
-- Two uses. Normally it walks the LVGL renderer. Set useLvgl to false in
-- bf.lua and it walks the same radio through the lcd.* fallback instead, which
-- is the only way to see what a colour radio on firmware older than 2.11.4
-- gets -- there is no cached simulator image for one. The two produce
-- different screens on purpose; the shots are named for what is being done,
-- not for which page happens to be under it.
--
-- Everything here is rotary plus ENTER, no touch. That is the point: every
-- button in the header is compiled under HARDWARE_TOUCH, so if the tool is not
-- fully drivable from the rotary it is not drivable at all on a radio whose
-- screen is not being poked.
--
-- TX16S has no arrow keys, and unlike gx12 a rotary step is worth 1. Getting
-- into the tool is SYS -> four tiles right to Tools -> ENTER -> ENTER on
-- Apps -> one right to "Betaflight setup", because "Betaflight CMS" sorts
-- first.

local SHOT = "obj/sim-color/"

key.press(KEY.SYS)
wait(1.5)
rotary(1)
wait(0.3)
rotary(1)
wait(0.3)
rotary(1)
wait(0.3)
rotary(1)
wait(0.5)
key.press(KEY.ENTER)
wait(1.5)
key.press(KEY.ENTER)
wait(2)
rotary(1)
wait(0.5)

-- First entry runs the COMPILE pass and exits back to the Apps list.
key.press(KEY.ENTER)
wait(30)

key.press(KEY.ENTER)
wait(6)
screenshot(SHOT .. "01-mainmenu.png")

-- The flight-controller actions are at the far end of the page list. Rotary
-- left from the first entry wraps to the last, which beats fifteen steps down.
rotary(-1)
wait(1)
screenshot(SHOT .. "02-mainmenu-actions.png")

-- Two back from "Download Board Info" is "Calibrate Accelerometer" -- the one
-- action whose confirmation can be cancelled without writing to the SD card.
rotary(-1)
wait(0.3)
rotary(-1)
wait(0.5)
key.press(KEY.ENTER)
wait(2)
screenshot(SHOT .. "03-confirm.png")

key.press(KEY.EXIT)
wait(2)

-- Back on a freshly built main menu, focus is on the first page.
key.press(KEY.ENTER)
wait(3)
screenshot(SHOT .. "04-page.png")

-- A page opens with nothing focused; the rotary ring is one detent for the
-- header nav arrows, then the rows, then "Save page" -- four detents on a
-- two-row page.
rotary(1)
wait(0.3)
rotary(1)
wait(0.3)
rotary(1)
wait(0.3)
rotary(1)
wait(0.5)
screenshot(SHOT .. "05-save-focus.png")

key.press(KEY.ENTER)
wait(3)
screenshot(SHOT .. "06-saved.png")

key.press(KEY.PAGEDN)
wait(3)
screenshot(SHOT .. "07-nextpage.png")

-- After a page turn one detent reaches the first editor.
rotary(1)
wait(0.5)
key.press(KEY.ENTER)
wait(1)
screenshot(SHOT .. "08-edit.png")

key.press(KEY.EXIT)
wait(1)

-- Two pages on from PIDs 1 is Rates: scaled values end to end. The mock serves
-- Betaflight's power-on defaults, so this screen has to read centre
-- sensitivity 70, max rate 670, expo 0.00 and throttle mid 0.50 -- a renderer
-- that floors scaled values shows 0 across the board here.
key.press(KEY.PAGEDN)
wait(3)
key.press(KEY.PAGEDN)
wait(3)
screenshot(SHOT .. "09-rates.png")

-- Ten detents from a fresh turn is "Rates Type": nine grid editors, then the
-- choice. Picking BETAFLIGHT (three back from ACTUAL) runs the field's
-- postEdit, which swaps every rate row's label, range and scale -- the screen
-- has to come back reading RC Rate 1.00, Super Rate 0.70, Expo 0.00.
for _ = 1, 10 do
    rotary(1)
    wait(0.25)
end
key.press(KEY.ENTER)
wait(1)
rotary(-3)
wait(0.5)
key.press(KEY.ENTER)
wait(2)
screenshot(SHOT .. "10-ratestype-bf.png")

key.press(KEY.EXIT)
wait(2)
screenshot(SHOT .. "11-back.png")

exit(0)
