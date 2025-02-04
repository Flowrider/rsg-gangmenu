local RSGCore = exports['rsg-core']:GetCoreObject()
local GangAccounts = {}

-------------------------------------------------------------------------------------------
-- functions
-------------------------------------------------------------------------------------------

function GetGangAccount(account)
    return GangAccounts[account] or 0
end

function AddGangMoney(account, amount)
    if not GangAccounts[account] then
        GangAccounts[account] = 0
    end

    GangAccounts[account] = GangAccounts[account] + amount
    MySQL.insert('INSERT INTO management_funds (job_name, amount, type) VALUES (:job_name, :amount, :type) ON DUPLICATE KEY UPDATE amount = :amount', { ['job_name'] = account, ['amount'] = GangAccounts[account], ['type'] = 'gang' })
end

function RemoveGangMoney(account, amount)
    local isRemoved = false
    if amount > 0 then
        if not GangAccounts[account] then
            GangAccounts[account] = 0
        end

        if GangAccounts[account] >= amount then
            GangAccounts[account] = GangAccounts[account] - amount
            isRemoved = true
        end

        MySQL.update('UPDATE management_funds SET amount = ? WHERE job_name = ? and type = "gang"', { GangAccounts[account], account })
    end
    return isRemoved
end

MySQL.ready(function ()
    local gangmenu = MySQL.query.await('SELECT job_name,amount FROM management_funds WHERE type = "gang"', {})
    if not gangmenu then return end

    for _,v in ipairs(gangmenu) do
        GangAccounts[v.job_name] = v.amount
    end
end)

-------------------------------------------------------------------------------------------
-- withdraw money
-------------------------------------------------------------------------------------------
RegisterNetEvent("rsg-gangmenu:server:withdrawMoney", function(amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player.PlayerData.gang.isboss then return end

    local gang = Player.PlayerData.gang.name
    if RemoveGangMoney(gang, amount) then
        Player.Functions.AddMoney("cash", amount, Lang:t('lang_24'))
        TriggerEvent('rsg-log:server:CreateLog', 'gangmenu', Lang:t('lang_25'), 'yellow', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. Lang:t('lang_26') .. amount .. ' (' .. gang .. ')', false)
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_27') ..amount, "success")
    else
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_28'), "error")
    end
end)

-------------------------------------------------------------------------------------------
-- deposit money
-------------------------------------------------------------------------------------------
RegisterNetEvent("rsg-gangmenu:server:depositMoney", function(amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player.PlayerData.gang.isboss then return end

    if Player.Functions.RemoveMoney("cash", amount) then
        local gang = Player.PlayerData.gang.name
        AddGangMoney(gang, amount)
        TriggerEvent('rsg-log:server:CreateLog', 'gangmenu', Lang:t('lang_29'), 'yellow', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. Lang:t('lang_30') .. amount .. ' (' .. gang .. ')', false)
        TriggerClientEvent('RSGCore:Notify', src,Lang:t('lang_31') ..amount, "success")
    else
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_32'), "error")
    end
end)

RSGCore.Functions.CreateCallback('rsg-gangmenu:server:GetAccount', function(_, cb, jobname)
    local result = GetAccount(jobname)
    cb(result)
end)

-------------------------------------------------------------------------------------------
-- get employees
-------------------------------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-gangmenu:server:GetEmployees', function(source, cb, gangname)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player.PlayerData.gang.isboss then return end

    local employees = {}
    local players = MySQL.query.await("SELECT * FROM `players` WHERE `gang` LIKE '%".. gangname .."%'", {})
    if players[1] ~= nil then
        for _, value in pairs(players) do
            local isOnline = RSGCore.Functions.GetPlayerByCitizenId(value.citizenid)

            if isOnline then
                employees[#employees+1] = {
                empSource = isOnline.PlayerData.citizenid,
                grade = isOnline.PlayerData.gang.grade,
                isboss = isOnline.PlayerData.gang.isboss,
                name = '🟢' .. isOnline.PlayerData.charinfo.firstname .. ' ' .. isOnline.PlayerData.charinfo.lastname
                }
            else
                employees[#employees+1] = {
                empSource = value.citizenid,
                grade =  json.decode(value.gang).grade,
                isboss = json.decode(value.gang).isboss,
                name = '❌' ..  json.decode(value.charinfo).firstname .. ' ' .. json.decode(value.charinfo).lastname
                }
            end
        end
    end
    cb(employees)
end)

-------------------------------------------------------------------------------------------
-- grade update
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:server:GradeUpdate', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Employee = RSGCore.Functions.GetPlayerByCitizenId(data.cid)

    if not Player.PlayerData.gang.isboss then return end
    if data.grade > Player.PlayerData.gang.grade.level then TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_33'), "error") return end

    if Employee then
        if Employee.Functions.SetGang(Player.PlayerData.gang.name, data.grade) then
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_34'), "success")
            TriggerClientEvent('RSGCore:Notify', Employee.PlayerData.source, Lang:t('lang_35') ..data.gradename..".", "success")
        else
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_36'), "error")
        end
    else
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_37'), "error")
    end
end)

