-- ------------------------------------------------------------------------------ --
--                           TradeSkillMaster_CRM                                 --
--                                                                                --
--             A TradeSkillMaster Addon for Ascension WoW                         --
--    Customer Relationship Management - Auto-whisper buyers on AH sales          --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
TSM = LibStub("AceAddon-3.0"):NewAddon(TSM, "TSM_CRM", "AceEvent-3.0", "AceConsole-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_CRM")

local savedDBDefaults = {
	global = {
		optionsTreeStatus = {},
		-- Historique des whispers : [buyerName] = timestamp du dernier whisper
		whisperHistory = {},
		-- File d'attente des whispers échoués (joueur offline)
		failedWhispers = {},  -- Array of {buyer=string, message=string, timestamp=number}
	},
}

-- Pending whispers tracking (in-memory only, not saved)
local pendingWhispers = {}  -- [buyerName] = {message, timestamp}
local OFFLINE_PATTERN = string.gsub(ERR_CHAT_PLAYER_NOT_FOUND_S, "%%s", "(.+)")
local PENDING_TIMEOUT = 5  -- seconds to wait before assuming success

-- Defaults pour les opérations CRM
TSM.operationDefaults = {
	enabled = true,
	firstMessage = "Thanks for buying %item%!",
	nextMessage = "And the %item%! :)",
	cooldown = 2, -- 2 heures par défaut

	-- Champs obligatoires TSM
	ignorePlayer = {},
	ignorerealm = {},
	relationships = {},
}

function TSM:OnInitialize()
	TSM.db = LibStub("AceDB-3.0"):New("AscensionTSM_CRMDB", savedDBDefaults, true)

	for moduleName, module in pairs(TSM.modules) do
		TSM[moduleName] = module
	end

	self:CleanupWhisperHistory()
	self:CleanupFailedWhispers()
	TSM:RegisterModule()
	TSM:SetupMailHook()
	TSM:RegisterEvent("CHAT_MSG_SYSTEM")
end

function TSM:RegisterModule()
	TSM.operations = {
		maxOperations = 1,
		callbackOptions = "Options:Load",
		callbackInfo = "GetOperationInfo",
	}

	TSM.icons = {
		{
			side = "module",
			desc = "CRM",
			slashCommand = "crm",
			callback = function() TSM:Print(L["CRM module loaded."]) end,
			icon = "Interface\\Icons\\INV_Letter_15",
		},
	}

	TSM.slashCommands = {
		{
			key = "crmretry",
			label = L["Toggle CRM Failed Whispers window"],
			callback = function()
				TSM:ToggleRetryWindow()
			end
		},
	}

	TSMAPI:NewModule(TSM)
end

function TSM:ToggleRetryWindow()
	if TSM.RetryQueue then
		TSM.RetryQueue:Toggle()
	end
end

function TSM:GetOperationInfo(operationName)
	TSMAPI:UpdateOperation("CRM", operationName)
	local operation = TSM.operations[operationName]
	if not operation then return end

	if not operation.enabled then
		return L["Disabled"]
	end

	return L["Auto-whisper on sale"]
end

-- ============================================================
-- HOOK AUTONOME : Intercepte AutoLootMailItem
-- ============================================================
function TSM:SetupMailHook()
	-- Hook la fonction globale AutoLootMailItem
	self:RawHook("AutoLootMailItem", function(index)
		self:ProcessMailBeforeLoot(index)
		self.hooks["AutoLootMailItem"](index)
	end, true)

	-- Hook aussi TakeInboxMoney pour les ventes sans items attachés
	self:RawHook("TakeInboxMoney", function(index)
		self:ProcessMailBeforeLoot(index)
		self.hooks["TakeInboxMoney"](index)
	end, true)
end

function TSM:ProcessMailBeforeLoot(index)
	-- Vérifier si c'est une vente AH
	local invoiceType, itemName, buyer, bid, buyout, deposit, ahcut, _, _, _, quantity = GetInboxInvoiceInfo(index)

	if invoiceType ~= "seller" then return end
	if not buyer or buyer == "" or buyer == "?" then return end
	if buyer == UnitName("player") then return end

	-- Ascension fournit la quantité, sinon default à 1
	quantity = quantity or 1
	local profit = bid - ahcut

	-- Traiter la vente
	self:OnSaleCollected({
		itemName = itemName,
		buyer = buyer,
		quantity = quantity,
		profit = profit,
	})
end

function TSM:OnSaleCollected(saleData)
	local buyer = saleData.buyer
	local itemName = saleData.itemName
	local quantity = saleData.quantity or 1
	local profit = saleData.profit or 0

	-- Trouver l'item dans les groupes TSM
	local itemString, groupPath = self:FindItemInGroups(itemName)
	if not itemString or not groupPath then return end

	-- Récupérer l'opération CRM pour ce groupe
	local operations = TSMAPI:GetItemOperation(itemString, "CRM")
	if not operations or not operations[1] then return end

	local operationName = operations[1]
	TSMAPI:UpdateOperation("CRM", operationName)
	local operation = TSM.operations[operationName]

	if not operation or not operation.enabled then return end

	-- Déterminer quel message envoyer (cooldown stocké en heures, converti en secondes)
	local cooldownSeconds = (operation.cooldown or 2) * 3600
	local isOnCooldown = self:IsOnCooldown(buyer, cooldownSeconds)
	local messageTemplate = isOnCooldown and operation.nextMessage or operation.firstMessage

	-- Construire et envoyer le message
	local message = self:BuildMessage(messageTemplate, itemName, buyer, quantity, profit)
	self:SendWhisper(buyer, message)

	-- Mettre à jour l'historique (toujours, que ce soit first ou next)
	self:RecordWhisper(buyer)

	self:Print(format(L["Sent whisper to %s: %s"], buyer, message))
