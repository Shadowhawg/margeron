-- Riverwatch's elected government, shared across all servers through DataStores.
--
--   "Government"          the current term: Lord, tax, decree, appointed officials
--   "Candidates_<term>"   who is standing for the NEXT term (registered during <term>)
--   Votes_<term>          OrderedDataStore of votes per candidate
--   "Treasury"            taxes collected on purchases everywhere
-- Without DataStore access (e.g. Studio with API access off) everything works in memory.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gov = require(Shared.Config.Government)

local GovernmentService = {}
local Services

local CYCLE = RunService:IsStudio() and Gov.StudioCycleSeconds or Gov.CycleSeconds
local MAX_CANDIDATES = 20

local store = nil
local memory = { Government = nil, Candidates = {}, Votes = {}, Treasury = 0 }

local state = nil -- cached Government record
local candidatesCache = { Term = -1, List = {}, Votes = {}, FetchedAt = 0 }
local pendingTax = 0

local function currentTerm()
	return math.floor((os.time() - Gov.Epoch) / CYCLE)
end

local function termEndsAt(term)
	return Gov.Epoch + (term + 1) * CYCLE
end

local function defaultState(term)
	return {
		Term = term,
		LordId = 0,
		LordName = Gov.RegentName,
		LordGender = "Female",
		Tax = Gov.DefaultTax,
		Decree = "None",
		Steward = { Id = 0, Name = "" },
		Captain = { Id = 0, Name = "" },
	}
end

-- Storage helpers (DataStore or memory) ---------------------------------------------------

local function getKey(key)
	if not store then
		return memory[key]
	end
	local ok, value = pcall(store.GetAsync, store, key)
	return ok and value or nil
end

local function updateKey(key, transform)
	if not store then
		local new = transform(memory[key])
		if new ~= nil then
			memory[key] = new
		end
		return new
	end
	local ok, value = pcall(store.UpdateAsync, store, key, transform)
	if not ok then
		warn("[GovernmentService] UpdateAsync failed:", value)
		return nil
	end
	return value
end

local function votesStore(term)
	if not store then
		memory.Votes[term] = memory.Votes[term] or {}
		return nil
	end
	return DataStoreService:GetOrderedDataStore("Votes_" .. term)
end

local function addVote(term, userId)
	local ods = votesStore(term)
	if not ods then
		memory.Votes[term][userId] = (memory.Votes[term][userId] or 0) + 1
		return true
	end
	local ok, err = pcall(ods.IncrementAsync, ods, tostring(userId), 1)
	if not ok then
		warn("[GovernmentService] Vote failed:", err)
	end
	return ok
end

local function readVotes(term)
	local ods = votesStore(term)
	local out = {}
	if not ods then
		for userId, n in pairs(memory.Votes[term]) do
			out[userId] = n
		end
		return out
	end
	local ok, pages = pcall(ods.GetSortedAsync, ods, false, MAX_CANDIDATES)
	if ok then
		for _, entry in ipairs(pages:GetCurrentPage()) do
			out[tonumber(entry.key)] = entry.value
		end
	end
	return out
end

-- State ------------------------------------------------------------------------------------

local function refreshOfficials(old, new)
	local changed = not old
		or old.LordId ~= new.LordId
		or old.Steward.Id ~= new.Steward.Id
		or old.Captain.Id ~= new.Captain.Id
	Services.WorldService.SetLordName(
		new.LordName == Gov.RegentName and ("Riverwatch - ruled by " .. new.LordName)
			or (Gov.Offices.Lord[new.LordGender or "Male"] .. ": " .. new.LordName)
	)
	if changed then
		for _, player in ipairs(Players:GetPlayers()) do
			Services.AppearanceService.Apply(player)
		end
	end
end

local function setState(new)
	local old = state
	state = new
	refreshOfficials(old, new)
end

