-- Player extension methods
function Player:SendErrorMessage( str )
    self:SendChatMessage( str, Color( 255, 0, 0 ) )
end

function Player:SendSuccessMessage( str )
    self:SendChatMessage( str, Color( 0, 255, 0 ) )
end

-- Buy Menu
function BuyMenu:__init()
    self.items      = {}
    self.vehicles   = {}
    self.hotspots   = {}
	VIPRank			=	5
	VIPPlayers	=	{
					"SteamID"
					}
    self.ammo_counts            = {
--		ID			Mag		Reserve			Weapon Name
        [2]		= {	12,		300 },		--	Pistol
		[43]	= {	125,	500 },		--	Bubble Blaster
		[4]		= {	7,		175 },		--	Revolver
        [6]		= {	3,		150 },		--	Sawed-Off Shotgun
		[5]		= {	30,		750 },		--	Submachine Gun
		[13]	= {	6,		150 },		--	Shotgun
		[11]	= {	20,		500 },		--	Assault Rifle
        [28]	= {	26,		650 },		--	Machine Gun
        [14]	= {	4,		100 },		--	Sniper Rifle
		[17]	= {	5,		125 },		--	Grenade Launcher
		[16]	= {	3,		75 },		--	Rocket Launcher
		[26]	= {	100,	500 },		--	?????
		[66]	= {	116,	580 },		--	Panay's Rocket Launcher Modification
		[103]	= {	6,		150 },		--	Rico's Signature Gun			DLC
		[101]	= {	100,	5000 },		--	Air Propulsion Gun				DLC
		[100]	= {	24,		600 },		--	Bull's Eye Assault Rifle		DLC
		[104]	= {	8,		400 },		--	Quad Rocket Launcher			DLC
		[102]	= {	1,		125 },		--	Cluster Bomb Launcher			DLC
		[105]	= {	4,		200 },		--	Multi-Lock Missile Launcher		DLC
    }

    self:CreateItems()

    Events:Subscribe( "PlayerJoin", self, self.PlayerJoin )
    Events:Subscribe( "PlayerQuit", self, self.PlayerQuit )
    Events:Subscribe( "ModuleUnload", self, self.ModuleUnload )

    Events:Subscribe( "SpawnPoint", self, self.AddHotspot )
    Events:Subscribe( "TeleportPoint", self, self.AddHotspot )

    Network:Subscribe( "PlayerFired", self, self.PlayerFired )    
    Network:Subscribe( "ColorChanged", self, self.ColorChanged )
	
    SQL:Execute( "CREATE TABLE IF NOT EXISTS buymenu_players (steamid VARCHAR UNIQUE, model_id INTEGER)")
    SQL:Execute( "CREATE TABLE IF NOT EXISTS buymenu_colors (steamid VARCHAR UNIQUE, r1 INTEGER, g1 INTEGER, b1 INTEGER, r2 INTEGER, g2 INTEGER, b2 INTEGER)")
    SQL:Execute( "CREATE TABLE IF NOT EXISTS buymenu_players_appearances (steamid VARCHAR UNIQUE, head VARCHAR, covering VARCHAR, hair VARCHAR, face VARCHAR, neck VARCHAR, back VARCHAR, torso VARCHAR, righthand VARCHAR, lefthand VARCHAR, legs VARCHAR, rightfoot VARCHAR, leftfoot VARCHAR)")

	-- Save color
	Network:Subscribe("BuyMenuGetSaveColor", self, self.GetSaveColor)
	Network:Subscribe("BuyMenuSaveColor", self, self.SaveColor)
end

-- Utility
function BuyMenu:IsInHotspot( pos )
    for _, v in ipairs(self.hotspots) do
        if (pos - v):LengthSqr() < 625 then -- 25m deadzone
            return true
        end
    end

    return false
end

function BuyMenu:SaveColor(args, player)
	local tone1 = args.tone1
	local tone2 = args.tone2

	local cmd = SQL:Command("INSERT OR REPLACE INTO buymenu_colors (steamid, r1, g1, b1, r2, g2, b2) values (?, ?, ?, ?, ?, ?, ?)")
    cmd:Bind(1, player:GetSteamId().id)
    cmd:Bind(2, tone1.r)
    cmd:Bind(3, tone1.g)
    cmd:Bind(4, tone1.b)
    cmd:Bind(5, tone2.r)
    cmd:Bind(6, tone2.g)
    cmd:Bind(7, tone2.b)
    cmd:Execute()
