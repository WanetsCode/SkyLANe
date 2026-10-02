local skyLaneButton

function script:buildCityGUI()
    local root = GUI.getRoot()

    local icon = Draft.getDraft("$skylane.icon"):getFrame(0)

    skyLaneButton = root:addButton{
        text = "",
        icon = icon,
        onClick = function()
            GUI.createDialog{
                title = "SkyLANe",
                text = "SkyLANe is running!",
                okText = "OK"
            }
        end
    }

    skyLaneButton:setSize(25, 25)
    skyLaneButton:setPosition(0, 125)
end