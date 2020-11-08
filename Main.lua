local GUI = require("GUI")
local system = require("System")
local filesystem = require("Filesystem")
local component = require("Component")
local paths = require("Paths")
local internet = require("Internet")
local json = require("JSON")
local cp = require("CubiPlayer")

--------------------------------------------------------------------------------------------------------------------------

local internetFeatures = true

--Check radio exists or not
if not component.isAvailable("openfm_radio") then
  GUI.alert("This program requires an OpenFM Radio")
  return
end

--Check internet card exist or not
if not component.isAvailable("internet") then
  internetFeatures = false
end

--------------------------------------------------------------------------------------------------------------------------

local appPath = paths.user.applicationData .. "Cubify/"
local workspace, window = system.addWindow(GUI.titledWindow(1, 1, 80, 27, "Cubify"))
local player = cp.player(component.openfm_radio)

player.radio.setScreenText("Cubify")
window:addChild(GUI.panel(1, 2, window.width, window.height-1, 0x3C3C3C))
local leftListPanel = window:addChild(GUI.panel(1, 2, 20, 26, 0x252525))
local leftList = window:addChild(GUI.list(1, 5, leftListPanel.width, 25, 3, 0, 0x252525, 0x787878, 0x252525, 0x787878, 0x3C3C3C, 0xCCCCCC, false))

local contentContainer = window:addChild(GUI.container(21, 2, 60, 26))

--------------------------------------------------------------------------------------------------------------------------

--Spizheno from ECS's App Market
local function newPlusMinusCyka(width, disableLimit)
  local layout = GUI.layout(1, 1, width, 1, 2, 1)
  layout:setColumnWidth(1, GUI.SIZE_POLICY_RELATIVE, 1.0)
  layout:setColumnWidth(2, GUI.SIZE_POLICY_ABSOLUTE, 8)
  layout:setFitting(1, 1, true, false)
  layout:setMargin(2, 1, 1, 0)
  layout:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_TOP)
  layout:setAlignment(2, 1, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_TOP)
  layout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
  layout:setDirection(2, 1, GUI.DIRECTION_HORIZONTAL)

  layout.comboBox = layout:addChild(GUI.comboBox(1, 1, width - 7, 1, 0xFFFFFF, 0x878787, 0x969696, 0xE1E1E1))
  layout.defaultColumn = 2
  layout.addButton = layout:addChild(GUI.button(1, 1, 3, 1, 0x696969, 0xFFFFFF, 0x2D2D2D, 0xFFFFFF, "+"))
  layout.removeButton = layout:addChild(GUI.button(1, 1, 3, 1, 0x696969, 0xFFFFFF, 0x2D2D2D, 0xFFFFFF, "-"))

  local overrideRemoveButtonDraw = layout.removeButton.draw
  layout.removeButton.draw = function(...)
    layout.removeButton.disabled = layout.comboBox:count() <= disableLimit
    overrideRemoveButtonDraw(...)
  end
  
  layout.removeButton.onTouch = function()
    layout.comboBox:removeItem(layout.comboBox.selectedItem)
    workspace:draw()
  end
  return layout
end