-- Close the election for the previous term and install the winner.
local function resolveTerm(term)
	local electionTerm = term - 1
	local candidates = getKey("Candidates_" .. electionTerm) or {}
	local votes = readVotes(electionTerm)
	local winner, best = nil, 0
	for _, c in ipairs(candidates) do
		local n = votes[c.UserId] or 0
		if n > best then
			winner, best = c, n
		end
	end
	local new = updateKey("Government", function(old)
		if old and old.Term >= term then
			return nil -- another server already resolved it
		end
		local s = defaultState(term)
		if winner then
			s.LordId = winner.UserId
			s.LordName = winner.Name
			s.LordGender = winner.Gender or "Male"
			s.Decree = Gov.Decrees[winner.Pledge] and winner.Pledge or "None"
		end
		return s
	end)
	local record = new or getKey("Government")
	if record then
		setState(record)
		if winner and record.LordId == winner.UserId and new then
			for _, player in ipairs(Players:GetPlayers()) do
				Services.PlayerService.Notify(player, winner.Name .. " has been elected to rule Riverwatch!", "Boss")
			end
		end
	end
end

local function poll()
	local record = getKey("Government")
	local term = currentTerm()
	if not record or record.Term < term then
		resolveTerm(term)
	else
		setState(record)
	end
	-- Flush taxes collected on this server.
	if pendingTax > 0 then
		local amount = pendingTax
		pendingTax = 0
		if store then
			local ok = pcall(store.IncrementAsync, store, "Treasury", amount)
			if not ok then
				pendingTax += amount
			end
		else
			memory.Treasury += amount
		end
	end
end

local function refreshCandidates(force)
	local term = currentTerm()
	if not force and candidatesCache.Term == term and os.clock() - candidatesCache.FetchedAt < 30 then
		return candidatesCache
	end
	candidatesCache = {
		Term = term,
		List = getKey("Candidates_" .. term) or {},
		Votes = readVotes(term),
		FetchedAt = os.clock(),
	}
	return candidatesCache
end

-- Queries ----------------------------------------------------------------------------------

function GovernmentService.OfficeOf(player)
	if not state then
		return nil
	end
	if state.LordId == player.UserId then
		return "Lord"
	elseif state.Steward.Id == player.UserId then
		return "Steward"
	elseif state.Captain.Id == player.UserId then
		return "Captain"
	end
	return nil
end

function GovernmentService.OfficeTitle(player)
	local office = GovernmentService.OfficeOf(player)
	if not office then
		return nil
	end
	local data = Services.PlayerService.GetData(player)
	local gender = data and data.Appearance.Gender or "Male"
	return Gov.Offices[office][gender]
end

function GovernmentService.DecreeActive(decreeId)
	return state ~= nil and state.Decree == decreeId
end

-- Returns totalPrice, taxPortion. Officials get a discount.
function GovernmentService.PriceWithTax(player, basePrice)
	local office = GovernmentService.OfficeOf(player)
	local discount = office and Gov.OfficialDiscount[office] or 0
	local base = math.floor(basePrice * (1 - discount))
	local tax = math.floor(base * (state and state.Tax or Gov.DefaultTax))
	return base + tax, tax
end

function GovernmentService.CollectTax(amount)
	if amount and amount > 0 then
		pendingTax += amount
	end
end

