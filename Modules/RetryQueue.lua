-- ------------------------------------------------------------------------------ --
-- TradeSkillMaster_CRM - Retry Queue Window
-- Standalone movable frame for viewing and retrying failed whispers
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_CRM")

-- ============================================================================= --
-- Module Setup
-- ============================================================================= --

TSM.RetryQueue = {}
local RQ = TSM.RetryQueue

local private = {
	frame = nil,
	rows = {},
	headCols = {},
	scrollFrame = nil,
	searchBox = nil,
	stContainer = nil,
	countLabel = nil,
	NUM_ROWS = 10,
	ROW_HEIGHT = 24,
	searchFilter = "",
	sortedEntries = {},
}

local FRAME_WIDTH = 560
local FRAME_HEIGHT = 350
local HEAD_HEIGHT = 22
local HEAD_SPACE = 2

local COL_INFO = {
	{ name = L["Player"],  width = 0.20 },
	{ name = L["Message"], width = 0.45 },
	{ name = L["Date"],    width = 0.20 },
}

-- ============================================================================= --
-- Public API
-- ============================================================================= --

function RQ:Toggle()
	if not private.frame then
		RQ:CreateFrame()
	end
	if private.frame:IsShown() then
		private.frame:Hide()
	else
		private.frame:Show()
		RQ:Refresh()
	end
end

function RQ:Show()
	if not private.frame then
		RQ:CreateFrame()
	end
	private.frame:Show()
	RQ:Refresh()
end

function RQ:Refresh()
	if not private.frame or not private.frame:IsShown() then return end
	RQ:BuildSortedEntries()
	RQ:UpdateCountLabel()
	RQ:DrawRows()
end

-- ============================================================================= --
-- Data Helpers
-- ============================================================================= --

function RQ:BuildSortedEntries()
	local queue = TSM.db.global.failedWhispers
	local filter = strlower(strtrim(private.searchFilter or ""))

	wipe(private.sortedEntries)

	for i, entry in ipairs(queue) do
		if filter == "" or strfind(strlower(entry.buyer), filter, 1, true) then
			tinsert(private.sortedEntries, {
				index = i,
				buyer = entry.buyer,
				message = entry.message,
				timestamp = entry.timestamp,
			})
		end
	end

	-- Sort by timestamp descending (newest first)
	table.sort(private.sortedEntries, function(a, b)
		return a.timestamp > b.timestamp
	end)
end

function RQ:UpdateCountLabel()
	if not private.countLabel then return end
	local total = #TSM.db.global.failedWhispers
	private.countLabel:SetText(format(L["%d failed"], total))
end

-- ============================================================================= --
-- Frame Creation
-- ============================================================================= --

