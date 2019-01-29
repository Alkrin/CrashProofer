--CrashProoferMessageBuilder
-- This class is responsible for collecting and assembling packets into actual data strings that we can pass off to the Session classes.

-- Class definition.
local CrashProoferMessageBuilder = {} -- the table representing the class, which will double as the metatable for the instances
CrashProoferMessageBuilder.__index = CrashProoferMessageBuilder -- failed table lookups on the instances should fallback to the class table, to get methods

-- Creates and returns a CPMessageBuilder object.
function CrashProoferMessageBuilder_Create(headerPacket, sender)
    local BUILDER = setmetatable({}, CrashProoferMessageBuilder)
    BUILDER.sender = CrashProofer_NameFromSender(sender)
    BUILDER.packetType = CP_NETWORK:ExtractPacketType(headerPacket)
    BUILDER.totalPacketCount = CP_NETWORK:ExtractPacketData(headerPacket)
    BUILDER.dataPackets = {}

    return BUILDER
end

function CrashProoferMessageBuilder.AddPacket(self, packet)
    local packetNumber = CP_NETWORK:ExtractPacketNumber(packet)
    -- We are only storing the raw data segment here because all of the other information was already parsed from the header packet.
    local packetData = CP_NETWORK:ExtractPacketData(packet)
    self.dataPackets[packetNumber] = packetData
end

function CrashProoferMessageBuilder.IsComplete(self)
    for i = 1, self.totalPacketCount, 1 do
        if (self.dataPackets[i] == nil) then
            return false
        end
    end
    return true
end

function CrashProoferMessageBuilder.GetDataString(self)
    if (self:IsComplete()) then
        local data = ""
        for i = 1, self.totalPacketCount, 1 do
            data = data..self.dataPackets[i]
        end
        return data
    else
        return nil
    end
end
