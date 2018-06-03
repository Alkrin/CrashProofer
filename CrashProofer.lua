--CrashProofer

CRASHPROOFER_PREFIX = "CP";
CP_ANNOUNCE = "ANN"
CP_REQUEST  = "REQ"
CP_RECORD   = "REC"

--Contains tables by Addon name.  Each sub-table contains name-keyed functions whose value is the function to run for that record type.
CP_RECORD_FUNCTIONS = {}
--Keys are the names of addons currently being compressed.  Value is a table of records to replace the old ones when compression is done.
CP_NOW_COMPRESSING = {}
--Contains tables with pending records by addon name.  Otherwise identical to CP_DB.
CP_PENDING_RECORDS = {}

--Contains all queued, outgoing packets.
CP_PACKET_QUEUE = {}


function CrashProofer_RegisterEvents()
    this:RegisterEvent("VARIABLES_LOADED");
    this:RegisterEvent("CHAT_MSG_ADDON"); --default networking support in addons!
    --add event registrations here
end

function CrashProofer_Init()
    --add variable initializations here
    if (CP_DB == nil) then CP_DB = {} end
    if (CP_COMPRESSION_DATES == nil) then CP_COMPRESSION_DATES = {} end

    CrashProofer_AnnounceAll()
end

function CrashProofer_RegisterSlashCommands()
    SLASH_cpStuff1 = "/cp";
    SlashCmdList["cpStuff"] = function() CrashProofer_SlashCommand(); end

    --add slash command registrations here
end

function CrashProofer_SlashCommand()
    --Do your slash command code here.
    D("CrashProofer does nothing on slash!")
end


function CrashProofer_OnLoad()
    CrashProofer_RegisterEvents();
    CrashProofer_RegisterSlashCommands();
end

function CrashProofer_OnEvent()
    if ( event == "VARIABLES_LOADED" ) then
        CrashProofer_Init();
    elseif( event == "CHAT_MSG_ADDON" ) then
        if(arg1 == CRASHPROOFER_PREFIX) then
            CrashProofer_NetworkEvent(arg2, arg3, arg4);
        end
    end
end

function CrashProofer_SendNetworkMessage(msg, destination)
    if(destination == "GUILD") then
        if(IsInGuild()) then
             SendAddonMessage(CRASHPROOFER_PREFIX,msg,destination);
        end
    elseif(destination == "RAID") then
        if(GetNumRaidMembers()) then
            SendAddonMessage(CRASHPROOFER_PREFIX,msg,destination);
        end
    elseif(destination == "PARTY") then
        if(GetNumPartyMembers()) then
            SendAddonMessage(CRASHPROOFER_PREFIX,msg,destination);
        end
    elseif(destination == "BATTLEGROUND") then
        if(GetBattlefieldInstanceRunTime()) then
            SendAddonMessage(CRASHPROOFER_PREFIX,msg,destination);
        end
    end
end

function CrashProofer_NetworkEvent(msg, channel, sender)
    if(sender ~= UnitName("player")) then -- process only network events from others, ignore ourselves.
        --So we just got a packet from another CP user.  What kind of packet was it?
        local packetType = string.sub(msg,1,3)
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

--An empty function for record types with no function of their own.
function CrashProofer_EmptyFunction()
end

--addonName      = string name of the addon for which the record type is being registered
--typeName       = string name of this new record type
--recordFunction = function to be called when this record type is recorded, or nil if no action to be taken
function CrashProofer_RegisterRecordType(addonName,typeName,recordFunction)
    if (CP_RECORD_FUNCTIONS == nil) then CP_RECORD_FUNCTIONS = {} end
    if (CP_RECORD_FUNCTIONS[addonName] == nil) then CP_RECORD_FUNCTIONS[addonName] = {} end

    --This will overwrite a previously registered function if one exists, else create a new record type.
    if (recordFunction == nil) then recordFunction = CrashProofer_EmptyFunction end
    CP_RECORD_FUNCTIONS[addonName][typeName] = recordFunction
end

