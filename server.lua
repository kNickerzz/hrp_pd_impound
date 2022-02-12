local QBCore = exports['qb-core']:GetCoreObject()

-- Allowed to reset during server restart
-- You can use this number to calculate a vehicle spawn location index if you have multiple
-- eg: 3 spawnlocations = index % 3 + 1
local _UnimpoundedVehicleCount = 1;

RegisterServerEvent('HRP:Impound:ImpoundVehicle')
RegisterServerEvent('HRP:Impound:GetImpoundedVehicles')
RegisterServerEvent('HRP:Impound:GetVehicles')
RegisterServerEvent('HRP:Impound:UnimpoundVehicle')
RegisterServerEvent('HRP:Impound:UnlockVehicle')

AddEventHandler('HRP:Impound:ImpoundVehicle', function (form)
	Citizen.Trace("HRP: Impounding vehicle: " .. form.plate);
	_source = source;
	MySQL.query.await('INSERT INTO `h_impounded_vehicles` VALUES (@plate, @officer, @mechanic, @releasedate, @fee, @reason, @notes, CONCAT(@vehicle), @citizen_id, @hold_o, @hold_m)',
		{
			['@plate'] 			= form.plate,
			['@officer']     	= form.officer,
			['@mechanic']       = form.mechanic,
			['@releasedate']	= form.releasedate,
			['@fee']			= form.fee,
			['@reason']			= form.reason,
			['@notes']			= form.notes,
			['@vehicle']		= form.vehicle,
			['@citizen_id']		= form.citizen_id,
			['@hold_o']			= form.hold_o,
			['@hold_m']			= form.hold_m
		}, function(rowsChanged)
			if (rowsChanged == 0) then
				TriggerClientEvent('esx:showNotification', _source, 'Could not impound')
			else
				TriggerClientEvent('esx:showNotification', _source, 'Vehicle Impounded')
			end
	end)
end)

AddEventHandler('HRP:Impound:GetImpoundedVehicles', function (citizen_id)
	_source = source;
	MySQL.query.await('SELECT * FROM `h_impounded_vehicles` WHERE `citizen_id` = @citizen_id ORDER BY `releasedate`',
		{
			['@citizen_id'] = citizen_id,
		}, function (impoundedVehicles)
			TriggerClientEvent('HRP:Impound:SetImpoundedVehicles', _source, impoundedVehicles)
	end)
end)

AddEventHandler('HRP:Impound:UnimpoundVehicle', function (plate)
	_source = source;
	xPlayer = QBCore.Functions.GetPlayer(_source)

	_UnimpoundedVehicleCount = _UnimpoundedVehicleCount + 1;

	Citizen.Trace('HRP: Unimpounding Vehicle with plate: ' .. plate);

	local veh = MySQL.query('SELECT * FROM `h_impounded_vehicles` WHERE `plate` = @plate',
	{
		['@plate'] = plate,
	})

	if(veh == nil) then
		TriggerClientEvent("HRP:Impound:CannotUnimpound")
		return
	end

	if (xPlayer.getMoney() < veh[1].fee) then
		TriggerClientEvent("HRP:Impound:CannotUnimpound")
	else

		xPlayer.removeMoney(round(veh[1].fee));

		MySQL.query.await('DELETE FROM `h_impounded_vehicles` WHERE `plate` = @plate',
		{
			['@plate'] = plate,
		}, function (rows)
			TriggerClientEvent('HRP:Impound:VehicleUnimpounded', _source, veh[1], _UnimpoundedVehicleCount)
		end)
	end
end)

AddEventHandler('HRP:Impound:GetVehicles', function ()
	_source = source;

	local vehicles = MySQL.query.await('SELECT * FROM `h_impounded_vehicles`', nil, function (vehicles)
		TriggerClientEvent('HRP:Impound:SetImpoundedVehicles', _source, vehicles);
	end);
end)

AddEventHandler('HRP:Impound:UnlockVehicle', function (plate)
	MySQL.query.await('UPDATE `h_impounded_vehicles` SET `hold_m` = false, `hold_o` = false WHERE `plate` = @plate', {
		['@plate'] = plate
	}, function (bs)
		-- Something
	end)
end)

-------------------------------------------------------------------------------------------------------------------------------
-- Stupid extra shit because fuck all of this
-------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent('HRP:ESX:GetCharacter')
AddEventHandler('HRP:ESX:GetCharacter', function (citizen_id)
	local _source = source
	MySQL.query.await('SELECT * FROM `players` WHERE `citizenid` = @citizenid',
		{
			['@citizenid'] 		= citizen_id,
		}, function(players)
		TriggerClientEvent('HRP:ESX:SetCharacter', _source, players[1]);
	end)
end)

RegisterServerEvent('HRP:ESX:GetVehicleAndOwner')
AddEventHandler('HRP:ESX:GetVehicleAndOwner', function (plate)
	local _source = source
	if (Config.NoPlateColumn == false) then
		MySQL.query('select * from `player_vehicles` LEFT JOIN `players` ON players.citizenid = player_vehicles.citizenid WHERE `plate` = rtrim(@plate)',
			{
				['@plate'] 		= plate,
			}, function(vehicleAndOwner)
			TriggerClientEvent('HRP:ESX:SetVehicleAndOwner', _source, vehicleAndOwner[1]);
		end)
	else
		MySQL.query('SELECT * FROM `player_vehicles` LEFT JOIN `players` ON players.citizenid = player_vehicles.citizenid', {}, function (result)
			for i=1, #result, 1 do
				local vehicleProps = json.decode(result[i].vehicle)

				if vehicleProps.plate:gsub("%s+", "") == plate:gsub("%s+", "") then
					vehicleAndOwner = result[i];
					vehicleAndOwner.plate = vehicleProps.plate;
					TriggerClientEvent('HRP:ESX:SetVehicleAndOwner', _source, vehicleAndOwner);
					break;
				end
			end
		end)
	end
end)


function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function round(x)
	return x>=0 and math.floor(x+0.5) or math.ceil(x-0.5)
end
