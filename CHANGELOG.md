# Changelog - Bleakfiber's Quest Tracker (Forever)

All notable changes to **Bleakfiber's Quest Tracker - Forever** are documented below.

## [1.2.4] - 2026-10-22: Quest Item Buttons for Changing Items and Sound File Fix

### Fixed
- **Quest item button disappearing when the item changes**:
  - Some quests turn their item into a new one partway through, for example an empty bowl you fill at a moonwell and then place. The button used to vanish once the original item was gone.
  - The tracker now remembers each quest's item and, when it changes form, finds the new version in your bags (for example *Empty Cleansing Bowl* becoming *Filled Cleansing Bowl*), so the button stays.
- **Lua errors with other addons that use LibSharedMedia**: some addons (for example Basic Minimap) load a newer LibSharedMedia that rejects .wav sound files, which caused two errors at login. This is fixed.

### Changed
- **Updated LibSharedMedia**: the tracker now bundles the latest LibSharedMedia-3.0 (v12.1.3).
- **Sounds are now .ogg and .mp3 only**:
  - The bundled sounds have been converted to .ogg.
  - **If you added your own custom sounds as .wav files, you need to convert them to .ogg** (keep the same name, for example `fart.wav` becomes `fart.ogg`) and restart the game. Your saved sound settings already point to the .ogg name, so nothing else needs changing.
  - The first time you log in after updating, a message lists any of your sound files that need converting.
  - Adding a new custom sound only accepts .ogg and .mp3 files.

## [1.2.3] - 2026-10-20: Markers for Quests New in WoW Forever

### Added
- **See which quests are new in WoW Forever**:
  - Quests that were not in original Classic now get a small infinity marker on their title in the tracker.
  - Hovering one of these quests shows a **New in WoW Forever** line in its tooltip.
  - The list of new quests was gathered directly from the WoW game clients, by comparing the quest data in the WoW Forever client with the quest data in the original Classic (Classic Era) client. It covers 1,808 quests and does not rely on any other addon.
- **Marker settings** in **Settings > Quests & Items > Forever Quests**:
  - Turn the marker on or off, place it before or after the quest name, and choose the infinity icon or a **[F]** text badge.
  - Pick its size and color, and optionally tint the whole quest name in the marker color.
- **New command `/bfq questid`**: hover a quest in the tracker (or type a quest ID after the command) to see the quest's ID and whether it is new in WoW Forever. Handy for reporting a quest that looks wrongly marked.

## [1.2.2] - 2026-10-19: Quest Action Buttons, Classic Quest Log Support, and No More Dead Space

### Added
- **Quest action buttons** (optional, off by default):
  - Small buttons at the right end of each quest title: **Set Active**, **Show on Map**, **Share** (only while you are in a group and the quest can be shared) and **Open Quest**.
  - Choose **Off**, **Show on Hover** or **Always** in **Settings > Quests & Items > Quest Action Buttons**, set the button size, and switch each button on or off.
  - The buttons always sit to the left of the quest item button and never cover it.
  - **Open Quest**: left-click opens the quest on the world map, right-click opens it in a classic quest log addon.
  - Show on Map and Open Quest are greyed out in combat, because the game does not allow opening those windows during a fight.
- **Choose where quests open**:
  - New **Open Quests In** setting: **World Map (Blizzard)**, **Classic Quest Log** or **Both**.
  - It applies to Ctrl+Click on a quest, **Show in Quest Log** in the quest menu, and the **[Log]** button in the header.
  - Classic Quest Log works with classic-style quest log addons such as *Kerzo's Classic Quest Log*. If none is installed, the world map opens instead.
- **Bottom Padding** setting in **Settings > General** to choose how much space is left under the last quest (0 to 20 px).
- **Test quest item button**:
  - Turn on **Show Test Quest Item Button** in **Settings > Quests & Items**, or type `/bfq testitem`, to place a test button on one of your quests.
  - Use it to check the button's position, size and your **Quest Item Key** without needing a quest item. Clicking it or pressing the key shows a confirmation and a short cooldown sweep. It never uses an item.
  - It can be moved and re-docked like a real quest item button, and it turns off when you reload.

### Fixed
- **Empty space at the bottom of the tracker**:
  - The tracker no longer adds spacing after the last quest, so the frame now ends right under it.
  - When the list is longer than the tracker, it now ends on a whole quest instead of cutting a line in half.
  - The tracker never grows past the edge of the screen.
- **Scrolling long lists**: the mouse wheel now moves one quest or zone at a time.

### Changed
- The **Double-Click Sets Active Quest** setting now mentions that you can turn it off for instant single clicks if you use the Set Active button.

## [1.2.1] - 2026-10-19: Double-Click to Set Active Quest and Inline Arrow Size Fix

### Added
- **Double-click to set the active quest**:
  - Double-click any quest in the tracker to make it your active quest. The Wayfinder arrows then point to it.
  - A single click still collapses or expands the quest. It now waits 0.25 seconds first, to tell a single click from a double-click.
  - Turn it off with **Double-Click Sets Active Quest** in **Settings > Headers & Sort**. It has no effect while *Left-Click Sets Active Quest* is on.

### Fixed
- **Inline Wayfinder arrow too small**:
  - With *Align Quest Titles* turned on (the default), the small arrow next to your active quest was squeezed to 16 px. The *Inline Arrow Size* slider had almost no effect.
  - The title column now widens to fit the arrow at the size you choose, so the slider works across its full 14 to 32 px range again. Quest titles stay neatly aligned.

## [1.2.0] - 2026-10-18: One Settings Window, Language Packs, Combat-Safe Quest Items, and a Leaner Core

### Added
- **Languages**:
  - Choose a language in **Settings > General > Language**. *Automatic* follows your game client.
  - Included languages: Deutsch, English, Español (España), Español (Latinoamérica), Français, Italiano, Português (Brasil), Русский, 한국어, 简体中文 and 繁體中文.
  - Every language pack covers the whole addon: the tracker, its menus and tooltips, the DataBars, Wayfinder, the setup walkthrough and the complete settings window.
  - The translations are machine-assisted. Corrections are welcome.
  - Change the language with `/bfq lang <code>` (for example `/bfq lang deDE` or `/bfq lang auto`). Reload the interface afterwards so every window picks it up.
  - Other addons can add or improve a language with `BleakfibersQuestTrackerForever:RegisterLanguagePack(code, name, strings)`.
- **Debug & Chat Output toggle**:
  - The tracker no longer writes anything to your chat window unless **Settings > General > Debug & Chat Output** is on. It is off by default.
  - Feedback for your own actions (locking the tracker, sharing a quest, applying a preset) now appears briefly at the top of the screen.
  - `/bfq debug` turns chat output on or off.
- **Settings in the Blizzard AddOns panel**: the settings are also available under **Esc > Options > AddOns > Bleakfiber's Quest Tracker**.
- **More settings in the settings window**: these were only in the old Blizzard panel and are now in the main window:
  - Quests: quest filter mode, cross-zone objective tracking, timers in objective text, the best-sell reward highlight, the active quest marker and the quest item key.
  - Appearance: background on/off, border thickness, corner size and DataBar docking spacing.
  - Headers: header color sharing, the quest counter format and the collapsed tracker text.
  - Wayfinder: arrow lock and backdrop, destination name and format, text outlines, distance, ETA, map pins, map coordinates, auto-track, inline arrow position, arrival distance and the waypoint clear delay.
  - DataBars: shared appearance, the XP bar text and texture options, the Location Bar format and size, and every Quest Timer Bar option, plus border, background and color settings for each bar.
- **Quest filter in the quick menu**: the header's quick menu can now switch between All Quests, Current Zone Only and Watched Only.
- **Settings that now work**: Tracker Alpha, Collapse Tracker In Combat, and the quest item button options (show buttons, button size, auto-detect quest items) were listed in the settings but had no effect before.

### Changed
- **One settings window**:
  - The old Blizzard (Ace3) options panel has been removed.
  - The same settings window now opens from `/bfq`, inside Bleakfiber's Addon Config, and in the Blizzard AddOns panel.
  - Switching, copying or resetting a profile updates every open settings window right away.
- **Quest item buttons and combat**:
  - The tracker keeps updating during combat. New objectives, completions and reordering all show immediately.
  - Quest item buttons keep working in combat. They stay where they are while you fight and move to their new place when combat ends.
  - With *Hide Tracker In Combat* on, the item buttons hide together with the tracker, so no invisible buttons are left on screen.
- **Keybindings**: the quest item and hide/show tracker keys now use secure click bindings, so they work in combat. Your existing key bindings are moved to the new bindings automatically.
- **Settings are stored in one place**:
  - The backup copies (`BleakfiberTrackerBackupDB` and `BleakfiberTrackerCharDB`) are gone.
  - Your existing settings are upgraded automatically the first time you log in.
  - Party members' quest progress is no longer saved between sessions.
- **Slash commands**:
  - `/bfqway`, `/bfqcway` and `/bfqpaste` always work.
  - `/way`, `/cway` and `/waypaste` are only added when no other addon (such as TomTom) already uses them.
  - Diagnostic commands (`/bfq pos`, `/bfq sharetest`, `/bfq poi`) print to chat while chat output is on, and remind you how to turn it on when it is off.
- **Fast Auto Loot** only speeds up looting when the game's own auto loot is active, including while you hold the auto-loot modifier key.

### Fixed
- **Quest item buttons**:
  - Quest item buttons use the item by its ID, so they never use a different item when your bags change.
  - The bound quest item key no longer fires twice.
- **Quest automation**:
  - *Auto Accept Shared Quests* and *Auto Accept NPC Quests* now each apply only to their own kind of quest.
  - Quests the game accepts automatically are acknowledged the way the default UI does it.
  - PvP-flagged quests always ask for confirmation.
  - Auto turn-in now completes quests that have no reward choice. It skips quests that ask for gold.