end

function BuyMenu:GetSaveColor(args, player)
    local colorQuery = SQL:Query("SELECT r1, g1, b1, r2, g2, b2 FROM buymenu_colors WHERE steamid = ?")
    colorQuery:Bind(1, player:GetSteamId().id)
    local colorResult = colorQuery:Execute()

    if #colorResult == 1 then
		local row = colorResult[1]
		Network:Send(player, "BuyMenuSavedColor", {
			tone1 = Color(tonumber(row.r1), tonumber(row.g1), tonumber(row.b1)),
			tone2 = Color(tonumber(row.r2), tonumber(row.g2), tonumber(row.b2))
		})
    end
end

function BuyMenu:ColorChanged( args, sender )
    local veh = sender:GetVehicle()
    if IsValid(veh) then
        if self.vehicles[sender:GetId()] ~= nil and self.vehicles[sender:GetId()]:GetId() == veh:GetId() then
            veh:SetColors( args.tone1, args.tone2 )
        else
            sender:SendChatMessage("This isn't your vehicle!", Color(255,0,0))
        end
    end
end

-- Events
function BuyMenu:PlayerJoin( args )
	self:SetPlayerModelFromDB(args)
	self:SetPlayerAppearancesFromDB(args)
end

function BuyMenu:SetPlayerModelFromDB( args )
    local qry = SQL:Query( "select model_id from buymenu_players where steamid = (?)" )
    qry:Bind( 1, args.player:GetSteamId().id )
    local result = qry:Execute()

    if #result > 0 then
        args.player:SetModelId( tonumber(result[1].model_id) )
    end
end

function BuyMenu:SetPlayerAppearancesFromDB( args )
    local qry = SQL:Query( "SELECT head, covering, hair, face, neck, back, torso, righthand, lefthand, legs, rightfoot, leftfoot FROM buymenu_players_appearances where steamid = (?)" )
    qry:Bind( 1, args.player:GetSteamId().id )
    local result = qry:Execute()

    if #result > 0 then
		args.player:SetNetworkValue( "AppearanceHat", result[1].head) -- Store the Appearance Item as a player value
--		print("Head: ",result[1].head)
		args.player:SetNetworkValue( "AppearanceCovering", result[1].covering) -- Store the Appearance Item as a player value
--		print("Covering: ",result[1].covering)
		args.player:SetNetworkValue( "AppearanceHair", result[1].hair) -- Store the Appearance Item as a player value
--		print("Hair: ",result[1].hair)
		args.player:SetNetworkValue( "AppearanceFace", result[1].face) -- Store the Appearance Item as a player value
--		print("Face: ",result[1].face)
		args.player:SetNetworkValue( "AppearanceNeck", result[1].neck) -- Store the Appearance Item as a player value
--		print("Neck: ",result[1].neck)
		args.player:SetNetworkValue( "AppearanceBack", result[1].back) -- Store the Appearance Item as a player value
--		print("Back: ",result[1].back)
		args.player:SetNetworkValue( "AppearanceTorso", result[1].torso) -- Store the Appearance Item as a player value
--		print("Torso: ",result[1].head)
		args.player:SetNetworkValue( "AppearanceRightHand", result[1].righthand) -- Store the Appearance Item as a player value
--		print("RightHand: ",result[1].covering)
		args.player:SetNetworkValue( "AppearanceLeftHand", result[1].lefthand) -- Store the Appearance Item as a player value
--		print("LeftHand: ",result[1].hair)
		args.player:SetNetworkValue( "AppearanceLegs", result[1].legs) -- Store the Appearance Item as a player value
--		print("Legs: ",result[1].face)
		args.player:SetNetworkValue( "AppearanceRightFoot", result[1].rightfoot) -- Store the Appearance Item as a player value
--		print("RightFoot: ",result[1].neck)
		args.player:SetNetworkValue( "AppearanceLeftFoot", result[1].leftfoot) -- Store the Appearance Item as a player value
--		print("LeftFoot: ",result[1].back)
    end
end

function BuyMenu:PlayerQuit( args )
    if IsValid( self.vehicles[ args.player:GetId() ] ) then
        self.vehicles[ args.player:GetId() ]:Remove()
        self.vehicles[ args.player:GetId() ] = nil
    end