-- Everything the Government window needs.
function GovernmentService.GetState(player)
	local data = Services.PlayerService.GetData(player)
	local term = currentTerm()
	local c = refreshCandidates(false)
	local list = {}
	for _, cand in ipairs(c.List) do
		table.insert(
			list,
			{ UserId = cand.UserId, Name = cand.Name, Pledge = cand.Pledge, Votes = c.Votes[cand.UserId] or 0 }
		)
	end
	table.sort(list, function(a, b)
		return a.Votes > b.Votes
	end)
	local s = state or defaultState(term)
	local treasury = nil
	if GovernmentService.OfficeOf(player) == "Lord" then
		treasury = (store and (getKey("Treasury") or 0) or memory.Treasury) + pendingTax
	end
	return {
		Term = term,
		EndsIn = termEndsAt(term) - os.time(),
		LordName = s.LordName,
		LordTitle = s.LordId == 0 and "Regent" or Gov.Offices.Lord[s.LordGender or "Male"],
		Tax = s.Tax,
		Decree = s.Decree,
		Steward = s.Steward.Name,
		Captain = s.Captain.Name,
		Candidates = list,
		HasVoted = data and data.Gov.VotedTerm == term,
		HasRun = data and data.Gov.RanTerm == term,
		MyOffice = GovernmentService.OfficeOf(player),
		Treasury = treasury,
	}
end

-- Actions ----------------------------------------------------------------------------------

local function result(ok, message, extra)
	local r = extra or {}
	r.ok = ok
	r.message = message
	return r
end

local function atHall(player)
	return Services.NPCService.IsNear(player, "Herald")
end

function GovernmentService.Run(player, pledge)
	local data = Services.PlayerService.GetData(player)
	if not data or type(pledge) ~= "string" or not Gov.Decrees[pledge] then
		return result(false)
	end
	if not atHall(player) then
		return result(false, "Speak to Herald Corwin at the Town Hall.")
	end
	local term = currentTerm()
	if data.Gov.RanTerm == term then
		return result(false, "You're already standing in this election.")
	end
	if data.Level < Gov.RunLevelReq or data.Renown < Gov.RunRenownReq then
		return result(false, "Candidates need level " .. Gov.RunLevelReq .. " and " .. Gov.RunRenownReq .. " Renown.")
	end
	if data.Gold < Gov.RunFee then
		return result(false, "The filing fee is " .. Gov.RunFee .. " gold.")
	end
	local full = false
	local saved = updateKey("Candidates_" .. term, function(old)
		local list = old or {}
		for _, c in ipairs(list) do
			if c.UserId == player.UserId then
				return nil
			end
		end
		if #list >= MAX_CANDIDATES then
			full = true
			return nil
		end
		table.insert(
			list,
			{ UserId = player.UserId, Name = player.DisplayName, Pledge = pledge, Gender = data.Appearance.Gender }
		)
		return list
	end)
	if full then
		return result(false, "The ballot is full this term.")
	end
	if not saved and store then
		return result(false, "The Hall's records are busy. Try again shortly.")
	end
	Services.PlayerService.SpendGold(player, Gov.RunFee)
	GovernmentService.CollectTax(Gov.RunFee)
	data.Gov.RanTerm = term
	refreshCandidates(true)
	for _, other in ipairs(Players:GetPlayers()) do
		Services.PlayerService.Notify(
			other,
			player.DisplayName
				.. " is standing for Lord of Riverwatch, pledging the "
				.. Gov.Decrees[pledge].Name
				.. "!",
			"Quest"
		)
	end
	Services.PlayerService.Changed(player)
	return result(true, nil, { state = GovernmentService.GetState(player) })
end

function GovernmentService.Vote(player, candidateId)
	local data = Services.PlayerService.GetData(player)
	if not data or type(candidateId) ~= "number" then
		return result(false)
	end
	if not atHall(player) then
		return result(false, "Votes are cast at the Town Hall.")
	end
	local term = currentTerm()
	if data.Gov.VotedTerm == term then
		return result(false, "You've already voted this term.")
	end
	if data.Level < Gov.VoteLevelReq then
		return result(false, "You must be level " .. Gov.VoteLevelReq .. " to vote.")
	end
	if candidateId == player.UserId then
		return result(false, "You can't vote for yourself.")
	end
	local c = refreshCandidates(true)
	local found = false
	for _, cand in ipairs(c.List) do
		if cand.UserId == candidateId then
			found = true
		end
	end
	if not found then
		return result(false, "That candidate isn't on the ballot.")
	end
	if not addVote(term, candidateId) then
		return result(false, "The ballot box is jammed. Try again shortly.")
	end
	data.Gov.VotedTerm = term
	refreshCandidates(true)
	Services.QuestService.OnEvent(player, "Vote")
	Services.PlayerService.Changed(player)
	return result(true, "Your vote has been counted.", { state = GovernmentService.GetState(player) })
