local skyLaneButton

local CONNECTION_DISCONNECTED = 1
local CONNECTION_HOSTING = 2
local CONNECTION_JOINING = 3

local connectionState = CONNECTION_DISCONNECTED

local STORAGE = TheoTown.getFileStorage()
local WORLD_KEY = "skylane.world"
local SYNC_INTERVAL = 1000

local lastSync = 0
local lastAppliedRevision = 0
local worldRevision = 0
local applyingWorld = false

local iconDraft = Draft.getDraft("$skylane.icon")

local disconnectedIcon = iconDraft:getFrame(1)
local hostingIcon = iconDraft:getFrame(2)
local joiningIcon = iconDraft:getFrame(3)


local function getDialogSize()
    local root = GUI.getRoot()

    local clientWidth = root:getClientWidth()
    local clientHeight = root:getClientHeight()

    local width = math.min(420, math.max(180, clientWidth * 0.72))
    local height = math.min(260, math.max(100, clientHeight * 0.42))

    return width, height
end


local function setConnectionState(state)
    connectionState = state

    if not skyLaneButton then
        return
    end

    if state == CONNECTION_HOSTING then
        skyLaneButton:setIcon(hostingIcon)

    elseif state == CONNECTION_JOINING then
        skyLaneButton:setIcon(joiningIcon)

    else
        skyLaneButton:setIcon(disconnectedIcon)
    end
end


local function makeWorldSnapshot()
    local snapshot = {
        version = 1,
        cityId = City.getId(),
        cityName = City.getName(),
        width = City.getWidth(),
        height = City.getHeight(),
        buildings = {},
        roads = {}
    }

    local buildingCount = City.countBuildings()

    for i = 1, buildingCount do
        local x, y = City.getBuilding(i)

        if x and y then
            local building = Tile.getBuilding(x, y)

            if building then
                local draft = building:getDraft()

                if draft then
                    snapshot.buildings[#snapshot.buildings + 1] = {
                        id = draft:getId(),
                        x = x,
                        y = y,
                        frame = building:getFrame()
                    }
                end
            end
        end
    end

    local roadCount = City.countRoads()

    for i = 1, roadCount do
        local x, y, level = City.getRoad(i)

        if x and y and level then
            local draft = Tile.getRoadDraft(x, y, level)

            if draft then
                snapshot.roads[#snapshot.roads + 1] = {
                    id = draft:getId(),
                    x = x,
                    y = y,
                    level = level,
                    bridge = (Tile.getRoadBridgeType(x, y, level) or 0) ~= 0
                }
            end
        end
    end

    return snapshot
end


local function saveWorld()
    if applyingWorld or not City or not City.getId then
        return
    end

    local snapshot = makeWorldSnapshot()

    worldRevision = worldRevision + 1
    snapshot.revision = worldRevision
    snapshot.timestamp = Runtime.getTime()

    STORAGE[WORLD_KEY] = snapshot
end


local function clearBuildings()
    local positions = {}

    local count = City.countBuildings()

    for i = 1, count do
        local x, y = City.getBuilding(i)

        if x and y then
            positions[#positions + 1] = {
                x = x,
                y = y
            }
        end
    end

    for i = 1, #positions do
        Builder.remove(positions[i].x, positions[i].y)
    end
end


local function clearRoads()
    local positions = {}

    local count = City.countRoads()

    for i = 1, count do
        local x, y, level = City.getRoad(i)

        if x and y and level then
            positions[#positions + 1] = {
                x = x,
                y = y,
                level = level
            }
        end
    end

    for i = 1, #positions do
        Builder.remove(
            positions[i].x,
            positions[i].y
        )
    end
end


local function applyWorld(snapshot)
    if not snapshot or snapshot.version ~= 1 then
        return
    end

    if snapshot.cityId ~= City.getId() then
        return
    end

    applyingWorld = true

    clearBuildings()
    clearRoads()

    if snapshot.roads then
        for i = 1, #snapshot.roads do
            local road = snapshot.roads[i]

            Builder.buildRoad(
                road.id,
                road.x,
                road.y,
                road.x,
                road.y,
                road.level,
                road.level,
                road.bridge
            )
        end
    end

    if snapshot.buildings then
        for i = 1, #snapshot.buildings do
            local building = snapshot.buildings[i]

            Builder.buildBuilding(
                building.id,
                building.x,
                building.y,
                building.frame
            )
        end
    end

    applyingWorld = false
end


local function syncWorld()
    local now = Runtime.getTime()

    if now - lastSync < SYNC_INTERVAL then
        return
    end

    lastSync = now

    if connectionState == CONNECTION_HOSTING then
        saveWorld()

    elseif connectionState == CONNECTION_JOINING then
        local snapshot = STORAGE[WORLD_KEY]

        if snapshot and snapshot.revision and snapshot.revision ~= lastAppliedRevision then
            applyWorld(snapshot)
            lastAppliedRevision = snapshot.revision
        end
    end
