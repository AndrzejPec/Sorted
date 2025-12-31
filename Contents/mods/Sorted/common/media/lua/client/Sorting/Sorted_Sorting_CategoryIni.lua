if not Sorted then
  Sorted = {}
end

if Sorted._dynamicCategoryPersistLoaded then
  return
end
Sorted._dynamicCategoryPersistLoaded = true

Sorted.dynamicCategoryPersist = Sorted.dynamicCategoryPersist or {
  seen = {},
  pending = {},
}

local function shouldPersistCategory(category)
  if not category or category == "" then
    return false
  end
  if category == "Container" then
    return false
  end
  return string.sub(category, 1, 4) == "Food"
end

local function canWrite()
  return Sorted and Sorted.writeCategoryToIni and Sorted.getSavedCategory
end

local function flushPending()
  if not canWrite() then
    return
  end

  for fullType, category in pairs(Sorted.dynamicCategoryPersist.pending) do
    local saved = Sorted.getSavedCategory(fullType)
    if not saved or saved == "none" then
      Sorted.writeCategoryToIni(fullType, category, true)
    end
  end

  Sorted.dynamicCategoryPersist.pending = {}
end

function Sorted.persistDynamicCategory(fullType, category)
  if not fullType or not shouldPersistCategory(category) then
    return
  end

  local lastCategory = Sorted.dynamicCategoryPersist.seen[fullType]
  if lastCategory == category then
    return
  end

  if canWrite() then
    local saved = Sorted.getSavedCategory(fullType)
    if saved and saved ~= "none" then
      Sorted.dynamicCategoryPersist.seen[fullType] = category
      return
    end

    Sorted.writeCategoryToIni(fullType, category, true)
  else
    Sorted.dynamicCategoryPersist.pending[fullType] = category
  end

  Sorted.dynamicCategoryPersist.seen[fullType] = category
end

if Events and Events.OnGameBoot then
  Events.OnGameBoot.Add(flushPending)
end
