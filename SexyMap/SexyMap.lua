SexyMap = LibStub("AceAddon-3.0"):NewAddon("SexyMap", "AceEvent-3.0", "AceConsole-3.0", "AceHook-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SexyMap")
local mod = SexyMap

local _G = getfenv(0)
local pairs, ipairs, type, select = _G.pairs, _G.ipairs, _G.type, _G.select

local min = _G.math.min
local MinimapCluster = _G.MinimapCluster
local GetMouseFocus = _G.GetMouseFocus

local options = {
	type = "group",
	args = {}
}
mod.options = options

local defaults = {
	profile = {}
}

mod.backdrop = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	insets = {left = 4, top = 4, right = 4, bottom = 4},
	edgeSize = 16,
	tile = true
}

local optionFrames = {}
local ACD3 = LibStub("AceConfigDialog-3.0")
function mod:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("SexyMapDB", defaults)
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("SexyMap", options)
	self:RegisterChatCommand("minimap", "OpenConfig")
	self:RegisterChatCommand("sexymap", "OpenConfig")
	self:RegisterChatCommand("map", "OpenConfig")
end

function mod:OnEnable()
	if _G.simpleMinimap then
		self:Print("|cffff0000Warning!|r simpleMinimap is enabled. SexyMap may not work correctly.")
	end
	
	if not self.profilesRegistered then
		self:RegisterModuleOptions("Profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db), L["Profiles"])
		self.profilesRegistered = true
	end
	
	self:SecureHook("Minimap_OnClick")
	self:HookAll(MinimapCluster, "OnEnter", MinimapCluster:GetChildren())
	
	self.db.RegisterCallback(self, "OnProfileChanged", "ReloadAddon")
	self.db.RegisterCallback(self, "OnProfileCopied", "ReloadAddon")
	self.db.RegisterCallback(self, "OnProfileReset", "ReloadAddon")
end

function mod:ReloadAddon()
	self:Disable()
	self:Enable()
end

function mod:HookAll(frame, script, ...)
	self:HookScript(frame, script)
	for i = 1, select("#", ...) do
		local f = select(i, ...)
		self:HookScript(f, script)
	end
end

function mod:OpenConfig(name)
	if self:GetModule("General").db.profile.rightClickToConfig then
		InterfaceOptionsFrame_OpenToFrame(optionFrames[name] or optionFrames.default)
	end
end

function mod:Minimap_OnClick(frame, button)
	if button == "RightButton" then
		mod:OpenConfig()
	end
end

function mod:OnDisable()
end

function mod:RegisterModuleOptions(name, optionTbl, displayName)
	options.args[name] = (type(optionTbl) == "function") and optionTbl() or optionTbl
	if not optionFrames.default then
		optionFrames.default = ACD3:AddToBlizOptions("SexyMap", nil, nil, name)
	else
		optionFrames[name] = ACD3:AddToBlizOptions("SexyMap", displayName, "SexyMap", name)
	end
end

do
	local faderFrame = CreateFrame("Frame")
	local fading = {}
	local fadeTarget = 0
	local fadeTime
	local totalTime = 0
	
	local function fade(self, t)
		totalTime = totalTime + t
		local pct = min(1, totalTime / fadeTime)
		local total = 0
		for k, v in pairs(fading) do
			local alpha = v + ((fadeTarget - v) * pct)
			total = total + 1
			if not k.SetAlpha then
				mod:Print("No SetAlpha for", k:GetName())
			end
			k:SetAlpha(alpha)
			k:Show()
			if alpha == fadeTarget then
				fading[k] = nil
				total = total - 1
				if fadeTarget == 0 then
					k:Hide()
				end
			end
		end
		if total == 0 then
			faderFrame:SetScript("OnUpdate", nil)
		end
	end
	
	local function startFade(t)
		fadeTime = t or 0.2
		totalTime = 0
		faderFrame:SetScript("OnUpdate", fade)
	end	
	
	local hoverButtons = {}
	function mod:RegisterHoverButton(frame, showFunc)
		local frameName = frame
		if type(frame) == "string" then
			frame = _G[frame]
		elseif frame then
			frameName = frame:GetName()
		end
		if not frame then
			-- self:Print("Unable to register", frameName, ", does not exit")
			return
		end
		frame:SetAlpha(0)
		frame:Hide()
		hoverButtons[frame] = showFunc or true
	end

	function mod:UnregisterHoverButton(frame)
		if type(frame) == "string" then
			frame = _G[frame]
		end
		if not frame then return end
		if hoverButtons[frame] == true or type(hoverButtons[frame]) == "function" and hoverButtons[frame](frame) then
			frame:SetAlpha(1)
			frame:Show()
		end
		hoverButtons[frame] = nil
	end

	function mod:OnEnter()
		if self.checkExit then return end
		self.checkExit = self:ScheduleRepeatingTimer("CheckExited", 0.1)
		fadeTarget = 1
		for k, v in pairs(hoverButtons) do
			if v == true or type(v) == "function" and v(k) then
				fading[k] = k:GetAlpha()
				startFade()
			end
		end
	end

	function mod:OnExit()
		self:CancelTimer(self.checkExit, true)
		self.checkExit = nil
		
		fadeTarget = 0
		for k, v in pairs(hoverButtons) do
			fading[k] = k:GetAlpha()
			startFade()
		end
	end

	function mod:CheckExited()
		if self.fadeDisabled then return end
		local f = GetMouseFocus()
		local p = f:GetParent()
		while(p and p ~= UIParent) do
			if p == MinimapCluster then return true end
			p = p:GetParent()
		end
		self:OnExit()
	end
	
	function mod:EnableFade()
		self.fadeDisabled = false
	end

	function mod:DisableFade()
		self.fadeDisabled = true
	end
end
