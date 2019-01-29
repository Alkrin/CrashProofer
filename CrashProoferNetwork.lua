--CrashProoferNetwork

-- Private variables
-- Key: MessageType  Value: Array of update functions.
local CP_UPDATE_REGISTRY = {}

-- All pending out-going messages.  One packet gets sent per update to avoid the broadcast limit.
-- Key: MessageId  Value: CrashProoferMessage object
local CP_MESSAGE_QUEUE = {}
-- The mId of the message currently being sent, or -1 if none
local CP_CURRENT_MESSAGE_ID = -1

local CP_ANNOUNCE_PREFIX = "ANN"
local CP_RECORD_PREFIX   = "REC"

-- Class definition.
local CrashProoferNetwork = {} -- the table representing the class, which will double as the metatable for the instances
CrashProoferNetwork.__index = CrashProoferNetwork -- failed table lookups on the instances should fallback to the class table, to get methods

-- Any in-progress CPMessageBuilders.
local CP_BUILDERS = {}

function CrashProoferNetwork.PacketReceived(self, packet, sender)
    D("RECEIVED PACKET from "..sender..": "..packet)
    
    --So we just got a packet from another CP user.  What kind of CP packet was it? (Announce, HeadsUp, or Record)
    local packetType = self:ExtractPacketType(packet)
    
    -- TODO: This might be the spot to decide if we need to abort an AnnounceSession or RecordSession.

    -- If the packet type is invalid, we don't want to try to process it.  Just spit out a debug message.
    if (CP_UPDATE_REGISTRY[packetType] == nil) then
        D("RECEIVED PACKET OF INVALID TYPE: '"..packetType.."'")
        return
    end

    -- This will either plug the packet into an existing builder or else make a new builder for it.
    local builder = self:GetOrCreateMessageBuilderForPacket(packet, sender)

    -- If the message is complete, send it on to whoever handles it.
    if (builder ~= nil and builder:IsComplete()) then
        D("Message is complete!  Sending to the matching Session.")
        CP_UPDATE_REGISTRY[packetType](builder)
        -- And now that the message has been handled, erase it to save memory.
        self:DestroyMessageBuilderForPacket(packet, sender)
    end
end

function CrashProoferNetwork.ExtractPacketType(self, packet)
    -- First three characters identify the CrashProofer packet type (HUP, ANN, REC).
    return string.sub(packet, 1, 3)
end

function CrashProoferNetwork.ExtractMessageId(self, packet)
    -- Second three characters are the sender's messageId (rotating cycle from 0-999)
    return string.sub(packet, 4, 3)
end

function CrashProoferNetwork.ExtractPacketNumber(self, packet)
    -- After the id is the number of the packet (inside the associated message).
    return tonumber(string.match(packet, "(%d+)#", 7))
end

function CrashProoferNetwork.ExtractPacketData(self, packet)
    -- After the packet number is a '#' and then the data.
    -- For header packets this is the total packet count.
    -- For data packets this is the actual data segment (which may be blank).
    return string.match(packet, "%d+#(.*)", 7)
end

function CrashProoferNetwork.PacketIsHeader(self, packet)
    -- If the packetNumber is zero, then this is a header, which has the total packet count as its data.
    local packetNumber = self:ExtractPacketNumber(packet)
    return packetNumber == 0
end

function CrashProoferNetwork.GetOrCreateMessageBuilderForPacket(self, packet, sender)
    -- Make sure there is an entry for this sender.
    if (CP_BUILDERS[sender] == nil) then
        CP_BUILDERS[sender] = {}
    end
    local buildersForSender = CP_BUILDERS[sender]

    local messageId = self:ExtractMessageId(packet)

    if (self:PacketIsHeader(packet)) then
        D("This is a header packet.  Creating a new Builder.")
        -- If this is a header packet, then we need to create a new builder and add it to the stash.
        buildersForSender[messageId] = CrashProoferMessageBuilder_Create(packet, sender)
    else
        -- If this is a data packet...
        local builder = buildersForSender[messageId]
        if (builder == nil) then
            -- ... and we don't have a builder already, then it is invalid for us.
            -- We will just ignore it, because a HeadsUpSession should be happening right now anyway.
            -- It should only be possible to receive unrecognized data packets if you log in when someone else is in the middle of an Announce or Record session.
            D("Received data packet for messageId:"..messageId..", for which you have not seen a Header packet.")
        else
            D("This is a data packet.  Adding it to the existing builder.")
            -- ... and we already have a builder, add to it.
            builder:AddPacket(packet)
        end
    end
    -- This may be nil if we receive a bad packet.
    return buildersForSender[messageId]
end

function CrashProoferNetwork.DestroyMessageBuilderForPacket(self, packet, sender)
    -- No need to check for presence, because we only call this function when we already know a builder exists.
    local messageId = self:ExtractMessageId(packet)
    CP_BUILDERS[sender][messageId] = nil
end

-- mType should be a short identifying string (exactly 3 characters).
-- handler should be a function to which we will pass the packet.
function CrashProoferNetwork.RegisterForMessages(self, mType, handler)
    --This registry is only used internally for Session management, so there's no risk of multiple people wanting to handle a single packet.
    CP_UPDATE_REGISTRY[mType] = handler
end

function CrashProoferNetwork.AddMessage(self, msg, clearQueue)
    D("CPN.AddMessage with id:"..msg.mId)
    --Currently used only by a fresh HeadsUpSession.
    if clearQueue then
        CP_MESSAGE_QUEUE = {}
        CP_CURRENT_MESSAGE_ID = -1
    end

    CP_MESSAGE_QUEUE[msg.mId] = msg

    --If we're not sending anything else, start sending this message!
    if (CP_CURRENT_MESSAGE_ID == -1) then
        CP_CURRENT_MESSAGE_ID = msg.mId
    end
end

function CrashProoferNetwork.OnUpdate(self)
    --Send the next packet from the queue.
    if (CP_CURRENT_MESSAGE_ID >= 0) then
        local msg = CP_MESSAGE_QUEUE[CP_CURRENT_MESSAGE_ID]
        if (msg ~= nil) then
            local packet = msg:PopPacket()
            if (packet ~= nil) then
                --Actually send the darn thing!
                CrashProofer_SendNetworkMessage(packet, msg.recipient)
            else
                --The message has been completely sent, so clear it to free up memory and move on to the next one.
                CP_MESSAGE_QUEUE[CP_CURRENT_MESSAGE_ID] = nil
                --Remember that we cycle through 0-999.
                local nextMessageId = (CP_CURRENT_MESSAGE_ID + 1) % 1000
                if (CP_MESSAGE_QUEUE[nextMessageId] ~= nil) then
                    --Another message is waiting to be sent.  Set it up for the next update.
                    CP_CURRENT_MESSAGE_ID = nextMessageId
                else
                    --No messages waiting in the queue, so we can stop.
                    CP_CURRENT_MESSAGE_ID = -1
                end
            end
        else
            --CP_CURRENT_MESSAGE_ID claimed we had a message to send, but they were wrong!  Fix bookkeeping.
            CP_CURRENT_MESSAGE_ID = -1
        end
    end
end

--The public singleton
CP_NETWORK = setmetatable({}, CrashProoferNetwork)