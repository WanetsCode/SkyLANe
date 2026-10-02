local skyLaneButton


local CONNECTION_DISCONNECTED = 1
local CONNECTION_HOSTING = 2
local CONNECTION_JOINING = 3

local connectionState = CONNECTION_DISCONNECTED

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


local function showServerCreated()
    local width, height = getDialogSize()

    GUI.createDialog{
        icon = hostingIcon,

        title = "Server Active | SkyLANe",

        text =
            "Your SkyLANe server is currently active.\n\n" ..
            "Turn on your hotspot and share the password with your friends " ..
            "so they can join your city.\n\n" ..
            "Players connected to this server will have access to your city.",

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
            "Your SkyLANe server has been closed.\n\n" ..
            "Your city is no longer being shared with other players.",

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

    setConnectionState(CONNECTION_HOSTING)

    Debug.toast("SkyLANe server created!")

    showServerCreated()
end


local function joinServer()
    setConnectionState(CONNECTION_JOINING)

    local width, height = getDialogSize()

    GUI.createDialog{
        icon = joiningIcon,

        title = "Join Server | SkyLANe",

        text =
            "SkyLANe is preparing a connection to another city.\n\n" ..
            "LAN server discovery and connection will be implemented here.",

        width = width,
        height = height,

        closeable = true,
        pause = true
    }

    Debug.toast("Joining SkyLANe server...")
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
            "You are not currently connected to a SkyLANe server.\n\n" ..
            "Host a server to share this city, or join an existing server.",

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
            text = "Server is currently active.",

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
            text = "You are currently joining a server.",

            actions = {
                {
                    text = "Connection information",

                    onClick = function()
                        local width, height = getDialogSize()

                        GUI.createDialog{
                            icon = joiningIcon,

                            title = "Joining Server | SkyLANe",

                            text =
                                "SkyLANe is currently attempting to connect " ..
                                "to another city.\n\n" ..
                                "The actual LAN connection backend will be " ..
                                "connected here later.",

                            width = width,
                            height = height,

                            closeable = true,
                            pause = true
                        }
                    end
                },

                {
                    text = "Cancel connection",

                    onClick = function()
                        setConnectionState(CONNECTION_DISCONNECTED)

                        Debug.toast("SkyLANe connection cancelled")
                    end
                }
            }
        }

        return
    end


    GUI.createMenu{
        title = "SkyLANe",

        text =
            "Connect your cities over the local network.",

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