local function playlists()
  if not filesystem.exists(appPath .. "Playlists/") then
    filesystem.makeDirectory(appPath .. "Playlists/")
  end
  
  contentContainer:removeChildren()
  player.onEnd = nil
  player.onNextTrack = nil
  
  local layout = contentContainer:addChild(GUI.layout(1, 1, contentContainer.width, contentContainer.height, 1, 3))
  layout:setRowHeight(1, GUI.SIZE_POLICY_ABSOLUTE, 5)
  layout:setRowHeight(2, GUI.SIZE_POLICY_ABSOLUTE, 20)
  layout:setRowHeight(3, GUI.SIZE_POLICY_ABSOLUTE, 1)
  layout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
  local pl_list = layout:setPosition(1, 2, layout:addChild(GUI.list(1, 1, 60, 20, 1, 0, 0x2d2d2d, 0x878787, 0x2d2d2d, 0xb4b4b4, 0x993399, 0xc3c3c3, false)))
  
  local function getCurrPlst()
    local i = pl_list:getItem(pl_list.selectedItem)
    if i ~= nil then
      return i.playlist
    end
  end
  
  for _, v in pairs(filesystem.list(appPath .. "Playlists/")) do
    if filesystem.exists(appPath .. "Playlists/" .. v) then
      local l = filesystem.readTable(appPath .. "Playlists/" .. v)
      pl_list:addItem(l.name).playlist = l
    end
  end
  local current_label = layout:setPosition(1, 3, layout:addChild(GUI.label(1, 1, layout.width-2, 1, 0xCCCCCC, " ")))
  
  layout:setPosition(1, 1, layout:addChild(GUI.roundedButton(1, 1, 7, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "Add"))).onTouch = function()
    if pl_list:count() > 20 then
      GUI.alert("Get Cubify Premium to display more than 20 playlists!\n\n\nJust a joke, in fact, I'm just too lazy to implement it, later as the time will come to do it.")
    end
    local cnt = GUI.addBackgroundContainer(workspace, true, true, "Add new Playlist")
    local input = cnt.layout:addChild(GUI.input(1, 1, 30, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, nil, "Playlsit Name"))
    cnt.layout:addChild(GUI.roundedButton(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "Add!")).onTouch = function()
      filesystem.writeTable(appPath .. "Playlists/" .. input.text .. ".cfg", {
        name = input.text,
        tracks = {}
      })
      playlists()
      cnt:remove()
    end
  end
  
  layout:setPosition(1, 1, layout:addChild(GUI.roundedButton(1, 1, 7, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "Edit"))).onTouch = function()
    if getCurrPlst() == nil then
      GUI.alert("No playlists to edit!")
      return
    end
    local cnt = GUI.addBackgroundContainer(workspace, true, true, "Edit " .. getCurrPlst().name)
    local pname = cnt.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, getCurrPlst().name, "Playlist Name"))
    cnt.layout:addChild(GUI.label(1, 1, 14, 1, 0xCCCCCC, "Select Tracks:"))
    local pmcyka = cnt.layout:addChild(newPlusMinusCyka(60, 0))
    
    for k, v in pairs(getCurrPlst().tracks) do
      pmcyka.comboBox:addItem(v.name).track = v
    end
    pmcyka.comboBox.selectedItem = 1
    
    pmcyka.addButton.onTouch = function()
      local container = GUI.addBackgroundContainer(workspace, true, true, "Add new track")
      local tname = container.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, nil, "Track Name"))
      local turl = container.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, nil, "Track URL"))
      local tduration = container.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, nil, "Track Duration (seconds)"))
      container.layout:addChild(GUI.roundedButton(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "Create!")).onTouch = function()
        pmcyka.comboBox:addItem(tname.text).track = {name=tname.text, url=turl.text, duration=tonumber(tduration.text)}
        pmcyka.comboBox.selectedItem = pmcyka.comboBox:count()
        container:remove()
      end
    end
    
    local btnslay = cnt.layout:addChild(GUI.layout(1, 1, 50, 3, 1, 1))
    btnslay:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
    
    btnslay:addChild(GUI.roundedButton(1, 1, 10, 3, 0xFF4940, 0xFFFFFF, 0x880000, 0xFFFFFF, "Remove!")).onTouch = function()
      filesystem.remove(appPath .. "Playlists/" .. getCurrPlst().name .. ".cfg")
      playlists()
      cnt:remove()
    end
    
    btnslay:addChild(GUI.roundedButton(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "Edit!")).onTouch = function()
      if pname.text ~= getCurrPlst().name then
        filesystem.rename(appPath .. "Playlists/" .. getCurrPlst().name .. ".cfg", appPath .. "Playlists/" .. pname.text .. ".cfg")
        getCurrPlst().name = pname.text
      end
      local newlist = {name = getCurrPlst().name, tracks={}}
      for i = 1, pmcyka.comboBox:count() do
        newlist.tracks[i] = pmcyka.comboBox:getItem(i).track
      end
      filesystem.writeTable(appPath .. "Playlists/" .. getCurrPlst().name .. ".cfg", newlist)
      playlists()
      cnt:remove()
    end
  end
  layout:setPosition(1, 1, layout:addChild(GUI.roundedButton(1, 1, 7, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "▕◀"))).onTouch = function()
    player:prev()
  end
  local play_btn = layout:setPosition(1, 1, layout:addChild(GUI.roundedButton(1, 1, 7, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "▷")))
  
  player.onEnd = function()
    play_btn.text = "▷"
    current_label.text = " "
    workspace:draw()
  end
  
  player.onNextTrack = function()
    play_btn.text = "▐█▌"
    current_label.text = "Now Playing: " .. player.current.name
    workspace:draw()
  end
  
  play_btn.onTouch = function()
    if getCurrPlst() == nil then
      GUI.alert("No playlists to play!")
      return
    end
  
    if not player.isPlaying then
      if #player.queue == 0 and player.current == nil then
        for k, v in pairs(getCurrPlst().tracks) do
          player:addTrack(v)
        end
      end
      player:play()
    else
      player:stop()
    end
  end
  
  layout:setPosition(1, 1, layout:addChild(GUI.roundedButton(1, 1, 7, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "▶▏"))).onTouch = function()
    player:next()
  end
  
  local slider = layout:setPosition(1, 1, layout:addChild(GUI.slider(1, 1, 14, 0x993399, 0x0, 0xCCCCCC, 0xAAAAAA, 0, 9, 5, false)))
  slider.roundValues = true
  slider.onValueChanged = function()
    player:setVol(slider.value)
  end
