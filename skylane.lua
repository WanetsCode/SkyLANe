-- SkyLANe
-- Phase 1: TheoTown plugin UI test

local dialog

local function showSkyLANe()
  if dialog then
    dialog:close()
  end

  dialog = GUI.createDialog{
    title = "SkyLANe",
    text = "Phase 1 UI test",
    width = 240,
    height = 120,
    actions = {
      {
        text = "Test Button",
        onClick = function()
          Debug.toast("SkyLANe button works!")
        end
      }
    }
  }
end

function script:init()
  Debug.toast("SkyLANe loaded!")
  showSkyLANe()
end
