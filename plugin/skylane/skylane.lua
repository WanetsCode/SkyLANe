local skyLaneButton

local CONNECTION_DISCONNECTED = 1
local CONNECTION_HOSTING = 2
local CONNECTION_JOINING = 3
local CONNECTION_CONNECTED = 4
local CONNECTION_ERROR = 5
local CONNECTION_UPDATE = 6

local connectionState = CONNECTION_DISCONNECTED

-- The external SkyLANe test app writes this file into the plugin directory.
-- It must return a table such as:
-- return {
--     id = 1,
--     type = "message",
--     text = "Hello from another instance"
-- }
local UPDATE_FILE = "skylane.update.lua"

local SYNC_INTERVAL = 500

local lastSync = 0
local lastUpdateId = 0

local iconDraft = Draft.getDraft("$skylane.icon")

local disconnectedIcon = iconDraft:getFrame(1)
local hostingIcon = iconDraft:getFrame(2)
local joiningIcon = iconDraft:getFrame(3)
local connectedIcon = iconDraft:getFrame(4)
local updateIcon = iconDraft:getFrame(6)


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

    elseif state == CONNECTION_CONNECTED then
        skyLaneButton:setIcon(connectedIcon)

    elseif state == CONNECTION_ERROR then
        -- Connection/update errors use the update icon.
        skyLaneButton:setIcon(updateIcon)

    elseif state == CONNECTION_UPDATE then
        skyLaneButton:setIcon(updateIcon)

    else
        skyLaneButton:setIcon(disconnectedIcon)
    end
end


local function showMessage(message)
    local width, height = getDialogSize()

    GUI.createDialog{
        icon = connectedIcon,

        title = "Message | SkyLANe",

        text = message,

        width = width,
        height = height,

        closeable = true,
        pause = true
    }
end


local function applyUpdate(update)
    if type(update) ~= "table" then
        setConnectionState(CONNECTION_ERROR)
        Debug.toast("SkyLANe update is not a table")
        return false
    end

    if type(update.id) ~= "number" then
        setConnectionState(CONNECTION_ERROR)
        Debug.toast("SkyLANe update has no valid ID")
        return false
    end

    if update.id <= lastUpdateId then
        return true
    end

    if update.type == "message" then
        if type(update.text) ~= "string" then
            setConnectionState(CONNECTION_ERROR)
            Debug.toast("SkyLANe message update is invalid")
            return false
        end

        lastUpdateId = update.id

        if connectionState == CONNECTION_HOSTING or
           connectionState == CONNECTION_JOINING then
            setConnectionState(CONNECTION_CONNECTED)
        end

        showMessage(update.text)

        return true
    end

    setConnectionState(CONNECTION_ERROR)
    Debug.toast("SkyLANe update type not supported: " .. tostring(update.type))

    return false
end


local function readUpdateFile()
    -- dofile executes the externally generated Lua update and returns
    -- whatever value the update script returns.
    local ok, update = pcall(dofile, UPDATE_FILE)

    if not ok then
        -- A missing update file is normal; do not show an error for it.
        if tostring(update):find("cannot open", 1, true) or
           tostring(update):find("No such file", 1, true) then
            return
        end

        setConnectionState(CONNECTION_ERROR)
        Debug.toast("SkyLANe update error: " .. tostring(update))
        return
    end

    if update ~= nil then
        applyUpdate(update)
    end
end


local function sendMessageTest()
    if connectionState ~= CONNECTION_HOSTING and
       connectionState ~= CONNECTION_CONNECTED then
        Debug.toast("Connect to a SkyLANe test session first")
        return
    end

    GUI.createRenameDialog{
        icon = connectedIcon,

        title = "Generate Message | SkyLANe",

        text =
            "Enter a test message.\n\n" ..
            "The external SkyLANe app should turn this into " ..
            "skylane.update.lua for the other instance.",

        value = "",

        okText = "Send",
        cancelText = "Cancel",

        onOk = function(value)
            if not value or value:len() == 0 then
                Debug.toast("Message is empty")
                return
            end

            -- This is deliberately only a test notification.
            -- The TheoTown plugin does not write files itself.
            Debug.toast("Message queued for the SkyLANe app")
        end
    }
end


local function showConnectionInfo()
    local width, height = getDialogSize()

    local text
    local icon

    if connectionState == CONNECTION_HOSTING then
        text =
            "SkyLANe test host is active.\n\n" ..
            "Waiting for generated Lua updates."

        icon = hostingIcon

    elseif connectionState == CONNECTION_CONNECTED then
        text =
            "Connected to the SkyLANe test session.\n\n" ..
            "Updates are loaded from skylane.update.lua."

        icon = connectedIcon

    elseif connectionState == CONNECTION_JOINING then
        text =
            "Waiting for the SkyLANe update source..."

        icon = joiningIcon

    elseif connectionState == CONNECTION_ERROR then
        text =
            "A SkyLANe update or connection error occurred.\n\n" ..
            "The update icon indicates the error state."

        icon = updateIcon

    else
        text =
            "No SkyLANe test connection is active."

        icon = disconnectedIcon
    end

    GUI.createDialog{
        icon = icon,

        title = "Connection | SkyLANe",

        text = text,

        width = width,
        height = height,

        closeable = true,
        pause = true
    }
end


local function closeConnection()
    setConnectionState(CONNECTION_DISCONNECTED)

    Debug.toast("SkyLANe disconnected")
end


local function hostServer()
    if connectionState == CONNECTION_HOSTING then
        closeConnection()
        return
    end

    lastUpdateId = 0
    lastSync = 0

    setConnectionState(CONNECTION_HOSTING)

    Debug.toast("SkyLANe test host ready")
end


local function joinServer()
    setConnectionState(CONNECTION_JOINING)

    lastUpdateId = 0
    lastSync = 0

    Debug.toast("SkyLANe test client waiting for updates")
end


local function showSkyLANeMenu()

    if connectionState == CONNECTION_HOSTING or
       connectionState == CONNECTION_CONNECTED then

        GUI.createMenu{
            title = "SkyLANe",

            text =
                connectionState == CONNECTION_HOSTING
                    and "Local test host is active."
                    or "Connected to the local test session.",

            actions = {
                {
                    text = "Generate message",

                    onClick = function()
                        sendMessageTest()
                    end
                },

                {
                    text = "Connection information",

                    onClick = function()
                        showConnectionInfo()
                    end
                },

                {
                    text = "Disconnect",

                    onClick = function()
                        closeConnection()
                    end
                }
            }
        }

        return
    end


    GUI.createMenu{
        title = "SkyLANe",

        text = "Lua-file update test.",

        actions = {
            {
                text = "Host a test session",

                onClick = function()
                    hostServer()
                end
            },

            {
                text = "Join a test session",

                onClick = function()
                    joinServer()
                end
            }
        }
    }
end


local function syncUpdates()
    local now = Runtime.getTime()

    if now - lastSync < SYNC_INTERVAL then
        return
    end

    lastSync = now

    if connectionState ~= CONNECTION_HOSTING and
       connectionState ~= CONNECTION_JOINING and
       connectionState ~= CONNECTION_CONNECTED then
        return
    end

    readUpdateFile()
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
    syncUpdates()
end