function RQ:CreateFrame()
	local frameDefaults = {
		x = 500,
		y = 300,
		width = FRAME_WIDTH,
		height = FRAME_HEIGHT,
		scale = 1,
	}
	local frame = TSMAPI:CreateMovableFrame("TSMCRMRetryQueueFrame", frameDefaults)
	frame:SetFrameStrata("HIGH")
	TSMAPI.Design:SetFrameBackdropColor(frame)
	frame:SetResizable(true)
	frame:SetMinResize(440, 220)
	frame:SetMaxResize(800, 600)

	-- Title
	local title = TSMAPI.GUI:CreateLabel(frame)
	title:SetText(L["CRM - Failed Whispers"])
	title:SetPoint("TOPLEFT")
	title:SetPoint("TOPRIGHT")
	title:SetHeight(20)

	-- Vertical line before close button
	local line = TSMAPI.GUI:CreateVerticalLine(frame, 0)
	line:ClearAllPoints()
	line:SetPoint("TOPRIGHT", -25, -1)
	line:SetWidth(2)
	line:SetHeight(22)

	-- Close button
	local closeBtn = TSMAPI.GUI:CreateButton(frame, 18)
	closeBtn:SetPoint("TOPRIGHT", -3, -3)
	closeBtn:SetWidth(19)
	closeBtn:SetHeight(19)
	closeBtn:SetText("X")
	closeBtn:SetScript("OnClick", function() frame:Hide() end)

	-- Horizontal separator below title
	TSMAPI.GUI:CreateHorizontalLine(frame, -23)

	-- Retry All button (top-left, below title)
	local retryBtn = TSMAPI.GUI:CreateButton(frame, 14)
	retryBtn:SetPoint("TOPLEFT", 3, -26)
	retryBtn:SetWidth(80)
	retryBtn:SetHeight(20)
	retryBtn:SetText(L["Retry All"])
	retryBtn:SetScript("OnClick", function()
		TSM:RetryAllWhispers()
	end)

	-- Count label (right of Retry All button)
	local countLabel = frame:CreateFontString(nil, "OVERLAY")
	countLabel:SetFont(TSMAPI.Design:GetContentFont("small"))
	countLabel:SetPoint("LEFT", retryBtn, "RIGHT", 8, 0)
	countLabel:SetTextColor(0.7, 0.7, 0.7)
	private.countLabel = countLabel

	-- Search bar (right side of top bar)
	local searchBox = CreateFrame("EditBox", "TSMCRMRetrySearchBox", frame, "InputBoxTemplate")
	searchBox:SetPoint("TOPLEFT", countLabel, "TOPRIGHT", 8, 0)
	searchBox:SetPoint("TOPRIGHT", -6, -26)
	searchBox:SetHeight(20)
	searchBox:SetAutoFocus(false)
	searchBox:SetFont(TSMAPI.Design:GetContentFont("small"))
	searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	searchBox:SetScript("OnTextChanged", function(self)
		private.searchFilter = self:GetText() or ""
		RQ:Refresh()
	end)

	-- Placeholder text for search box
	local placeholder = searchBox:CreateFontString(nil, "ARTWORK")
	placeholder:SetFont(TSMAPI.Design:GetContentFont("small"))
	placeholder:SetText(L["Search by player name..."])
	placeholder:SetTextColor(0.5, 0.5, 0.5)
	placeholder:SetPoint("LEFT", 5, 0)
	searchBox.placeholder = placeholder
	searchBox:SetScript("OnEditFocusGained", function(self)
		self.placeholder:Hide()
	end)
	searchBox:SetScript("OnEditFocusLost", function(self)
		if self:GetText() == "" then
			self.placeholder:Show()
		end
	end)
	searchBox:HookScript("OnTextChanged", function(self)
		if self:GetText() ~= "" then
			self.placeholder:Hide()
		elseif not self:HasFocus() then
			self.placeholder:Show()
		end
	end)
	private.searchBox = searchBox

	-- Horizontal separator below search bar
	TSMAPI.GUI:CreateHorizontalLine(frame, -48)

	-- Content container (between search bar and bottom)
	local stContainer = CreateFrame("Frame", nil, frame)
	stContainer:SetPoint("TOPLEFT", 0, -50)
	stContainer:SetPoint("BOTTOMRIGHT", 0, 5)
	TSMAPI.Design:SetFrameColor(stContainer)
	private.stContainer = stContainer

	-- Create column headers
	RQ:CreateHeaders(stContainer)

	-- Create FauxScrollFrame
	local scrollFrame = CreateFrame("ScrollFrame", "TSMCRMRetryQueueScrollFrame", stContainer, "FauxScrollFrameTemplate")
	scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, private.ROW_HEIGHT, function() RQ:DrawRows() end)
	end)
	scrollFrame:SetAllPoints(stContainer)
	private.scrollFrame = scrollFrame

	-- Style scroll bar
	local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("BOTTOMRIGHT", stContainer, -2, 0)
	scrollBar:SetPoint("TOPRIGHT", stContainer, -2, -HEAD_HEIGHT - 4)
	scrollBar:SetWidth(12)
	local thumbTex = scrollBar:GetThumbTexture()
	thumbTex:SetPoint("CENTER")
	TSMAPI.Design:SetContentColor(thumbTex)
	thumbTex:SetHeight(50)
	thumbTex:SetWidth(scrollBar:GetWidth())
	_G[scrollBar:GetName() .. "ScrollUpButton"]:Hide()
	_G[scrollBar:GetName() .. "ScrollDownButton"]:Hide()

	-- Create rows
	RQ:CreateRows(stContainer)

	-- Resize handle (bottom-right corner)
	local resizeHandle = CreateFrame("Frame", nil, frame)
	resizeHandle:SetSize(16, 16)
	resizeHandle:SetPoint("BOTTOMRIGHT", -1, 1)
	resizeHandle:EnableMouse(true)
	resizeHandle:SetScript("OnMouseDown", function()
		frame:StartSizing("BOTTOMRIGHT")
	end)
	resizeHandle:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		frame:SavePositionAndSize()
		RQ:UpdateLayout()
	end)
	-- Resize grip texture
	local gripTex = resizeHandle:CreateTexture(nil, "OVERLAY")
	gripTex:SetAllPoints()
	gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	resizeHandle:SetScript("OnEnter", function()
		gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	end)
	resizeHandle:SetScript("OnLeave", function()
		gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	end)

	-- Hook OnSizeChanged for live resize
	frame:SetScript("OnSizeChanged", function(self)
		self:SavePositionAndSize()
		RQ:UpdateLayout()
	end)

	private.frame = frame
	frame:Hide()
