--CrashProofer

--Cache this locally for efficiency, since we use it in an update loop.
local time = time

local CP_HEADSUP_TIMEOUT = 5.0 --seconds
local CP_ANNOUNCE_TIMEOUT = 5.0 --seconds
local CP_RECORD_TIMEOUT = 5.0 --seconds

--These are separate for efficiency, since they are referenced in an update loop.
--Key: storageId for pending local broadcasts Value: true
local CP_PENDING_BROADCASTS = {}
--Key: storageId of previous local broadcasts Value: time() value when we are allowed to next broadcast for this storageId.
local CP_NEXT_BROADCASTS= {}

function CrashProofer_RegisterEvents()
    CrashProoferFrame:RegisterEvent("VARIABLES_LOADED")
    CrashProoferFrame:RegisterEvent("CHAT_MSG_ADDON")
    C_ChatInfo.RegisterAddonMessagePrefix(CRASHPROOFER_PREFIX)
end

function CrashProofer_Init()
    if (CP_DB == nil) then 
        CP_DB = {} 
    end

    -- When you log in, the first thing you need is a HeadsUp session to see who
    -- else is online and using CrashProofer.
    CP_HEADSUP_SESSION:SetSessionEndedDelegate(CrashProofer_OnHeadsUpSessionEnded)
    D("Init() - Calling HUP.StartSession")
    CP_HEADSUP_SESSION:StartSession()

    --DEBUG ONLY
    CPTEST()
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

function CrashProofer_NetworkEvent(msg, channel, sender)
    -- Process only network events from others; ignore ourselves.
    -- Strip server name right away.  CrashProofer only talks with the user's server.
    sender = CrashProofer_NameFromSender(sender)
    if (sender ~= UnitName("player")) then
        D("NetworkEvent from "..sender.." ~= "..UnitName("player"))
        CP_NETWORK:PacketReceived(msg, sender)
    end
end

function CrashProofer_OnHeadsUpSessionEnded()
    --TODO: Start Announce session.
    D("CrashProofer_OnHeadsUpSessionEnded()")
end

local function CrashProofer_SendPendingBroadcasts()
    --This gets called in an update loop, so we need to keep it efficient.
    local currentTime = time()
    for storageId, _ in pairs(CP_PENDING_BROADCASTS) do
        if (CP_NEXT_BROADCASTS[storageId] <= currentTime) then
            D("Preparing to broadcast storageId '"..storageId.."'")
            --TODO: Create a CrashProoferMessage and throw it in the network queue!
            
            --Now that this storageId has been broadcast, mark when the next broadcast window opens.
            CP_PENDING_BROADCASTS[storageId] = currentTime + CP_DB[storageId].broadcastFrequency
            --And mark that we no longer need to send it.
            CP_PENDING_BROADCASTS[storageId] = nil
        end
    end
end

function CrashProofer_OnUpdate()
    CP_NETWORK:OnUpdate()
    CP_HEADSUP_SESSION:OnUpdate()
    --Sends any data that you recently updated to everyone else.  Only sends your own data.
    CrashProofer_SendPendingBroadcasts()
end

local function CrashProofer_InitializeStorage(storageId, broadcastFrequency)
    if (broadcastFrequency == nil) then
        --By default, broadcast no more than once every 15 seconds.
        broadcastFrequency = 15
    end
    if (CP_DB[storageId] == nil) then
        CP_DB[storageId] = {}
    end
    CP_DB[storageId].broadcastFrequency = broadcastFrequency
    if (CP_DB[storageId].Users == nil) then
        CP_DB[storageId].Users = {}
    end
end

-- storageId: unique identifier, commonly related to the addon registering for storage.
-- broadcastFrequency: minimum number of seconds that must pass between each locally-authored broadcast.
function CrashProofer_RegisterForStorage(storageId, broadcastFrequency)
    CrashProofer_InitializeStorage(storageId, broadcastFrequency)
    
    if (CP_DB[storageId].Users[UnitName("player")] == nil) then
        CrashProofer_UpdateStorage(storageId, UnitName("player"), {})
    end

    -- Only data that you locally register will get sent via this system.
    -- Any data from other people for addons you don't personally use will
    --   only go out via a standard Announce session.
    CP_NEXT_BROADCASTS[storageId] = time()
end

--This is the primary call for consumers of CrashProofer.  It should be made whenever data has changed that you don't want to risk losing.
--Note that the actual backing up will not occur more often than the broadcastFrequency that you registered for the storageId.
--If owner is nil, owner will be the local player.
--dontBroadcast is used when receiving your own data back from a different player, as that player has already just broadcast it.
function CrashProofer_UpdateStorage(storageId, data, owner, dontBroadcast)
    if (owner == nil) then
        owner = UnitName("player")
    end
    local isLocalData = owner == UnitName("player")
    if (CP_DB[storageId] == nil) then
        --If an addon is trying to call UpdateStorage before calling RegisterForStorage, then they have done something wrong.
        if (isLocalData) then
            --TODO: Should this be a proper, thrown LUA error?
            D("ERROR: Attempted to call UpdateStorage for unregistered storageId '"..storageId.."'.  Please register the storageId first.")
            return
        end
        --This is the first update call for a storageId that someone is backing up to you, so you won't have it set up yet.
         CrashProofer_InitializeStorage(storageId)
    end
    local info = {}
    info.timeStamp = CrashProofer_TimeStamp()
    info.data = data
    CP_DB[storageId].Users[owner] = info

    --Only your own data gets auto-broadcast.  Everything else only happens during a normal Announce session.
    if (isLocalData and dontBroadcast ~= true) then
        if (CP_PENDING_BROADCASTS[storageId] == nil) then
            CP_PENDING_BROADCASTS[storageId] = true
            D("Broadcast scheduled for storageId '"..storageId.."'")
        else
            D("Duplicate broadcast requested for storageId '"..storageId.."'")
        end
    end
end

--TODO: Functions for reading other people's personal storage that has been backed up to us.
--TODO: Functions for replacing our own personal data with somebody else's?  Or would that be
--        handled already if the consumer just alters their personal data directly?

--TODO: Admin panel to manually trigger sessions / sends / debug events.



function CPTEST()
    CrashProofer_RegisterForStorage("DEBUG")

    local t = {}
    t.a = "A"
    t.b = "B"
    t.c = "C"
    t.d = "D"
    t.e = "E"
    t.f = "F"
    t.g = "G"
    t.t = {}
    t.t.h = "H"
    t.t.i = "I"
    t.t.j = "J"
    t.t.k = "K"
    t.t.l = "L"
    t.t.m = "M"
    t.t.n = "N" 

    CrashProofer_UpdateStorage("DEBUG", t)

    D("Attempting to send HUP from Bob")
    CrashProofer_NetworkEvent("HUP0010#0", "", "Bob")
end