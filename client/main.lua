
local QBCore = exports['qb-core']:GetCoreObject()

local crate_obj = nil
local crate_model = nil
local closestCrate = nil
local crateDistance = 10.0
local closestTruck = nil
local truckDistance = 10.0
local attachedEntity = nil

local canPickupCrate = false
local canPutCrateInTruck = false
local isAttached = false

RegisterCommand("crate", function(source, args, rawCommand)
    	
	if crate_obj ~= nil then
		SetEntityAsMissionEntity(crate_obj, true, true)
		DeleteEntity(crate_obj)
	end
	
	crate_model = Config.Crates[math.random(#Config.Crates)]
	
	x, y, z = table.unpack(GetOffsetFromEntityInWorldCoords(PlayerPedId(-1), 0.0, 1.8, 0.0))
	local heading = GetEntityHeading(GetPlayerPed(-1))
	if heading < 270 then heading = heading - 90 end
	crate_obj  = CreateObject(crate_model, x, y, z, true, true, true)
	SetEntityHeading(crate_obj, heading)
	PlaceObjectOnGroundProperly(crate_obj)
	FreezeEntityPosition(crate_obj, true)
	SetEntityCollision(crate_obj, true, true)
	
end, false)

RegisterCommand("debug", function(source, args, rawCommand)
    	
	local currentVehicle = GetVehiclePedIsIn(PlayerPedId(-1), false)
	SetVehicleOnGroundProperly(currentVehicle)
	SetForkliftForkHeight(currentVehicle, 0.05)
	
end, false)

----------- INTERACTING WITH THE CRATES -------------

CreateThread(function()
	AddTextEntry("press_attach_crate", "Press ~INPUT_JUMP~ to pick up this crate")
	AddTextEntry("press_drop_crate", "Press ~INPUT_JUMP~ to drop this crate")
	AddTextEntry("press_truck_crate", "Press ~INPUT_JUMP~ to put crate in truck")

    while true do
        Wait(0)

		if canPickupCrate then
			DisplayHelpTextThisFrame("press_attach_crate")
		elseif isAttached and not canPutCrateInTruck then
			DisplayHelpTextThisFrame("press_drop_crate")
		elseif isAttached and canPutCrateInTruck and closestTruck then
			DisplayHelpTextThisFrame("press_truck_crate")
		end
		
		local currentVehicle = GetVehiclePedIsIn(PlayerPedId(-1), false)
		
		if IsControlJustPressed(0, 22) and GetEntityModel(currentVehicle) == `forklift` then
					
			-- if already attached detach
			if isAttached and not canPutCrateInTruck then
				print("DROP ON GROUND")
				
				SetForkliftForkHeight(currentVehicle, 0.05)
				Wait(1000) -- For some reason you need to wait exactly 1 second otherwise the forks stop at a random height
				DetachEntity(attachedEntity, true, true)
				SetForkliftForkHeight(currentVehicle, 0.05)
				PlaceObjectOnGroundProperly(attachedEntity)				
				attachedEntity = nil
				isAttached = false
				
			elseif isAttached and canPutCrateInTruck and closestTruck then
			
				print("PUT CRATE IN TRUCK")
			
				SetForkliftForkHeight(currentVehicle, 1.0)
				Wait(1100)
				DetachEntity(attachedEntity, true, true)          -- RIGHT, FRWD, UP
				AttachEntityToEntity(attachedEntity, closestTruck, 18, 0.7, 1.1, 0.3, 0.0, 0, 90.0, false, false, false, false, 2, true) -- Bone options: 5, (14, 15), (16, 17)
				isAttached = false
				
			else -- Pick up crate off ground		
				-- if crate is found
				if closestCrate then
					
					-- check if player is in forklift
					if GetEntityModel(currentVehicle) == `forklift` then 
					
						print("ATTACH")
						
						if attachedEntity then DetachEntity(attachedEntity, true, true) end
											
						isAttached = true
						canPickupCrate = false
						attachedEntity = closestCrate
						
						-- attach crate to forklift
						AttachEntityToEntity(closestCrate, currentVehicle, 3, 0.0, 1.4, -0.55, 0.0, 0, 90.0, false, false, true, false, 2, true)
						
						if GetEntityCoords(GetPlayerPed(-1)).z > GetEntityCoords(closestCrate).z then
							SetForkliftForkHeight(currentVehicle, 0.15)
						end
						
						
					end
				end
			end
        end   
        
    end
end)

-------- FINDING THE CRATES --------------

function GetObjectCoords(objectHash, objectType, maxDistance)

	local object = nil
	if objectType == "object" then 
		object = GetClosestObjectOfType(GetEntityCoords(PlayerPedId(-1)), maxDistance, GetHashKey(objectHash), false, false, false)
	elseif objectType == "vehicle" then 
		object = GetClosestVehicle(GetEntityCoords(PlayerPedId(-1)), maxDistance, GetHashKey(objectHash), 70) 
	end
	
    if object then
        return object, GetEntityCoords(object)
    else
        return object, vector3(0, 0, 0) -- Return a default position if the object is not found
    end
end

function GetClosestObjectInFront(playerPos, playerHeading, objectHashes, objectType, maxDistance)
    local closestObject = nil
    local closestDistance = maxDistance
	objectType = objectType or "object"

    for _, objectHash in ipairs(objectHashes) do

        local object, objectCoords = GetObjectCoords(objectHash, objectType, maxDistance) 
        local distance = #(playerPos - objectCoords)
        -- Angle of the box to the player
		local angle = math.deg(math.atan2(objectCoords.y - playerPos.y, objectCoords.x - playerPos.x))
		-- Normalise the angles to comapre with player heading
		if angle >= 0 and angle < 90 then angle = 270 + angle
		elseif angle >= 90 and angle <= 180 then angle = (angle - 90)
		else angle = 270 + angle end
        local angleDiff = math.abs(playerHeading - angle)

        -- Check if the object is in front of the player within 45 degree threshold
        if angleDiff <= 27 then
            -- Update closest object if the current object is closer
            if distance < closestDistance then
                closestDistance = distance
                closestObject = object
            end
        end
    end

    return closestObject, closestDistance
end

CreateThread(function()
	while true do
		-- check every 500ms if helptext should show
		Wait(500)
						
		local playerPed = PlayerPedId()

		if not isAttached and IsPedInAnyVehicle(playerPed) and GetEntityModel(GetVehiclePedIsIn(playerPed)) == `forklift` then
		
			local playerCoords = GetEntityCoords(playerPed)			
			closestCrate, crateDistance = GetClosestObjectInFront(playerCoords, GetEntityHeading(GetPlayerPed(-1)), Config.Crates, "object", 3.0)
			if closestCrate then print("Crate Found: " .. closestCrate .. " , " .. crateDistance .. " units") end
			
			canPickupCrate = (closestCrate ~= nil)
			
		else canPickupCrate = false end
		
	end
end)

---------- FINDING THE TRUCKS ------------

function debugBox(truck)

	local dimensionMin, dimensionMax = GetModelDimensions(GetEntityModel(truck))
	local p = GetOffsetFromEntityInWorldCoords(truck, 0.0, (dimensionMin.y), 0.0)
	DrawBox(p.x + 1, p.y + 1, p.z + 1, p.x - 1, p.y -1, p.z -1, 255, 0, 25, 255)

end

function crateInTruck(closestTruck)

	print("CHECKING CRATE IN TRUCK")	

	if not isAttached then
		return false
	elseif closestTruck == nil then
		return false
	else
		
		print("CHECKING OBJECT POOL")
	
		local objPool = GetGamePool('CObject') 
		local p = GetEntityCoords(playerPed)
		for i = 1, #objPool do
			local o = GetEntityCoords(objPool[i])
			
			if GetDistanceBetweenCoords(p.x, p.y, p.z, o.x, o.y, o.z, true) < 10 and o ~= attachedEntity then
			
				print("NEARBY OBJ: " .. GetEntityModel(o))
			
				for j=1, #Config.Crates do
				
				
					if GetEntityModel(o) == Config.Crates[j] then
					
						print("CRATE FOUND")
					
						if IsEntityAttachedToEntity(o, closestTruck) then
							print("CRATE IN TRUCK")
							return true
						end
					
					end				
				end			
			end			
		end
		return false
	end
	

end

CreateThread(function()

    while true do
		
		Wait(100)
    
        local playerPed = PlayerPedId()

		local playerCoords = GetEntityCoords(playerPed)
		closestTruck, truckDistance = GetClosestObjectInFront(playerCoords, GetEntityHeading(GetPlayerPed(-1)), Config.Trucks, "vehicle", 8.0)
		debugBox(closestTruck)
		
		canPutCrateInTruck = (closestTruck ~= nil)
		
		canPutCrateInTruck = (canPutCrateInTruck and not crateInTruck(closestTruck))
		
        
        -- if not inTruck then
        
        --     local playerCoords = GetEntityCoords(playerPed)
        --     closestTruck, truckDistance = GetClosestObjectInFront(playerCoords, GetEntityHeading(GetPlayerPed(-1)), Config.Trucks, "vehicle", 8.0)
        --     debugBox(closestTruck)
			
		-- 	canPutCrateInTruck = (closestTruck ~= nil)
			
		-- 	canPutCrateInTruck = (canPutCrateInTruck and not crateInTruck(closestTruck))
        
        -- else canPutCrateInTruck = false end
    
    
    end


end)
