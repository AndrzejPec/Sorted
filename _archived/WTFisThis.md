# _archived/

This folder contains files that were removed from the active mod codebase but are preserved here intentionally — either because they contain ideas worth revisiting, serve as a reference for future projects, or document a previous approach.

These files are **not loaded by the game** (they live outside the `media/lua/` folder).

---

## Files

### `0_LoL_debug.lua`

**Origin:** Was loaded as part of the Sorted mod's client-side Lua scripts (`media/lua/client/`).

**Why it's here:** This file was the early foundation of a planned standalone library called **LibraryOfLouisville (LoL)**. It contains a collection of debugging utilities, event probes, fluid analysis helpers, item inspection tools, and tag enumeration routines — all written during Sorted's development as exploratory/diagnostic code.

The LoL namespace (`LoL = LoL or {}`) was intended to eventually become a general-purpose utility library for PZ modding, extracted from Sorted and published separately. The code is commented out because it was never production-ready, but the ideas and patterns here are worth carrying forward when that project gets started.

**Planned next use:** LibraryOfLouisville — a standalone PZ modding utility library.

---

### `Sorted_Sorting_Categories.lua`

**Origin:** `media/lua/client/Sorting/`

**Why it's here:** This was the original hand-curated category assignment system. It used `TweakItem()` calls to override `DisplayCategory` for individual items, written before the `ItemDictionary` algorithm-based categorization existed.

All the `TweakItem()` calls are commented out because the ItemDictionary system (with `algorithm`, `mapped`, `user` hierarchy) replaced this approach entirely. The file still contains a `require("Sorting/Sorted_Sorting_ItemTweaker_CC")` which was the TweakItem infrastructure.

**Reference value:** The item list here shows which items had problematic categories in early B42 and how they were originally fixed. Useful as a lookup if regression issues appear.

---

### `Sorted_Shifting_Manager_old.lua`

**Origin:** `media/lua/client/Shifting/`

**Why it's here:** The original single-window category manager UI (`Sorted.Manager`). Replaced entirely by `Sorted_Shifting_Manager.lua` which introduced the `ManagerMC` multi-column approach with bulk editing.

The old implementation used `ISScrollingListBox` directly and wrote assignments to an INI file without going through ItemDictionary. The new one integrates with the source-of-truth system.

**Reference value:** If the current Manager UI needs a simpler fallback mode or reference for how ISPanel/ISScrollingListBox was wired up previously.

---

### `SKAL_Items.lua`

**Origin:** `media/lua/client/Sorting/Mod Support/`

**Why it's here:** A placeholder file for compatibility with the **SKAL** mod (smokeless tobacco items). The `TweakItem()` calls that would assign `Drugs` category to SKAL items are all commented out, because the SKAL mod compatibility was never implemented beyond this stub.

**Planned next use:** If SKAL support is added in the future, this file shows which items need categorizing and what category they should get. Can be un-archived and adapted to use `setAlgorithmCategory()` instead of TweakItem.
