if not getActivatedMods():contains("TheyKnewB42") then
  return
end

if not Sorted then
  Sorted = {}
end

function Sorted.getZomboxCategory(item)
  if not item or not item.getFullName then
    return nil
  end

  local fullName = item:getFullName()
  if fullName and fullName:sub(1, 6) == "Zombox" then
    return "FirstAid"
  end

  return nil
end
