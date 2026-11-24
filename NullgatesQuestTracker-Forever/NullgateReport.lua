-- Nullgate report window: the copy-and-paste bug report window every Nullgate addon shares.
--
-- Every addon ships an identical copy of this file. The copy with the highest REVISION wins, so
-- all addons show the same window even when they were released at different times. The master
-- copy is Shared\NullgateReport.lua in the suite folder: change it there, raise REVISION, and copy
-- it into every addon.
--
-- An addon opens it with NullgateReport.Show{...} (see Show below) and calls
-- NullgateReport.Update(slug) after adding a line to its log, so an open window stays current.
local REVISION = 1

local lib = _G.NullgateReport
if lib and (lib.revision or 0) >= REVISION then return end
lib = lib or {}
lib.revision = REVISION
_G.NullgateReport = lib

-- The report form on our website. ?addon=<slug> picks the addon in the form.
lib.SITE = "https://nullgatestudios.com/report"

function lib.URL(slug)
    return lib.SITE .. "?addon=" .. tostring(slug or "other")
end

-- Chat colour codes and textures are meaningless outside the game.
local function Plain(text)
    text = tostring(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    return text
end
lib.Plain = Plain

local function Lines(opts)
    local lines = opts.lines
    if type(lines) == "function" then lines = lines() end
    return type(lines) == "table" and lines or {}
end

-- The report as text: which addon, its version, the client, then the addon's log.
function lib.Text(opts)
    local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = meta and opts.addon and meta(opts.addon, "Version") or "?"
    local client, build = "?", "?"
    if GetBuildInfo then client, build = GetBuildInfo() end
    local out = {
        "Addon: " .. tostring(opts.slug),
        tostring(opts.name) .. " - Forever " .. tostring(version),
        "Client: " .. tostring(client) .. " (" .. tostring(build) .. "), " .. tostring(GetLocale and GetLocale() or "?"),
    }
    if opts.command then out[#out + 1] = "Command: " .. opts.command end
    if date then out[#out + 1] = "Time: " .. date("%Y-%m-%d %H:%M") end
    out[#out + 1] = ""
    local log = Lines(opts)
    if #log == 0 then out[#out + 1] = "(nothing logged)" end
    for _, line in ipairs(log) do out[#out + 1] = Plain(line) end
    return table.concat(out, "\n")
end

local function SetTitle(frame, text)
    if type(frame.SetTitle) == "function" then frame:SetTitle(text)
    elseif type(frame.TitleText) == "table" then frame.TitleText:SetText(text)
    elseif frame.TitleContainer and frame.TitleContainer.TitleText then frame.TitleContainer.TitleText:SetText(text) end
end

-- The window, made the first time it's needed. Addons may anchor their own check panel to it.
function lib.Frame()
    if lib.window then return lib.window end
    local name = "NullgateReportWindow"
    local window = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(560, 420)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, name) end

    local help = window:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    help:SetPoint("TOPLEFT", window, "TOPLEFT", 14, -32)
    help:SetPoint("TOPRIGHT", window, "TOPRIGHT", -14, -32)
    help:SetJustifyH("LEFT")
    window.help = help

    -- The link can't be opened from the game, so it's selectable text to copy into a browser.
    local link = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    link:SetPoint("TOPLEFT", window, "TOPLEFT", 20, -74)
    link:SetPoint("TOPRIGHT", window, "TOPRIGHT", -16, -74)
    link:SetHeight(20)
    link:SetAutoFocus(false)
    link:SetScript("OnTextChanged", function(self, user) if user then self:SetText(window.url or "") self:HighlightText() end end)
    link:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    link:SetScript("OnMouseUp", function(self) self:SetFocus() self:HighlightText() end)
    link:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    window.link = link

    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", window, "TOPLEFT", 14, -104)
    scroll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -32, 44)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontSmall")
    box:SetWidth(500)
    box:SetScript("OnEscapePressed", function() window:Hide() end)
    box:SetScript("OnTextChanged", function(self, user) if user then self:SetText(window.text or "") self:HighlightText() end end)
    scroll:SetScrollChild(box)
    window.box = box

    local select = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    select:SetSize(140, 24)
    select:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 14, 12)
    select:SetScript("OnClick", function() box:SetFocus() box:HighlightText() end)
    window.select = select

    local copyLink = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    copyLink:SetSize(140, 24)
    copyLink:SetPoint("LEFT", select, "RIGHT", 8, 0)
    copyLink:SetScript("OnClick", function() link:SetFocus() link:HighlightText() end)
    window.copyLink = copyLink

    lib.window = window
    return window
end

-- Opens the window for one addon. opts:
--   slug       the addon's slug on the website's report form, such as "blessings"
--   name       "Nullgate's Blessings"
--   addon      the addon's folder name, used to read its version
--   command    the check command, such as "/nbless check" (optional)
--   lines      the log: a list of lines, or a function returning one
--   title, help, selectAll, selectLink   the addon's own translations of the window's text
function lib.Show(opts)
    local window = lib.Frame()
    window.opts = opts
    window.url = lib.URL(opts.slug)
    window.text = lib.Text(opts)
    SetTitle(window, tostring(opts.name) .. ": " .. tostring(opts.title or "Bug report"))
    window.help:SetText(opts.help or "")
    window.select:SetText(opts.selectAll or "Select all")
    window.copyLink:SetText(opts.selectLink or "Select link")
    window.link:SetText(window.url)
    window.box:SetText(window.text)
    window:Show()
    window.box:SetFocus()
    window.box:HighlightText()
    return window
end

-- Whether the window is open, for this addon when a slug is given.
function lib.IsShown(slug)
    local window = lib.window
    if not (window and window:IsShown()) then return false end
    return slug == nil or (window.opts and window.opts.slug == slug) or false
end

-- Refreshes the report when the window is open for this addon (after its log grew).
function lib.Update(slug)
    local window = lib.window
    if not lib.IsShown(slug) then return end
    window.text = lib.Text(window.opts)
    window.box:SetText(window.text)
end