- **Merchants**: selling junk and repairing run once per merchant visit instead of several times.
- **Zone filter**: the active quest and the Wayfinder arrow are kept when you change zones while filtering by zone.
- **Inline arrow**: sizes from 14 to 17 px are no longer reset at login.
- **DataBars**:
  - *Reset Free Loc Position* now moves the Location Bar back.
  - The territory color now uses your real faction.
- **Restore Untracked Quests** refreshes the tracker straight away.
- **Keybindings**: removed duplicate keybinding labels.
- **Login**: fixed a possible error while loading settings when a saved tracker position had no anchor point.

### Performance
- **Timed quests**: only the countdown text is redrawn each second instead of the whole tracker.
- **Coalesced refreshes**: quest log, completion and DataBars refreshes triggered close together now run once.
- **Settings sliders**: dragging a slider applies the change once when you settle instead of on every step.
- **Fewer events**: stopped listening to redundant bag and addon-message events.
- **Smaller install**: removed the unused bundled libraries (AceAddon, AceConfig, AceGUI, AceComm, AceEvent, AceTimer and others), the unused Target Marker module, and unused textures. The addon now loads less code and uses less memory.

## [1.1.18] - 2026-10-18: Context Menu Tooltip Suppression, Title Column Alignment, Zone Collapse Shapes, Hover Colors, and Completed Quest Styling

### Fixed
- **Context Menu Pop-Under Tooltip**:
  - Resolved an issue where right-clicking a quest row could spawn or leave quest tooltips covering the context menu dropdown.
  - Implemented active dropdown tracking (`isContextMenuOpen`), hooked `GameTooltip:OnShow` and `DropDownList1:OnHide`, elevated `DropDownList1` stratum to `"TOOLTIP"`, and guarded block mouseover scripts to completely suppress tooltips while menus are open.
- **Quest Title Column Alignment**:
  - Fixed an alignment inconsistency where quest titles shifted left into the icon gutter when not displaying an active navigation arrow or turn-in question mark.
  - Decoupled status icons from the title text string and placed them into a dedicated prefix slot, ensuring all quest titles and level tags align in a consistent vertical column.

### Added
- **Zone Collapse Indicator Shapes and Custom Color**:
  - Added a "Zone Collapse Indicator" option under **Headers & Sort > ZONE GROUPING & SORTING** supporting Arrow, Plus / Minus, and None.
  - Allows players to customize or hide the indicator to prevent visual confusion with Wayfinder navigation arrows.
  - Added a "Zone Collapse Icon Color" picker under **Colors & Fonts > HEADERS & TITLES** with hex input and reset option.
- **Customizable Mouseover Hover Colors**:
  - Added dedicated hover highlight color and opacity pickers under **Colors & Fonts > HIGHLIGHTS & HOVER** for both Quest Rows and Zone Headers.
  - Configurable via interactive color pickers, opacity sliders, and hex inputs.
- **Completed Quest Visual Recognition**:
  - Added a "Completed Quest Background" toggle and color picker under **Colors & Fonts > QUEST STATUS & COMPLETION** to display a subtle background tint behind finished quests.
  - Added a "Completed Quest Title Color" mode selector:
    - Difficulty Color (Default): Keeps original quest level difficulty coloring (red/orange/yellow/green/grey) while using the background tint to signal completion.
    - Turn-in Color: Displays completed quest titles in standard quest turn-in gold.
    - Custom Color: Allows specifying any custom color for completed quest titles.
- **Align Quest Titles Toggle**:
  - Added an optional toggle under **Headers & Sort > ZONE GROUPING & SORTING** ("Align Quest Titles", enabled by default) allowing players to toggle between uniform column alignment and compact left-aligned text.

## [1.1.17] - 2026-10-17: Context Menu Layering Fix, In-Place Collapse, Wayfinder Distance Slider, Usable Item Filter, and Scalable Menus

### Fixed
- **Quest Context Menu Z-Index Layering**:
  - Fixed an issue where right-clicking a quest row spawned the dropdown menu underneath the quest tooltip.
  - Right-clicking now immediately hides the active tooltip, elevates `DropDownList1` to the `"TOOLTIP"` stratum with high frame level, and suppresses tooltip hover events while the menu is open.
- **Tracker Header Tooltip Persistence**:
  - Fixed tooltip staying visible after right-clicking or clicking the options button on the tracker header.

### Added
- **Optional Left-Click In-Place Minimizing (Off by Default)**:
  - Added an optional toggle under **Headers & Sort > ZONE GROUPING & SORTING** and in the "Tracker Options" quick menu: "Left-Click Sets Active Quest (Move to Top)".
  - Off by default: left-clicking any quest header expands or minimizes the quest in place without changing list order or promoting it to the active quest.
  - When enabled, left-clicking an inactive quest promotes it to the active quest and brings it to the top.
- **Configurable Wayfinder HUD Text Distance (5px to 50px)**:
  - Added a "HUD Text Spacing" slider in `/bfq` under **Wayfinder / Audio** allowing users to adjust the vertical distance between the floating navigation arrow and the destination/distance text from 5px to 50px (default 12px).
  - Eliminates dead space beneath the arrow and updates text positioning on screen in real time.
- **Interactive Quest Items Only Filter**:
  - Filtered quest item buttons to strictly show items that possess a clickable On-Use spell effect.
  - Passive quest objectives and loot (such as Tough Wolf Meat) no longer spawn redundant action buttons in the tracker.
- **Scalable Right-Click & Tracker Options Menus (80% to 160%)**:
  - Added a "Popup & Context Menu Scale" slider under **Colors & Fonts > TYPOGRAPHY & SIZING** in `/bfq`.
  - Scales both the right-click quest context menu and the header "Tracker Options" quick menu for improved readability.

## [1.1.16] - 2026-10-15: Dedicated Class Quests Header, Floating XP Bar Sizing, and Custom Sound Slot Selection

### Added
- **Dedicated Class Quests Header and Cross-Zone Display**:
  - Added a dedicated "Separate Class Quests Header" toggle under **Headers & Sort > ZONE GROUPING & SORTING** in `/bfq` (enabled by default).
  - Class quests (such as Druid quests taken in Moonglade or Thunder Bluff) remain visible in the tracker regardless of current zone, even when zone filtering is enabled.
  - Automatically groups class quests into their own dedicated collapsible header named after your actual class (e.g. Paladin, Druid) styled in your class color.
  - The class header sorts cleanly to the bottom of the list during normal questing, and immediately pops to the top whenever an active class quest is tracked or selected.
- **Independent Floating XP Bar Height and Width Controls**:
  - Added an independent "XP Bar Width (Floating):" slider (140px to 800px) in `/bfq` under **Databars**.
  - Enabled live visual feedback for both XP Bar Height and XP Bar Width sliders, instantly adjusting bar dimensions on screen as sliders are adjusted without requiring a UI reload.
- **Dynamic Custom Sound Support & Manager (Named Files & Clean Dropdown)**:
  - Allowed custom sound files to be named arbitrarily (e.g. `fart.wav`, `cheer.wav`, `custom1.wav`).
  - Added an in-game **Custom Audio Files** manager in `/bqt` -> **Audio** to add, preview, and remove custom sound files on the fly.
  - Added `Media\CustomSounds.lua` for players who prefer registering audio files directly in a text file.
  - Replaced the 1-99 empty slots list with a dynamic list showing only loaded custom sounds formatted as `Custom 1 (fart.wav)`, `Custom 2 (cheer.wav)`, etc.
  - Fixed fallback logic in `SocialModule:PlaySoundKey` so custom and LibSharedMedia sounds play their actual audio files without falling back to the Peon sound.
  - Standardized on universal 16-bit 44.1kHz PCM `.wav` format for maximum client reliability.

## [1.1.15] - 2026-10-14: Quest Item Protected Action Fix and Blizzard Interface Difficulty Parity

### Fixed
- **Quest Item Click Error (`ADDON_ACTION_FORBIDDEN`)**:
  - Fixed an error when left-clicking quest item buttons in the tracker (`tried to call the protected function 'UNKNOWN()' at StandaloneTracker.lua:520`).
  - Removed the redundant call to `UseQuestLogSpecialItem` from the button's `PostClick` script. The tracker's secure action button already executes the item use securely via macro attributes (`/use ...`), avoiding taint and protected function errors.
- **Quest Difficulty Color Parity (Green vs Yellow Resolution)**:
  - Fixed an issue where quests displayed as green in Blizzard's quest log appeared yellow in the tracker.
  - Aligned difficulty color calculation directly with Blizzard FrameXML (`DifficultyUtil.lua` and `QuestMapFrame.lua`): the tracker now prioritizes `C_PlayerInfo.GetContentDifficultyQuestForPlayer(questID)` and maps the result through `GetDifficultyColor(difficultyEnum)`.
  - Updated relative difficulty level delta fallbacks to match Blizzard's native brackets (`levelDiff >= -4` for yellow, within `UnitQuestTrivialLevelRange("player")` for green).

## [1.1.14] - 2026-10-13: Automation Sync, Surface Texture Selector, and Full Profile Management

### Added
- **Background Surface Texture Dropdown in Native Settings (`/bfq`)**:
  - Restored the **Surface Texture** selector dropdown under **Colors & Fonts > TRACKER BACKDROP & BORDER** in the native configuration window.
  - Choose between **Solid / Flat**, **Blizzard Tooltip Dark**, **Blizzard Marble**, **Blizzard Rock**, **Blizzard Quest Parchment**, and **Blizzard Parchment (Clean)**.
  - Automatically adapts backdrop colors to warm tones when Parchment is selected, and syncs live across the tracker and DataBars.
