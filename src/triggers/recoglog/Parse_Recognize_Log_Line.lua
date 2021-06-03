if not recoginator.checkingLogs then return end
if recoginator.isToday(matches.day) and matches.recogniser == gmcp.Char.Name.name then
  recoginator.recogs_today = recoginator.recogs_today + 1
end
