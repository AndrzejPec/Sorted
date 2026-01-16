
if not ItemTweaker then  ItemTweaker = {} end
if not TweakItem then  TweakItem = {} end
if not TweakItemData then  TweakItemData = {} end

local function sortedLog(msg, lvl)
	if Sorted and Sorted.log then
		Sorted:log(msg, lvl or 3)
		return
	end
	print(msg)
end

function ItemTweaker.tweakItems()
	local item;
	for k,v in pairs(TweakItemData) do
		for t,y in pairs(v) do
			item = ScriptManager.instance:getItem(k);
			if item ~= nil then
				item:DoParam(t.." = "..y);
				sortedLog(k..": "..t..", "..y)
			end
		end
	end
end

function TweakItem(itemName, itemProperty, propertyValue)
	if not TweakItemData[itemName] then
		TweakItemData[itemName] = {};
	end
	TweakItemData[itemName][itemProperty] = propertyValue;
end