- **Header & Zone Text/Bar Colors Directly in Headers & Sort**:
  - Added direct color pickers with `#RRGGBB` Hex inputs and reset buttons for **Header Text**, **Header Bar**, **Header Buttons**, **Zone Text**, **Zone Bar**, and **Match Zone Header Color to Border** directly inside the **Headers & Sort** tab (as well as **Colors & Fonts**), ensuring effortless discovery regardless of which tab you prefer.
- **Complete In-Panel Profile Management (Switch, Create, Copy, Delete)**:
  - Upgraded the **Profiles** tab in `/bfq` with full AceDB profile lifecycle management:
    - **Active Profile**: Live display and a dropdown to switch between existing profiles instantly.
    - **Create New Profile**: Name input field with one-click **Create Profile** button.
    - **Copy From Existing Profile**: Dropdown listing other profiles with a one-click **Copy Profile** button to duplicate existing layouts.
    - **Delete Profile**: Inactive profile selector with a **Delete Profile** button to clean up unused configurations.
    - **Reset to Defaults**: One-click reset for the active profile.
  - Switching, creating, or copying profiles instantly updates the on-screen tracker and refreshes all 8 configuration tabs.

### Fixed
- **Auto-Accept Quests Toggle Synchronization**:
  - Fixed a disconnect in the **Automation** tab where toggling **Auto-Accept Quests from NPCs**, **Auto-Accept Shared Quests**, **Auto-Turn In Quests**, or **Hold Shift to Bypass** updated `db.social` while `QuestAutomationModule` read `db.questAutomation`.
  - Both settings tables are now fully synchronized bidirectionally across the settings panel, the onboarding walkthrough, and the automation module.

## [1.1.13] - 2026-10-13: Config Panel Reorganization, Centralized Colors & Fonts, 3D Wayfinder, and Silent Chat Muting

### Added
- **Config Panel Layout Reorganization (8 Streamlined Tabs)**:
  - Reorganized the configuration interface into 8 intuitive top-level tabs:
    1. **General**: Sizing, layout, backdrop opacity, and visibility toggles.
    2. **Quests & Items**: Quest item button sizing, placement, tracker filters, and objective grouping.
    3. **Colors & Fonts**: Unified control center containing all color and typography settings across the entire addon.
    4. **Headers & Sort**: Header bar styling, zone header sorting, expand/collapse behavior, and zone icons.
    5. **Wayfinder/Audio**: Navigation arrow styles, range thresholds, waypoint management, and arrival audio alerts.
    6. **Databars**: Experience Bar, Location/Coordinates Bar, and Quest Timer Bar settings.
    7. **Automation**: Fast auto-loot, auto-vendor greys/junk, auto-repair, and auto quest turn-in/accept.
    8. **Profiles**: Profile management, importing, exporting, and switching.
- **Centralized Colors & Fonts Hub with `#RRGGBB` Hex & Default Resets**:
  - Consolidated all styling controls into the **Colors & Fonts** tab:
    - **Tracker Backdrop & Border**: Custom background color, alpha, border color, and one-click `#000000` Pure Black preset.
    - **Header Colors**: Main Header Text, Main Header Bar, and Main Header Buttons with reset buttons.
    - **Zone Header Colors**: Zone Header Text, Zone Header Bar, and **Match Zone Header Color to Border** toggle with reset buttons.
    - **DataBars Colors**: XP Bar, Location Bar, Timer Bar, and Coordinates text color with reset buttons.
    - **Wayfinder Navigation Colors**: Normal, Warning, Close, and Arrived arrow colors with individual `#RRGGBB` hex fields and reset buttons.
    - **Quest Title & Objectives**: Quest title color (when level difficulty coloring is off), active objective color, and completed objective color with reset buttons.
- **3D Perspective Floating Wayfinder Arrow Styles**:
  - Added **3D Perspective (Modern)** and **3D Perspective (Classic)** 64-angle pre-rendered 3D compass arrow models alongside **2D Modern Minimalist** and **2D Classic Guide Arrow** under **Wayfinder/Audio**.
- **Audible Menu Open Sound**:
  - Added native UI sound feedback (`SOUNDKIT.IG_MAINMENU_OPEN` / `850`) when clicking the tracker header gear button or toggling the configuration window.

### Changed
- **Zero Chat Outputs, Prints & Debug Messages**:
  - Completely silenced all chat frame outputs across the addon and sub-modules:
    - Tracker visibility toggles via keybind, macro (`Bleakfiber_ToggleTracker()`, `Bleakfiber_HideTracker()`, `Bleakfiber_ShowTracker()`), header button, and slash commands (`/bfqhide`, `/bfhide`, `/bfq togglehide`, `/bfq hide`, `/bfq show`).
    - Wayfinder navigation alerts (arrival notifications, waypoint addition/removal, waypoint listing, `/way test` preview).
    - Auto-repair vendor transaction outputs (personal and guild bank repairs).
    - Setting resets, preset switches, and diagnostics.
  - All visual HUD indicators, 3D compass orientation, on-screen arrival messages, and arrival chime sounds remain fully functional.

### Fixed
- **Floating Wayfinder Arrow Anti-Aliasing (Eliminated Jaggies)**:
  - Upgraded the 2D minimalist arrow to an 8x-supersampled texture and disabled pixel-snapping during continuous rotation (`SetSnapToPixelGrid(false)`, `SetTexelSnappingBias(0)`, `"TRILINEAR"` filtering) for smooth, jaggie-free directional movement.
- **Crisp Pixel-Aligned Zone Headers & Text Drop Shadows**:
  - Added physical screen-pixel coordinate snapping (`ns.SnapToPixel`), enforced even-integer header and zone header heights to eliminate half-pixel vertical centering jitter, and applied full-opacity `SetShadowColor(0, 0, 0, 1.0)` across all tracker FontStrings.

## [1.1.12] - 2026-10-12: High-Contrast Pitch-Black Background (`#000000`) & Tracker / DataBars Visibility Keybind & Macros

### Added
- **Custom Background Color & Hex Input (`#000000` High-Contrast Support)**:
  - Added a direct Hex Color Input box (`#000000`) and a one-click **Pure Black (`#000000`)** preset button under **Colors & Fonts > Tracker Backdrop & Border**, setting a 100% opaque pitch-black background (`solid` texture, alpha `1.0`) for maximum visual contrast.
  - Upgraded the in-game Color Picker enhancement bar with a live **Hex (`#RRGGBB`)** input field and a **Black (`#000000`)** quick-select button that work across every color picker in the addon.
