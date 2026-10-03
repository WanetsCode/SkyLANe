local skyLaneButton

local CONNECTION_DISCONNECTED = 1
local CONNECTION_HOSTING = 2
local CONNECTION_JOINING = 3
local CONNECTION_CONNECTED = 4
local CONNECTION_ERROR = 5
local CONNECTION_UPDATE = 6

local connectionState = CONNECTION_DISCONNECTED

local STORAGE = TheoTown.getFileStorage()

local HOST_KEY = "skylane.test.host"
local MESSAGE_KEY = "skylane.test.message"
local MESSAGE_ID_KEY = "skylane.test.message.id"

local SYNC_INTERVAL = 500
local HOST_TIMEOUT = 3000

local lastSync = 0
local lastMessageId = 0
local lastSentMessageId = 0

local iconDraft = Draft.getDraft("$skylane.icon")

local disconnectedIcon = iconDraft:getFrame(1)
local hostingIcon = iconDraft:getFrame(2)
local joiningIcon = iconDraft:getFrame(3)
local connectedIcon = iconDraft:getFrame(4)
local errorIcon = iconDraft:getFrame(5)
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
        skyLaneButton:setIcon(errorIcon)

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


local function sendMessage()
    if connectionState ~= CONNECTION_HOSTING and
       connectionState ~= CONNECTION_CONNECTED then
        Debug.toast("Connect to a SkyLANe test session first")
        return
    end

    GUI.createRenameDialog{
        icon = connectedIcon,

        title = "Send Message | SkyLANe",

        text = "Enter a message to send to the other TheoTown instance.",

        value = "",

        okText = "Send",
        cancelText = "Cancel",

        onOk = function(value)
            if not value or value:len() == 0 then
                Debug.toast("Message is empty")
                return
            end

            local messageId = Runtime.getTime()

            STORAGE[MESSAGE_KEY] = value
            STORAGE[MESSAGE_ID_KEY] = messageId

            lastSentMessageId = messageId
            lastMessageId = messageId

            Debug.toast("SkyLANe message sent")
        end
    }
end


local function showConnectionInfo()
    local width, height = getDialogSize()

    local text

    if connectionState == CONNECTION_HOSTING then
        text =
            "This TheoTown instance is hosting the local test session.\n\n" ..
            "The host heartbeat is being written to shared file storage."

    elseif connectionState == CONNECTION_CONNECTED then
        text =
            "Connected to the local test host.\n\n" ..
            "Messages are exchanged through shared file-backed storage."

    elseif connectionState == CONNECTION_JOINING then
        text =
            "Looking for the local test host..."

    elseif connectionState == CONNECTION_ERROR then
        text =
            "The SkyLANe test connection reported an error."

    else
        text =
            "No SkyLANe test connection is active."
    end

    GUI.createDialog{
        icon =
            connectionState == CONNECTION_HOSTING and hostingIcon or
            connectionState == CONNECTION_CONNECTED and connectedIcon or
            connectionState == CONNECTION_JOINING and joiningIcon or
            connectionState == CONNECTION_ERROR and errorIcon or
            disconnectedIcon,

        title = "Connection | SkyLANe",

        text = text,

        width = width,
        height = height,

        closeable = true,
        pause = true
    }
end


local function closeConnection()
    if connectionState == CONNECTION_HOSTING then
        STORAGE[HOST_KEY] = 0
    end

    setConnectionState(CONNECTION_DISCONNECTED)

    Debug.toast("SkyLANe disconnected")
end


local function hostServer()
    if connectionState == CONNECTION_HOSTING then
        closeConnection()
        return
    end

    local now = Runtime.getTime()

    STORAGE[HOST_KEY] = now

    lastMessageId = 0
    lastSentMessageId = 0
    lastSync = 0

    setConnectionState(CONNECTION_HOSTING)

    Debug.toast("SkyLANe test host started")
end


local function joinServer()
    local hostTime = STORAGE[HOST_KEY]
    local now = Runtime.getTime()

    if not hostTime or now - hostTime > HOST_TIMEOUT then
        setConnectionState(CONNECTION_ERROR)
        Debug.toast("No SkyLANe test host found")
        return
    end

    lastMessageId = 0
    lastSentMessageId = 0
    lastSync = 0

    setConnectionState(CONNECTION_CONNECTED)

    Debug.toast("SkyLANe test client connected")
end


local function showSkyLANeMenu()

    if connectionState == CONNECTION_HOSTING or
       connectionState == CONNECTION_CONNECTED then

        GUI.createMenu{
            title = "SkyLANe",

            text =
                connectionState == CONNECTION_HOSTING
                    and "Local test host is active."
                    or "Connected to the local test host.",

            actions = {
                {
                    text = "Send message",

                    onClick = function()
                        sendMessage()
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

        text = "Local same-device file messaging test.",

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


local function syncTestConnection()
    local now = Runtime.getTime()

    if now - lastSync < SYNC_INTERVAL then
        return
    end

    lastSync = now

    if connectionState == CONNECTION_HOSTING then
        STORAGE[HOST_KEY] = now

    elseif connectionState == CONNECTION_CONNECTED then
        local hostTime = STORAGE[HOST_KEY]

        if not hostTime or now - hostTime > HOST_TIMEOUT then
            setConnectionState(CONNECTION_ERROR)
            Debug.toast("SkyLANe host connection lost")
            return
        end
    end


    if connectionState ~= CONNECTION_HOSTING and
       connectionState ~= CONNECTION_CONNECTED then
        return
    end

    local messageId = STORAGE[MESSAGE_ID_KEY]

    if messageId and messageId ~= lastMessageId then
        local message = STORAGE[MESSAGE_KEY]

        if message then
            lastMessageId = messageId

            if messageId ~= lastSentMessageId then
                showMessage(message)
            end
        end
    end
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
    syncTestConnection()
end