end

function BuyMenu:ModuleUnload()
    for k, v in pairs(self.vehicles) do
        if IsValid( v ) then
            v:Remove()
        end
    end
end

function BuyMenu:AddHotspot( pos )
    for _, v in ipairs(self.hotspots) do
        if (pos - v):LengthSqr() < 16 then -- 4m error
            return
        end
    end
    
    table.insert( self.hotspots, pos )
end

function BuyMenu:PlayerFired( args, player )
    local category_id       = args[1]
    local subcategory_name  = args[2]
    local index             = args[3]
    local tone1             = args[4]
    local tone2             = args[5]

    local hotspot_categories = {
        self.types.Vehicle
    }

    if player:GetWorld() ~= DefaultWorld then
        player:SendErrorMessage( "You are not in the main world!" )
        return
    end

    if  self:IsInHotspot( player:GetPosition() ) and 
        table.find( hotspot_categories, category_id ) ~= nil then

        player:SendErrorMessage( 
            "You are in a hotspot! You can't buy that kind of item here." )
        return
    end

    local item = self.items[category_id][subcategory_name][index]

    if item == nil then
        player:SendErrorMessage( "Invalid item!" )
        return
    end

    if player:GetMoney() < item:GetPrice() then
        local str = string.format(
            "You do not have enough money for a %s! "..
            "You need an additional $%i.",
            item:GetName(),
            item:GetPrice() - player:GetMoney() )

        player:SendErrorMessage( str )
        return
    end 

    local success, err    

    if category_id == self.types.Vehicle then
        success, err = self:BuyVehicle( player, item, tone1, tone2 )
    elseif category_id == self.types.Weapon then           
        success, err = self:BuyWeapon( player, item )
    elseif category_id == self.types.Model then
        success, err = self:BuyModel( player, item )
	elseif category_id == self.types.Appearance then
        success, err = self:BuyAppearance( player, item )
    end
	
    if success then
        player:SetMoney( player:GetMoney() - item:GetPrice() )

        local str = string.format(
            "You have purchased a %s for $%i! Your balance is now $%i.",
            item:GetName(),
            item:GetPrice(),
            player:GetMoney() )

        player:SendSuccessMessage( str )
    else
        player:SendErrorMessage( err )
    end
end

function BuyMenu:IsVIPPlayer(player)
	local PlayerSteamID = player:GetSteamId()
	for _,v in pairs(VIPPlayers) do
		if tostring(v) == tostring(PlayerSteamID) then
			return true
		end
	end
	return false
end

function BuyMenu:BuyVehicle( player, item, tone1, tone2 )
	--	The actual execution of the create item functions has been moved to a Execute<ItemType> function.
	--	This allows you to do applicable checks here, inside the buy function-
	--	and then fire the command if your checks are valid. This gives more flexibility.
	
	if item:GetRank() ~= nil then
		local RequiredRank = item:GetRank()
		print("VIPRank",VIPRank)
		print("RequiredRank",RequiredRank)
		if VIPRank >= RequiredRank then
			 if self:IsVIPPlayer(player) then
				self:ExecuteVehicle( player, item, tone1, tone2 )
				return true, ""
			else
				return false, "You must be a VIP or Donor to buy this."
			end
		end
	end
	
	self:ExecuteVehicle( player, item, tone1, tone2 )
    return true, ""	--	Return true must be right after the execution else the confirmation message gives an error.
end

function BuyMenu:ExecuteVehicle( player, item, tone1, tone2 )
    if player:GetState() == PlayerState.InVehiclePassenger then
        return false, "You cannot purchase a vehicle while in the passenger seat!"
    end

    if IsValid( self.vehicles[ player:GetId() ] ) then
        self.vehicles[ player:GetId() ]:Remove()
        self.vehicles[ player:GetId() ] = nil
    end
	
    local args = {}
    args.model_id           = item:GetModelId()
	
	if item:GetTemplate() ~= nil then
		args.template = item:GetTemplate()
	end
	
	if item:GetDecal() ~= nil then
		args.decal = item:GetDecal()
	end

    args.position           = player:GetPosition()
    args.angle              = player:GetAngle()
    args.linear_velocity    = player:GetLinearVelocity() * 1.1
    args.enabled            = true
    args.tone1              = tone1
    args.tone2              = tone2

    local v = Vehicle.Create( args )
    self.vehicles[ player:GetId() ] = v

    v:SetUnoccupiedRespawnTime( nil )
	v:SetDeathRemove(true)
    player:EnterVehicle( v, VehicleSeat.Driver )

    return true, ""
