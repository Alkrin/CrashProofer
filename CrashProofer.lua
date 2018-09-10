--CrashProofer

local CP_HEADSUP_TIMEOUT = 5.0 --seconds
local CP_ANNOUNCE_TIMEOUT = 5.0 --seconds
local CP_RECORD_TIMEOUT = 5.0 --seconds

function CPTEST()
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
    D(#(table.save(t)))
end

CPTEST()

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
    CP_HEADSUP_SESSION:StartSession()
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
            --D("Received packet from "..sender)
            --D("   "..msg)
            CrashProofer_NetworkEvent(msg, channel, sender)
        end
    end
end

function CrashProofer_NetworkEvent(msg, channel, sender)
    -- Process only network events from others; ignore ourselves.
    if (sender ~= UnitName("player")) then
        CP_NETWORK:PacketReceived(msg, sender)
    end
end

function CrashProofer_OnHeadsUpSessionEnded()
    --TODO: Start Announce session.
end

function CrashProofer_OnUpdate()
    CP_NETWORK:OnUpdate()
    CP_HEADSUP_SESSION:OnUpdate()
end
