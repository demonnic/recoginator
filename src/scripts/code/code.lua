--- The recogINATOR is designed to help you remember who you enjoyed RPing with
--- so they can get that sweet sweet mechanical benefit
recoginator = recoginator or {}
recoginator.data = recoginator.data or {}
recoginator.data.recogs = recoginator.data.recogs or {}
recoginator.window = recoginator.window or "main"
recoginator.width = recoginator.width or 80
local ft = require("@PKGNAME@.ftext")
local filename = getMudletHomeDir() .. "/recoginator.lua"
local backup = filename .. ".bak"

local printTable = ft.TableMaker:new({allowPopups = true, autoEchoConsole = recoginator.window})
printTable:addColumn({name = "#", width = 3, textColor = "<orange>"})
printTable:addColumn({name = "Server Time", width = 20, textColor = "<orange>", alignment = "left"})
printTable:addColumn({name = " Name", width = 16, textColor = "<turquoise>", alignment = "left"})
printTable:addColumn({name = " Reason", width = (recoginator.width - 44), textColor = "<green>", alignment = "left"})

local monthToDays = {
  31,
  28,
  31,
  30,
  31,
  30,
  31,
  31,
  30,
  31,
  30,
  31
}

local function copyFile(original, new)
  if not io.exists(original) then
    return nil, f"File {original} not found"
  end
  local currentFile = io.open(original, "r")
  local currentContents = currentFile:read("*a")
  currentFile:close()
  local backupFile = io.open(new, "w")
  backupFile:write(currentContents)
  backupFile:close()
end

local function isLeapYear(year)
  if year % 4 ~= 0 then
    return false
  end
  if year % 100 ~= 0 then
    return true
  end
  return year % 400 == 0
end

local function daysInMonth(month, year)
  if month == 0 then
    month = 12
    year = year - 1
  elseif month == 13 then
    month = 1
    year = year + 1
  end
  local days = monthToDays[month]
  if days == 28 and isLeapYear(year) then
    days = 29
  end
  return days
end

function recoginator.add(name, reason)
  local data = recoginator.data.recogs
  recoginator.last_action = "add"
  local timeTable = recoginator.timeywimey()
  local timeStamp = string.format("%d/%02d/%02d %02d:%02d:%02d",
                                  timeTable.year,
                                  timeTable.month,
                                  timeTable.day,
                                  timeTable.hour,
                                  timeTable.min,
                                  timeTable.sec
                                 )

  local key = timeStamp..name
  if data[key] then --my but we're recognizing the same person rapidly. Add a second to make a new timestamp
    timeStamp = string.format("%d/%02d/%02d %02d:%02d:%02d",
                                  timeTable.year,
                                  timeTable.month,
                                  timeTable.day,
                                  timeTable.hour,
                                  timeTable.min,
                                  timeTable.sec + 1
                                 )
    key = timeStamp..name
  end
  local entry = {
    name = name,
    reason = reason,
    timeStamp = timeStamp
  }
  data[key] = entry
  recoginator.last_added = key
  recoginator.save()
end

function recoginator.remove(key)
  local data = recoginator.data.recogs
  recoginator.last_action = "remove"
  local removedEntry = data[key]
  local removed = {}
  data[key] = nil
  removed[key] = removedEntry
  recoginator.removed = removed
  recoginator.save()
  return removedEntry
end

function recoginator.removeAll(name)
  local data = {}
  local removed = {}
  local recogs = recoginator.data.recogs
  for key, info in pairs(recogs) do
    if info.name ~= name then
      data[key] = info
    else
      removed[key] = info
    end
  end
  if table.is_empty(removed) then
    return
  end
  recoginator.last_action = "remove"
  recoginator.data.recogs = data
  recoginator.removed = removed
  recoginator.save()
  return removed
end

function recoginator.undoRemove()
  local data = recoginator.data.recogs
  recoginator.last_action = "add"
  for key,info in pairs(recoginator.removed) do
    data[key] = info
  end
  recoginator.removed = {}
  recoginator.save()
end

function recoginator.undoAdd()
  return recoginator.remove(recoginator.last_added)
end

function recoginator.isToday(dateString)
  local dateTable = dateString:split("/")
  local now = recoginator.timeywimey()
  return (now.year == tonumber(dateTable[1]) and now.month == tonumber(dateTable[2]) and now.day == tonumber(dateTable[3]))
end

function recoginator.undo(redisplay)
  if recoginator.last_action == "add" then
    recoginator.undoAdd()
  elseif recoginator.last_action == "remove" then
    recoginator.undoRemove()
  elseif recoginator.last_action == "recognize" then
    if recoginator.recogs_today and recoginator.recogs_today > 0 then
      recoginator.recogs_today = recoginator.recogs_today - 1
    end
    recoginator.undoRemove()
  end
  if redisplay then
    recoginator.redisplay()
  end