end

function BuyMenu:BuyWeapon( player, item )
	--	The actual execution of the create item functions has been moved to a Execute<ItemType> function.
	--	This allows you to do applicable checks here, inside the buy function-
	--	and then fire the command if your checks are valid. This gives more flexibility.
	if item:GetRank() ~= nil then
		local RequiredRank = item:GetRank()
		print("VIPRank",VIPRank)
		print("RequiredRank",RequiredRank)
		if VIPRank >= RequiredRank then
			 if self:IsVIPPlayer(player) then
				self:ExecuteWeapon( player, item )
				return true, ""
			else
				return false, "You must be a VIP or Donor to buy this."
			end
		end
	end
	self:ExecuteWeapon( player, item )
    return true, ""	--	Return true must be right after the execution else the confirmation message gives an error.
end

function BuyMenu:ExecuteWeapon( player, item )
    player:GiveWeapon( item:GetSlot(), 
        Weapon( item:GetModelId(), 
            self.ammo_counts[item:GetModelId()][1] or 0,
            (self.ammo_counts[item:GetModelId()][2] or 200) * 6 ) )

    return true, ""
end

function BuyMenu:BuyModel( player, item )
	--	The actual execution of the create item functions has been moved to a Execute<ItemType> function.
	--	This allows you to do applicable checks here, inside the buy function-
	--	and then fire the command if your checks are valid. This gives more flexibility.
	if item:GetRank() ~= nil then
		local RequiredRank = item:GetRank()
		print("VIPRank",VIPRank)
		print("RequiredRank",RequiredRank)
		if VIPRank >= RequiredRank then
			 if self:IsVIPPlayer(player) then
				self:ExecuteModel( player, item )
				return true, ""
			else
				return false, "You must be a VIP or Donor to buy this."
			end
		end
	end
	self:ExecuteModel( player, item )
    return true, ""	--	Return true must be right after the execution else the confirmation message gives an error.
end

function BuyMenu:ExecuteModel( player, item )
    player:SetModelId( item:GetModelId() )

    local cmd = SQL:Command( 
        "insert or replace into buymenu_players (steamid, model_id) values (?, ?)" )
    cmd:Bind( 1, player:GetSteamId().id )
    cmd:Bind( 2, item:GetModelId() )
    cmd:Execute()

    return true, ""
end

function BuyMenu:BuyAppearance( player, item )
	--	The actual execution of the create item functions has been moved to a Execute<ItemType> function.
	--	This allows you to do applicable checks here, inside the buy function-
	--	and then fire the command if your checks are valid. This gives more flexibility.
	if item:GetRank() ~= nil then
		local RequiredRank = item:GetRank()
		print("VIPRank",VIPRank)
		print("RequiredRank",RequiredRank)
		if VIPRank >= RequiredRank then
			 if self:IsVIPPlayer(player) then
				self:ExecuteAppearance( player, item )
				return true, ""
			else
				return false, "You must be a VIP or Donor to buy this."
			end
		end
	end
	self:ExecuteAppearance( player, item )
    return true, ""	--	Return true must be right after the execution else the confirmation message gives an error.
end

