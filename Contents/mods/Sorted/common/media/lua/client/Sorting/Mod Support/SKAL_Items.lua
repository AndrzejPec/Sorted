require("Sorting/ItemTweaker_Copy_CC");

--SKAL
--Support for SKAL module items
if getActivatedMods():contains("SKAL") then

local moduleName = "SKAL";

-- All SKAL items with "Log" in the name -> Drugs category
TweakItem(moduleName..".SkalMintLog","DisplayCategory","Drugs");
TweakItem(moduleName..".SkalStraightLog","DisplayCategory","Drugs");
TweakItem(moduleName..".SkalWintergreenLog","DisplayCategory","Drugs");
TweakItem(moduleName..".KojakMintLog","DisplayCategory","Drugs");
TweakItem(moduleName..".XenMintLog","DisplayCategory","Drugs");
TweakItem(moduleName..".XenCoffeeLog","DisplayCategory","Drugs");
TweakItem(moduleName..".HalkenWintergreenLog","DisplayCategory","Drugs");

end