end

function recoginator.redisplay()
  if recoginator.window ~= "main" or recoginator.reprintOnMain then
    recoginator.display()
  end
end

function recoginator.makeRow(key,index)
  local entry = recoginator.data.recogs[key]
  local name = entry.name

  local remove = function()
    recoginator.remove(key)
    recoginator.redisplay()
  end

  local removeAll = function()
    recoginator.removeAll(name)
    recoginator.redisplay()
  end

  local recognize = function()
    recoginator.recognize(key)
    recoginator.redisplay()
  end

  local commands = {
    recognize,
    remove,
    removeAll
  }

  local hints = {
    f"Recognize {entry.name} for {entry.reason}",
    "Remove this entry",
    f"Remove all entries for {entry.name}" 
  }
  return {
    {index, commands, hints},
    entry.timeStamp,
    " " .. entry.name,
    " " .. entry.reason
  }
end

function recoginator.setWidth(width)
  width = tonumber(width)
  if not width or width < 55 then
    recoginator.echo("The recoginator does not display well within the void. The recoginator also refuses to wear spanx.")
    recoginator.echo("You have to specify a width which is a number and is at least 55")
    return
  end
  recoginator.width = width
  printTable.columns[4].options.width = width - 44
  recoginator.save()
  recoginator.redisplay()
end

function recoginator.display()
  local data = recoginator.data.recogs
  local window = recoginator.window
  local width = recoginator.width
  local indexToKey = {}
  local starline = string.rep("*", width)
  local bannerText = ft.fText("Welcome to the RECOGINATOR!", {alignment = "center", width = width, cap = "*", inside = true})
  local msg = string.format("\n<white>%s\n%s\n", starline, bannerText)
  if window ~= "main" then clearWindow(window) end
  cechoPopup(window, msg, {recoginator.display, function() recoginator.undo(true) end}, {"Reprint display", "undo last action"}, true)
  printTable.rows = {}
  local index = 0
  if table.is_empty(data) then
    printTable:addRow({"0","heat death","the void","Staring back at me when I stared at it"})
  else
    for key,_ in spairs(data) do
      index = index + 1
      printTable:addRow(recoginator.makeRow(key, index))
      indexToKey[index] = key
    end
  end
  printTable:assemble()
  recoginator.indexToKey = indexToKey
end

function recoginator.removeByIndex(index)
  local key = recoginator.indexToKey[index]
  if key then
    recoginator.remove(key)
  end
end

function recoginator.removeAllByIndex(index)
  local key = recoginator.indexToKey[index]
  if not key then return end
  local entry = recoginator.data.recogs[key]
  if entry then
    recoginator.removeAll(entry.name)
  end
end

function recoginator.recognizeByIndex(index)
  local key = recoginator.indexToKey[index]
  if not key then return end
  recoginator.recognize(key)
end

function recoginator.recognize(key)
  if recoginator.recogs_today and recoginator.recogs_today >= 3 then
    recoginator.echo("It seems you've used your three recognizes for today, perhaps best to wait.")
    return
  end
  local entry = recoginator.remove(key)
  recoginator.last_action = "recognize"
  send(f("recognize {entry.name} {entry.reason} (occurred {entry.timeStamp})"))
  recoginator.recogs_today = (recoginator.recogs_today or 0) + 1
end

function recoginator.save()
  if io.exists(filename) then
    copyFile(filename, backup)
  end
  recoginator.data.offset = recoginator.offset
  recoginator.data.window = recoginator.window
  recoginator.data.width = recoginator.width
  recoginator.data.reprintOnMain = recoginator.reprintOnMain
  local ok, err = pcall(table.save, filename, recoginator.data)
  if not ok then
    local msg = f"RECOGINATOR: unable to save data to {filename} because: {content} -- Original backed up to {backup} first"
    debugc(msg)
    return nil, msg
  end
  return true
end

function recoginator.load()
  if not io.exists(filename) then return end
  local data = {}
  table.load(filename, data)
  recoginator.offset = data.offset or recoginator.offset
  recoginator.window = data.window or recoginator.window
  recoginator.width = data.width
  printTable.columns[4].options.width = data.width - 44
  recoginator.reprintOnMain = data.reprintOnMain or recoginator.reprintOnMain
  printTable.autoEchoConsole = recoginator.window
  recoginator.data = data
end

function recoginator.setWindow(win)
  recoginator.window = win
  printTable.autoEchoConsole = win
  recoginator.save()
  if win ~= "main" or recoginator.reprintOnMain then
    recoginator.display()
  end
end