- **Hide / Show Tracker & DataBars Completely (Keybind, Checkbox, Slash Commands & Macro Support)**:
  - Added a dedicated keybinding **Toggle Tracker Visibility (Hide/Show)** in the Blizzard Keybindings menu (under **Bleakfiber's Quest Tracker**) and an in-panel keybind button under **General > Visibility & Combat Behavior**.
  - Added a **Hide DataBars When Tracker Hidden** toggle checkbox (available in both **General** and **DataBars** tabs, enabled by default) so hiding the quest tracker also hides all active DataBars (XP Bar, Location Bar, and Quest Timer Bar).
  - Added slash commands `/bfqhide`, `/bfhide`, `/bfq hide`, `/bfq show`, and `/bfq togglehide` to completely hide or show the tracker, quest item buttons, and DataBars.
  - Added global macro functions `Bleakfiber_ToggleTracker()`, `Bleakfiber_HideTracker()`, and `Bleakfiber_ShowTracker()` for custom `/run` macros.

## [1.1.11] - 2026-10-10: Objective Line Indentation Hotfix

### Fixed
- **Objective Line Indentation Calculation**: Fixed Lua runtime error on `leftItemOffset` in `RenderQuestBlock` by properly retaining the base offset variable during item button sizing calculations.

## [1.1.10] - 2026-10-10: Quest Item Button Placement & Docking Polish

### Fixed
- **Quest Item Button Placement Options**: Fixed the GUI dropdown under `/bfq` > Quests & Items to clearly provide and properly apply the two docking placements:
  - **Left Side (Outside Tracker)** (`outside_left`)
  - **Right Side (Inside Tracker)** (`inside_right`)
- **Resolved Fixed-Left Button Locking**: Corrected the GUI dropdown getter/setter to read and write `itemButtonPlacement` directly (instead of disconnected legacy variables) and cleared saved drag overrides on selection so the button immediately re-docks to the chosen side.
- **Dynamic Title Indentation & Sizing**: Automatically adjusts quest title right padding dynamically when positioned on the inside-right matching button size, and triggers a live tracker layout update upon changing placement or button size.

## [1.1.9] - 2026-10-10: Bindings Header Duplicate Registration & Polish

### Fixed
- **Bindings Header Duplicate Registration**: Resolved `LUA_WARNING: Binding header BLEAKFIBER_TRACKER was attempted to be loaded more than once` from `Bindings.xml`. Consolidated the quest item shortcut into a single canonical binding definition (`BLEAKFIBER_USE_QUEST_ITEM`), eliminating duplicate header definitions and streamlining the Blizzard Key Bindings interface.
- **Keybinding Migration**: Added automatic migration during login for any players who previously had the secondary button binding configured.

## [1.1.8] - 2026-10-10: Performance Optimization & Hitch Elimination

### Fixed
- **Eliminated Map & Quest Log Hitching**: Removed `SelectQuestLogEntry` selection thrashing in `CrossZoneModule`. The module previously looped through all quests and swapped the active quest log selection back and forth, forcing 40+ Blizzard Quest Log UI repaints, scroll recalculations, and event storms every time the map or quest log opened.
- **Eliminated Settings Adjustment Freeze**: Debounced `FlushDBToGlobals` SavedVariables serialization with a 1.5-second timer. Synchronous recursive `DeepCopy` operations no longer execute dozens of times per second while moving sliders or clicking options.
- **Optimized Redraw & Bag Scanning**: Single-pass bag scanner in `UpdateItemButton` reduces bag slot queries by over 80%. Coalesced tracker re-layout requests in `Tracker:UpdateSettings` and suppressed redundant tracker redraw triggers in `WayfinderModule` during `QUEST_LOG_UPDATE`.

## [1.1.7] - 2026-10-10: Party Quest Status & Quest Item Layering / Macro Execution

### Fixed
- **Party Quest Status & Evaluation**: Corrected argument order in modern API `C_QuestLog.IsUnitOnQuest(unit, questID)` and optimized group iteration across raid and 2-person party units. Party member status (such as spouse or teammates) now accurately identifies active quests in tooltips and badges instead of showing false "Missing" status.
- **Quest Item Button Execution & Layering**:
  - Resolved mouse capture layering when quest items are placed inside the tracker (`inside_right`) by setting elevated frame levels (250+) above the quest header block.
  - Registered quest item buttons for both `AnyDown` and `AnyUp` clicks, supporting modern key-down click handling without drag intercept conflicts.
  - Added live bag and slot resolution fallback to execute `/use <bag> <slot>` and `/use <item>` secure macros directly, preventing silent failures from uncached item links.
  - Linked keybinding execution through a clean global `Bleakfiber_UseQuestItem` wrapper, eliminating XML parser syntax warnings.

## [1.1.4] - 2026-10-10: Blizzard Texture Art Asset Polish

### Changed
- **Blizzard Texture Art Integration**: Replaced Unicode and text markers with native Blizzard art assets:
  - **Group / Party Icon**: Rendered the crisp party silhouette sprite from `Interface\QUESTFRAME\QuestLogQuestTypeIcons2x` for party member count badges.
  - **Arrows, Checkmarks & X Marks**: Rendered native textures from `Interface\Common\CommonIcons` for party status tooltips (green checkmark for "On Quest", red X for "Missing"), Ding Ready alerts, active quest pointer arrows, and dropdown item selection.
  - **Zone Header Collapse / Expand**: Replaced `[+]` / `[-]` text with hardware-rotated gold arrow textures from `CommonIcons` (pointing right when collapsed, pointing down when expanded).
  - **Tracker Header Settings Button**: Styled the menu button as a native Blizzard gear button using normal, highlight, and pushed states from `Interface\Common\CommonDropdownSettings2x`.

## [1.1.3] - 2026-10-10: Quest Item Secure Action, Strata & Keybinding Polish

### Fixed
- **ADDON FORBIDDEN: UseQuestLogSpecialItem Crash**: Eliminated insecure `HookScript("OnClick")` fallback invoking protected API `UseQuestLogSpecialItem()`. Quest item buttons now rely purely on Blizzard's native C++ `SecureActionButtonTemplate` item execution.
- **Quest Item Button Strata**: Lowered default frame strata of quest item shortcut buttons from `HIGH` to `MEDIUM` (frame level 25) matching the tracker frame so overlapping windows (such as bag addons) properly cover them.
- **Configurable Frame Strata**: Added an `Item Frame Strata` selector (`Low`, `Medium`, `High`, `Dialog`) in both the native Dark Slate & Gold GUI and AceConfig with live dynamic sync.
- **Keybinding Engine Integration**: Streamlined `BLEAKFIBER_USE_QUEST_ITEM` keybinding to use secure `CLICK BleakfiberQuestItemButton1:LeftButton` dispatch, eliminating script evaluation in combat.
- **Initialization Pre-Creation**: Pre-created primary quest item button during module startup so keybinding click targets always exist.

## [1.1.0] - 2026-10-08: Party Quest Status & Tooltip Integration

### Party Quest Status & Tooltip Integration
- **Party Quest Status in Tooltips**:
  - Integrated native Blizzard engine query support (`IsUnitOnQuest` and `C_QuestLog.IsUnitOnQuest`) with zero-latency party checks and Addon Sync fallback.
  - Hovering over any quest title in the tracker displays a dedicated `Party Quest Status` section in the tooltip listing party members who have the quest (`[✓ On Quest]`) and members who are missing it (`[✗ Missing]`).
  - Formats party member names with their native class colors (`RAID_CLASS_COLORS`) and adds `(Offline)` status indicators for disconnected party members.
  - Pushable quests dynamically display actionable share hints (`(Click to Share)`) next to missing teammates.
- **Tracker Header Party Badges**:
  - Added optional `[👥 #]` group counter badges displayed beside quest titles when group members share the quest.
- **Configuration & Quick Access Toggles**:
  - Added 4 dedicated toggles in both the native Dark Slate & Gold GUI (`Quests & Items` tab) and AceConfig: `Show Party Members on Quest`, `Show Missing Party Members`, `Class Color Party Names`, and `Show Party Count Badge [👥 #]`.
  - Added a quick `Show Party Members` toggle into the tracker header `[...]` popup menu for on-the-fly toggling in dungeons.
- **Version Format Standardization**:
  - Standardized version numbering format to `#.#.#` (`v1.1.0`) across all documentation and TOC manifests to ensure consistent SemVer alignment with the Bleakfiber Addon Suite.

---

## [1.0.19] - 2026-10-08: Complete Configuration Restoration & Audio Suite Polish

### Configuration GUI Restoration & Completeness
- **Module Management Toggles (General Tab)**: Restored master toggles for all standalone sub-modules (`Wayfinder Navigation Module`, `DataBars Suite Module`, `Quest Automation Module`, `Quality of Life (QoL) Module`) with instant live event/timer binding without requiring `/reload`.
- **Utility & Setup Actions (General Tab)**: Restored `Show Bounds Overlay & Resize Handle` toggle, `Run Setup Walkthrough` (`/bfq onboard`), `Reset Tracker Position`, and `Reset Untracked Quests` action buttons.
- **Zone Expansion Actions (Quests & Items Tab)**: Added quick action buttons to `Expand All Zones` and `Collapse All Zones` across the active quest list.
- **Theme Presets & Palette Resets (Colors & Fonts Tab)**:
  - Added one-click theme presets: `Modern Dark Glass (Default)`, `Classic WoW Plus`, and `Ultra Minimalist`.
  - Added color restoration actions: `Reset Background Color`, `Reset Text to Class Color`, and `Reset Buttons to Class Color`.
- **Full Merchant & Social Automation (Automation & QoL Tab)**:
  - Restored `Auto-Share Quests with Party` toggle under quest automation.
  - Restored `Use Guild Bank for Repairs` toggle with personal funds fallback.
  - Restored `Hold Shift to Bypass Vendor Auto-Sell/Repair` modifier toggle.
  - Restored party chat announcement controls: `Announce to Party Chat (Master Toggle)` and `Announce Objective Progress (N/X)`.
- **Complete Audio Alerts & Wayfinder Utilities (Wayfinder & Audio Tab)**:
  - Added cycle selectors for `Complete Sound` (Peon "Work complete!", Classic, Whisper Ping, Coins, Loot Clink, Fanfare, Raid Warning, Ready Check, PvP Horn, Custom Slot) and `Complete Channel` (Master, SFX, Ambience).
  - Added `Preview Complete Sound` button testing playback at currently configured volume.
  - Added cycle selectors for `Objective Sound` and `Objective Channel`.
  - Added `Preview Objective Sound` button testing playback at currently configured volume.
  - Restored Wayfinder navigation action buttons: `Preview / Move Arrow` HUD mover, `Reset Arrow Position`, `Point Closest (/cway)`, and `Clear All Custom Waypoints`.
- **DataBars & Timer Bar Management (DataBars Tab)**:
  - Restored `Reset Free XP Position` and `Reset XP Colors` action buttons.
  - Restored `Reset Free Loc Position` button for the location and coordinates header bar.
  - Added `QUEST TIMER BAR & DOCKING` section with `Preview / Move Timer Bar` and `Reset Timer Bar Position` buttons.
- **Dynamic Layout & Reflow**: All 36 restored settings, toggles, cycle selectors, and action buttons dynamically adapt to canvas width with responsive 2-column or stacked 1-column layouts, strict text wrapping, and auto-hiding scrollbars with zero element overlap.

---

## [1.0.18] - 2026-10-08: Native Slate & Gold Configuration GUI & Responsive Reflow

### Configuration GUI Redesign & Suite Unification
- **Signature Dark Slate & Gold GUI**: Replaced AceGUI embedded options with a bespoke, native 8-sub-tab configuration renderer (`General`, `Quests & Items`, `Colors & Fonts`, `Headers & Sort`, `Automation`, `Wayfinder/Audio`, `DataBars`, `Profiles`) matching the Bleakfiber suite design language.
- **Dynamic Responsive Reflow**: Embedded settings dynamically calculate available canvas width on window resize and reposition controls between a balanced 2-column layout (`width >= 470`) and a clean single-column stacked layout (`width < 470`) to eliminate element overlaps.
- **Label Wrapping & Text Containment**: Form labels, checkboxes, and sliders enforce strict word wrapping and maximum widths to eliminate clipping and collisions.
- **Smart Auto-Hiding Scrollbars**: Integrated `SetupAutoScroll` helper across standalone and embedded frames that automatically hides scrollbars and disables mouse wheel scrolling whenever content fits within the visible height.
- **Master Mover Mode Integration**: Registered `toggleMovers` and `isMoversUnlocked` callbacks with `BleakfibersAddonConfig-Forever` to support global master mover unlock/lock mode (`/bac mover`).

---

## [1.0.17] - Non-Destructive Profile Synchronization

### Master Config Profile Synchronization
- **Non-Destructive Profiles**: Added complete `profiles` contract (`GetCurrent`, `SetCurrent`, `Create`, `SaveCurrentAs`, `List`, `Delete`, `Copy`, `Reset`) to `RegisterWithMasterConfig` for AceDB-backed synchronization with `BleakfibersAddonConfigForever`.
- **Settings Capture**: New profile creations capture active settings by copying the current profile rather than resetting to defaults.
- **Overwrite Protection**: Switching to or synchronizing with an existing profile preserves the user's custom settings and never overwrites them.

---

## [1.0.16] - Master Config Integration & Sleek Theme Redesign

### Master Config Addon Compatibility & Full Options Embedding
- **Centralized Master Config Integration**:
  - Embedded the complete, 10-tab configuration panel directly into `BleakfibersAddonConfigForever` when selecting Quest Tracker, providing full real-time configuration without popups or cut-down menus.
  - Added support for the centralized configuration addon via `OptionalDeps`.
  - Exposed a public module API (`BleakfibersQuestTrackerForever`) with real-time visual refresh (`ApplySettings()`).
  - Added automatic registration into the master configuration registry while retaining standalone slash command support.

### Standalone Configuration Window Redesign
- **Aesthetic Excellence & The Bleakfiber Standard**:
  - Re-themed the standalone configuration window (`/bfq` / `/bfq standalone`) to match the signature dark slate/iron background with beveled gold border accents and crisp typography.
  - Interactive window controls include smooth dragging by the title bar, bottom-right resizing grip, and persistent coordinate and dimension saving.
  - Integrated the full 10-tab settings panel seamlessly into the inset content pane.

### Bug Fixes
- **Combat Lockdown Secure Action Button Safety**:
  - Resolved an `ADDON_ACTION_BLOCKED` issue caused by calling `SetFrameStrata` on secure quest item buttons when initiating combat.
  - Implemented a lightweight, non-secure cooldown updater (`UpdateItemButtonCooldowns`) to handle action bar and inventory cooldown events during combat without modifying secure frame state.
  - Hardened frame creation and visibility transitions to prevent protected Blizzard API calls while in combat lockdown.
- **Configuration Frame Syntax Fix**:
  - Resolved a missing block closure in `Config.lua` for the standalone configuration toggle.

---

## [1.0.15] - API Compliance, Namespace Sanitization & Architecture Optimization

### Core Architecture & Namespace Safety
- **Global Variable Scoping & Leak Fix**:
  - Corrected an unscoped variable assignment (`questLogIndex`) in `Core.lua:GetQuestObjectives`, preventing inadvertent pollution of the global `_G` environment during quest log iterations.
  - Modernized quest log index lookup to prioritize modern `C_QuestLog.GetInfo(i)` and `C_QuestLog.GetNumQuestLogEntries()`.

### Modular Event De-duplication
- **Elimination of Parallel Automation Handlers**:
  - Removed duplicate event registrations (`LOOT_READY`, `LOOT_OPENED`, `QUEST_DETAIL`, `QUEST_PROGRESS`, `QUEST_COMPLETE`, `GOSSIP_SHOW`, `QUEST_GREETING`) from `SocialModule.lua`.
  - Focused `SocialModule` strictly on Party Quest Sync, Chat Announcements, and Audio Alerts, delegating all automation logic cleanly to `QuestAutomationModule` and `QoLModule` to prevent duplicate API executions in the same frame.

### Wayfinder Slash Command Scoping
- **Safe Global Aliasing**:
  - Re-scoped internal Wayfinder slash command registrations (`/way`, `/cway`, `/waypaste`) to use dedicated addon-prefixed globals (`_G["SLASH_BLEAKFIBER_WAY*"]`), preventing namespace conflicts with external navigation addons.

### Performance & Update Loop Optimization
- **Dynamic Timer Bar Ticker Management**:
  - Optimized the Quest Timer DataBar `OnUpdate` ticker in `DataBarsModule.lua` to dynamically attach only when an active timed quest is displayed, and detach (`SetScript("OnUpdate", nil)`) when hidden or idle, eliminating background CPU overhead.

### Wayfinder World Map Waypoint Pins
- **Authentic Blizzard Waypoint Marker Styling**:
  - Overhauled custom map pin visuals to use the default Blizzard diamond waypoint pins (`WaypoinMapPinUI`).
  - Active/tracked waypoints now render with the vibrant golden diamond pin, and untracked waypoints display the classic bronze diamond pin.
  - Added native mouseover highlight outline styling and eliminated background circular glows for a clean, pixel-perfect map presentation.

---

## [1.0.14] - Account Onboarding, Modular Architecture, Automation, QoL & Quest Timer Overhaul

### Modern API Architecture & Countdown Timer Isolation
- **Pure Modern Retail API Implementation**:
  - Re-architected quest countdown timer retrieval to strictly target the modern retail engine API `C_QuestLog.GetTimeAllowed(questID)`.
  - Removed all obsolete pre-8.0 legacy Classic timer fallbacks (`GetQuestTimers`, `GetQuestIndexForTimer`, `GetQuestTimer`, `GetQuestLogTimeLeft`, and legacy timer frame queries) that previously caused un-timed quests to falsely inherit countdown timers.
  - Objective countdown timer lines (`- Time Remaining: [MM:SS]`) now render exclusively on quests confirmed by `C_QuestLog.GetTimeAllowed` to have an active timer duration.

### Timer DataBar Dynamic Auto-Hiding & Selection Sync
- **Strict Auto-Hide Behavior**:
  - The Quest Timer DataBar now dynamically hides whenever an un-timed quest is selected or super-tracked.
  - When switching between quests, the Timer DataBar instantly displays the selected quest if it is timed, and immediately hides if it is not.
  - When no specific quest is selected, the bar only appears if a timed quest exists in the active quest log, automatically tracking the quest with the shortest time remaining.

### Cache & SavedVariables Sanitization
- **Authoritative Cache Scrubbing**:
  - Enhanced cache validation during login, zone transitions, and quest log updates to eliminate ghost timer data from persisting across sessions.
  - Purged invalid cached timer entries from memory and profile SavedVariables.

### Wayfinder Navigation Engine & Live Rotation Overhaul
- **Live Turning & Rotation Smoothness**:
  - Re-architected `WayfinderModule:CalculateNavigation` to calculate relative angles and positions in real-time, eliminating a flawed stationary calculation bypass that froze character yaw changes.
  - Increased arrow update frequency to 40 Hz (25ms throttle) and eliminated rotational dead-zones, enabling both the floating 3D HUD arrow and the inline tracker mini-arrow to rotate smoothly and instantaneously as the player turns.
  - Resolved an initialization issue where `self.isEnabled` was not set upon addon load, which caused the HUD arrow to hide and stopped the main navigation `OnUpdate` loop.
  - Corrected method calls in `WayfinderModule:Enable()` to properly restart navigation updates without throwing silent runtime errors.
  - Ensured active quest navigation waypoints persist while working on objectives instead of prematurely auto-clearing and hiding the arrow upon entering proximity.

### Interactive Account Onboarding Walkthrough
- **Guided Setup Walkthrough (/bfq onboard)**:
  - Added a guided 6-step setup walkthrough modal for new users, automatically presented on initial installation or triggered on-demand via `/bfq onboard` or `/bfq onboarding`.
  - Also accessible via the "Run Setup Walkthrough" button under `/bfq` > General.
  - Comprehensive walkthrough steps:
    1. **Visual Theme Presets**: Choose between Modern Dark Glass, Classic WoW Plus (authentic parchment), or Ultra Minimalist.
    2. **Feature Modules**: Select which modules to enable (Wayfinder, DataBars, Quest Automation, Quality of Life) with inline aligned list controls.
    3. **Quest Items & Timers**: Configure quest item button placement (Inside Left/Right, Outside Left/Right) and toggle inline objective countdown timers.
    4. **Quest Automation**: Configure Auto Accept NPC Quests, Auto Accept Shared Quests, Auto Turn-In Quests (1 or Less Choice), Auto-Share Quests, and Shift-Key bypass.
    5. **Quality of Life**: Configure Fast Auto Loot (overriding Blizzard auto-loot entirely), Auto Vendor Grey / Junk Items, Auto-Repair Equipment, Use Guild Bank for Repairs, and Shift-Key Bypass.
    6. **Social & Audio Feedback**: Configure Announce Quest Progress to Party Chat (activating completion announcements only), Play Objective Progress Sound with sound selection dropdown and instant audio preview, and Play Quest Complete Sound with dropdown selector and audio preview.

### Modular Architecture & Dynamic Module Management
- **Zero-Reload Module Management**:
  - Added a dedicated `Modules` tab in the options panel to enable or disable individual addon modules:
    - **Wayfinder Module**: Waypoint navigation, map pins, floating HUD arrow, and inline directional arrows.
    - **DataBars Module**: Experience Bar, Location & Precision Coordinates, and Quest Timer Bar.
    - **Quest Automation Module**: Auto-accept, auto-turn-in, and auto-sharing.
    - **Quality of Life Module**: Fast Auto Loot, auto-vendor junk, and auto-repair.
  - Disabling a module dynamically unregisters events, halts update timers, and hides all associated frames and pins instantly without requiring a `/reload`.
  - Config tabs for disabled modules automatically hide to keep the settings menu clean and focused.

### Consolidated Appearance Tab & Border Fixes
- **Unified Appearance Settings**:
  - Consolidated all visual options into a master `Appearance` tab with organized sub-tabs:
    - **Window & Borders**: Backdrop visibility, background color/opacity, border styles, corner sizing, insets, and tracker dimensions.
    - **Headers & Sections**: Header bar textures, color sharing with borders, quest counter formatting, and collapsible zone headers.
    - **Fonts & Typography**: SharedMedia font selection, font sizes, text outlines, shadows, and active marker icons.
    - **Visual Presets**: One-click visual presets to apply curated themes instantly.
- **Authentic Parchment Texture Support**:
  - Cropped World of Warcraft's parchment texture to remove decorative top and bottom scroll margins, creating a solid rectangular paper backdrop that fits the frame cleanly.
  - Selecting the Parchment texture automatically applies authentic warm parchment paper colors and opacity.
- **Border Sizing & Corner Bleed Elimination**:
  - Fixed an issue where the "Corner & Border Sizing (px)" slider did not update "Blizzard Thin" borders.
  - Eliminated background texture bleed over rounded border corners using dynamic backdrop insets.
- **Prominent Tracker Sizing & Dimensions**:
  - Added width, grow-down range / max height, scale, and bounding box resize overlay controls directly under both General and Window & Borders.
- **Context-Aware Active Quest Marker**:
  - The Active Quest Marker Icon setting is automatically hidden when inline Wayfinder navigation arrows are active to prevent conflicting indicators.
- **Color Picker Alpha Slider Orientation**:
  - Corrected an issue where the transparency slider inside color picker dialogs was inverted (100% visible displaying as transparent and vice-versa) by properly aligning AceGUI with the modern client's direct alpha engine.

### Experience DataBar Overhaul & Smart Truncation
- **Hide Blizzard Experience Bar by Default**:
  - Enabled `hideBlizzardXPBar = true` by default, cleanly replacing the standard Blizzard status tracking bar with live toggling (zero `/reload` needed).
- **Five-Tier Custom Color Layering**:
  - **Base Background**: Choosable backdrop color, defaulted to transparent.
  - **Earned Player XP**: Choosable bar color, defaulted to vibrant purple.
  - **Rested XP**: Choosable bar color, defaulted to blue, rendered on a higher z-layer above quest ghost bars so bonus XP remains clear.
  - **Full Quest Log XP**: Choosable bar color, defaulted to darker green (80% opacity), toggled off by default.
  - **Completed Quest Log XP**: Choosable bar color, defaulted to lighter green with subtle opacity, rendered cleanly above full quest log XP.
- **Streamlined [Ding Ready!] Alert**:
  - When completed turn-in XP meets the current level requirement, the bar displays `[DING READY!] <XP%> + <Completed%>`, hiding extraneous text for a clean, distraction-free alert.
- **Intelligent Smart Text Truncation**:
  - Implemented multi-tier responsive truncation to prevent XP text from overflowing bar boundaries on compact tracker widths or large level values.
  - Automatically abbreviates numbers to clean compact format (e.g., 20.2k / 27.3k) and prioritizes essential values when space is constrained.
- **Tracker Appearance & Texture Inheritance**:
  - DataBars automatically inherit the tracker frame's background surface texture (Solid, Blizzard Tooltip, Blizzard Marble, Blizzard Rock, Blizzard Parchment), background color & opacity, border style, edge size, border color, and class coloring by default (`useTrackerAppearance`).
  - For the XP Bar specifically, the base backdrop layer behind status bars mirrors the tracker's texture and color settings (including cropped parchment texture), ensuring unfilled XP ranges and translucent ghost bars seamlessly display the matching background.
  - Status bars inside the XP Bar and Quest Timer Bar automatically respect border frame insets to prevent texture clipping over rounded corners.
  - Added dedicated background texture dropdown selectors (`xpBgTexture`, `locBgTexture`, `timerBgTexture`) for independent customization when appearance inheritance is disabled.
- **Default Docking Layout & Zero-Gap Spacing**:
  - XP bar docks to the bottom of the quest tracker container by default with zero gap.
  - Location header bar docks to the top of the quest tracker container by default with zero gap.
  - Quest timer bar docks directly above the location bar (or tracker) by default with zero gap.
  - Added a new **Docked Module Spacing** slider under `/bfq` > DataBars to customize pixel spacing between the tracker frame and docked bars as well as between stacked bars (default: 0px for seamless edge-to-edge docking).

### Quest Automation Module
- **Automated Questing Workflow**:
  - **Auto Accept Quests**: Automatically accepts standard NPC quests and shared party quests.
  - **Auto Complete Quests**: Automatically finishes quests and turns them in when there is only one or no reward choice.
  - **Auto Share Quests**: Automatically shares newly accepted quests with party members.
  - **Shift-Key Bypass**: Temporarily disables all automation while holding down the Shift key.

### Quality of Life (QoL) Module
- **Fast Auto Loot**: Instantaneous looting without delay or throttle.
- **Auto Vendor Greys / Junk**: Automatically sells poor-quality (grey) items when interacting with merchants using batched server safe transactions, accurate sell-price detection, client item caching fallback, and prints a clear earnings summary in chat.
- **Auto Repair**: Automatically repairs damaged gear at capable vendors, with an option to utilize Guild Bank funds when permitted.
- **Shift-Key Bypass**: Holding Shift while opening a merchant window skips auto-vendoring and auto-repairs.

### Multi-Item Quest Buttons & In-Tracker Integration
- **Pooled Quest Item Buttons**:
  - Added support for multiple concurrent quest items using button pool `BleakfiberQuestItemButton1..N` (e.g., handling multiple Darkshore Moonwell phials).
  - Enhanced bag scanning cross-references objective text to accurately detect quest-related consumables and items.
- **Flexible Button Placement & Title Indentation**:
  - Four mutually exclusive placement modes: Inside Right, Inside Left, Outside Right, and Outside Left relative to the tracker.
  - When Inside Left is selected, quest titles and objective lines automatically shift right to maintain clean margins and avoid overlapping buttons.
- **Layering & Bag Window Stacking**:
  - Adjusted quest item button frame strata to Medium (frame level 10) so player bags and inventory containers render cleanly above quest buttons.
- **In-Config Keybinding Widget**:
  - Added an interactive keybinding control under `/bfq` > General to bind `BLEAKFIBER_USE_QUEST_ITEM` directly within the options interface.

### Objective Countdown Timers & Interface Polish
- **Inline Objective Countdown Timers**:
  - Live countdown timers (`[MM:SS]`) display directly next to active timed quest objectives.
  - Corrected timer lookup function reference to ensure objective timers activate accurately on all timed quests.
- **Config Option Truncation Elimination**:
  - Expanded all configuration controls and toggle labels with full-width layouts to prevent ellipsis (`...`) text clipping in options dialogs.
- **Wayfinder HUD Mouseover Fix**:
  - Resolved a script error (`attempt to call a nil value`) when mousing over the Wayfinder HUD navigation arrow.

## [1.0.13] - Frame Borders, Wayfinder Units, Quest Timers & DataBars Overhaul

### Tracker Frame & Border Customization
- **Classic WoW Borders & Appearance Customization**:
  - Added new border frame styles under `/bfq` > Appearance:
    - **Blizzard Tooltip (Classic Rounded)**: Authentic Blizzard rounded corners with 16px edge size and clean 4px insets.
    - **Blizzard Dialog Frame**: Ornate classic dialog border with recessed corners.
    - **Blizzard Toast Frame**: Smooth rounded border styling.
    - **Sleek Modern Flat (Default)**: Clean 1px glassmorphism border.
    - **Borderless**: Clean floating display with no border edge.
  - Added background texture options: Solid, Blizzard Tooltip, Marble, Rock, and Parchment.
  - Added dynamic border thickness, insets, and background opacity controls.
- **Instant Real-Time Appearance Updates (Zero `/reload` Required)**:
  - Eliminated the requirement to `/reload` the user interface when modifying border styles, corner sizing, textures, or colors.
  - Resolved an engine issue where modern WoW's `BackdropTemplateMixin` bypassed redrawing when re-using static table references.
  - Implemented automatic 9-slice backdrop clearing and instant slice reconstruction across both the main tracker and all DataBars, allowing live styling and color picking with zero frame drops or lag.

### Wayfinder Imperial & Metric Units
- **Distance Unit Selector**:
  - Added a distance unit toggle under `/bfq` > Wayfinder (`Distance Measurement Unit`):
    - **Imperial (Yards / Miles)**: Displays distances in yards (`yd`) and miles (`mi`).
    - **Metric (Meters / Kilometers)**: Displays distances in meters (`m`) and kilometers (`km`), dynamically converted from world coordinates.
  - Seamlessly updates across all Wayfinder readouts including the floating HUD navigation arrow, map pin tooltips, and chat announcements.

### DataBars Appearance, XP Overhaul & Quest Timers
- **All Active Quests XP Overlay (Ghost Bar)**:
  - Added an optional secondary ghost bar under `/bfq` > DataBars (`Show All Quests XP`) that calculates and displays the combined total XP of all active quests in the quest log (both in-progress and completed).
  - Layered seamlessly behind completed quest turn-ins and player earned XP, filling dynamically as players complete objectives or level up.
  - Fully customizable color and opacity picker with defaults to a subtle cyan/teal.
- **Streamlined [Ding Ready!] Readout**:
  - Re-formatted the Ding Ready alert to cleanly display `[DING READY!] <XP%> + <Completed%>` (e.g., `[DING READY!] 75.0% + 30.0%`), omitting raw numerical values for a sleek, distraction-free display.
- **Full Visual Customization for DataBars**:
  - Added comprehensive styling options under `/bfq` > DataBars for all bars (XP Bar, Location Bar, Timer Bar):
    - **Border Styles**: Choose between Classic Tooltip rounded borders, Dialog borders, Toast borders, Flat 1px borders, or Borderless.
    - **Statusbar Textures**: Select custom textures (Solid, Blizzard, Flat, etc.) for status bar fills.
    - **Color & Opacity**: Independent color pickers with alpha sliders for bar fill colors, backdrop background colors, and border edge colors.
    - **Location Text Override**: Option to override PvP territory dynamic text colors with a custom location text color.
- **Quest Timer DataBar (Enabled by Default)**:
  - Enabled the Timer DataBar by default for seamless plug-and-play tracking of timed quests.
  - Streamlined objective text by keeping the main tracker clean while the dedicated Timer Bar monitors remaining quest time.
  - Dynamic active quest synchronization: Selecting an active quest without a timer automatically hides the Timer DataBar, while swapping back to a timed quest immediately displays its title and countdown.
  - Resolved an API fallback edge case where no-argument timer queries inadvertently mirrored timers onto non-timed quests.
  - Supports dynamic urgency color shifts across the bar fill and border (gold when safe, amber at 2 minutes, and pulsing red under 60 seconds).
  - SavedVariables persistence ensures remaining quest durations do not reset when reloading UI.

### Combat Lockdown Hardening & Taint Elimination
- **WorldMap Combat Action Blocked Fix**:
  - Replaced synchronous `OnShow`/`OnHide` script hooks on Blizzard's `WorldMapFrame` with clean `hooksecurefunc` listeners.
  - Isolated custom Wayfinder waypoint map pins within a dedicated overlay container rather than directly attaching to the Blizzard canvas, preventing interference with Blizzard's protected `SetPassThroughButtons()` routine.
  - Added combat lockdown guards (`InCombatLockdown()`) across all WorldMap pin rendering, cursor tracking updates, and interactive map clicks to prevent any combat taint during battlegrounds and PvP combat.
  - Automatically refreshes map waypoints and coordinates immediately upon exiting combat if the World Map remains open.

### Quest Failure Detection & [FAILED] Tag
- **Automatic Quest Failure Tracking**:
  - Added comprehensive quest failure detection using modern `C_QuestLog.IsFailed` and legacy return statuses.
  - When a quest fails, it immediately displays an unmistakable red `[FAILED]` tag on the quest header and a red `Quest Failed` status beneath the quest.
  - Automatically purges expired or failed quests from the active timer databar and cache.

### Party Progress & Objective Announcements
- **Configurable Party Chat Announcements**:
  - Expanded party chat automation in `/bfq` > Social & Automation with independent toggles:
    - **Announce Quest Completion**: Broadcasts when a quest is ready for turn-in (`[BFQ] Completed: [Quest Title]`).
    - **Announce Objective Completion**: Broadcasts when a specific objective is fulfilled (`[BFQ] [Quest Title]: [Objective] (Complete)`).
    - **Announce Objective Progress**: Broadcasts real-time step progress (`[BFQ] [Quest Title]: [Objective] (N/X)`).

### Performance & Engine Optimizations
- **Micro-Stutter & Hitching Elimination**:
  - Re-architected quest item bag detection to use an event-driven bag cache (`BAG_UPDATE_DELAYED` / `BAG_UPDATE`) instead of querying all inventory slots with tooltip parsing on every tracker render cycle, completely eliminating micro-stutters in high-quest zones.
  - Removed synchronous multi-zone searches from objective target resolution, eliminating frame freezes when cycling active quests.
- **Quest Log Tracking & Retracking Synchronization**:
  - Hooked Blizzard's quest watch APIs (`C_QuestLog.AddQuestWatch`, `AddQuestWatch`, `C_QuestLog.RemoveQuestWatch`, `RemoveQuestWatch`) and hardened `QUEST_WATCH_UPDATE` event handling. Retracking a quest via the Blizzard Quest Log immediately restores and updates the quest on the tracker across all filter modes.
  - Added a "Reset Untracked Quests" button under `/bfq` > General to restore all manually untracked quests.
- **Engine Event Safety**:
  - Protected `QUEST_TIMER_UPDATE` event registration against modern client architectures where the legacy event is not present, preventing unknown event Lua errors while utilizing efficient self-ticking update loops.

---

## [1.0.12] - Smart Reward Tooltips & Comprehensive Typography Overhaul

### Wayfinder HUD Arrow & In-Flight Navigation
- **Destination Title & Zone Location Display**:
  - Added a dedicated `Show Destination Name` toggle (`showDestination = true` by default) to display the destination above the distance and time readout on the floating HUD arrow.
  - Added a `Destination Name Format` selector with three flexible display modes:
    - **Zone Location (Default)**: Displays the active zone name or dungeon area (e.g., `Westfall`, `Wailing Caverns`).
    - **Quest Title**: Displays the full quest title (e.g., `The People's Militia`).
    - **Zone & Quest Title**: Displays both zone and quest (e.g., `Westfall - The People's Militia`).
  - Dynamically re-anchors the distance readout beneath the destination title when active, and snaps up to the arrow base if destination display is toggled off.
- **Dungeon & Raid Quest Waypoint Resolution**:
  - Added a comprehensive Classic dungeon and raid entrance registry (Wailing Caverns, Deadmines, Shadowfang Keep, Blackfathom Deeps, Gnomeregan, Scarlet Monastery, Uldaman, Zul'Farrak, Maraudon, Sunken Temple, Blackrock Depths, Blackrock Spire, Stratholme, Scholomance, Dire Maul, and all 40-man raids).
  - Quests located inside instances (such as *Deviate Hides* or *Underground Assault*) that lack standard Blizzard map POIs now automatically point directly to the dungeon entrance in the exterior world zone rather than causing the navigation arrow to disappear.
- **Dedicated Destination Typography Controls**:
  - Added independent `Destination Text Size (px)` slider (8 to 18px) and `Destination Text Outline` selector under Wayfinder settings, allowing full typographic customization separate from distance numbers.
- **In-Flight Location Display**:
  - Upgraded flight path navigation to capture destination flight master nodes upon taking a taxi, formatting the in-flight status line with the exact arrival location (e.g., `IN FLIGHT to STORMWIND`).
  - Seamlessly clears when landing or transitioning back to on-foot quest tracking.

### Typography & Font Styling Consistency
- **Independent Outline Controls**:
  - Separated font outline controls into **Header & Title Outline** (applied to Quest Titles, Zone Headers, and the Tracker Header) and **Objective Text Outline** (applied to quest objectives, descriptions, and party progress).
  - Players can now pair crisp outlined titles with clean, unoutlined objective text (or vice versa) across all outline modes (`None`, `Outline`, `Thick Outline`, `Outline Monochrome`).
- **Text Drop Shadow Toggle**:
  - Added a dedicated `Enable Text Drop Shadow` toggle under Fonts & Typography, rendering a soft, high-contrast drop shadow behind tracker text for optimal readability against transparent or minimalist backdrops.
- **Dedicated Zone Header Size Slider**:
  - Added an independent font size slider for collapsible Zone Headers (`Westfall (3)`), allowing players to make zone headers prominent section titles or subtle compact dividers.
- **DataBars Typography Controls & Size Persistence**:
  - Added independent Font Size sliders (8 to 18px) and Font Outline selectors for both the **Experience Progress Bar** and the **Location Header Bar**.
  - Fixed an issue where the Experience Bar text size and outline would reset back to default sizes during experience updates.
  - Resolved Location Bar text auto-truncation jitter caused by coordinate width fluctuations; implemented reserved coordinate bounds and an off-screen measuring string for smooth, jitter-free zone and subzone rendering.
- **Wayfinder Typography Integration**:
  - The floating HUD navigation arrow distance readout now inherits tracker typography and features dedicated Font Size and Outline controls in `/bfq` Wayfinder.
- **Configurable Frame Border Width**:
  - Added a `Border Width (px)` slider under Appearance, allowing players to select between ultra-thin 1px borders, standard 2px, or bold 3px frame borders.

### Combat Visibility & Auto-Hiding
- **Hide Quest Tracker in Combat**:
  - Added an option under General Settings (`/bfq` > General > `Hide Tracker in Combat`) to automatically hide the quest tracker while engaged in combat, instantly restoring it when combat ends.
  - Off by default (`hideInCombat = false`) to preserve classic quest visibility.
  - Automatically manages the dedicated quest item button, suppressing interaction during combat lockdown and cleanly restoring it when leaving combat.
  - Resolved `ADDON_ACTION_BLOCKED` errors on `BleakfiberQuestItemFrame` by removing protected `EnableMouse` calls during active combat lockdown.
- **Hide DataBars in Combat**:
  - Added an option under DataBars Settings (`/bfq` > DataBars > `Hide DataBars in Combat`) to automatically hide both the Experience Progress Bar and Location Header Bar during combat encounters.
  - Off by default (`hideInCombat = false`) to avoid unexpected UI changes for players who prefer persistent status bars.
  - Fully synced with player combat state (`PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED`), restoring bars and updating progress smoothly upon combat exit.

### Quest Rewards & Tooltip Enhancements
- **XP Percentage Towards Current Level**:
  - Quest XP rewards now display the exact percentage toward your current level (e.g., `3,450 XP (14.2% of lvl 22)`).
  - Automatically hidden when at maximum player level.
  - Fully toggleable under `/bfq` > Objectives > Quest Titles > `Show XP % Towards Current Level`.
- **Class-Usable Gear Highlighting**:
  - Hovering over a quest title now tags equipment rewards with a clear `[Usable]` indicator for weapons and armor wearable by your active character class.
  - Unusable equipment is politely dimmed and tagged with `[Unusable]`, preventing players from accidentally picking rewards they cannot wear.
  - Non-equipment items (potions, reagents, consumables) remain cleanly untagged.
  - Fully toggleable under `/bfq` > Objectives > Quest Titles > `Highlight Class-Usable Gear Rewards`.
- **Highest Vendor Resale Indicator ("Best Sell")**:
  - For quests with multiple choices (`Choose One`), the addon calculates the vendor sell value of every option and marks the most lucrative choice with a gold coin icon and resale price (e.g., `[Best Sell: 32s 50c]`).
  - Helps players quickly maximize vendor gold while leveling without needing external lookups.
  - Fully toggleable under `/bfq` > Objectives > Quest Titles > `Highlight Most Valuable Choice Reward (Best Sell)`.

---

## [1.0.11] - Class-Colored Borders, Audio Slot Dropdowns & Font Persistence Fix

### Tracker Appearance & Typography
- **Class-Colored Border**: Added a new `Class-Colored Border` toggle under Tracker Appearance settings (`/bfq` > Appearance > Tracker Backdrop).
  - Automatically colors the tracker border to match the player's active character class (e.g., green for Hunter, blue for Shaman, brown for Warrior, orange for Druid) while preserving user-defined alpha.
  - Seamlessly integrates with Zone Header color sharing (`zoneHeaderColorShare`), allowing zone headers to automatically reflect class coloring.
  - Custom border color picker automatically disables with clear indication when Class-Colored Border is enabled.
- **Font Persistence Bug Fix**:
  - Fixed an issue where selecting a font in Settings (such as standard game font `Friz Quadrata TT` or any third-party font) reverted back to default `Nata Sans Bold` after `/reload` or relogging.
  - Removed legacy migration checks that unconditionally overwrote user font choices during initialization.
  - Added immediate DB state flushing (`ns.FlushDBToGlobals()`) on font selection so changes persist instantly across fast reloads or client disconnects.
  - Added dynamic `LibSharedMedia_Registered` listener so late-loading third-party font packs immediately refresh tracker typography without requiring a manual UI reload.

### Audio & Sound System
- **Custom Sound Slot Dropdown System (No File Paths Needed)**:
  - Replaced cumbersome manual file path typing with an intuitive dropdown menu for both Quest Completion and Objective Progress alerts.
  - Pre-mapped 7 instant sound slots under `Media\Sounds\`:
    - `Bleakfiber Beep` (`beep.wav` - clean subtle notification tone)
    - `Bleakfiber Click` (`click.wav` - soft mechanical tick)
    - `Custom Slot 1` through `Custom Slot 5` (`custom1.wav` to `custom5.wav`)
  - Players can simply drop any audio file into `Interface\AddOns\BleakfibersQuestTracker-Forever\Media\Sounds\` named `custom1.wav` .. `custom5.wav` and select it from the dropdown immediately.
  - Automatically lists all sounds registered with LibSharedMedia (LSM).
  - Advanced manual file path input remains available under `Manual File Path (Advanced)`.
- **Subtle Objective Audio Selection (Max 5 Classic Choices)**:
  - Streamlined the Objective Progress sound dropdown to strictly 5 subtle, classic-authentic sounds designed for clear, non-intrusive feedback:
    1. **Whisper Ping (TellMessage)**: The crisp direct whisper notification ping (`SoundKit 3081`).
    2. **Gold Coin Ding**: The high-pitched coin ding when looting money (`SoundKit 895`).
    3. **Loot Coin Clink**: The classic backpack money clink (`SoundKit 880`).
    4. **Mini-Map Ping**: The radar ping (`SoundKit 3175`).
    5. **Subtle Click**: The soft interface checkbox tick (`SoundKit 856`).
  - Purged non-Classic sound references ensuring 100% audio reliability on WoW Forever.
- **Dedicated Volume Sliders**: Added independent volume sliders (5% to 100%) for both **Quest Completion** and **Objective Progress** alerts, allowing players to fine-tune alert loudness without altering global game volume.
- **Audio Channel Routing**: Added channel selectors (`Master Channel`, `Sound Effects (SFX)`, `Ambience Channel`) for both complete and progress triggers.

### Performance & Engine Fixes
- **Comprehensive SavedVariables Persistence Audit & Multi-Layer Backup**:
  - **Universal Settings Wrapper (`WrapSettersWithFlush`)**: Wrapped every setting setter across all 105+ options controls in `Config.lua` to immediately trigger deep-copy synchronization to both `BleakfiberTrackerDB` and `BleakfiberTrackerBackupDB`.
  - **Interactive Frame Position Persistence**: Added immediate database flushes to drag-and-drop end handlers (`OnDragStop`) and frame context menus across all movable elements: the main tracker container, tracker resize overlay handles, quest item buttons, Wayfinder HUD arrow, Experience Bar, and Location Bar.
  - **Zone & Quest Collapse Persistence**: Collapsing or expanding zones and quests in the tracker is now instantly saved to persistent database profiles.
  - **Multi-Profile Backup Safety**: Upgraded `InitializeDB` profile-recovery fallback to detect and preserve ANY active character profile data (not just the default profile), protecting against WoW Forever's `70/` SavedVariables directory generation quirk.
  - **Emergency Fallback Sync**: Enhanced `FlushDBToGlobals` to guarantee safe global persistence even if AceDB-3.0 fails to load.
- **World Map Open/Close Stutter Fix**: Resolved reported micro-stutter when opening and closing the World Map (`WorldMapFrame`):
  - **Zero On-Hide Overhead**: Streamlined the `WorldMapFrame` `OnHide` handler, eliminating heavy pin loops and redundant child-frame updates on map close.
  - **Debounced Map Transitions**: Coalesced rapid consecutive `OnShow` and `OnMapChanged` events into a single, smooth throttled refresh pass.
  - **Pre-Allocated Map Frames**: Map coordinate overlays and "+ Waypoint" buttons are now constructed at addon startup rather than lazily allocated during the critical first map-open frame.

---

## [1.0.10] - High-Performance Engine & Architecture Overhaul

### Target Interface & Manifest
- **SavedVariables Integrity**: 100% backward-compatible profile schemas (`BleakfiberTrackerDB`, `BleakfiberTrackerBackupDB`, `BleakfiberTrackerCharDB`). All existing player positions, custom font sizes, backdrop colors, and Wayfinder coordinates load smoothly with zero profile resets.

---

### Core Engine & Performance Optimizations (Zero-Allocation Hot Loops)
- **Top-Level API Upvalue Localization**: Cached all high-frequency Blizzard Lua and C-APIs (`C_QuestLog.*`, `C_Map.*`, `C_SuperTrack.*`, `GetNumQuestLogEntries`, `GetQuestLogTitle`, `GetQuestDifficultyColor`, `SelectQuestLogEntry`, `QuestLogPushQuest`, frame methods, `pairs`, `ipairs`, `tinsert`, `wipe`, `format`, etc.) across all core and module files. Cuts down global namespace lookups in rendering routines.
- **Zero-Allocation Quest & Objective Object Pooling**:
  - Implemented reusable static pools (`questEntryPool`, `objectiveObjPool`, `completedQuestPool`) across `Core.lua`, `StandaloneTracker.lua`, and `DataBarsModule.lua`.
  - Objective tables and quest data structures are wiped and recycled in-place rather than discarded and garbage-collected on every frame or quest log update.
  - Hot loop paths (`QUEST_LOG_UPDATE`, `QUEST_WATCH_UPDATE`, `BAG_UPDATE`, `UpdateTracker`, `OnUpdate`) run completely garbage-free.
- **Static Sort Comparators**:
  - Eliminated dynamic closure generation during quest ordering passes.
  - Replaced inline anonymous sort functions with static file-scope comparators: `QuestListComparator`, `ZoneOrderComparator`, and `ZoneQuestComparator`.
- **String Concatenation & Territory Parsing Optimization**:
  - Pre-allocated static normalize buffers (`staticNormValid`) in `CrossZoneModule.lua` to test territory matches without intermediate table generation.
  - Streamlined zone lookups and map ID evaluations with static caching (`playerValidZones`).

---

### Dynamic Event Management & Combat Frame-Time Protection
- **Dynamic Event Registration (Zero Dormant Overhead)**:
  - **Social & Automation Module (`Modules/SocialModule.lua`)**: Gossip and quest dialogue events (`GOSSIP_SHOW`, `QUEST_GREETING`, `QUEST_DETAIL`, `QUEST_PROGRESS`, `QUEST_COMPLETE`) unregister dynamically whenever auto-accept and auto-turn-in are disabled.
  - **DataBars Module (`Modules/DataBarsModule.lua`)**: Unhooks XP and zone update events when respective bars are toggled off.
- **Throttled Render Pipeline**:
  - Quest log events are bucket-throttled to execute at most once per frame burst, completely preventing micro-stutter during rapid quest progress updates or mass turn-ins.

---

### Module Hardening & Footprint Minimization
- **Deprecation & Removal of Quest Mob Target Markers**: Completely removed the mob-marking feature (`TargetMarkerModule.lua`), associated TOC entries, configuration toggles, and event listeners. This reduces nameplate hook overhead (`NAME_PLATE_UNIT_ADDED`, `UPDATE_MOUSEOVER_UNIT`, `PLAYER_TARGET_CHANGED`), eliminates target-frame taint risks in combat, and trims overall memory footprint.
- **Purged Legacy Tour Subsystem**: Completely removed the deprecated Quest Tour system (`TourModule.lua`) and all associated hooks, reducing memory footprint, eliminating dead code, and streamlining the Wayfinder navigation pipeline.
- **Dead Code Cleanup**: Stripped out legacy party progress display pools and unreferenced helper code from `StandaloneTracker.lua`.
- **Wayfinder HUD Optimization**:
  - Tightened math routines in the 360° directional arrow `OnUpdate` handler.
  - Wayfinder custom waypoints and map pin overlays maintain $O(1)$ zero-garbage coordinate projection onto WoW Forever maps.

---

### Audio Alerts & Sound Feedback
- **Quest Completion & Objective Progress Sounds Restored**:
  - **Cross-Version API Normalization**: Fixed an engine-level bug where 9-value `GetQuestLogTitle` returns on WotLK/WoW Forever clients caused quests to be misidentified as headers due to Lua truthiness rules (`suggestedGroup = 0`), silently bypassing completion checks.
  - **Objective-Driven Completion Detection**: Quest turn-in readiness now evaluates fulfilled objectives directly (`allObjectivesDone`), ensuring completion audio cues reliably fire the moment all requirements are fulfilled in the field.
  - **Counter & Progress Tracking**: Added direct numeric progress tracking (`numFulfilled` / `numRequired`) alongside string parsing, ensuring intermediate objective updates (e.g. 1/5, 2/5) reliably play progress chimes.
  - **Safe Profile Backfill & Event Routing**: Ensured sound alerts are enabled by default across existing saved variable profiles without requiring profile resets, eliminated subzone transition muting from `ZONE_CHANGED`, and hooked `UI_INFO_MESSAGE` and `QUEST_DATA_CHANGED` for instant audio response.