end

---------------------------------------------------------------------------------------------------

local function loctracks()
  if not filesystem.exists(appPath .. "Tracks/") then
    filesystem.makeDirectory(appPath .. "Tracks/")
  end
  
  contentContainer:removeChildren()
  player.onEnd = nil
  player.onNextTrack = nil
  
  local layout = contentContainer:addChild(GUI.layout(1, 1, contentContainer.width, contentContainer.height, 1, 3))
  layout:setRowHeight(1, GUI.SIZE_POLICY_ABSOLUTE, 5)
  layout:setRowHeight(2, GUI.SIZE_POLICY_ABSOLUTE, 20)
  layout:setRowHeight(3, GUI.SIZE_POLICY_ABSOLUTE, 1)
  layout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
  local tr_list = layout:setPosition(1, 2, layout:addChild(GUI.list(1, 1, 60, 20, 1, 0, 0x2d2d2d, 0x878787, 0x2d2d2d, 0xb4b4b4, 0x993399, 0xc3c3c3, false)))
  
  local function getCurrTrack()
    local i = tr_list:getItem(tr_list.selectedItem)
    if i ~= nil then
      return i.track
    end
  end
  
  for _, v in pairs(filesystem.list(appPath .. "Tracks/")) do
    if filesystem.exists(appPath .. "Tracks/" .. v) then
      local l = filesystem.readTable(appPath .. "Tracks/" .. v)
      local i = tr_list:addItem(l.name)
      i.track = l
      i.onTouch = function()
        if tr_list.onItemsTouch ~= nil then
          tr_list:onItemsTouch()
        end
      end
    end
  end
  
  local current_label = layout:setPosition(1, 3, layout:addChild(GUI.label(1, 1, layout.width-2, 1, 0xCCCCCC, " ")))
  
  layout:setPosition(1, 1, layout:addChild(GUI.roundedButton(1, 1, 7, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "Add"))).onTouch = function()
    if tr_list:count() > 20 then
      GUI.alert("Get Cubify Premium to display more than 20 tracks!\n\n\nJust a joke, in fact, I'm just too lazy to implement it, later as the time will come to do it.")
    end
    local container = GUI.addBackgroundContainer(workspace, true, true, "Add new track")
    local tname = container.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, nil, "Track Name"))
    local turl = container.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, nil, "Track URL"))
    local tduration = container.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, nil, "Track Duration (seconds)"))
    container.layout:addChild(GUI.roundedButton(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "Create!")).onTouch = function()
      filesystem.writeTable(appPath .. "Tracks/" .. tname.text .. ".cfg", {
        name = tname.text, 
        url = turl.text, 
        duration = tonumber(tduration.text)
      })
      loctracks()
      container:remove()
    end
  end
  
  layout:setPosition(1, 1, layout:addChild(GUI.roundedButton(1, 1, 7, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "Edit"))).onTouch = function()
    if getCurrTrack() == nil then
      GUI.alert("No tracks to edit!")
      return
    end
    local container = GUI.addBackgroundContainer(workspace, true, true, "Edit " .. getCurrTrack().name)
    local tname = container.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, getCurrTrack().name, "Track Name"))
    local turl = container.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, getCurrTrack().url, "Track URL"))
    local tduration = container.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, getCurrTrack().duration, "Track Duration (seconds)"))
    
    local btnslay = container.layout:addChild(GUI.layout(1, 1, 50, 3, 1, 1))
    btnslay:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
    
    btnslay:addChild(GUI.roundedButton(1, 1, 10, 3, 0xFF4940, 0xFFFFFF, 0x880000, 0xFFFFFF, "Remove!")).onTouch = function()
      filesystem.remove(appPath .. "Tracks/" .. getCurrTrack().name .. ".cfg")
      loctracks()
      container:remove()
    end
    
    btnslay:addChild(GUI.roundedButton(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "Edit!")).onTouch = function()
      if tname.text ~= getCurrTrack().name then
        filesystem.rename(appPath .. "Tracks/" .. getCurrTrack().name .. ".cfg", appPath .. "Tracks/" .. tname.text .. ".cfg")
        getCurrTrack().name = tname.text
      end
      if turl.text ~= getCurrTrack().url then
        getCurrTrack().url = turl.text
      end
      if tduration.text ~= getCurrTrack().duration then
        getCurrTrack().duration = tonumber(tduration.text)
      end
      filesystem.writeTable(appPath .. "Tracks/" .. getCurrTrack().name .. ".cfg", getCurrTrack())
      loctracks()
      container:remove()
    end
  end
  layout:setPosition(1, 1, layout:addChild(GUI.roundedButton(1, 1, 7, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "▕◀"))).onTouch = function()
    if tr_list.selectedItem-1 > 0 and player.isPlaying then
      tr_list.selectedItem = tr_list.selectedItem - 1
    end
    player:prev()
  end
  local play_btn = layout:setPosition(1, 1, layout:addChild(GUI.roundedButton(1, 1, 7, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "▷")))
  
  player.onEnd = function()
    play_btn.text = "▷"
    current_label.text = " "
    workspace:draw()
  end
  
  player.onNextTrack = function()
    play_btn.text = "▐█▌"
    current_label.text = "Now Playing: " .. player.current.name
    workspace:draw()
  end
  
  player.onTrackEnds = function()
    if tr_list.selectedItem+1 <= tr_list:count() and player.isPlaying then
      tr_list.selectedItem = tr_list.selectedItem + 1
    end
  end
  
  tr_list.onItemsTouch = function()
    if getCurrTrack() == nil then
      GUI.alert("No tracks to play!")
      return
    end
    if player.isPlaying then
      player.queue = {}
      player.current = nil
      if #player.queue == 0 and player.current == nil then
        for i = 1, tr_list.selectedItem-1 do
          table.insert(player.previous, #player.previous+1, tr_list:getItem(i).track)
        end
        for i = tr_list.selectedItem, tr_list:count() do
          player:addTrack(tr_list:getItem(i).track)
        end
      end
      player:play()
    end
  end
  
  play_btn.onTouch = function()
    if getCurrTrack() == nil then
      GUI.alert("No tracks to play!")
      return
    end
    if not player.isPlaying then
      if #player.queue == 0 and player.current == nil then
        for i = 1, tr_list.selectedItem-1 do
          table.insert(player.previous, #player.previous+1, tr_list:getItem(i).track)
        end
        for i = tr_list.selectedItem, tr_list:count() do
          player:addTrack(tr_list:getItem(i).track)
        end
      end
      player:play()
    else
      player:stop()
    end
  end
  
  layout:setPosition(1, 1, layout:addChild(GUI.roundedButton(1, 1, 7, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "▶▏"))).onTouch = function()
    if tr_list.selectedItem+1 <= tr_list:count() and player.isPlaying then
      tr_list.selectedItem = tr_list.selectedItem + 1
    end
    player:next()
  end
  
  local slider = layout:setPosition(1, 1, layout:addChild(GUI.slider(1, 1, 14, 0x993399, 0x0, 0xCCCCCC, 0xAAAAAA, 0, 9, 5, false)))
  slider.roundValues = true
  slider.onValueChanged = function()
    player:setVol(slider.value)
  end
end

---------------------------------------------------------------------------------------------------

local function hex_to_char(x)
  return string.char(tonumber(x, 16))
end

local function percentDecode(text)
  if text == nil then
    return
  end
  text = text:gsub("+", " ")
  text = text:gsub("%%(%x%x)", hex_to_char)
  return text
end

local function cltracks()
  if not filesystem.exists(appPath .. "Tracks/") then
    filesystem.makeDirectory(appPath .. "Tracks/")
  end
  
  contentContainer:removeChildren()
  player.onEnd = nil
  player.onNextTrack = nil
  
  local layout = contentContainer:addChild(GUI.layout(1, 1, contentContainer.width, contentContainer.height, 1, 4))
  layout:setRowHeight(1, GUI.SIZE_POLICY_ABSOLUTE, 5)
  layout:setRowHeight(2, GUI.SIZE_POLICY_ABSOLUTE, 19)
  layout:setRowHeight(3, GUI.SIZE_POLICY_ABSOLUTE, 1)
  layout:setRowHeight(4, GUI.SIZE_POLICY_ABSOLUTE, 1)
  layout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
  layout:setDirection(1, 3, GUI.DIRECTION_HORIZONTAL)
  local tr_list = layout:setPosition(1, 2, layout:addChild(GUI.list(1, 1, 60, 19, 1, 0, 0x2d2d2d, 0x878787, 0x2d2d2d, 0xb4b4b4, 0x993399, 0xc3c3c3, false)))
  
  local function getCurrTrack()
    local i = tr_list:getItem(tr_list.selectedItem)
    if i ~= nil then
      return i.track
    end
  end
  
  for _, v in pairs(filesystem.list(appPath .. "Tracks/")) do
    if filesystem.exists(appPath .. "Tracks/" .. v) then
      local l = filesystem.readTable(appPath .. "Tracks/" .. v)
      local i = tr_list:addItem(l.name)
      i.track = l
      i.onTouch = function()
        if tr_list.onItemsTouch ~= nil then
          tr_list:onItemsTouch()
        end
      end
    end
  end
  
  local page = 1
  layout:setSpacing(1, 3, 2)
  --layout:setPosition(1, 3, layout:addChild(GUI.panel(1, 1, layout.width, 1, 0x2D2D2D)))
  local back_btn = layout:setPosition(1, 3, layout:addChild(GUI.roundedButton(1, 1, 3, 1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "<")))
  local page_txt = layout:setPosition(1, 3, layout:addChild(GUI.text(1, 1, 0xCCCCCC, "Page " .. page)))
  local next_btn = layout:setPosition(1, 3, layout:addChild(GUI.roundedButton(1, 1, 3, 1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, ">")))
  local current_label = layout:setPosition(1, 4, layout:addChild(GUI.label(1, 1, layout.width-2, 1, 0xCCCCCC, " ")))
  
  local function switchPage(forward)
    local res, reason = internet.request("https://api.rainbowbot.xyz/cubify/tracks/page?page=" .. page-1 .. "&count=19", nil, {
      ["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X x.y; rv:42.0) Gecko/20100101 Firefox/42.0"
    }, "GET")
    if not res then
      GUI.alert(reason)
      return
    else
      page = page + (forward and 1 or -1)
      tr_list:removeChildren()
      data = json.decode(res)
      for i = 1, #data.tracks do
        local item = tr_list:addItem(percentDecode(data.tracks[i].name))
        item.track = {name = percentDecode(data.tracks[i].name), url = percentDecode(data.tracks[i].url), duration = 9999999}
        item.onTouch = function()
          if tr_list.onItemsTouch ~= nil then
            tr_list:onItemsTouch()
          end
        end
      end
    end
    page_txt.text = "Page " .. page
    back_btn.disabled = page == 1
  end
  switchPage(true)
  back_btn.disabled = page == 1
  back_btn.onTouch = function()
    switchPage(false)
  end
  
  next_btn.onTouch = function()
    switchPage(true)
  end
  
  layout:setPosition(1, 1, layout:addChild(GUI.roundedButton(1, 1, 7, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "Add"))).onTouch = function()
    if tr_list:count() > 20 then
      GUI.alert("Get Cubify Premium to display more than 20 tracks!\n\n\nJust a joke, in fact, I'm just too lazy to implement it, later as the time will come to do it.")
    end
    local container = GUI.addBackgroundContainer(workspace, true, true, "Add new track")
    local tname = container.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, nil, "Track Name"))
    local turl = container.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, nil, "Track URL"))
    local tduration = container.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, nil, "Track Duration (seconds)"))
    container.layout:addChild(GUI.roundedButton(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "Create!")).onTouch = function()
      filesystem.writeTable(appPath .. "Tracks/" .. tname.text .. ".cfg", {
        name = tname.text, 
        url = turl.text, 
        duration = tonumber(tduration.text)
      })
      loctracks()
      container:remove()
    end
  end
  
  layout:setPosition(1, 1, layout:addChild(GUI.roundedButton(1, 1, 7, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "Edit"))).onTouch = function()
    if getCurrTrack() == nil then
      GUI.alert("No tracks to edit!")
      return
    end
    local container = GUI.addBackgroundContainer(workspace, true, true, "Edit " .. getCurrTrack().name)
    local tname = container.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, getCurrTrack().name, "Track Name"))
    local turl = container.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, getCurrTrack().url, "Track URL"))
    local tduration = container.layout:addChild(GUI.input(1, 1, 60, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, getCurrTrack().duration, "Track Duration (seconds)"))
    
    local btnslay = container.layout:addChild(GUI.layout(1, 1, 50, 3, 1, 1))
    btnslay:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
    
    btnslay:addChild(GUI.roundedButton(1, 1, 10, 3, 0xFF4940, 0xFFFFFF, 0x880000, 0xFFFFFF, "Remove!")).onTouch = function()
      filesystem.remove(appPath .. "Tracks/" .. getCurrTrack().name .. ".cfg")
      loctracks()
      container:remove()
    end
    
    btnslay:addChild(GUI.roundedButton(1, 1, 30, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "Edit!")).onTouch = function()
      if tname.text ~= getCurrTrack().name then
        filesystem.rename(appPath .. "Tracks/" .. getCurrTrack().name .. ".cfg", appPath .. "Tracks/" .. tname.text .. ".cfg")
        getCurrTrack().name = tname.text
      end
      if turl.text ~= getCurrTrack().url then
        getCurrTrack().url = turl.text
      end
      if tduration.text ~= getCurrTrack().duration then
        getCurrTrack().duration = tonumber(tduration.text)
      end
      filesystem.writeTable(appPath .. "Tracks/" .. getCurrTrack().name .. ".cfg", getCurrTrack())
      loctracks()
      container:remove()
    end
  end
  layout:setPosition(1, 1, layout:addChild(GUI.roundedButton(1, 1, 7, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "▕◀"))).onTouch = function()
    if tr_list.selectedItem-1 > 0 and player.isPlaying then
      tr_list.selectedItem = tr_list.selectedItem - 1
    end
    player:prev()
  end
  local play_btn = layout:setPosition(1, 1, layout:addChild(GUI.roundedButton(1, 1, 7, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "▷")))
  
  player.onEnd = function()
    play_btn.text = "▷"
    current_label.text = " "
    workspace:draw()
  end
  
  player.onNextTrack = function()
    play_btn.text = "▐█▌"
    current_label.text = "Now Playing: " .. player.current.name
    workspace:draw()
  end
  
  player.onTrackEnds = function()
    if tr_list.selectedItem+1 <= tr_list:count() and player.isPlaying then
      tr_list.selectedItem = tr_list.selectedItem + 1
    end
  end
  
  tr_list.onItemsTouch = function()
    if getCurrTrack() == nil then
      GUI.alert("No tracks to play!")
      return
    end
    if player.isPlaying then
      player.queue = {}
      player.current = nil
      if #player.queue == 0 and player.current == nil then
        for i = 1, tr_list.selectedItem-1 do
          table.insert(player.previous, #player.previous+1, tr_list:getItem(i).track)
        end
        for i = tr_list.selectedItem, tr_list:count() do
          player:addTrack(tr_list:getItem(i).track)
        end
      end
      player:play()
    end
  end
  
  play_btn.onTouch = function()
    if getCurrTrack() == nil then
      GUI.alert("No tracks to play!")
      return
    end
    if not player.isPlaying then
      if #player.queue == 0 and player.current == nil then
        for i = 1, tr_list.selectedItem-1 do
          table.insert(player.previous, #player.previous+1, tr_list:getItem(i).track)
        end
        for i = tr_list.selectedItem, tr_list:count() do
          player:addTrack(tr_list:getItem(i).track)
        end
      end
      player:play()
    else
      player:stop()
    end
  end
  
  layout:setPosition(1, 1, layout:addChild(GUI.roundedButton(1, 1, 7, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "▶▏"))).onTouch = function()
    if tr_list.selectedItem+1 <= tr_list:count() and player.isPlaying then
      tr_list.selectedItem = tr_list.selectedItem + 1
    end
    player:next()
  end
  
  local slider = layout:setPosition(1, 1, layout:addChild(GUI.slider(1, 1, 14, 0x993399, 0x0, 0xCCCCCC, 0xAAAAAA, 0, 9, 5, false)))
  slider.roundValues = true
  slider.onValueChanged = function()
    player:setVol(slider.value)
  end
end

playlists()
leftList:addItem("Playlists").onTouch = playlists
leftList:addItem("Tracks").onTouch = loctracks
leftList:addItem("Cloud Tracks").onTouch = cltracks
leftList:addItem("Settings").onTouch = settings


window.actionButtons.maximize:remove()
window.actionButtons.close.onTouch = function()
  player:stop()
  player.radio.setScreenText("Cubify")
  window:remove()
end

--------------------------------------------------------------------------------------------------------------------------------------
workspace:draw()