end

-- ============================================================================= --
-- Headers
-- ============================================================================= --

function RQ:CreateHeaders(parent)
	private.headCols = {}
	local contentWidth = FRAME_WIDTH - 30

	for i, info in ipairs(COL_INFO) do
		local col = CreateFrame("Button", "TSMCRMRetryHeadCol" .. i, parent)
		col:SetHeight(HEAD_HEIGHT)
		col:SetWidth(info.width * contentWidth)
		if i == 1 then
			col:SetPoint("TOPLEFT")
		else
			col:SetPoint("TOPLEFT", private.headCols[i - 1], "TOPRIGHT")
		end

		local text = col:CreateFontString()
		text:SetFont(TSMAPI.Design:GetContentFont("small"))
		text:SetJustifyH("CENTER")
		text:SetJustifyV("CENTER")
		text:SetAllPoints()
		TSMAPI.Design:SetWidgetTextColor(text)
		col:SetFontString(text)
		col:SetText(info.name or "")

		local tex = col:CreateTexture()
		tex:SetAllPoints()
		tex:SetTexture("Interface\\WorldStateFrame\\WorldStateFinalScore-Highlight")
		tex:SetTexCoord(0.017, 1, 0.083, 0.909)
		tex:SetAlpha(0.5)
		col:SetNormalTexture(tex)

		tinsert(private.headCols, col)
	end

	TSMAPI.GUI:CreateHorizontalLine(parent, -HEAD_HEIGHT)
end

-- ============================================================================= --
-- Row Creation
-- ============================================================================= --

function RQ:CreateSingleRow(parent, index, contentWidth)
	local row = CreateFrame("Frame", "TSMCRMRetryRow" .. index, parent)
	row:SetHeight(private.ROW_HEIGHT)
	if index == 1 then
		row:SetPoint("TOPLEFT", 0, -(HEAD_HEIGHT + HEAD_SPACE))
		row:SetPoint("TOPRIGHT", -15, -(HEAD_HEIGHT + HEAD_SPACE))
	else
		row:SetPoint("TOPLEFT", private.rows[index - 1], "BOTTOMLEFT")
		row:SetPoint("TOPRIGHT", private.rows[index - 1], "BOTTOMRIGHT")
	end

	-- Highlight
	local highlight = row:CreateTexture()
	highlight:SetAllPoints()
	highlight:SetTexture(1, 0.9, 0, 0.3)
	highlight:Hide()
	row.highlight = highlight

	-- Alternating background
	if index % 2 == 0 then
		local bgTex = row:CreateTexture(nil, "BACKGROUND")
		bgTex:SetAllPoints()
		bgTex:SetTexture("Interface\\WorldStateFrame\\WorldStateFinalScore-Highlight")
		bgTex:SetTexCoord(0.017, 1, 0.083, 0.909)
		bgTex:SetAlpha(0.3)
	end

	-- Hover highlight
	row:EnableMouse(true)
	row:SetScript("OnEnter", function() row.highlight:Show() end)
	row:SetScript("OnLeave", function() row.highlight:Hide() end)

	-- Col 1: Player Name (FontString)
	local nameText = row:CreateFontString(nil, "OVERLAY")
	nameText:SetFont(TSMAPI.Design:GetContentFont("small"))
	nameText:SetJustifyH("LEFT")
	nameText:SetJustifyV("CENTER")
	nameText:SetPoint("TOPLEFT", 6, 0)
	nameText:SetWidth(COL_INFO[1].width * contentWidth - 6)
	nameText:SetHeight(private.ROW_HEIGHT)
	TSMAPI.Design:SetWidgetTextColor(nameText)
	row.nameText = nameText

	-- Col 2: Message (FontString, truncated)
	local messageText = row:CreateFontString(nil, "OVERLAY")
	messageText:SetFont(TSMAPI.Design:GetContentFont("small"))
	messageText:SetJustifyH("LEFT")
	messageText:SetJustifyV("CENTER")
	messageText:SetPoint("TOPLEFT", nameText, "TOPRIGHT", 2, 0)
	messageText:SetWidth(COL_INFO[2].width * contentWidth - 6)
	messageText:SetHeight(private.ROW_HEIGHT)
	TSMAPI.Design:SetWidgetTextColor(messageText)
	row.messageText = messageText

	-- Col 3: Date (FontString)
	local dateText = row:CreateFontString(nil, "OVERLAY")
	dateText:SetFont(TSMAPI.Design:GetContentFont("small"))
	dateText:SetJustifyH("CENTER")
	dateText:SetJustifyV("CENTER")
	dateText:SetPoint("TOPLEFT", messageText, "TOPRIGHT", 2, 0)
	dateText:SetWidth(COL_INFO[3].width * contentWidth - 6)
	dateText:SetHeight(private.ROW_HEIGHT)
	TSMAPI.Design:SetWidgetTextColor(dateText)
	row.dateText = dateText

	-- Remove button (X) - rightmost position
	local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	removeBtn:SetSize(22, private.ROW_HEIGHT - 6)
	removeBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -3)
	removeBtn:SetText("X")
	removeBtn:SetNormalFontObject(GameFontNormalSmall)
	removeBtn:SetHighlightFontObject(GameFontHighlightSmall)
	row.removeBtn = removeBtn

	row:Hide()
	return row
