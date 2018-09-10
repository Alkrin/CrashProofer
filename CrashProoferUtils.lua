--CrashProoferUtils

CRASHPROOFER_PREFIX = "CxP";

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

function CrashProofer_TableSize(table)
    local count = 0
    for _, _ in pairs(table) do 
        count = count + 1 
    end
    return count
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
            if (stype == "table") then
                if (not lookup[v]) then
                    table.insert(tables, v)
                    lookup[v] = #tables
                end
                result = result..charS.."{"..lookup[v].."},"..charE
            elseif (stype == "string") then
                result = result..charS..exportstring(v)..","..charE
            elseif (stype == "number") then
                result = result..charS..tostring( v )..","..charE
            end
        end

        for i, v in pairs(t) do
            -- escape handled values
            if (not thandled[i]) then
            
                local str = ""
                local stype = type(i)
                -- handle index
                if (stype == "table") then
                    if (not lookup[i]) then
                        table.insert(tables, i)
                        lookup[i] = #tables
                    end
                    str = charS.."[{"..lookup[i].."}]="
                elseif (stype == "string") then
                    str = charS.."["..exportstring(i).."]="
                elseif (stype == "number") then
                    str = charS.."["..tostring(i).."]="
                end
            
                if (str ~= "") then
                    stype = type(v)
                    -- handle value
                    if (stype == "table") then
                        if (not lookup[v]) then
                            table.insert(tables, v)
                            lookup[v] = #tables
                        end
                        result = result..str.."{"..lookup[v].."},"..charE
                    elseif (stype == "string") then
                        result = result..str..exportstring( v )..","..charE
                    elseif (stype == "number") then
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
            if (type(v) == "table") then
                tables[idx][i] = tables[v[1]]
            end
            if (type(i) == "table") and tables[i[1]] then
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

function CrashProofer_SendNetworkMessage(msg, recipient)
    -- CrashProofer only backs up to and from guild members.
    if (IsInGuild()) then
        if (recipient == nil) then
            C_ChatInfo.SendAddonMessage(CRASHPROOFER_PREFIX, msg, "GUILD")
        else
            C_ChatInfo.SendAddonMessage(CRASHPROOFER_PREFIX, msg, "WHISPER", recipient)
        end
    end
end
