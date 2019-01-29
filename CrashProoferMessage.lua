--CrashProoferMessage
-- This class is for splitting data into packets so that we can send it off to other players.
-- The data is not intended to be read from it.  That is CrashProoferMessageBuilder's job.

-- Rotating id between 0 and 999.  We assign one to each CPMessage as it is created.
local CP_NEXT_MESSAGE_ID = 0

-- Class definition.
local CrashProoferMessage = {} -- the table representing the class, which will double as the metatable for the instances
CrashProoferMessage.__index = CrashProoferMessage -- failed table lookups on the instances should fallback to the class table, to get methods

--Creates and returns a CPMessage object.
--pType is one of the basic packet prefixes (HUP, ANN, REC)
--data is the string containing all data to be broadcast
--recipient may be nil.  If so, the message will be sent to all guild members.
function CrashProoferMessage_Create(pType, data, recipient)
    local MESSAGE = setmetatable({}, CrashProoferMessage)
    MESSAGE.mId = CrashProoferMessage_GetNextId()
    MESSAGE.pType = pType
    MESSAGE.recipient = recipient
    MESSAGE.packets = {}
    MESSAGE.nextPacketToSend = 1
    --Create a header packet.
    --The header packet gives all relevant information about the message, so we don't have to include as much in each individual packet.
    --It needs to include the total packet count for the message, but we don't have that just yet.  We'll add it in a bit.
    local headerPacket = pType..string.format("%03d", MESSAGE.mId).."0#"
    table.insert(MESSAGE.packets, headerPacket)
    -- Turn 'data' into individual packets.
    local packetCount = 0
    while (string.len(data) > 0) do
        packetCount = packetCount + 1
        --Each packet starts with the messageId so recipients can match up packets to rebuild the message,
        --plus the index of this packet in the total message so we can reassemble them in order.
        local packet = string.format("%03d", MESSAGE.mId)..packetCount.."#"
        --Blizzard gives us a max of 255 characters per packet.
        --The first four are used by Blizzard already.  Three are used by CrashProofer's prefix (CxP). The next is a '\t' character.
        --That leaves us with a max of 251 characters per packet.
        local charactersRemaining = 251 - string.len(packet)
        --We'll grab as many characters as we can out of 'data' to stuff in this packet.
        if (string.len(data) <= charactersRemaining) then
            packet = packet..data
            data = ""
        else
            packet = packet..string.sub(data, 1, charactersRemaining)
            data = string.sub(data, charactersRemaining + 1)
        end
        table.insert(MESSAGE.packets, packet)
    end
    --The first packet is always the header packet.  We need to add the total number of packets to it still.
    MESSAGE.packets[1] = MESSAGE.packets[1]..packetCount

    return MESSAGE
end

function CrashProoferMessage_GetNextId()
    local id = CP_NEXT_MESSAGE_ID
    CP_NEXT_MESSAGE_ID = (CP_NEXT_MESSAGE_ID + 1) % 1000
    return id
end

function CrashProoferMessage.PopPacket(self)
    --This will return nil if called after popping all packets.
    local nextPacket = self.packets[self.nextPacketToSend]
    self.nextPacketToSend = self.nextPacketToSend + 1
    return nextPacket
end