end

function RQ:CreateRows(parent)
	private.rows = {}
	local contentWidth = FRAME_WIDTH - 30

	for i = 1, private.NUM_ROWS do
		local row = RQ:CreateSingleRow(parent, i, contentWidth)
		tinsert(private.rows, row)
	end
end

-- ============================================================================= --
-- Dynamic Layout Update (on resize)
-- ============================================================================= --

function RQ:UpdateLayout()
	if not private.frame then return end
	local contentWidth = private.frame:GetWidth() - 30

	-- Update header columns
	for i, col in ipairs(private.headCols) do
		col:SetWidth(COL_INFO[i].width * contentWidth)
	end

	-- Calculate how many rows fit in the available height
	local containerHeight = private.stContainer:GetHeight()
	local availableHeight = containerHeight - HEAD_HEIGHT - HEAD_SPACE
	local newNumRows = math.floor(availableHeight / private.ROW_HEIGHT)
	if newNumRows < 1 then newNumRows = 1 end

	-- Create additional rows if needed
	if newNumRows > #private.rows then
		for i = #private.rows + 1, newNumRows do
			local row = RQ:CreateSingleRow(private.stContainer, i, contentWidth)
			tinsert(private.rows, row)
		end
	end

	private.NUM_ROWS = newNumRows

	-- Update all row widget widths
	for _, row in ipairs(private.rows) do
		row.nameText:SetWidth(COL_INFO[1].width * contentWidth - 6)
		row.messageText:SetWidth(COL_INFO[2].width * contentWidth - 6)
		row.dateText:SetWidth(COL_INFO[3].width * contentWidth - 6)
	end

	RQ:DrawRows()
end

-- ============================================================================= --
-- Row Drawing
-- ============================================================================= --

function RQ:DrawRows()
	local data = private.sortedEntries
	if not data then return end

	FauxScrollFrame_Update(private.scrollFrame, #data, private.NUM_ROWS, private.ROW_HEIGHT)
	local offset = FauxScrollFrame_GetOffset(private.scrollFrame)

	for i = 1, #private.rows do
		local row = private.rows[i]

		-- Hide rows beyond current NUM_ROWS (window was resized smaller)
		if i > private.NUM_ROWS then
			row:Hide()
		else
			local dataIndex = i + offset
			local entry = data[dataIndex]

			if entry then
				row:Show()

				-- Player name column
				row.nameText:SetText(entry.buyer)

				-- Message column
				row.messageText:SetText(entry.message)

				-- Date column
				row.dateText:SetText(date("%m/%d %H:%M", entry.timestamp))

				-- Remove button callback
				row.removeBtn:SetScript("OnClick", function()
					TSM:RemoveFailedWhisper(entry.index)
					TSM:Print(format(L["Removed failed whisper to %s."], entry.buyer))
					RQ:Refresh()
				end)
			else
				row:Hide()
			end
		end
	end
end
