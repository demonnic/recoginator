local slots = tonumber(matches[2])
if slots > 3 then slots = 3 end
if slots < 0 then slots = 0 end
recoginator.recogs_today = 3 - slots
