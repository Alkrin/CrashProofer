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
    SlashCmdList["cpStuff"] = CrashProofer_SlashCommand
end

function CrashProofer_SlashCommand()
    D("CrashProofer does nothing on slash!")
end


function CrashProofer_OnLoad()
    CrashProofer_RegisterEvents()
    CrashProofer_RegisterSlashCommands()
end

function CrashProofer_OnEvent(frame, event, ...)
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
