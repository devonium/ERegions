 local print = function(...)
    if #{...} == 0 then
        return reaper.ShowConsoleMsg(dbg "nil\n")
    end
    for k, v in pairs({...}) do
        reaper.ShowConsoleMsg(tostring(v) .. "\n")
    end
end

local function removeRegionRenderMarks()
  local regindex = -1
  while true do
      local r, a, num_regions = reaper.CountProjectMarkers(0)
      if regindex >= num_regions then
          break
      end
  
      local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers2(0, regindex)
  
      if retval ~= 0 then
          if isrgn and string.match(name, "^rrr") ~= nil then
              reaper.DeleteProjectMarkerByIndex(0, regindex)
              regindex = -1
          end
      end
      regindex = regindex + 1
  end
end

local function addRegionsToSelectedTracks(includeMuted, useItemsName, aExt, useGroups)
    local items = {}

    for i = 0, reaper.CountSelectedMediaItems(0) do
        local mitem = reaper.GetSelectedMediaItem(0, i)
        if mitem and (includeMuted or (reaper.GetMediaItemInfo_Value(mitem, "B_MUTE") == 0 and reaper.GetMediaTrackInfo_Value(reaper.GetMediaItemInfo_Value(mitem, "P_TRACK"),"B_MUTE") == 0))  then
            local istart = reaper.GetMediaItemInfo_Value(mitem, "D_POSITION")
            local iend = istart + reaper.GetMediaItemInfo_Value(mitem, "D_LENGTH")
            
            local name = tostring(reaper.GetTakeName(reaper.GetActiveTake(mitem)))

            if not aExt then name = name:gsub("%.[^%.]*$", "") end
            name = name:gsub("%.", "_")
            items[#items + 1] = {istart = istart, iend = iend, disabled = false, 
              name = name, 
              groupID = reaper.GetMediaItemInfo_Value(mitem, "I_GROUPID")}
        end
    end

    table.sort(
        items,
        function(a, b)
            return a.istart < b.istart
        end
    )
    
    for _, v in pairs(items) do
        ::repeatl::
        local datachanged = false
        if not v.disabled then
            for _, nextv in pairs(items) do
                if v ~= nextv and (not nextv.disabled) then
                    if nextv.istart > v.istart and nextv.istart < v.iend and nextv.iend < v.iend then
                        nextv.disabled = true
                    elseif nextv.istart < v.iend and nextv.iend > v.istart then
                        v.iend = nextv.iend
                        nextv.disabled = true
                        datachanged = true
                    elseif useGroups and (nextv.istart > v.iend) and ((nextv.groupID == v.groupID) and (nextv.groupID + v.groupID) ~= 0) then
                        nextv.disabled = true
                        v.iend = nextv.iend
                        datachanged = true
                    end
                end
            end
        end

        if datachanged then
            goto repeatl
        end
    end

    --print(#items)

    local rIndex = 0

    local r, a, num_regions = reaper.CountProjectMarkers(0)
    for i = 0, num_regions do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers2(0, i)

        if retval ~= 0 then
            if isrgn and string.match(name, "^rrr_") ~= nil then
                local n = string.match(name, "rrr_([0-9]*)")
                if n then
                    n = tonumber(n)
                end
                if n then
                    rIndex = n + 1
                end
            end
        end
    end

    for k, v in pairs(items) do
        --print(rIndex..":"..v.istart.." "..v.iend)
        if not v.disabled then

            reaper.AddProjectMarker2(0, true, v.istart, v.iend, "rrr_" .. rIndex .. (useItemsName and ("_"..v.name) or ""), -1, 0)
            rIndex = rIndex + 1
        end
    end
end

local press = {}
local function button(text)
    local ox = gfx.x
    local w, h = #text * 8 + 8, gfx.texth * 2
    local click = false
    if gfx.mouse_x >= gfx.x and gfx.mouse_x < (gfx.x + w) and gfx.mouse_y >= gfx.y and gfx.mouse_y < (gfx.y + h) then
        if (gfx.mouse_cap & 1) == 1 then
            press[text] = true
        elseif press[text] and (gfx.mouse_cap & 1) ~= 1 then
            click = true
            press[text] = false
        end
        gfx.r = 0
        gfx.b = 0
    else
        press[text] = false
        gfx.r = 1
        gfx.b = 1
    end
    gfx.rect(gfx.x, gfx.y, w, h, false)
    gfx.y = gfx.y + 4
    gfx.x = gfx.x + 4
    gfx.drawstr(text)
    gfx.x = ox
    gfx.y = gfx.y + gfx.texth * 2 + 2

    return click
end

local chekboxd = {}
local function chekbox(text,deval, disabled)
    if chekboxd[text] == nil then chekboxd[text] = deval end
    local ox = gfx.x
    local w, h = #text * 8 + 8, gfx.texth * 2
    if not disabled then
      if gfx.mouse_x >= gfx.x and gfx.mouse_x < (gfx.x + w) and gfx.mouse_y >= gfx.y and gfx.mouse_y < (gfx.y + h) then
          if (gfx.mouse_cap & 1) == 1 then
              press[text] = true
          elseif press[text] and (gfx.mouse_cap & 1) ~= 1 then
              chekboxd[text] = not chekboxd[text]
              press[text] = false
          end
          gfx.r = 0
          gfx.b = 0  
      else
          press[text] = false
          gfx.r = 1
          gfx.b = 1
      end
    else
      gfx.r,gfx.g,gfx.b = 0.5,0.5,0.5
    end

    gfx.rect(gfx.x, gfx.y, h, h, false)
    if chekboxd[text] then gfx.rect(gfx.x + 2, gfx.y + 2, h -4, h - 4,true) end
    gfx.y = gfx.y + h / 4 + 1
    gfx.x = gfx.x + h + 5
    gfx.drawstr(text)
    gfx.x = ox
    gfx.y = gfx.y + gfx.texth * 2 + 2


    gfx.r,gfx.g,gfx.b = 1,1,1
    return chekboxd[text]
end

local ignorem = false
local appendn = false
local appendext = false
local ugroups = false
local function main()
    gfx.x = 5
    gfx.y = 5
    if (button("Add selection to render")) then
        addRegionsToSelectedTracks(not ignorem, appendn, not appendext, ugroups)
    end
    
    appendn = chekbox("Append item's name", true)
    appendext = chekbox("Remove extension", true, not appendn)
    ugroups = chekbox("Merge grouped clips", true)
    ignorem = chekbox("Ignore muted tracks & items", true)
    
    if (button("Clear render regions")) then
        removeRegionRenderMarks()
    end

    if gfx.getchar() > -1 then
        reaper.defer(main)
    end
end

gfx.init("ERegions", 256, 140, 0, 100, 100)
main()