--addonName = string name of the addon which is adding the record.
--record    = table containing the record data.  Only requirement is a string member called "Type" that matches a registered record type for that addon.
function CrashProofer_AddRecord(addonName,record)
    --Make sure the record is valid.
    if (record == nil) then return end
    if (record.Type == nil) then return end
    if (CP_RECORD_FUNCTIONS[addonName] == nil) then CP_RECORD_FUNCTIONS[addonName] = {} end
    if (CP_RECORD_FUNCTIONS[addonName][record.Type] == nil) then CP_RECORD_FUNCTIONS[addonName][record.Type] = CrashProofer_EmptyFunction end

    --If you get this far, we have a valid record, so add it and call its function.
    if (CP_DB[addonName] == nil) then 
        CP_DB[addonName] = {}
        CP_COMPRESSION_DATES[addonName] = CrashProofer_GetFullTimeStamp()
    end
    if (CP_NOW_COMPRESSING[addonName] == nil) then
        table.insert(CP_DB[addonName],record)
    else
        table.insert(CP_NOW_COMPRESSING[addonName],record)
    end
    CP_RECORD_FUNCTIONS[addonName][record.Type](record)

    --And broadcast this new record.
    CrashProofer_SendRecord(addonName,#CP_DB[addonName])
end

function CrashProofer_ClearAllRecords(addonName)
    CP_DB[addonName] = {}
end

function CrashProofer_BeginCompression(addonName)
    CP_NOW_COMPRESSING[addonName] = {}
end

function CrashProofer_EndCompression(addonName)
    if (CP_NOW_COMPRESSING[addonName] == nil) then return end

    CP_DB[addonName] = CP_NOW_COMPRESSING[addonName]
    CP_NOW_COMPRESSING[addonName] = nil
    CP_COMPRESSION_DATES[addonName] = CrashProofer_GetFullTimeStamp()

    --Announce our newly compressed addon data.
    CrashProofer_AnnounceOne(addonName)
end

function CrashProofer_GetDateTimeStamp()
    local _,month,day,year = CalendarGetDate()

    if (month < 10) then month = "0"..month end
    if (day < 10) then day = "0"..day end

    return year..month..day
end

function CrashProofer_GetFullTimeStamp()
    local hour,minute = GetGameTime()
    if (hour < 10) then hour = "0"..hour end
    if (minute < 10) then minute = "0"..minute end

    return CrashProofer_GetDateTimeStamp()..hour..minute
end

function CrashProofer_AnnounceOne(addonName)
    CrashProofer_AddPacketToQueue(CP_ANNOUNCE..addonName.." "..CP_COMPRESSION_DATES[addonName]..(#CP_DB[addonName]))
end

function CrashProofer_AnnounceAll()
    for addonName,data in pairs(CP_DB) do
        CrashProofer_AnnounceOne(addonName)
    end
end

function CrashProofer_Request(addonName,timestamp,firstRecord)
    if (firstRecord == nil) then firstRecord = 1 end

    CrashProofer_AddPacketToQueue(CP_REQUEST..addonName.." "..timestamp..firstRecord)
end

function CrashProofer_SendRecord(addonName,recordNumber)
    local s = CP_RECORD..addonName.." "..CP_COMPRESSION_DATES[addonName]..recordNumber
    --Now to tack on all of the record data.
    for k,v in pairs(CP_DB[addonName][recordNumber]) do
        s = s.." "..k.."="..v
    end

    CrashProofer_AddPacketToQueue(s)
end

function CrashProofer_ParseRecordPacket(packet)
    local _,_,addonName,timestamp,recordNumber = string.find(packet,CP_RECORD.."(.*) (%d%d%d%d%d%d%d%d%d%d%d%d)(%d*)")
    local record = {}

    for k,v in string.gmatch(packet," ([^%s]*)=([^%s]*)") do
        record[k] = v
    end

    return addonName,timestamp,tonumber(recordNumber),record
end

function CrashProofer_ParseRequestPacket(packet)
    --Splits out the addonName, timestamp, and firstRecord requested.
    local _,_,addonName,timestamp,firstRecord = string.find(packet,CP_REQUEST.."(.*) (%d%d%d%d%d%d%d%d%d%d%d%d)(%d*)")
    return addonName,timestamp,tonumber(firstRecord)
end

function CrashProofer_ParseAnnouncePacket(packet)
    --Splits out the addonName, timestamp, and record count.
    local _,_,addonName,timestamp,recordCount = string.find(packet,CP_ANNOUNCE.."(.*) (%d%d%d%d%d%d%d%d%d%d%d%d)(%d*)")
    return addonName,timestamp,tonumber(recordCount)
end

function CrashProofer_HandleAnnouncePacket(packet)
    local addonName,timestamp,recordCount = CrashProofer_ParseAnnouncePacket(packet)

    if (CP_DB[addonName] == nil) then
        --We don't have any data for this addon, so get all of it!
        CrashProofer_Request(addonName,timestamp)
    else
        --We have this addon in our DB, so...
        if (timestamp < CP_COMPRESSION_DATES[addonName]) then
            --The other person has older data than us, so let them know there's something new.
            CrashProofer_AnnounceOne(addonName)
        elseif (timestamp > CP_COMPRESSION_DATES[addonName]) then
            --The other person has newer data than us, so let's get it!
            CrashProofer_Request(addonName,timestamp)
        else
            --We both have the same dates, so see if either of us is missing records.
            local myRecordCount = #CP_DB[addonName]
            if (recordCount < myRecordCount) then
                --I have records that the other guy doesn't, so let him know!
                CrashProofer_AnnounceOne(addonName)
            elseif (recordCount > myRecordCount) then
                --He has records that I don't, so request them!
                CrashProofer_Request(addonName,timestamp,myRecordCount+1)
            else
                --We both have the same number of records, so no updates are necessary.
            end
        end
    end
end

function CrashProofer_HandleRequestPacket(packet)
    local addonName,timestamp,firstRecord = CrashProofer_ParseRequestPacket(packet)

    if (CP_DB[addonName] == nil) then
        --We don't have any data for this addon, so get all of it!
        CrashProofer_Request(addonName,timestamp)
    else
        --We have this addon in our DB, so...
        if (timestamp < CP_COMPRESSION_DATES[addonName]) then
            --The other person has older data than us, so let them know there's something new.
            CrashProofer_AnnounceOne(addonName)
        elseif (timestamp > CP_COMPRESSION_DATES[addonName]) then
            --The other person has newer data than us, so let's get it!
            CrashProofer_Request(addonName,timestamp)
        else
            --We both have the same dates, so see if we have anything to send.
            local myRecordCount = #CP_DB[addonName]
            if (firstRecord <= myRecordCount) then
                --I have records that the other guy doesn't, so send them off!
                for i=firstRecord,myRecordCount do
                    CrashProofer_SendRecord(addonName,i) --TODO: Might have to work on this to avoid disconnection.
                end
            else
                --He is requesting a record outside of my own record set, so I must be missing some.  Ask for them!
                CrashProofer_Request(addonName,timestamp,myRecordCount+1)
            end
        end
    end
end

function CrashProofer_HandleRecordPacket(packet)
    local addonName,timestamp,recordNumber,record = CrashProofer_ParseRecordPacket(packet)

    if (CP_DB[addonName] == nil) then
        --We don't have any data for this addon, so create a table for it.
        CP_DB[addonName] = {}
        CP_COMPRESSION_DATES[addonName] = timestamp
    end
    --For sure, we now have a table for this addon.
    if (timestamp < CP_COMPRESSION_DATES[addonName]) then
        --The other guy was sending out of date data.  Let him know we have something better.
        CrashProofer_AnnounceOne(addonName)
    elseif (timestamp > CP_COMPRESSION_DATES[addonName]) then
        --The other guy has newer data than us.  We need to update to his data set.
        CP_DB[addonName] = {}
        CP_COMPRESSION_DATES[addonName] = timestamp
    end
    --We don't use an ELSE here, because if we just got the FIRST record for a set, we want to add it instead of requesting the
    --data a second time.
    if (timestamp == CP_COMPRESSION_DATES[addonName]) then
        --We both have the same timestamp, so...
        local myRecordCount = #CP_DB[addonName]
        if (recordNumber <= myRecordCount) then
            --The record is one that we already have, so we can ignore it.
        elseif (recordNumber == myRecordCount+1) then
            --The record is the next one after our current dataset, so add it and run its function (if we have one).
            CP_DB[addonName][recordNumber] = record
            if (CP_RECORD_FUNCTIONS[addonName][record.Type]) then
                CP_RECORD_FUNCTIONS[addonName][record.Type](record)
            end
            --Check for any pending records that can now validly be added.
            if (CP_PENDING_RECORDS[addonName] ~= nil) then
                while (true) do
                    myRecordCount = #CP_DB[addonName]
                    if (CP_PENDING_RECORDS[addonName][myRecordCount + 1] ~= nil) then
                        --If the next needed record is pending, add it!
                        CP_DB[addonName][myRecordCount+1] = CP_PENDING_RECORDS[addonName][myRecordCount+1]
                        CP_PENDING_RECORDS[addonName][myRecordCount + 1] = nil
                        --Run the newly added record's function, if we have one.
                        record = CP_DB[addonName][myRecordCount+1]
                        if (CP_RECORD_FUNCTIONS[addonName][record.Type]) then
                            CP_RECORD_FUNCTIONS[addonName][record.Type](record)
                        end
                    else
                        --If the next needed record is NOT pending, we have to wait until it comes in.
                        break
                    end
                end            
            end
        else
            --The record is out of sequence, so put it into the pending table until we find the one(s) between our last and this one.
            if (CP_PENDING_RECORDS[addonName] == nil) then CP_PENDING_RECORDS[addonName] = {} end
            CP_PENDING_RECORDS[addonName][recordNumber] = record
            --And now request any missing records.
            CrashProofer_Request(addonName,timestamp,#CP_DB[addonName]+1)
        end
    end
end

function CrashProofer_TableSize(table)
    local count = 0
    for _,_ in pairs(table) do count = count + 1 end
    return count
end

function CrashProofer_AddPacketToQueue(packet)
    CP_PACKET_QUEUE[packet] = packet
end

function CrashProofer_SendNextPacket()
    --This only gets one packet.  Order is not guaranteed, but it's not really necessary either.
    for packet,_ in pairs(CP_PACKET_QUEUE) do
        D("SENDING PACKET: "..packet)
        CrashProofer_SendNetworkMessage(packet,"GUILD")
        CP_PACKET_QUEUE[packet] = nil
        break
    end
end

function CrashProofer_OnUpdate()
    if (CrashProofer_TableSize(CP_PACKET_QUEUE) > 0) then
        CrashProofer_SendNextPacket()
    end
end

function CPDump()
    for addonName,addonData in pairs(CP_DB) do
        D("DATA FOR "..addonName.." "..CP_COMPRESSION_DATES[addonName])
        for idx,record in ipairs(addonData) do
            D("RECORD #"..idx)
            for k,v in pairs(record) do
                D("  "..k.." = "..v)
            end
        end
    end
end

function CPTest1()
    --Clear all data.
    CP_DB = {}
    CP_COMPRESSION_DATES = {}
    CP_RECORD_FUNCTIONS = {}
    CP_NOW_COMPRESSING = {}
    CP_PENDING_RECORDS = {}
    CP_PACKET_QUEUE = {}
    --Create test data.
    CP_DB["Test"] = {}
    CP_COMPRESSION_DATES["Test"] = CrashProofer_GetFullTimeStamp()
    table.insert(CP_DB["Test"],{Type="Time",Data="1"})
    table.insert(CP_DB["Test"],{Type="Time",Data="2"})
    table.insert(CP_DB["Test"],{Type="Time",Data="3"})
    table.insert(CP_DB["Test"],{Type="Time",Data="4"})
    table.insert(CP_DB["Test"],{Type="Time",Data="5"})
    --Announce test data.
    CrashProofer_AnnounceOne("Test")
end

function CrashProofer_AddonHasData(addonName)
    if (CP_DB[addonName] == nil) then return false end
    if (#CP_DB[addonName] == 0) then return false end
    
    return true
end

function CrashProofer_GetCompressionDate(addonName)
    if (CP_COMPRESSION_DATES[addonName] ~= nil) then
        --Parse out the timestamp into a legible format.
        local s = CP_COMPRESSION_DATES[addonName]
        local date = string.sub(s,5,6).."/"..string.sub(s,7,8).."/"..string.sub(s,1,4).." "..string.sub(s,9,10)..":"..string.sub(s,11,12)
        return date
    else
        return "None"
    end
end

function D(s)
    DEFAULT_CHAT_FRAME:AddMessage(s)
end