function recoginator.echo(msg)
  cecho("<green>(<orange>RECOGINATOR<green>)<r>: " .. msg .. "\n")
end

function recoginator.usage()
  local formatter = ft.TextFormatter:new({width = recoginator.width - 4, alignment = "left"})
  local function oecho(option, msg)
    local wrapped = ft.wordWrap(msg, recoginator.width - 4, "    ")
    cecho("<green>  " .. option .. "\n")
    cecho("<orange>" .. wrapped .. "\n")
  end
  cecho("<orange>Recoginator!<r> Usage:\n")
  oecho("recog", "print this message")
  oecho("recog help", "print this message")
  oecho("recog add", "add someone to the queue for recognition")
  oecho("recog window <window>", "set the window to display recoginator queue in. Use main for the main game output area")
  oecho("recog reprintOnMain <yes|no>", "Reprint the queue after interaction even on the main window?")
  oecho("recog display", "Prints out the list of recognitions in the queue")
  oecho("recog do <#>","perform the recognition command for index # provided, if you have slots left")
  oecho("recog del <#>","removes the entry at index # provided")
  oecho("recog delall <# or name>","removes all entries in the queue for the person named, or the person from index # provided")
  oecho("recog undo", "Undoes the last del, delall, add, or do action undoing the 'do' action obviously cannot take backs from the server, but will add the entry back to the queue and add 1 back to the number of recognize slots for the day, in case it didn't go through")
  oecho("recog slots <#>", "Set the number of recognition slots available to # (0-3). Normally this should be detected via RECOGNISELOG")
  oecho("recog width <width>","Set the width of the recoginator display. Default is 80. The recoginator is a diva who refers to themselves in the third person and refuses to wear spanx, so width must be >= 55")
  oecho("RECOGNISELOG", "The same, but it's an alias now so I can do a little setup to parse the log for how many slots have been used today.")
end

function recoginator.timeywimey()
  local timeTable = getTime()
  timeTable.hour = timeTable.hour + recoginator.offset
  local daysCurrent = daysInMonth(timeTable.month, timeTable.year)
  local monthPrev = timeTable.month - 1
  local daysPrev = daysInMonth(monthPrev, timeTable.year)
  if timeTable.hour < 0 then
    timeTable.hour = 24 - timeTable.hour
    timeTable.day = timeTable.day - 1
    if timeTable.day < 0 then
      timeTable.day = daysPrev
      if monthPrev == 0 then
        timeTable.month = 12
        timeTable.year = timeTable.year - 1
      end
    end
  elseif timeTable.hour >= 24  then
    timeTable.hour = timeTable.hour - 24
    timeTable.day = timeTable.day + 1
    if timeTable.day > daysCurrent then
      timeTable.day = 1
      timeTable.month = timeTable.month + 1
      if timeTable.month == 13 then
        timeTable.month = 1
        timeTable.year = timeTable.year + 1
      end
    end
  end
  return timeTable
end

function recoginator.setUTCoffset(offset)
  if offset then
    recoginator.offset = tonumber(offset)
    return offset
  end
  if recoginator.utcHandlerSuccess then killAnonymousEventHandler(recoginator.utcHandlerSuccess) end
  if recoginator.utcHandlerFailure then killAnonymousEventHandler(recoginator.utcHandlerError) end
  local utcURL = "http://worldclockapi.com/api/json/utc/now"
  local function eventHandler(eventName, url, response)
    if eventName == "sysGetHttpDone" then
      if url ~= utcURL then return true end
      local utcTime = {yajl.to_value(response).currentDateTime:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+)Z")}
      utcTime.day = tonumber(utcTime[3])
      utcTime.hour = tonumber(utcTime[4])
      local localTime = getTime()
      local dayDiff = utcTime.day - localTime.day
      if dayDiff > 1 then dayDiff = -1 end -- 30 - 1 = 29, so local day is actually ahead of utc day by 1
      if dayDiff < -1 then dayDiff = 1 end -- 1 - 30 = -29, so local day is actually behind of utc day by 1
      recoginator.offset = ((24 * dayDiff) + utcTime.hour) - localTime.hour
      debugc("UTC offset set to " .. recoginator.offset)
    elseif eventName == "sysGetHttpError" then
      if response ~= utcURL then return true end
      debugc(f"There was an error retrieving the current UTC time at {url}. Details: {response}")
    end
  end
  recoginator.utcHandlerSuccess = registerAnonymousEventHandler("sysGetHttpDone", eventHandler, true)
  recoginator.utcHandlerError = registerAnonymousEventHandler("sysGetHttpError", eventHandler, true)
  getHTTP(utcURL)
end

if not recoginator.initialized then
  recoginator.initialized = true
  recoginator.load()
  recoginator.setUTCoffset()
end