end


local function showServerCreated()
    local width, height = getDialogSize()

    GUI.createDialog{
        icon = hostingIcon,

        title = "Server Active | SkyLANe",

        text =
            "Your SkyLANe server is currently active.\n\n" ..
            "This test host is continuously writing the city state " ..
            "to shared SkyLANe storage so another TheoTown instance " ..
            "on the same device can read it.",

        width = width,
        height = height,

        closeable = true,
        pause = true
    }
end


local function closeServer()
    if connectionState ~= CONNECTION_HOSTING then
        return
    end

    setConnectionState(CONNECTION_DISCONNECTED)

    Debug.toast("SkyLANe server closed")

    local width, height = getDialogSize()

    GUI.createDialog{
        icon = disconnectedIcon,

        title = "Server Closed | SkyLANe",

        text =
            "The SkyLANe host has stopped publishing the city state.",

        width = width,
        height = height,

        closeable = true,
        pause = true
    }
end


local function hostServer()
    if connectionState == CONNECTION_HOSTING then
        closeServer()
        return
    end

    worldRevision = 0
    lastSync = 0

    setConnectionState(CONNECTION_HOSTING)

    saveWorld()

    Debug.toast("SkyLANe test host started")

    showServerCreated()
end


local function joinServer()
    local snapshot = STORAGE[WORLD_KEY]

    if not snapshot then
        Debug.toast("No SkyLANe host snapshot found")
        return
    end

    if snapshot.cityId ~= City.getId() then
        Debug.toast("SkyLANe city mismatch")
        return
    end

    lastAppliedRevision = 0
    lastSync = 0

    setConnectionState(CONNECTION_JOINING)

    local width, height = getDialogSize()

    GUI.createDialog{
        icon = joiningIcon,

        title = "Join Server | SkyLANe",

        text =
            "Connected to the local SkyLANe test host.\n\n" ..
            "The other TheoTown instance is publishing its city " ..
            "state through the shared file-backed storage.",

        width = width,
        height = height,

        closeable = true,
        pause = true
    }

    Debug.toast("SkyLANe test client connected")
end


local function showServerInfo()
    if connectionState == CONNECTION_HOSTING then
        showServerCreated()

        return
    end

    local width, height = getDialogSize()

    GUI.createDialog{
        icon = disconnectedIcon,

        title = "SkyLANe",

        text =
            "You are not currently connected to a SkyLANe test host.\n\n" ..
            "Host one TheoTown instance, then join from the other instance.",

        width = width,
        height = height,

        closeable = true,
        pause = true
    }
end


local function showSkyLANeMenu()

    if connectionState == CONNECTION_HOSTING then

        GUI.createMenu{
            title = "SkyLANe",
            text = "Local test host is active.",

            actions = {
                {
                    text = "Server information",

                    onClick = function()
                        showServerInfo()
                    end
                },

                {
                    text = "Close server",

                    onClick = function()
                        closeServer()
                    end
                }
            }
        }

        return
    end


    if connectionState == CONNECTION_JOINING then

        GUI.createMenu{
            title = "SkyLANe",
            text = "Connected to the local test host.",

            actions = {
                {
                    text = "Connection information",

                    onClick = function()
                        local width, height = getDialogSize()

                        GUI.createDialog{
                            icon = joiningIcon,

                            title = "Connected | SkyLANe",

                            text =
                                "This instance is reading the host city's " ..
                                "latest snapshot from shared storage.",

                            width = width,
                            height = height,

                            closeable = true,
                            pause = true
                        }
                    end
                },

                {
                    text = "Disconnect",

                    onClick = function()
                        setConnectionState(CONNECTION_DISCONNECTED)

                        Debug.toast("SkyLANe test client disconnected")
                    end
                }
            }
        }

        return
    end


    GUI.createMenu{
        title = "SkyLANe",

        text =
            "Local same-device multiplayer test.",

        actions = {
            {
                text = "Host a server",

                onClick = function()
                    hostServer()
                end
            },

            {
                text = "Join a server",

                onClick = function()
                    joinServer()
                end
            }
        }
    }
end


function script:buildCityGUI()

    local root = GUI.getRoot()

    skyLaneButton = root:addButton{
        text = "",

        icon = disconnectedIcon,

        frameDefault = NinePatch.BLUE_BUTTON,
        framePressed = NinePatch.BLUE_BUTTON_PRESSED,

        width = 25,
        height = 25,

        onClick = function()
            showSkyLANeMenu()
        end
    }

    skyLaneButton:setPosition(0, 125)

    setConnectionState(CONNECTION_DISCONNECTED)
end


function script:update()
    syncWorld()
end
