local _, ns = ...
local L = ns.L
local N = ns.Notes

-- Notes stuck to an NPC or an item show in its tooltip.

local function addNotes(tooltip, notes)
	if #notes == 0 then
		return
	end
	tooltip:AddLine(" ")
	tooltip:AddLine("|TInterface\\Icons\\INV_Misc_Book_09:14|t " .. L.TOOLTIP_HEADER, 0.56, 0.82, 0.77)
	for i = 1, math.min(#notes, 3) do
		local note = notes[i]
		tooltip:AddLine(N.DisplayTitle(note), 1, 1, 1)
		local preview = ns.Preview(note.body, 80)
		if preview ~= "" and preview ~= N.DisplayTitle(note) then
			tooltip:AddLine(preview, 0.8, 0.8, 0.8, true)
		end
	end
end

local function onUnit(tooltip)
	if tooltip ~= GameTooltip or not ns.db or not ns.db.settings.tooltipNotes then
		return
	end
	local _, unit = tooltip:GetUnit()
	unit = ns.Plain(unit)
	if not unit or UnitIsPlayer(unit) then
		return
	end
	local charKey = ns.CharKey()
	local notes = N.ForAttachment("npc", N.NpcIDFromGUID(UnitGUID(unit)), charKey)
	if #notes == 0 then
		local name = ns.Plain(UnitName(unit))
		if name then
			notes = N.ForAttachment("npcname", string.lower(name), charKey)
		end
	end
	addNotes(tooltip, notes)
end

local function onItem(tooltip)
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip or not ns.db or not ns.db.settings.tooltipNotes then
		return
	end
	local _, link = tooltip:GetItem()
	link = ns.Plain(link)
	if not link then
		return
	end
	local itemID = C_Item.GetItemInfoInstant(link)
	if itemID then
		addNotes(tooltip, N.ForAttachment("item", itemID, ns.CharKey()))
	end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, onUnit)
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItem)
end