end

local function lordUpdate(player, mutate)
	if GovernmentService.OfficeOf(player) ~= "Lord" then
		return result(false, "Only the ruler of Riverwatch can do that.")
	end
	local new = updateKey("Government", function(old)
		if not old or old.LordId ~= player.UserId then
			return nil
		end
		mutate(old)
		return old
	end)
	if new then
		setState(new)
		return result(true, nil, { state = GovernmentService.GetState(player) })
	end
	return result(false, "The Hall's records are busy. Try again shortly.")
end

function GovernmentService.SetTax(player, rate)
	if type(rate) ~= "number" or rate ~= rate then
		return result(false)
	end
	rate = math.clamp(math.floor(rate * 100 + 0.5) / 100, 0, Gov.MaxTax)
	return lordUpdate(player, function(s)
		s.Tax = rate
	end)
end

function GovernmentService.SetDecree(player, decreeId)
	if type(decreeId) ~= "string" or not Gov.Decrees[decreeId] then
		return result(false)
	end
	local r = lordUpdate(player, function(s)
		s.Decree = decreeId
	end)
	if r.ok then
		for _, other in ipairs(Players:GetPlayers()) do
			Services.PlayerService.Notify(
				other,
				"By decree of the "
					.. (GovernmentService.OfficeTitle(player) or "Lord")
					.. ": "
					.. Gov.Decrees[decreeId].Name
					.. "! "
					.. Gov.Decrees[decreeId].Description,
				"Quest"
			)
		end
	end
	return r
end

function GovernmentService.Appoint(player, office, username)
	if (office ~= "Steward" and office ~= "Captain") or type(username) ~= "string" or #username > 20 then
		return result(false)
	end
	if username == "" then
		return lordUpdate(player, function(s)
			s[office] = { Id = 0, Name = "" }
		end)
	end
	local ok, userId = pcall(Players.GetUserIdFromNameAsync, Players, username)
	if not ok or not userId then
		return result(false, "No one by that name.")
	end
	if userId == player.UserId then
		return result(false, "You already rule. Pick someone else.")
	end
	local nameOk, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	return lordUpdate(player, function(s)
		s[office] = { Id = userId, Name = nameOk and name or username }
	end)
end

function GovernmentService.ClaimTreasury(player)
	if GovernmentService.OfficeOf(player) ~= "Lord" then
		return result(false, "Only the ruler may claim the treasury.")
	end
	local amount = 0
	if store then
		updateKey("Treasury", function(old)
			amount = old or 0
			return 0
		end)
	else
		amount = memory.Treasury
		memory.Treasury = 0
	end
	amount += pendingTax
	pendingTax = 0
	if amount <= 0 then
		return result(false, "The treasury is empty.")
	end
	Services.PlayerService.AddGold(player, amount)
	return result(
		true,
		"You claim " .. amount .. " gold from the treasury.",
		{ state = GovernmentService.GetState(player) }
	)
end

function GovernmentService.Init(services)
	Services = services
	local ok, result_ = pcall(function()
		local ds = DataStoreService:GetDataStore("MargeronGovernment_v1")
		ds:GetAsync("__probe")
		return ds
	end)
	if ok then
		store = result_
	else
		warn("[GovernmentService] DataStores unavailable; elections run in memory for this server only.")
	end
	state = defaultState(currentTerm())
end

function GovernmentService.Start()
	poll()
	while true do
		task.wait(30)
		local ok, err = pcall(poll)
		if not ok then
			warn("[GovernmentService] poll failed:", err)
		end
	end
end

return GovernmentService
