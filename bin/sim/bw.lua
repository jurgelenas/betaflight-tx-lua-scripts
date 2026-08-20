-- Drives the B&W tool through the screens a renderer change could move, and
-- screenshots each one into obj/sim/. Run `make sim-bw` before and after a
-- refactor and md5sum the two directories: at 128x64 the difference between
-- "the list scrolled" and "the list did not" is a few pixels, so comparing by
-- eye has already produced one wrong conclusion on this project.
--
-- Deterministic because `make sim-bw` deletes obj/sim-sd first: the simulator
-- reinstalls the package, scripts_compiled.lua comes back as `return false`,
-- and the COMPILE pass always runs. Without that the first ENTER lands
-- somewhere different depending on whether the card was warm.
--
-- gx12 has only EXIT ENTER PAGEUP PAGEDN SYS plus the rotary, and a rotary
-- step is worth 2 -- see the skill notes.

local SHOT = "obj/sim/"

key.press(KEY.SYS)
wait(1)

-- Row 02 of the Tools list is "Betaflight setup".
rotary(2)
wait(0.4)

-- First entry runs the COMPILE pass, which exits back to the Tools list.
key.press(KEY.ENTER)
wait(30)

-- Second entry is the tool proper. The mock answers the init handshake within
-- a few frames.
key.press(KEY.ENTER)
wait(6)
screenshot(SHOT .. "01-mainmenu.png")

key.press(KEY.ENTER)
wait(3)
screenshot(SHOT .. "02-profiles.png")

key.press(KEY.PAGEDN)
wait(3)
screenshot(SHOT .. "03-pids1.png")

-- Two fields down: far enough to prove focus moves, not far enough to scroll.
rotary(2)
wait(0.3)
rotary(2)
wait(0.3)
screenshot(SHOT .. "04-pids1-focus.png")

key.press(KEY.ENTER)
wait(0.5)
screenshot(SHOT .. "05-pids1-edit.png")

key.press(KEY.EXIT)
wait(0.5)

key.press(KEY.PAGEDN)
wait(3)
key.press(KEY.PAGEDN)
wait(3)
screenshot(SHOT .. "06-rates.png")

-- Long ENTER opens the popup menu, which is the one piece of chrome the
-- controller owns the contents of and the renderer owns the box for.
key.longpress(KEY.ENTER)
wait(1)
screenshot(SHOT .. "07-popupmenu.png")

key.press(KEY.EXIT)
wait(0.5)
key.press(KEY.EXIT)
wait(2)
screenshot(SHOT .. "08-mainmenu-back.png")

exit(0)
