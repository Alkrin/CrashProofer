--CrashProofer

CRASHPROOFER_PREFIX = "C×P";
CP_ANNOUNCE = "ANN"
CP_REQUEST  = "REQ"
CP_RECORD   = "REC"

--Contains all queued, outgoing packets.
CP_PACKET_QUEUE = {}


function CrashProofer_RegisterEvents()
    CrashProoferFrame:RegisterEvent("VARIABLES_LOADED")
    CrashProoferFrame:RegisterEvent("CHAT_MSG_ADDON")
end

function CrashProofer_Init()
    if (CP_DB == nil) then 
        CP_DB = {} 
    end
end

function CrashProofer_RegisterSlashCommands()
    SLASH_cpStuff1 = "/cp";
    SlashCmdList["cpStuff"] = function() 
        CrashProofer_SlashCommand()
    end
end

function CrashProofer_SlashCommand()
    D("CrashProofer does nothing on slash!")
end


function CrashProofer_OnLoad()
    CrashProofer_RegisterEvents()
    CrashProofer_RegisterSlashCommands()
end

function CrashProofer_OnEvent(event, ...)
    if (event == "VARIABLES_LOADED") then
        CrashProofer_Init()
    elseif (event == "CHAT_MSG_ADDON") then
        local prefix, msg, channel, _, sender = ...
        if (prefix == CRASHPROOFER_PREFIX) then
            CrashProofer_NetworkEvent(msg, channel, sender)
        end
    end
end

function CrashProofer_SendNetworkMessage(msg, destination)
    if (destination == "GUILD") then
        if (IsInGuild()) then
             SendAddonMessage(CRASHPROOFER_PREFIX, msg, destination)
        end
    elseif (destination == "RAID") then
        if (GetNumRaidMembers()) then
            SendAddonMessage(CRASHPROOFER_PREFIX, msg, destination)
        end
    elseif (destination == "PARTY") then
        if (GetNumPartyMembers()) then
            SendAddonMessage(CRASHPROOFER_PREFIX, msg, destination)
        end
    elseif (destination == "BATTLEGROUND") then
        if (GetBattlefieldInstanceRunTime()) then
            SendAddonMessage(CRASHPROOFER_PREFIX, msg, destination)
        end
    end
end

function CrashProofer_NetworkEvent(msg, channel, sender)
    -- process only network events from others, ignore ourselves.
    if (sender ~= UnitName("player")) then
        --So we just got a packet from another CP user.  What kind of packet was it?
        local packetType = string.sub(msg, 1, 3)
        D("RECEIVED PACKET: "..msg)
        if (packetType == CP_RECORD) then
            CrashProofer_HandleRecordPacket(msg)
        elseif (packetType == CP_REQUEST) then
            CrashProofer_HandleRequestPacket(msg)
        elseif (packetType == CP_ANNOUNCE) then
            CrashProofer_HandleAnnouncePacket(msg)
        end
    end
end

function CrashProofer_GetDateTimeStamp()
    local _, month, day, year = CalendarGetDate()

    if (month < 10) then 
        month = "0"..month 
    end
    if (day < 10) then 
        day = "0"..day 
    end

    return year..month..day
end

function CrashProofer_GetFullTimeStamp()
    local hour,minute = GetGameTime()
    if (hour < 10) then
        hour = "0"..hour
    end
    if (minute < 10) then
        minute = "0"..minute
    end

    return CrashProofer_GetDateTimeStamp()..hour..minute
end

function CrashProofer_ParseRecordPacket(packet)
    local _, _, addonName, timestamp, recordNumber = string.find(packet, CP_RECORD.."(.*) (%d%d%d%d%d%d%d%d%d%d%d%d)(%d*)")
    local record = {}

    for k, v in string.gmatch(packet, " ([^%s]*)=([^%s]*)") do
        record[k] = v
    end

    return addonName, timestamp, tonumber(recordNumber), record
end

function CrashProofer_ParseRequestPacket(packet)
    --Splits out the addonName, timestamp, and firstRecord requested.
    local _, _, addonName, timestamp, firstRecord = string.find(packet, CP_REQUEST.."(.*) (%d%d%d%d%d%d%d%d%d%d%d%d)(%d*)")
    return addonName, timestamp, tonumber(firstRecord)
