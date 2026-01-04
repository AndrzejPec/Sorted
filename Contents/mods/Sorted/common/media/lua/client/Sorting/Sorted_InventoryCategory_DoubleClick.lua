---@diagnostic disable: inject-field, param-type-mismatch

-- Patch to enable double-click on category column in inventory to open category change modal

require "ISUI/ISInventoryPane"

Sorted = Sorted or {}

-- Store original onMouseDoubleClick
local original_onMouseDoubleClick = ISInventoryPane.onMouseDoubleClick

---Override onMouseDoubleClick to detect double-click on category column
---@param x number
---@param y number
function ISInventoryPane:onMouseDoubleClick(x, y)
    Sorted:log("[DoubleClick] onMouseDoubleClick called - x: " .. tostring(x) .. ", y: " .. tostring(y))
    Sorted:log("[DoubleClick] self.column3: " .. tostring(self.column3))
    Sorted:log("[DoubleClick] self.mouseOverOption: " .. tostring(self.mouseOverOption))
    Sorted:log("[DoubleClick] self.previousMouseUp: " .. tostring(self.previousMouseUp))

    -- First check if the double-click is in the category column area
    if self.items and self.mouseOverOption and self.previousMouseUp == self.mouseOverOption then
        Sorted:log("[DoubleClick] Basic conditions met - checking column position")

        -- column3 is where the category column starts
        if x >= self.column3 then
            Sorted:log("[DoubleClick] Click is in category column area!")

            local item = self.items[self.mouseOverOption]
            Sorted:log("[DoubleClick] Item type: " .. tostring(type(item)))

            -- If it's a collapsed stack, get the first item
            if item and not instanceof(item, "InventoryItem") then
                Sorted:log("[DoubleClick] Item is a stack, getting first item")
                if item.items and #item.items > 0 then
                    item = item.items[1]
                    Sorted:log("[DoubleClick] Got first item from stack")
                end
            end

            -- If we have a valid inventory item, open the category modal
            if item and instanceof(item, "InventoryItem") then
                Sorted:log("[DoubleClick] Valid inventory item found!")
                if Sorted.openModal then
                    Sorted:log("[DoubleClick] Opening modal for item: " .. tostring(item:getDisplayName()))
                    Sorted.openModal(item)
                    self.previousMouseUp = nil
                    return -- Don't execute default double-click behavior
                else
                    Sorted:log("[DoubleClick] ERROR: Sorted.openModal not found!")
                end
            else
                Sorted:log("[DoubleClick] Item is not a valid InventoryItem")
            end
        else
            Sorted:log("[DoubleClick] Click is NOT in category column (x < column3)")
        end
    else
        Sorted:log("[DoubleClick] Basic conditions NOT met - falling through to original handler")
    end

    -- Call original handler for all other cases
    if original_onMouseDoubleClick then
        Sorted:log("[DoubleClick] Calling original handler")
        original_onMouseDoubleClick(self, x, y)
    else
        Sorted:log("[DoubleClick] No original handler found")
    end
end

if Sorted and Sorted.log then
    Sorted:log("[Sorted] Inventory category double-click patch loaded", 3)
end
