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

function CrashProoferNetwork.PacketReceived(self, packet, sender)
    D("RECEIVED PACKET: "..packet)
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    --TODO: Need to create a CrashProoferMessageBuilder class and feed packet#0's into it.
    --TODO: When a Builder determines that it has all the packets it needs, THEN we should
    --      inform any registered listeners of the message.

    
    
    
    
    
    
    
    
    
    
    
    
    --So we just got a packet from another CP user.  What kind of CP packet was it? (Announce, HeadsUp, or Record)
    local packetType = string.sub(packet, 1, 3)

    if (CP_UPDATE_REGISTRY[packetType] ~= nil) then
        CP_UPDATE_REGISTRY[packetType](packet,sender)
    else
        D("RECEIVED PACKET OF INVALID TYPE: '"..packetType.."'")
    end

    --[[ Save this bit for when I make the RecordSession class.
    if (packetType == CP_RECORD_PREFIX) then
        --What is the identifier that a CP consumer would recognize?
        local messageType = string.sub(packet, 4, 3)
        --MessageId is a rotating identifier per user, per session, to help ensure that we don't mis-combine packets.
        local messageId = string.sub(packet, 7, 3)
        local packetNumber = string.match(packet, "(%d+)#", 10)
        if (packetNumber == 0) then
            --TODO: Start a packet collector.
        else
            --TODO: If there is a matching packet collector, add this packet to it.  If the message is complete, process it.
            --TODO: If there is no matching packet collector, throw it away and report an invalid packet (so we can start a new HeadsUpSession).
        end
    end
    ]]--
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