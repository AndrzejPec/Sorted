-- Patch for ManageContainers mod to recognize dynamic fluid categories
-- ManageContainers pobiera kategorie podczas inicjalizacji, ale nasze kategorie
-- (FoodM, FoodW, FoodB, FoodA) są nadawane dynamicznie dla fluid containers.
-- Ten patch zapewnia że ManageContainers widzi nasze dynamiczne kategorie.

if not getActivatedMods():contains("ManageContainers") then
  return
end

print("[Sorted] ManageContainers patch loading...")

-- Poczekaj aż ISItemsIncludeExclude się załaduje
local function patchManageContainers()
  if not ISItemsIncludeExclude then
    print("[Sorted] ManageContainers: ISItemsIncludeExclude not loaded yet, waiting...")
    return false
  end

  -- Zachowaj oryginalną funkcję populate
  if not ISItemsIncludeExclude._original_populate then
    ISItemsIncludeExclude._original_populate = ISItemsIncludeExclude.populate

    -- Override populate aby dodać nasze dynamiczne kategorie
    function ISItemsIncludeExclude:populate()
      -- Wywołaj oryginalną funkcję
      self:_original_populate()

      -- Dodaj nasze dynamiczne kategorie do dropdown listy DisplayCategory
      local combo = self.filterWidgetMap and self.filterWidgetMap.DisplayCategory
      if combo then
        -- Lista dynamicznych kategorii z Sorted
        local dynamicCategories = {
          "FoodM",  -- Milk (fluid containers z mlekiem)
          "FoodW",  -- Water (czysta woda)
          "FoodB",  -- Beverages (napoje)
          "FoodA",  -- Alcoholic (alkohol)
          "Fuel",   -- Paliwo
          "Drugs",  -- Narkotyki/logi tytoniowe (SKAL mod)
          "Plush",  -- Pluszaki
        }

        -- Sprawdź które kategorie już są w liście
        local existingOptions = {}
        for i = 1, combo:getOptionCount() do
          local optionText = combo:getOptionText(i)
          if optionText then
            existingOptions[optionText] = true
          end
        end

        -- Dodaj tylko te które nie istnieją
        local added = 0
        for _, category in ipairs(dynamicCategories) do
          if not existingOptions[category] then
            combo:addOption(category)
            added = added + 1
          end
        end

        if added > 0 then
          print("[Sorted] ManageContainers: Added " .. added .. " dynamic categories")
        end
      end
    end

    print("[Sorted] ManageContainers patch installed successfully!")
    return true
  end

  return true
end

-- Spróbuj zainstalować patch
local function attemptPatch()
  if patchManageContainers() then
    print("[Sorted] ManageContainers patch ready")
  else
    -- Jeśli się nie udało, spróbuj ponownie po OnGameBoot
    Events.OnGameBoot.Add(function()
      patchManageContainers()
    end)
  end
end

-- Zainstaluj patch
attemptPatch()