-------------------------------------------------------------------------------------------
-- fire employee
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:server:FireMember', function(target)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Employee = RSGCore.Functions.GetPlayerByCitizenId(target)

    if not Player.PlayerData.gang.isboss then return end

    if Employee then
        if target ~= Player.PlayerData.citizenid then
            if Employee.PlayerData.gang.grade.level > Player.PlayerData.gang.grade.level then TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_38'), "error") return end
            if Employee.Functions.SetGang("none", '0') then
                TriggerEvent("rsg-log:server:CreateLog", "gangmenu", Lang:t('lang_39'), "orange", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname .. Lang:t('lang_40') .. Employee.PlayerData.charinfo.firstname .. " " .. Employee.PlayerData.charinfo.lastname .. " (" .. Player.PlayerData.gang.name .. ")", false)
                TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_41'), "success")
                TriggerClientEvent('RSGCore:Notify', Employee.PlayerData.source , Lang:t('lang_42'), "error")
            else
                TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_43'), "error")
            end
        else
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_44'), "error")
        end
    else
        local player = MySQL.query.await('SELECT * FROM players WHERE citizenid = ? LIMIT 1', {target})
        if player[1] ~= nil then
            Employee = player[1]
            Employee.gang = json.decode(Employee.gang)
            if Employee.gang.grade.level > Player.PlayerData.job.grade.level then TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_45'), "error") return end
            local gang = {}
            gang.name = "none"
            gang.label = "No Affiliation"
            gang.payment = 0
            gang.onduty = true
            gang.isboss = false
            gang.grade = {}
            gang.grade.name = nil
            gang.grade.level = 0
            MySQL.update('UPDATE players SET gang = ? WHERE citizenid = ?', {json.encode(gang), target})
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_41'), "success")
            TriggerEvent("rsg-log:server:CreateLog", "gangmenu", Lang:t('lang_39'), "orange", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname .. Lang:t('lang_40') .. Employee.PlayerData.charinfo.firstname .. " " .. Employee.PlayerData.charinfo.lastname .. " (" .. Player.PlayerData.gang.name .. ")", false)
        else
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_37'), "error")
        end
    end
end)

-------------------------------------------------------------------------------------------
-- hire employee
-------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-gangmenu:server:HireMember', function(recruit)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Target = RSGCore.Functions.GetPlayer(recruit)

    if not Player.PlayerData.gang.isboss then return end

    if Target and Target.Functions.SetGang(Player.PlayerData.gang.name, 0) then
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('lang_46') .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. Lang:t('lang_47') .. Player.PlayerData.gang.label .. "", "success")
        TriggerClientEvent('RSGCore:Notify', Target.PlayerData.source , Lang:t('lang_48') .. Player.PlayerData.gang.label .. "", "success")
        TriggerEvent('rsg-log:server:CreateLog', 'gangmenu', Lang:t('lang_49'), 'yellow', (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname).. Lang:t('lang_50') .. Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname .. ' (' .. Player.PlayerData.gang.name .. ')', false)
    end
end)

-------------------------------------------------------------------------------------------
-- get closest player
-------------------------------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-gangmenu:getplayers', function(source, cb)
    local src = source
    local players = {}
    local PlayerPed = GetPlayerPed(src)
    local pCoords = GetEntityCoords(PlayerPed)
    for _, v in pairs(RSGCore.Functions.GetPlayers()) do
        local targetped = GetPlayerPed(v)
        local tCoords = GetEntityCoords(targetped)
        local dist = #(pCoords - tCoords)
        if PlayerPed ~= targetped and dist < 10 then
            local ped = RSGCore.Functions.GetPlayer(v)
            players[#players+1] = {
            id = v,
            coords = GetEntityCoords(targetped),
            name = ped.PlayerData.charinfo.firstname .. ' ' .. ped.PlayerData.charinfo.lastname,
            citizenid = ped.PlayerData.citizenid,
            sources = GetPlayerPed(ped.PlayerData.source),
            sourceplayer = ped.PlayerData.source
            }
        end
    end
        table.sort(players, function(a, b)
            return a.name < b.name
        end)
    cb(players)
end)
