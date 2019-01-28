--CrashProoferHeadsUpSession

-- Private constants
local CP_HEADSUP_PREFIX = "HUP" --Packet identifier.
local CP_HEADSUP_TIMEOUT = 5.0 --seconds

-- Local lookups
-- We use GetTime in the Update loop, so probably best to optimize the lookup.
local GetTime = GetTime


-- Private variables
-- The GetTime() value after which the current HeadsUp session should end.
local CP_HEADSUP_SESSION_WILL_EXPIRE = 0.0



-- Class definition.
local CrashProoferHeadsUpSession = {} -- the table representing the class, which will double as the metatable for the instances
CrashProoferHeadsUpSession.__index = CrashProoferHeadsUpSession -- failed table lookups on the instances should fallback to the class table, to get methods

-- The users who have sent a HeadsUp in the most recent session.
CrashProoferHeadsUpSession.Users = {}

function CrashProoferHeadsUpSession.SetSessionEndedDelegate(self, sessionEndedDelegate)
    -- The delegate should be a function to call when the session ends.
    self.sessionEndedDelegate = sessionEndedDelegate
end

local function CrashProoferHeadsUpSession_ResetExpiration()
    CP_HEADSUP_SESSION_WILL_EXPIRE = GetTime() + CP_HEADSUP_TIMEOUT
end

function CrashProoferHeadsUpSession.StartSession(self)
    --TODO: Prepare state for HeadsUp session.
    --TODO: Pretty sure that means that we need to cancel any in-progress Announce or Record sessions, since
    --      the work would end up being duplicated at the end of the new HeadsUp session otherwise.
    CrashProoferHeadsUpSession_ResetExpiration()
    --We already know WE are in this session.
    --Value will be ignored, but we want to be able to easily search on User names.
    CrashProoferHeadsUpSession.Users = {}
    CrashProoferHeadsUpSession.Users[UnitName("player")] = 1
    --When we start a session, let everyone know we're here.
    --Passing 'true' means we want to cancel everything else we were doing, as it would be made redundant
    --by the new HeadsUpSession.
    self:SendHeadsUp()
end

function CrashProoferHeadsUpSession.EndSession(self)
    -- Setting this to zero officially ends the session.
    CP_HEADSUP_SESSION_WILL_EXPIRE = 0.0

    D("HeadsUpSession ended")
    D("HeadsUp found these users:")
    for userName,_ in pairs(CrashProoferHeadsUpSession.Users) do
        D("   "..userName)
    end

    -- And now we inform our delegate function that the session has ended.
    self.sessionEndedDelegate()
end

function CrashProoferHeadsUpSession.IsInProgress(self)
    --HeadsUp is in progress if the session end time is non-zero.
    --The cleanup code for HeadsUp sessions sets this back to zero.
    return CP_HEADSUP_SESSION_WILL_EXPIRE > 0.0
end

function CrashProoferHeadsUpSession.IsExpired(self)
    --HeadsUp is expired if the current time is later than the expected expiration time.
    return GetTime() > CP_HEADSUP_SESSION_WILL_EXPIRE
end

function CrashProoferHeadsUpSession.OnUpdate(self)
    if (self:IsInProgress()) then
        if (self:IsExpired()) then
            self:EndSession()
        end
    end
end

function CrashProoferHeadsUpSession.SendHeadsUp(self, recipient)
    D("SendHeadsUp started")
    --A HeadsUp message has no extra data beyond the sender that Blizzard already provides.
    local msg = CrashProoferMessage_Create(CP_HEADSUP_PREFIX, "", recipient)
    --If the recipient is nil, this HeadsUp will cancel any pending messages, as the new HeadsUp
    --session makes them all redundant.
    CP_NETWORK:AddMessage(msg, recipient == nil)
end

function CrashProofer_ParseHeadsUpPacket(packet, sender)
    sender = CrashProofer_NameFromSender(sender)
    if (CP_HEADSUP_SESSION:IsInProgress()) then
        --If we are already in a HeadsUpSession, track the sender.
        if (CP_HEADSUP_SESSION.Users[sender] == nil) then
            CP_HEADSUP_SESSION.Users[sender] = 1
            --Let that person know that we exist.  Don't broadcast globally and spam folks.
            --We only do global broadcasts when we start a session.
            CP_HEADSUP_SESSION:SendHeadsUp(sender)
        else
            --We already know about this person, so we don't have to do anything.
        end
        --Don't time out until the airwaves have been silent for a while.
        CrashProoferHeadsUpSession_ResetExpiration()
    else
        --TODO: If we are not in a session, we need to start one and potentially interrupt any other session types.
        CP_HEADSUP_SESSION:StartSession()
    end
end

--The public singleton
CP_HEADSUP_SESSION = setmetatable({}, CrashProoferHeadsUpSession)

--Register to receive HeadsUp packets.
CP_NETWORK:RegisterForMessages(CP_HEADSUP_PREFIX, CrashProofer_ParseHeadsUpPacket)
