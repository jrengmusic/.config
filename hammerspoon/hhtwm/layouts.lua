-- hhtwm layouts

return function(hhtwm)
  local layouts = {}

  local getInsetFrame = function(screen)
    local screenFrame  = screen:fullFrame()
    local screenMargin = hhtwm.screenMargin or { top = 0, bottom = 0, right = 0, left = 0 }

    return {
      x = screenFrame.x + screenMargin.left,
      y = screenFrame.y + screenMargin.top,
      w = screenFrame.w - (screenMargin.left + screenMargin.right),
      h = screenFrame.h - (screenMargin.top + screenMargin.bottom)
    }
  end

  layouts["floating"] = function()
    return nil
  end

  layouts["monocle"] = function(_, _, screen)
    local margin     = hhtwm.margin or 0
    local insetFrame = getInsetFrame(screen)

    local frame = {
      x = insetFrame.x + margin / 2,
      y = insetFrame.y + margin / 2,
      w = insetFrame.w - margin,
      h = insetFrame.h - margin
    }

    return frame
  end

  layouts["main-left"] = function(window, windows, screen, index, layoutOptions)
    if #windows == 1 then
      return layouts["main-center"](window, windows, screen, index, layoutOptions)
    end

    local margin     = hhtwm.margin or 0
    local insetFrame = getInsetFrame(screen)

    if index == 1 then
      -- main window on left
      return {
        x = insetFrame.x + margin / 2,
        y = insetFrame.y + margin / 2,
        w = insetFrame.w * layoutOptions.mainPaneRatio - margin,
        h = insetFrame.h - margin
      }
    else
      -- secondary windows on right, stacked vertically
      local numSecondary = #windows - 1
      -- total margins needed: top + (numSecondary-1 gaps between windows) + bottom = numSecondary + 1 gaps
      -- but we use margin/2 at edges, so: margin/2 + (numSecondary-1)*margin + margin/2 = numSecondary * margin
      local totalMargins = numSecondary * margin
      local availableH = insetFrame.h - totalMargins
      local h = availableH / numSecondary
      local secondaryIndex = index - 2  -- 0-based index for secondary windows

      return {
        x = insetFrame.x + insetFrame.w * layoutOptions.mainPaneRatio + margin / 2,
        y = insetFrame.y + margin / 2 + secondaryIndex * (h + margin),
        w = insetFrame.w * (1 - layoutOptions.mainPaneRatio) - margin,
        h = h
      }
    end
  end

  layouts["main-right"] = function(window, windows, screen, index, layoutOptions)
    if #windows == 1 then
      return layouts["main-center"](window, windows, screen, index, layoutOptions)
    end

    local margin     = hhtwm.margin or 0
    local insetFrame = getInsetFrame(screen)

    if index == 1 then
      -- main window on right
      return {
        x = insetFrame.x + insetFrame.w * layoutOptions.mainPaneRatio + margin / 2,
        y = insetFrame.y + margin / 2,
        w = insetFrame.w * (1 - layoutOptions.mainPaneRatio) - margin,
        h = insetFrame.h - margin
      }
    else
      -- secondary windows on left, stacked vertically
      local numSecondary = #windows - 1
      local totalMargins = numSecondary * margin
      local availableH = insetFrame.h - totalMargins
      local h = availableH / numSecondary
      local secondaryIndex = index - 2

      return {
        x = insetFrame.x + margin / 2,
        y = insetFrame.y + margin / 2 + secondaryIndex * (h + margin),
        w = insetFrame.w * layoutOptions.mainPaneRatio - margin,
        h = h
      }
    end
  end

  layouts["main-center"] = function(window, windows, screen, index, layoutOptions)
    local insetFrame      = getInsetFrame(screen)
    local margin          = hhtwm.margin or 0
    local mainColumnWidth = insetFrame.w * layoutOptions.mainPaneRatio

    if index == 1 then
      return {
        x = insetFrame.x + (insetFrame.w - mainColumnWidth) / 2,
        y = insetFrame.y + margin / 2,
        w = mainColumnWidth - margin,
        h = insetFrame.h - margin
      }
    end

    local sideWidth = (insetFrame.w - mainColumnWidth) / 2 - margin

    -- windows alternate: left (even index-1), right (odd index-1)
    local isLeft = (index - 1) % 2 == 0
    local sideIndex = math.floor((index - 2) / 2)  -- 0-based index within each side

    -- count windows on each side
    local leftCount = math.floor((#windows - 1) / 2)
    local rightCount = math.ceil((#windows - 1) / 2)
    local numOnThisSide = isLeft and leftCount or rightCount

    if numOnThisSide == 0 then numOnThisSide = 1 end

    local totalMargins = numOnThisSide * margin
    local availableH = insetFrame.h - totalMargins
    local h = availableH / numOnThisSide

    local x = isLeft
      and (insetFrame.x + margin / 2)
      or (insetFrame.x + insetFrame.w - sideWidth - margin / 2)

    return {
      x = x,
      y = insetFrame.y + margin / 2 + sideIndex * (h + margin),
      w = sideWidth,
      h = h
    }
  end

  layouts["tabbed-left"] = function(window, windows, screen, index, layoutOptions)
    if #windows == 1 then
      return layouts["main-center"](window, windows, screen, index, layoutOptions)
    end

    local margin     = hhtwm.margin or 0
    local insetFrame = getInsetFrame(screen)

    local frame = {
      x = insetFrame.x,
      y = insetFrame.y,
      w = 0,
      h = 0
    }

    if index == 1 then
      frame.x = frame.x + insetFrame.w * layoutOptions.mainPaneRatio + margin / 2
      frame.y = frame.y + margin / 2
      frame.w = insetFrame.w * (1 - layoutOptions.mainPaneRatio) - margin
      frame.h = insetFrame.h - margin
    else
      frame.x = frame.x + margin / 2
      frame.y = frame.y + margin / 2
      frame.w = insetFrame.w * layoutOptions.mainPaneRatio - margin
      frame.h = insetFrame.h - margin
    end

    return frame
  end

  layouts["tabbed-right"] = function(window, windows, screen, index, layoutOptions)
    if #windows == 1 then
      return layouts["main-center"](window, windows, screen, index, layoutOptions)
    end

    local margin     = hhtwm.margin or 0
    local insetFrame = getInsetFrame(screen)

    local frame = {
      x = insetFrame.x,
      y = insetFrame.y,
      w = 0,
      h = 0
    }

    if index == 1 then
      frame.x = frame.x + margin / 2
      frame.y = frame.y + margin / 2
      frame.w = insetFrame.w * layoutOptions.mainPaneRatio - margin
      frame.h = insetFrame.h - margin
    else
      frame.x = frame.x + insetFrame.w * layoutOptions.mainPaneRatio + margin / 2
      frame.y = frame.y + margin / 2
      frame.w = insetFrame.w * (1 - layoutOptions.mainPaneRatio) - margin
      frame.h = insetFrame.h - margin
    end

    return frame
  end

  -- TODO
  -- layouts["stacking-columns"] = function(window, windows, screen, index, layoutOptions)
  --   return nil
  -- end

  return layouts
end