end

-- Construit le message à partir du template
function TSM:BuildMessage(template, itemName, buyer, quantity, profit)
	local message = template

	message = message:gsub("%%item%%", itemName)
	message = message:gsub("%%buyer%%", buyer)
	message = message:gsub("%%qty%%", tostring(quantity))

	if message:find("%%price%%") then
		local priceText = TSMAPI:FormatTextMoney(profit) or tostring(profit)
		-- Enlever les color codes (ne fonctionnent pas dans whisper)
		priceText = priceText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		message = message:gsub("%%price%%", priceText)
	end

	-- Nettoyer les espaces multiples
	message = message:gsub("%s+", " "):trim()
	return message
end

function TSM:SendWhisper(buyerName, message)
	-- Track as pending so we can detect offline failures
	pendingWhispers[buyerName] = {
		message = message,
		timestamp = time(),
	}
	SendChatMessage(message, "WHISPER", nil, buyerName)
	-- If no error after timeout, assume success and clear pending
	TSMAPI:CreateTimeDelay("crmPending_" .. buyerName, PENDING_TIMEOUT, function()
		pendingWhispers[buyerName] = nil
	end)
end

-- Recherche un item par nom dans les groupes TSM
function TSM:FindItemInGroups(soldItemName)
	local baseSoldName = strmatch(soldItemName, "^(.-)%s+of%s+") or soldItemName

	local mainTSM = LibStub("AceAddon-3.0"):GetAddon("TradeSkillMaster", true)
	if not mainTSM or not mainTSM.db or not mainTSM.db.profile then
		return nil, nil
	end

	for itemString, groupPath in pairs(mainTSM.db.profile.items) do
		local baseItemString = TSMAPI:GetBaseItemString(itemString)
		local itemFullName = TSMAPI:GetSafeItemInfo(baseItemString)

		if itemFullName then
			local baseGroupItemName = strmatch(itemFullName, "^(.-)%s+of%s+") or itemFullName
			if baseSoldName == baseGroupItemName then
				return baseItemString, groupPath
			end
		end
	end

	return nil, nil
end

-- ============================================================
-- COOLDOWN MANAGEMENT
-- ============================================================

-- Vérifie si le buyer est en cooldown
-- Le cooldown est global au buyer, pas par item
function TSM:IsOnCooldown(buyer, cooldownSeconds)
	local history = TSM.db.global.whisperHistory
	if not history[buyer] then return false end

	local lastWhisper = history[buyer]
	return (time() - lastWhisper) < cooldownSeconds
end

-- Enregistre un whisper (met à jour le timestamp)
function TSM:RecordWhisper(buyer)
	TSM.db.global.whisperHistory[buyer] = time()
end

-- Nettoie l'historique des entrées très anciennes (>7 jours)
function TSM:CleanupWhisperHistory()
	local history = TSM.db.global.whisperHistory
	local now = time()
	local maxAge = 7 * 24 * 60 * 60 -- 7 jours

	for buyer, timestamp in pairs(history) do
		if (now - timestamp) > maxAge then
			history[buyer] = nil
		end
	end
end

-- ============================================================
-- FAILED WHISPER DETECTION & RETRY
-- ============================================================

function TSM:CHAT_MSG_SYSTEM(_, msg)
	local failedName = msg:match(OFFLINE_PATTERN)
	if not failedName then return end

	local pending = pendingWhispers[failedName]
	if not pending then return end

	-- Move from pending to failed queue
	pendingWhispers[failedName] = nil
	TSMAPI:CancelFrame("crmPending_" .. failedName)

	tinsert(TSM.db.global.failedWhispers, {
		buyer = failedName,
		message = pending.message,
		timestamp = pending.timestamp,
	})

	TSM:Print(format(L["Whisper to %s failed (offline). Added to retry queue."], failedName))

	if TSM.RetryQueue then
		TSM.RetryQueue:Refresh()
	end
end

function TSM:RetryAllWhispers()
	local queue = TSM.db.global.failedWhispers
	local count = #queue
	if count == 0 then
		TSM:Print(L["No failed whispers to retry."])
		return
	end

	TSM:Print(format(L["Retrying %d failed whisper(s)..."], count))

	-- Process in reverse since we remove entries
	for i = count, 1, -1 do
		local entry = queue[i]
		TSM:SendWhisper(entry.buyer, entry.message)
		tremove(queue, i)
	end

	if TSM.RetryQueue then
		TSM.RetryQueue:Refresh()
	end
end

function TSM:RemoveFailedWhisper(index)
	local queue = TSM.db.global.failedWhispers
	if queue[index] then
		tremove(queue, index)
	end
end

-- Nettoie les entrées de la file d'attente de plus de 30 jours
function TSM:CleanupFailedWhispers()
	local queue = TSM.db.global.failedWhispers
	local now = time()
	local maxAge = 30 * 24 * 60 * 60 -- 30 jours

	for i = #queue, 1, -1 do
		if (now - queue[i].timestamp) > maxAge then
			tremove(queue, i)
		end
	end
end