function BuyMenu:ExecuteAppearance( player, item )
	local itemModel = item:GetModelId()
	local itemType = item:GetType()
	local qry = SQL:Query( "SELECT head, covering, hair, face, neck, back, torso, righthand, lefthand, legs, rightfoot, leftfoot FROM buymenu_players_appearances where steamid = (?)" )
	qry:Bind( 1, player:GetSteamId().id )
	local result = qry:Execute()

	if #result > 0 then
		if itemType == "Head" then
			player:SetNetworkValue( "AppearanceHat", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "UPDATE buymenu_players_appearances SET head = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "Covering" then
			player:SetNetworkValue( "AppearanceCovering", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "UPDATE buymenu_players_appearances SET covering = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "Hair" then
			player:SetNetworkValue( "AppearanceHair", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "UPDATE buymenu_players_appearances SET hair = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "Face" then
			player:SetNetworkValue( "AppearanceFace", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "UPDATE buymenu_players_appearances SET face = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "Neck" then
			player:SetNetworkValue( "AppearanceNeck", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "UPDATE buymenu_players_appearances SET neck = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "Back" then
			player:SetNetworkValue( "AppearanceBack", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "UPDATE buymenu_players_appearances SET back = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "Torso" then
			player:SetNetworkValue( "AppearanceTorso", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "UPDATE buymenu_players_appearances SET torso = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "RightHand" then
			player:SetNetworkValue( "AppearanceRightHand", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "UPDATE buymenu_players_appearances SET righthand = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "LeftHand" then
			player:SetNetworkValue( "AppearanceLeftHand", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "UPDATE buymenu_players_appearances SET lefthand = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "Legs" then
			player:SetNetworkValue( "AppearanceLegs", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "UPDATE buymenu_players_appearances SET legs = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "RightFoot" then
			player:SetNetworkValue( "AppearanceRightFoot", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "UPDATE buymenu_players_appearances SET rightfoot = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "LeftFoot" then
			player:SetNetworkValue( "AppearanceLeftFoot", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "UPDATE buymenu_players_appearances SET leftfoot = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		end
	else
		if itemType == "Head" then
			player:SetNetworkValue( "AppearanceHat", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "INSERT or REPLACE into buymenu_players_appearances (steamid, head) values (?, ?)" )
			cmd:Bind( 1, player:GetSteamId().id )
			cmd:Bind( 2, itemModel )
			cmd:Execute()
		elseif itemType == "Hair" then
			player:SetNetworkValue( "AppearanceHair", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "INSERT or REPLACE into buymenu_players_appearances (steamid, hair) values (?, ?)" )
			cmd:Bind( 1, player:GetSteamId().id )
			cmd:Bind( 2, itemModel )
			cmd:Execute()
		elseif itemType == "Covering" then
			player:SetNetworkValue( "AppearanceCovering", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "INSERT or REPLACE into buymenu_players_appearances (steamid, covering) values (?, ?)" )
			cmd:Bind( 1, player:GetSteamId().id )
			cmd:Bind( 2, itemModel )
			cmd:Execute()
		elseif itemType == "Face" then
			player:SetNetworkValue( "AppearanceFace", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "INSERT or REPLACE into buymenu_players_appearances (steamid, face) values (?, ?)" )
			cmd:Bind( 1, player:GetSteamId().id )
			cmd:Bind( 2, itemModel )
			cmd:Execute()
		elseif itemType == "Neck" then
			player:SetNetworkValue( "AppearanceNeck", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "INSERT or REPLACE into buymenu_players_appearances (steamid, neck) values (?, ?)" )
			cmd:Bind( 1, player:GetSteamId().id )
			cmd:Bind( 2, itemModel )
			cmd:Execute()
		elseif itemType == "Back" then
			player:SetNetworkValue( "AppearanceBack", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "INSERT or REPLACE into buymenu_players_appearances (steamid, back) values (?, ?)" )
			cmd:Bind( 1, player:GetSteamId().id )
			cmd:Bind( 2, itemModel )
			cmd:Execute()
		elseif itemType == "Torso" then
			player:SetNetworkValue( "AppearanceTorso", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "INSERT or REPLACE buymenu_players_appearances SET torso = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "RightHand" then
			player:SetNetworkValue( "AppearanceRightHand", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "INSERT or REPLACE buymenu_players_appearances SET righthand = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "LeftHand" then
			player:SetNetworkValue( "AppearanceLeftHand", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "INSERT or REPLACE buymenu_players_appearances SET lefthand = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "Legs" then
			player:SetNetworkValue( "AppearanceLegs", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "INSERT or REPLACE buymenu_players_appearances SET legs = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "RightFoot" then
			player:SetNetworkValue( "AppearanceRightFoot", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "INSERT or REPLACE buymenu_players_appearances SET rightfoot = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		elseif itemType == "LeftFoot" then
			player:SetNetworkValue( "AppearanceLeftFoot", itemModel) -- Store the Appeance Item as a player value
			local cmd = SQL:Command( "INSERT or REPLACE buymenu_players_appearances SET leftfoot = (?) WHERE steamid = (?)" )
			cmd:Bind( 1, itemModel )
			cmd:Bind( 2, player:GetSteamId().id )
			cmd:Execute()
		end
	end
	return true, ""
end

buy_menu = BuyMenu()
