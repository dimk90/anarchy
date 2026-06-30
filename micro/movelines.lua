VERSION = "1.0.0"

local buffer = import("micro/buffer")

-- micro's built-in MoveLinesUp moves the selected block but leaves the active
-- cursor on its original line instead of carrying it upward with the block.
-- Because BufPane:Relocate() scrolls only to follow the active cursor, the view
-- never scrolls when the block leaves the top of the viewport. (MoveLinesDown
-- is unaffected: there the cursor does travel down with the block.) This wrapper
-- re-points the cursor onto the top line of the moved block, then relocates, so
-- the view follows the selection upward.
function moveUp(bufpane)
    bufpane:MoveLinesUp()

    local cursor = bufpane.Cursor
    if cursor:HasSelection() then
        -- Land the cursor on the block's first line (the topmost endpoint), so
        -- Relocate has a reason to scroll the viewport up to it. CurSelection
        -- entries come back as *Loc, so compare X/Y directly and rebuild a Loc
        -- value for GotoLoc rather than calling Loc methods on a pointer.
        local first = cursor.CurSelection[1]
        local second = cursor.CurSelection[2]
        local top = first
        if second.Y < first.Y or (second.Y == first.Y and second.X < first.X) then
            top = second
        end
        cursor:GotoLoc(buffer.Loc(top.X, top.Y))
    end

    bufpane:Relocate()
end
