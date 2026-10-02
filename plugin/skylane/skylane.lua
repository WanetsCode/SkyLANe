local skyLaneButton

function script:buildCityGUI()
    local root = GUI.getRoot()

    local icon = Draft.getDraft("$skylane.icon"):getFrame(1)

    skyLaneButton = root:addButton{
        text = "",
        icon = Draft.getDraft("$skylane.icon"):getFrame(1),
    
        frameDefault = NinePatch.BLUE_BUTTON,
        framePressed = NinePatch.BLUE_BUTTON_PRESSED,
    
        width = 25,
        height = 25,
    
        onClick = function()
            GUI.createDialog{
                title = "SkyLANe menu",
                text = "Choose wether you want to host a server or connect to one.",
                okText = "OK"
            }
        end
    }
    
    skyLaneButton:setPosition(0, 125)
end