end

function CrashProofer_ParseAnnouncePacket(packet)
    --Splits out the addonName, timestamp, and record count.
    local _, _, addonName, timestamp, recordCount = string.find(packet,CP_ANNOUNCE.."(.*) (%d%d%d%d%d%d%d%d%d%d%d%d)(%d*)")
    return addonName, timestamp, tonumber(recordCount)
end

function CrashProofer_TableSize(table)
    local count = 0
    for _, _ in pairs(table) do 
        count = count + 1 
    end
    return count
end

function CrashProofer_AddPacketToQueue(packet)
    CP_PACKET_QUEUE[packet] = packet
end

function CrashProofer_SendNextPacket()
    --TODO: Order might start mattering soon.
    --This only gets one packet.  Order is not guaranteed, but it's not really necessary either.
    for packet, _ in pairs(CP_PACKET_QUEUE) do
        D("SENDING PACKET: "..packet)
        CrashProofer_SendNetworkMessage(packet, "GUILD")
        CP_PACKET_QUEUE[packet] = nil
        break
    end
end

function CrashProofer_OnUpdate()
    if (CrashProofer_TableSize(CP_PACKET_QUEUE) > 0) then
        CrashProofer_SendNextPacket()
    end
end

function D(s)
    DEFAULT_CHAT_FRAME:AddMessage("CP:"..s)
end

local function exportstring(s)
    return string.format("%q", s)
end

--// The Save Function
function table.save(tbl)
    local charS, charE = "   ", "\n"
    local result = ""

    -- initiate variables for save procedure
    local tables, lookup = {tbl}, {[tbl] = 1}
    result = result.."return {"..charE

    for idx, t in ipairs(tables) do
        result = result.."-- Table: {"..idx.."}"..charE
        result = result.."{"..charE
        local thandled = {}

        for i, v in ipairs(t) do
            thandled[i] = true
            local stype = type(v)
            -- only handle value
            if stype == "table" then
                if not lookup[v] then
                    table.insert(tables, v)
                    lookup[v] = #tables
                end
                result = result..charS.."{"..lookup[v].."},"..charE
            elseif stype == "string" then
                result = result..charS..exportstring(v)..","..charE
            elseif stype == "number" then
                result = result..charS..tostring( v )..","..charE
            end
        end

        for i, v in pairs(t) do
            -- escape handled values
            if (not thandled[i]) then
            
                local str = ""
                local stype = type(i)
                -- handle index
                if stype == "table" then
                    if not lookup[i] then
                        table.insert(tables, i)
                        lookup[i] = #tables
                    end
                    str = charS.."[{"..lookup[i].."}]="
                elseif stype == "string" then
                    str = charS.."["..exportstring(i).."]="
                elseif stype == "number" then
                    str = charS.."["..tostring(i).."]="
                end
            
                if str ~= "" then
                    stype = type(v)
                    -- handle value
                    if stype == "table" then
                        if not lookup[v] then
                            table.insert(tables, v)
                            lookup[v] = #tables
                        end
                        result = result..str.."{"..lookup[v].."},"..charE
                    elseif stype == "string" then
                        result = result..str..exportstring( v )..","..charE
                    elseif stype == "number" then
                        result = result..str..tostring( v )..","..charE
                    end
                end
            end
        end
        result = result.."},"..charE
    end
    result = result.."}"
    return result
end
   
--// The Load Function
function table.load(tstring)
    local ftables = assert(loadstring(tstring))
    local tables = ftables()
    for idx = 1, #tables do
        local tolinki = {}
        for i, v in pairs(tables[idx]) do
            if type(v) == "table" then
                tables[idx][i] = tables[v[1]]
            end
            if type(i) == "table" and tables[i[1]] then
                table.insert(tolinki, {i, tables[i[1]]})
            end
        end
        -- link indices
        for _, v in ipairs(tolinki) do
            tables[idx][v[2]], tables[idx][v[1]] =  tables[idx][v[1]], nil
        end
    end
    return tables[1]
end
