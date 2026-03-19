local caffeine = hs.menubar.new()

function setCaffeineDisplay(state)
    if state then
        caffeine:setIcon("caffeine/active.png")
    else
        caffeine:setIcon("caffeine/inactive.png")
    end
end

function caffeineClicked()
    setCaffeineDisplay(hs.caffeinate.toggle("displayIdle"))
end

if caffeine then
    caffeine:setClickCallback(caffeineClicked)
    setCaffeineDisplay(hs.caffeinate.get("displayIdle"))
end

function caffeineOn()
    hs.caffeinate.set("displayIdle", true)
    setCaffeineDisplay(hs.caffeinate.get("displayIdle"))
end

function caffeineOff()
    hs.caffeinate.set("displayIdle", false)
    setCaffeineDisplay(hs.caffeinate.get("displayIdle"))
end