
local addonName, addonTable = ...; 
local zc = addonTable.zc;


-----------------------------------------

local auctionator_orig_GameTooltip_OnTooltipAddMoney;

-----------------------------------------

function auctionator_GameTooltip_OnTooltipAddMoney (self, cost, maxcost)

	if (AUCTIONATOR_V_TIPS == 1) then
		return;
	end

	auctionator_orig_GameTooltip_OnTooltipAddMoney (self, cost, maxcost);
end

-----------------------------------------

function Atr_Hook_OnTooltipAddMoney()
	auctionator_orig_GameTooltip_OnTooltipAddMoney = GameTooltip_OnTooltipAddMoney;
	GameTooltip_OnTooltipAddMoney = auctionator_GameTooltip_OnTooltipAddMoney;
end

------------------------------------------------

local function Atr_AppendHint (results, price, text, volume)

	if (price and price > 0) then
		local e = {};
		e.price		= price;
		e.text		= text;
		e.volume	= volume;
		
		table.insert (results, e);
	end

end

------------------------------------------------

function Atr_BuildHints (itemName)

	local results = {};

	local itemLink = Atr_GetItemLink (itemName);

	if (itemLink == nil and itemName == nil) then
		return results;
	end

	-- Auctionator Full Scan
	
	if (itemName ~= nil and gAtr_ScanDB[itemName] ~= nil) then
		Atr_AppendHint (results, gAtr_ScanDB[itemName], ZT("Auctionator scan data"));
	end

	-- most recent historical price
	
	local price = Atr_GetMostRecentSale(itemName);
	if (price ~= nil) then
		Atr_AppendHint (results, price, ZT("your most recent posting"));
	end

	-- Wowecon

	if (Wowecon and Wowecon.API) then
	
		local priceG, volG, priceS, volS;
		
		if (itemLink) then
			priceG, volG = Wowecon.API.GetAuctionPrice_ByLink (itemLink, Wowecon.API.GLOBAL_PRICE)
			priceS, volS = Wowecon.API.GetAuctionPrice_ByLink (itemLink, Wowecon.API.SERVER_PRICE)
		else
			priceG, volG = Wowecon.API.GetAuctionPrice_ByName (itemName, Wowecon.API.GLOBAL_PRICE)
			priceS, volS = Wowecon.API.GetAuctionPrice_ByName (itemName, Wowecon.API.SERVER_PRICE)
		end
		
		Atr_AppendHint (results, priceG, ZT("Wowecon global price"), volG);
		Atr_AppendHint (results, priceS, ZT("Wowecon server price"), volS);
		
	end
	
	if (itemLink) then
	
		-- GoingPrice Wowhead
		
		local id = zc.ItemIDfromLink (itemLink);
		
		id = tonumber(id);

		if (GoingPrice_Wowhead_Data and GoingPrice_Wowhead_Data[id] and GoingPrice_Wowhead_SV._index) then
			local index = GoingPrice_Wowhead_SV._index["Buyout price"];

			if (index ~= nil) then
				local price = GoingPrice_Wowhead_Data[id][index];
			
				Atr_AppendHint (results, price, "GoingPrice - Wowhead");
			end
		end

		-- GoingPrice Allakhazam
		
		if (GoingPrice_Allakhazam_Data and GoingPrice_Allakhazam_Data[id] and GoingPrice_Allakhazam_SV._index) then
			local index = GoingPrice_Allakhazam_SV._index["Median"];

			if (index ~= nil) then
				local price = GoingPrice_Allakhazam_Data[id][index];
			
				Atr_AppendHint (results, price, "GoingPrice - Allakhazam");
			end
		end
	end
	
	return results;

end

-----------------------------------------

function Atr_ShowHints ()

	Atr_Col1_Heading:Hide();
	Atr_Col3_Heading:Hide();
	Atr_Col4_Heading:Hide();

	Atr_Col3_Heading:SetText (ZT("Source"));

	local currentPane = Atr_GetCurrentPane();

	currentPane.hints = Atr_BuildHints (currentPane.activeScan.itemName);
	
	local numrows = currentPane.hints and #currentPane.hints or 0;

	if (numrows > 0) then
		Atr_Col1_Heading:Show();
		Atr_Col3_Heading:Show();
	end

	local line;							-- 1 through 12 of our window to scroll
	local dataOffset;					-- an index into our data calculated from the scroll offset

	FauxScrollFrame_Update (AuctionatorScrollFrame, numrows, 12, 16);

	for line = 1,12 do

		dataOffset = line + FauxScrollFrame_GetOffset (AuctionatorScrollFrame);

		local lineEntry = getglobal ("AuctionatorEntry"..line);

		lineEntry:SetID(dataOffset);

		if (dataOffset <= numrows and currentPane.hints[dataOffset]) then

			local data = currentPane.hints[dataOffset];

			local lineEntry_item_tag = "AuctionatorEntry"..line.."_PerItem_Price";

			local lineEntry_item		= getglobal(lineEntry_item_tag);
			local lineEntry_itemtext	= getglobal("AuctionatorEntry"..line.."_PerItem_Text");
			local lineEntry_text		= getglobal("AuctionatorEntry"..line.."_EntryText");
			local lineEntry_stack		= getglobal("AuctionatorEntry"..line.."_StackPrice");

			lineEntry_item:Show();
			lineEntry_itemtext:Hide();
			lineEntry_stack:SetText	("");

			Atr_SetMFcolor (lineEntry_item_tag, true);

			MoneyFrame_Update (lineEntry_item_tag, zc.round(data.price) );

			local text = data.text;
			if (data.volume) then
				text = text.." ("..ZT("trade volume")..": "..data.volume..")";
			end
			
			lineEntry_text:SetText (text);
			lineEntry_text:SetTextColor (0.8, 0.8, 1.0);

			lineEntry:Show();
		else
			lineEntry:Hide();
		end
	end

	Atr_HighlightEntry (currentPane.hintsIndex);
end


-----------------------------------------

function Atr_SetMFcolor (frameName, blue)

	local goldButton = getglobal(frameName.."GoldButton");
	local silverButton = getglobal(frameName.."SilverButton");
	local copperButton = getglobal(frameName.."CopperButton");

	if (blue) then
		goldButton:SetNormalFontObject(NumberFontNormalRightATRblue);
		silverButton:SetNormalFontObject(NumberFontNormalRightATRblue);
		copperButton:SetNormalFontObject(NumberFontNormalRightATRblue);
	else
		goldButton:SetNormalFontObject(NumberFontNormalRight);
		silverButton:SetNormalFontObject(NumberFontNormalRight);
		copperButton:SetNormalFontObject(NumberFontNormalRight);
	end
	
end


-----------------------------------------

function Atr_GetAuctionPrice (item)  -- itemName or itemID

	local itemName;
	
	if (type (item) == "number") then
		itemName = GetItemInfo (item);
	else
		itemName = item;
	end

	if (itemName == nil) then
		return nil;
	end

	if (gAtr_ScanDB[itemName]) then
		return gAtr_ScanDB[itemName];
	end
	
	return Atr_GetMostRecentSale (itemName);
end	

-----------------------------------------

function Atr_GetAuctionPriceAverage (itemName, maxSamples)
	-- Calcula la media de los últimos precios vistos en el historial de subastas
	if (itemName == nil) then
		return nil;
	end
	
	maxSamples = maxSamples or 10; -- Por defecto, últimos 10 precios
	
	local prices = {};
	
	if (AUCTIONATOR_PRICING_HISTORY and AUCTIONATOR_PRICING_HISTORY[itemName]) then
		for tag, hist in pairs (AUCTIONATOR_PRICING_HISTORY[itemName]) do
			if (tag ~= "is") then
				-- ParseHist devuelve: when, type, price
				local when, type, price = ParseHist (tag, hist);
				if (price and price > 0) then
					table.insert(prices, {when = when, price = price});
				end
			end
		end
	end
	
	-- Si no hay historial, intentar obtener del scan DB
	if (#prices == 0 and gAtr_ScanDB[itemName]) then
		return gAtr_ScanDB[itemName];
	end
	
	-- Si no hay suficientes datos
	if (#prices == 0) then
		return nil;
	end
	
	-- Ordenar por fecha (más reciente primero)
	table.sort(prices, function(a, b) return a.when > b.when end);
	
	-- Calcular media de los últimos N precios
	local sum = 0;
	local count = 0;
	for i = 1, math.min(#prices, maxSamples) do
		sum = sum + prices[i].price;
		count = count + 1;
	end
	
	if (count > 0) then
		return math.floor(sum / count);
	end
	
	return nil;
end

-----------------------------------------

local function Atr_CalcTextWid (price)

	local wid = 15;
	
	if (price > 9)			then wid = wid + 12;	end;
	if (price > 99)			then wid = wid + 44;	end;
	if (price > 999)		then wid = wid + 12;	end;
	if (price > 9999)		then wid = wid + 44;	end;
	if (price > 99999)		then wid = wid + 12;	end;
	if (price > 999999)		then wid = wid + 12;	end;
	if (price > 9999999)	then wid = wid + 12;	end;
	if (price > 99999999)	then wid = wid + 12;	end;
	
	return wid;
end

-----------------------------------------

local function Atr_CalcTTpadding (price1, price2)

	local padding = "";

	if (price1 and price2) then
		local vpwidth = Atr_CalcTextWid (price1);
		local apwidth = Atr_CalcTextWid (price2);

		local padlen = math.floor ((apwidth - vpwidth)/6);
		local k;
		
		for k = 1,padlen do
			padding = padding.." ";
		end
	end

	return padding;

end

-----------------------------------------

local UNCOMMON	= 2;
local RARE		= 3;
local EPIC		= 4;

local WEAPON = 1;
local ARMOR  = 2;

local LESSER_MAGIC		= 10938;
local GREATER_MAGIC		= 10939;
local STRANGE_DUST		= 10940;

local SMALL_GLIMMERING	= 10978;
local LESSER_ASTRAL		= 10998;

local GREATER_ASTRAL	= 11082;
local SOUL_DUST			= 11083;
local LARGE_GLIMMERING	= 11084;

local LESSER_MYSTIC		= 11134;
local GREATER_MYSTIC	= 11135;
local VISION_DUST		= 11137;
local SMALL_GLOWING		= 11138;
local LARGE_GLOWING		= 11139;

local LESSER_NETHER		= 11174;
local GREATER_NETHER	= 11175;
local DREAM_DUST		= 11176;
local SMALL_RADIANT		= 11177;
local LARGE_RADIANT		= 11178;

local SMALL_BRILLIANT	= 14343;
local LARGE_BRILLIANT	= 14344;

local LESSER_ETERNAL	= 16202;
local GREATER_ETERNAL	= 16203;
local ILLUSION_DUST		= 16204;

local NEXUS_CRYSTAL		= 20725;

local ARCANE_DUST		= 22445;
local GREATER_PLANAR	= 22446;
local LESSER_PLANAR		= 22447;
local SMALL_PRISMATIC	= 22448;
local LARGE_PRISMATIC	= 22449;
local VOID_CRYSTAL		= 22450;

local DREAM_SHARD		= 34052;
local SMALL_DREAM		= 34053;

local INFINITE_DUST		= 34054;
local GREATER_COSMIC	= 34055;
local LESSER_COSMIC		= 34056;
local ABYSS_CRYSTAL		= 34057;

local engDEnames = {};

engDEnames [LESSER_MAGIC]		= "Lesser Magic Essence";
engDEnames [GREATER_MAGIC]		= "Greater Magic Essence";
engDEnames [STRANGE_DUST]		= "Strange Dust";

engDEnames [SMALL_GLIMMERING]	= "Small Glimmering Shard";
engDEnames [LESSER_ASTRAL]		= "Lesser Astral Essence";

engDEnames [GREATER_ASTRAL]		= "Greater Astral Essence";
engDEnames [SOUL_DUST]			= "Soul Dust";
engDEnames [LARGE_GLIMMERING]	= "Large Glimmering Essence";

engDEnames [LESSER_MYSTIC]		= "Lesser Mystic Essence";
engDEnames [GREATER_MYSTIC]		= "Greater Mystic Essence";
engDEnames [VISION_DUST]		= "Vision Dust";
engDEnames [SMALL_GLOWING]		= "Small Glowing Shard";
engDEnames [LARGE_GLOWING]		= "Large Glowing Shard";

engDEnames [LESSER_NETHER]		= "Lesser Nether Essence";
engDEnames [GREATER_NETHER]		= "Greater Nether Essence";
engDEnames [DREAM_DUST]			= "Dream Dust";
engDEnames [SMALL_RADIANT]		= "Small Radiant";
engDEnames [LARGE_RADIANT]		= "Large Radiant";

engDEnames [SMALL_BRILLIANT]	= "Small Brilliant Shard";
engDEnames [LARGE_BRILLIANT]	= "Large Brilliant Shard";

engDEnames [LESSER_ETERNAL]		= "Lesser Eternal Essence";
engDEnames [GREATER_ETERNAL]	= "Greater Eternal Essence";
engDEnames [ILLUSION_DUST]		= "Illusion Dust";

engDEnames [NEXUS_CRYSTAL]		= "Nexus Crystal";

engDEnames [ARCANE_DUST]		= "Arcane Dust";
engDEnames [GREATER_PLANAR]		= "Greater Planar Essence";
engDEnames [LESSER_PLANAR]		= "Lesser Planar Essence";
engDEnames [SMALL_PRISMATIC]	= "Small Prismatic Shard";
engDEnames [LARGE_PRISMATIC]	= "Large Prismatic Shard";
engDEnames [VOID_CRYSTAL]		= "Void Crystal";

engDEnames [DREAM_SHARD]		= "Dream Shard";
engDEnames [SMALL_DREAM]		= "Small Dream Shard";

engDEnames [INFINITE_DUST]		= "Infinite Dust";
engDEnames [GREATER_COSMIC]		= "Greater Cosmic Essence";
engDEnames [LESSER_COSMIC]		= "Lesser Cosmic Essence";
engDEnames [ABYSS_CRYSTAL]		= "Abyss Crystal";


local dustsAndEssences = {};

tinsert (dustsAndEssences, LESSER_MAGIC)
tinsert (dustsAndEssences, GREATER_MAGIC)
tinsert (dustsAndEssences, STRANGE_DUST)

tinsert (dustsAndEssences, SMALL_GLIMMERING)
tinsert (dustsAndEssences, LESSER_ASTRAL)

tinsert (dustsAndEssences, GREATER_ASTRAL)
tinsert (dustsAndEssences, SOUL_DUST)
tinsert (dustsAndEssences, LARGE_GLIMMERING)

tinsert (dustsAndEssences, LESSER_MYSTIC)
tinsert (dustsAndEssences, GREATER_MYSTIC)
tinsert (dustsAndEssences, VISION_DUST)
tinsert (dustsAndEssences, SMALL_GLOWING)
tinsert (dustsAndEssences, LARGE_GLOWING)

tinsert (dustsAndEssences, LESSER_NETHER)
tinsert (dustsAndEssences, GREATER_NETHER)
tinsert (dustsAndEssences, DREAM_DUST)
tinsert (dustsAndEssences, SMALL_RADIANT)
tinsert (dustsAndEssences, LARGE_RADIANT)

tinsert (dustsAndEssences, SMALL_BRILLIANT)
tinsert (dustsAndEssences, LARGE_BRILLIANT)

tinsert (dustsAndEssences, LESSER_ETERNAL)
tinsert (dustsAndEssences, GREATER_ETERNAL)
tinsert (dustsAndEssences, ILLUSION_DUST)

tinsert (dustsAndEssences, NEXUS_CRYSTAL)

tinsert (dustsAndEssences, ARCANE_DUST)
tinsert (dustsAndEssences, GREATER_PLANAR)
tinsert (dustsAndEssences, LESSER_PLANAR)
tinsert (dustsAndEssences, SMALL_PRISMATIC)
tinsert (dustsAndEssences, LARGE_PRISMATIC)
tinsert (dustsAndEssences, VOID_CRYSTAL)

tinsert (dustsAndEssences, DREAM_SHARD)
tinsert (dustsAndEssences, SMALL_DREAM)

tinsert (dustsAndEssences, INFINITE_DUST)
tinsert (dustsAndEssences, GREATER_COSMIC)
tinsert (dustsAndEssences, LESSER_COSMIC)
tinsert (dustsAndEssences, ABYSS_CRYSTAL)

gAtr_dustCacheIndex = 1;
local dustCacheState = 0;

-----------------------------------------

function Atr_GetNextDustIntoCache()		-- make sure all the dusts and essences are in the local cache
										-- only needed after a major patch and a cache wipe
	if (gAtr_dustCacheIndex == 0) then
		return;
	end

	local itemID		= dustsAndEssences[gAtr_dustCacheIndex];
	local itemString	= "item:"..itemID..":0:0:0:0:0:0:0";
	
	local itemName, itemLink = GetItemInfo(itemString);
	
	if (itemLink == nil and dustCacheState == 0) then
		dustCacheState = 1;
		zc.md ("pulling "..itemString.." into the local cache");
		AtrScanningTooltip:SetHyperlink(itemString);
	end

	if (itemLink) then
		--zc.md (itemName.." is already in local cache");
		dustCacheState = 0;
		gAtr_dustCacheIndex = gAtr_dustCacheIndex + 1;
		
		if (gAtr_dustCacheIndex > #dustsAndEssences) then
			gAtr_dustCacheIndex = 0;		-- finished
		end
	end
end

-----------------------------------------

local deItemNames = {};

local function Atr_GetDEitemName (itemID)

	if (deItemNames[itemID] == nil) then
		local itemName = GetItemInfo (itemID);
		if (itemName == nil) then
			zc.md ("defaulting to english DE mat name: "..engDEnames [itemID]);
			return engDEnames [itemID];
		end
		
		deItemNames[itemID] = itemName;
	end
	
	return deItemNames[itemID];

end

-----------------------------------------

function Atr_GetAuctionPriceDE (itemID)  -- same as Atr_GetAuctionPrice but understands that some "lesser" essences are convertible with "greater"

	local lesserPrice;
	local greaterPrice;
	
	if (itemID == LESSER_COSMIC) then
		lesserPrice  = Atr_GetAuctionPrice (Atr_GetDEitemName (LESSER_COSMIC));
		greaterPrice = Atr_GetAuctionPrice (Atr_GetDEitemName (GREATER_COSMIC));
	end
	
	if (itemID == LESSER_PLANAR) then
		lesserPrice  = Atr_GetAuctionPrice (Atr_GetDEitemName (LESSER_PLANAR));
		greaterPrice = Atr_GetAuctionPrice (Atr_GetDEitemName (GREATER_PLANAR));
	end
	
	if (lesserPrice ~= nil and greaterPrice ~= nil and lesserPrice * 3 > greaterPrice) then
		return math.floor (greaterPrice / 3);
	end
	
	return Atr_GetAuctionPrice (Atr_GetDEitemName (itemID));
end

-----------------------------------------

local deTable = {};

-----------------------------------------

local function deKey (itemType, itemRarity)
	local s = tostring(itemType).."_"..itemRarity
	return s;
end

-----------------------------------------

local function DEtableInsert(t, info)

	local entry = {};

	local x, i, n;
	
	entry[1]	= info[1];
	entry[2]	= info[2];
	
	n = 3;
	
	for x = 3,#info,3 do
		local nums = info[x+1];
		if (type(nums) == "number") then
			entry[n]   = info[x];
			entry[n+1] = info[x+1];
			entry[n+2] = info[x+2];
			n = n + 3;
		else
			for i = nums[1],nums[2] do
				entry[n]   = info[x]/(nums[2]-nums[1]+1);
				entry[n+1] = i;
				entry[n+2] = info[x+2];
				n = n + 3;				
			end
		end
	end
	
	table.insert (t, entry);

end


-----------------------------------------

function Atr_InitDETable()		-- based on table at wowwiki.com/Disenchanting_tables


	-- UNCOMMON ARMOR

	deTable[deKey(ARMOR, UNCOMMON)] = {};
	
	local t = deTable[deKey(ARMOR, UNCOMMON)];
	
	
	DEtableInsert (t, {5, 15,		80, {1,2}, STRANGE_DUST,	20, {1,2}, LESSER_MAGIC});
	DEtableInsert (t, {16, 20,		75, {2,3}, STRANGE_DUST,	20, {1,2}, GREATER_MAGIC,	5, 1, SMALL_GLIMMERING});
	DEtableInsert (t, {21, 25,		75, {4,6}, STRANGE_DUST,	15, {1,2}, LESSER_ASTRAL,	10, 1, SMALL_GLIMMERING});
	DEtableInsert (t, {26, 30,		75, {1,2}, SOUL_DUST,		20, {1,2}, GREATER_ASTRAL,	5, 1, LARGE_GLIMMERING});
	DEtableInsert (t, {31, 35,		75, {2,5}, SOUL_DUST,		20, {1,2}, LESSER_MYSTIC,	5, 1, SMALL_GLOWING});
	DEtableInsert (t, {36, 40,		75, {1,2}, VISION_DUST,		20, {1,2}, GREATER_MYSTIC,	5, 1, LARGE_GLOWING});
	DEtableInsert (t, {41, 45,		75, {2,5}, VISION_DUST,		20, {1,2}, LESSER_NETHER,	5, 1, SMALL_RADIANT});
	DEtableInsert (t, {46, 50,		75, {1,2}, DREAM_DUST,		20, {1,2}, GREATER_NETHER,	5, 1, LARGE_RADIANT});
	DEtableInsert (t, {51, 55,		75, {2,5}, DREAM_DUST,		20, {1,2}, LESSER_ETERNAL,	5, 1, SMALL_BRILLIANT});
	DEtableInsert (t, {56, 60,		75, {1,2}, ILLUSION_DUST,	20, {1,2}, GREATER_ETERNAL,	5, 1, LARGE_BRILLIANT});
	DEtableInsert (t, {61, 65,		75, {2,5}, ILLUSION_DUST,	20, {2,3}, GREATER_ETERNAL,	5, 1, LARGE_BRILLIANT});
	DEtableInsert (t, {66, 80,		75, {1,3}, ARCANE_DUST,		22, {1,3}, LESSER_PLANAR,	3, 1, SMALL_PRISMATIC});
	DEtableInsert (t, {81, 99,		75, {2,3}, ARCANE_DUST,		22, {2,3}, LESSER_PLANAR,	3, 1, SMALL_PRISMATIC});
	DEtableInsert (t, {100, 120,	75, {2,5}, ARCANE_DUST,		22, {1,2}, GREATER_PLANAR,	3, 1, LARGE_PRISMATIC});
	DEtableInsert (t, {121, 151,	75, {1,3}, INFINITE_DUST,	22, {1,2}, LESSER_COSMIC,	3, 1, SMALL_DREAM});
	DEtableInsert (t, {152, 200,	75, {4,7}, INFINITE_DUST,	22, {1,2}, GREATER_COSMIC,	3, 1, DREAM_SHARD});


	-- UNCOMMON WEAPONS

	deTable[deKey(WEAPON, UNCOMMON)] = {};
	
	local t = deTable[deKey(WEAPON, UNCOMMON)];

	DEtableInsert (t, {6, 15,		20, {1,2}, STRANGE_DUST,	80, {1,2}, LESSER_MAGIC});
	DEtableInsert (t, {16, 20,		20, {2,3}, STRANGE_DUST,	75, {1,2}, GREATER_MAGIC,	5, 1, SMALL_GLIMMERING});
	DEtableInsert (t, {21, 25,		15, {4,6}, STRANGE_DUST,	75, {1,2}, LESSER_ASTRAL,	10, 1, SMALL_GLIMMERING});
	DEtableInsert (t, {26, 30,		20, {1,2}, SOUL_DUST,		75, {1,2}, GREATER_ASTRAL,	5, 1, LARGE_GLIMMERING});
	DEtableInsert (t, {31, 35,		20, {2,5}, SOUL_DUST,		75, {1,2}, LESSER_MYSTIC,	5, 1, SMALL_GLOWING});
	DEtableInsert (t, {36, 40,		20, {1,2}, VISION_DUST,		75, {1,2}, GREATER_MYSTIC,	5, 1, LARGE_GLOWING});
	DEtableInsert (t, {41, 45,		20, {2,5}, VISION_DUST,		75, {1,2}, LESSER_NETHER,	5, 1, SMALL_RADIANT});
	DEtableInsert (t, {46, 50,		20, {1,2}, DREAM_DUST,		75, {1,2}, GREATER_NETHER,	5, 1, LARGE_RADIANT});
	DEtableInsert (t, {51, 55,		22, {2,5}, DREAM_DUST,		75, {1,2}, LESSER_ETERNAL,	5, 1, SMALL_BRILLIANT});
	DEtableInsert (t, {56, 60,		22, {1,2}, ILLUSION_DUST,	75, {1,2}, GREATER_ETERNAL,	5, 1, LARGE_BRILLIANT});
	DEtableInsert (t, {61, 65,		22, {2,5}, ILLUSION_DUST,	75, {2,3}, GREATER_ETERNAL,	5, 1, LARGE_BRILLIANT});
	DEtableInsert (t, {66, 99,		22, {2,3}, ARCANE_DUST,		75, {2,3}, LESSER_PLANAR,	3, 1, SMALL_PRISMATIC});
	DEtableInsert (t, {100, 120,	22, {2,5}, ARCANE_DUST,		75, {1,2}, GREATER_PLANAR,	3, 1, LARGE_PRISMATIC});
	DEtableInsert (t, {121, 151,	22, {1,3}, INFINITE_DUST,	75, {1,2}, LESSER_COSMIC,	3, 1, SMALL_DREAM});
	DEtableInsert (t, {152, 200,	22, {4,7}, INFINITE_DUST,	75, {1,2}, GREATER_COSMIC,	3, 1, DREAM_SHARD});
	
	-- RARE ITEMS
	
	deTable[deKey(ARMOR, RARE)] = {};
	
	t = deTable[deKey(ARMOR, RARE)];

	DEtableInsert (t, {11, 25,		100, 1, SMALL_GLIMMERING});
	DEtableInsert (t, {26, 30,		100, 1, LARGE_GLIMMERING});
	DEtableInsert (t, {31, 35,		100, 1, SMALL_GLOWING});
	DEtableInsert (t, {36, 40,		100, 1, LARGE_GLOWING});
	DEtableInsert (t, {41, 45,		100, 1, SMALL_RADIANT});
	DEtableInsert (t, {46, 50,		100, 1, LARGE_RADIANT});
	DEtableInsert (t, {51, 55,		100, 1, SMALL_BRILLIANT});
	DEtableInsert (t, {56, 65,		99.5, 1, LARGE_BRILLIANT,		0.5, 1, NEXUS_CRYSTAL});
	DEtableInsert (t, {66, 99,		99.5, 1, SMALL_PRISMATIC,		0.5, 1, NEXUS_CRYSTAL});
	DEtableInsert (t, {100, 120,	99.5, 1, LARGE_PRISMATIC,		0.5, 1, VOID_CRYSTAL});
	DEtableInsert (t, {121, 164,	99.5, 1, SMALL_DREAM,			0.5, 1, ABYSS_CRYSTAL});
	DEtableInsert (t, {165, 999,	99.5, 1, DREAM_SHARD,			0.5, 1, ABYSS_CRYSTAL});

	deTable[deKey(WEAPON, RARE)] = deTable[deKey(ARMOR, RARE)];


	-- EPIC ITEMS
	
	deTable[deKey(ARMOR, EPIC)] = {};
	
	t = deTable[deKey(ARMOR, EPIC)];

	DEtableInsert (t, {40, 45,		100, {2,4}, SMALL_RADIANT});
	DEtableInsert (t, {46, 50,		100, {2,4}, LARGE_RADIANT});
	DEtableInsert (t, {51, 55,		100, {2,4}, SMALL_BRILLIANT});
	DEtableInsert (t, {56, 60,		100, 1, NEXUS_CRYSTAL});
--	DEtableInsert (t, {61, 80,  FILLED IN BELOW
	DEtableInsert (t, {95, 100,		100, {1,2}, VOID_CRYSTAL});
	DEtableInsert (t, {105, 164,	33.3, 1, VOID_CRYSTAL,	66.6, 2, VOID_CRYSTAL});
	DEtableInsert (t, {165, 200,	100, 1, ABYSS_CRYSTAL});
	DEtableInsert (t, {200, 999,	100, 1, ABYSS_CRYSTAL});

	deTable[deKey(WEAPON, EPIC)] = zc.CopyDeep (deTable[deKey(ARMOR, EPIC)]);	-- copy it this time because of differences

	DEtableInsert (deTable[deKey(ARMOR,  EPIC)], {61, 80,	50,   1, NEXUS_CRYSTAL, 	50,   2, NEXUS_CRYSTAL});
	DEtableInsert (deTable[deKey(WEAPON, EPIC)], {61, 80,	33.3, 1, NEXUS_CRYSTAL, 	66.6, 2, NEXUS_CRYSTAL});

end

-----------------------------------------

local function Atr_FindDEentry (itemType, itemRarity, itemLevel)

	local itemTypeNum = Atr_ItemType2AuctionClass (itemType);

	local t = deTable[deKey(itemTypeNum, itemRarity)];

	if (t) then
		local n;
		for n = 1, #t do
			
			local ta = t[n];
			
			if (itemLevel >= ta[1] and itemLevel <= ta[2]) then
				return ta;
			end
		end
	end


end

-----------------------------------------

local function Atr_AddDEDetailsToTip (tip, itemType, itemRarity, itemLevel, DEreqLevel)

	local ta = Atr_FindDEentry (itemType, itemRarity, itemLevel);

	if (ta) then
		local x;
		for x = 3,#ta,3 do
			local percent = math.floor (ta[x]*100) / 100;

			local deitem = Atr_GetDEitemName(ta[x+2]);
			if (deitem == nil) then
				deitem = "???";
			end

			tip:AddLine ("  |cFFFFFFFF"..percent.."%|r   "..ta[x+1].." "..deitem);
		end
	end

	tip:AddLine ("  |cFFAAAAFF"..ZT("Required DE skill level")..": "..DEreqLevel);
end

-----------------------------------------

function Atr_DumpDETable (itemType, itemRarity)

	local t = deTable[deKey(itemType, itemRarity)];

	if (t) then
		local n, x;
		for n = 1, #t do
			local ta = t[n];
			
			zc.msg_pink ("iLvl: "..ta[1].."-"..ta[2]);
			
			for x = 3,#ta,3 do
				zc.msg_pink ("   "..ta[x].."%  "..ta[x+1].."  "..Atr_GetDEitemName(ta[x+2]).."  ("..Atr_GetAuctionPrice (Atr_GetDEitemName(ta[x+2]))..")");
			end
		end
	end

end

-----------------------------------------

function Atr_CalcDisenchantPrice (itemType, itemRarity, itemLevel)

	if (Atr_IsWeaponType (itemType) or Atr_IsArmorType (itemType)) then
		if (itemRarity == UNCOMMON or itemRarity == RARE or itemRarity == EPIC) then

			local dePrice = 0;

			local ta = Atr_FindDEentry (itemType, itemRarity, itemLevel);
			if (ta) then
				local x;
				for x = 3,#ta,3 do
					local price = Atr_GetAuctionPriceDE (ta[x+2]);
					if (price) then
						dePrice = dePrice + (ta[x] * ta[x+1] * price);
					end
				end
			end

			return math.floor (dePrice/100);
		end
	end
	
	return nil;		-- can't be disenchanted
end

-----------------------------------------

local function ShowTipWithPricing (tip, link, num)

	if (link == nil) then
		return;
	end

--[[
	if (num == "tradeskill") then
	
		local skill = link;
	
		local n;
		for n = 1,GetTradeSkillNumReagents(skill) do
			local rname, _, rnum = GetTradeSkillReagentInfo(skill, n);
			local rlink = GetTradeSkillReagentItemLink (skill, n);
			zc.md (skill, rlink, rnum);
		end
	
		return;
	end
]]--

	local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, _, _, _, _, itemVendorPrice = GetItemInfo (link);

	local itemID = zc.ItemIDfromLink (link);
	itemID = tonumber(itemID);
	
	local vendorPrice	= 0;
	local auctionPrice	= 0;
	local dePrice		= nil;
	
	if (AUCTIONATOR_V_TIPS == 1) then vendorPrice	= itemVendorPrice; end;
	if (AUCTIONATOR_A_TIPS == 1) then auctionPrice	= Atr_GetAuctionPrice (itemName); end;
	if (AUCTIONATOR_D_TIPS == 1) then dePrice		= Atr_CalcDisenchantPrice (itemType, itemRarity, itemLevel); end;
	
	local xstring = "";
	local showStackPrices = IsShiftKeyDown();
	
	if (AUCTIONATOR_SHIFT_TIPS == 2) then
		showStackPrices = not IsShiftKeyDown();
	end

	if (num and showStackPrices) then
		if (auctionPrice)	then	auctionPrice = auctionPrice * num;	end;
		if (vendorPrice)	then	vendorPrice  = vendorPrice  * num;	end;
		if (dePrice)  		then	dePrice  	 = dePrice  * num;	end;
		xstring = "|cFFAAAAFF x"..num.."|r";
	end;

	if (vendorPrice == nil) then
		vendorPrice = 0;
	end

	-- vendor info

	if (AUCTIONATOR_V_TIPS == 1 and vendorPrice > 0) then
		local vpadding = Atr_CalcTTpadding (vendorPrice, auctionPrice);
		tip:AddDoubleLine (ZT("Vendor")..xstring, "|cFFFFFFFF"..zc.priceToMoneyString (vendorPrice))
	end
	
	-- auction info

	if (AUCTIONATOR_A_TIPS == 1) then
		
		local bonding = Atr_GetBonding(itemID);
		local isBOP   = (bonding == 1);
		local isQuest = (bonding == 4 or bonding == 5);
		
		if (isBOP) then
			tip:AddDoubleLine (ZT("Auction")..xstring, "|cFFFFFFFF"..ZT("BOP").."  ");		
		elseif (isQuest) then
			tip:AddDoubleLine (ZT("Auction")..xstring, "|cFFFFFFFF"..ZT("Quest Item").."  ");		
		elseif (auctionPrice ~= nil) then
			tip:AddDoubleLine (ZT("Auction")..xstring, "|cFFFFFFFF"..zc.priceToMoneyString (auctionPrice));
		else
			tip:AddDoubleLine (ZT("Auction")..xstring, "|cFFFFFFFF"..ZT("unknown").."  ");
		end
		
		-- Agregar media de precios de subasta
		if (not isBOP and not isQuest) then
			local avgPrice = Atr_GetAuctionPriceAverage(itemName, 10);
			if (avgPrice ~= nil) then
				local displayAvg = avgPrice;
				if (num and showStackPrices) then
					displayAvg = avgPrice * num;
				end
				tip:AddDoubleLine (ZT("Auction avg")..xstring, "|cFF88AAFF"..zc.priceToMoneyString (displayAvg));
			end
		end
	end
	
	-- disenchanting info

	if (AUCTIONATOR_D_TIPS == 1 and dePrice ~= nil) then
		if (dePrice > 0) then
			tip:AddDoubleLine (ZT("Disenchant")..xstring, "|cFFFFFFFF"..zc.priceToMoneyString(dePrice));
		else
			tip:AddDoubleLine (ZT("Disenchant")..xstring, "|cFFFFFFFF"..ZT("unknown").."  ");
		end
	end

	local showDetails = true;
	
	if (AUCTIONATOR_DE_DETAILS_TIPS == 1) then showDetails = IsShiftKeyDown(); end;
	if (AUCTIONATOR_DE_DETAILS_TIPS == 2) then showDetails = IsControlKeyDown(); end;
	if (AUCTIONATOR_DE_DETAILS_TIPS == 3) then showDetails = IsAltKeyDown(); end;
	if (AUCTIONATOR_DE_DETAILS_TIPS == 4) then showDetails = false; end;
	if (AUCTIONATOR_DE_DETAILS_TIPS == 5) then showDetails = true; end;
	
	if (showDetails and dePrice ~= nil) then
		Atr_AddDEDetailsToTip (tip, itemType, itemRarity, itemLevel, Atr_DEReqLevel(itemID));
	end

	tip:Show()

end

-----------------------------------------

-- Variables globales para el tooltip de crafteo
local AtrCraftingTooltip = nil;

-- Hooks originales del GameTooltip (simplificado)
-- local auctionator_orig_GameTooltip_OnHide = nil;

-- Función para hook del GameTooltip cuando se oculta (ya no se usa)
-- function auctionator_GameTooltip_OnHide(self)

-- Función para configurar los hooks del GameTooltip (ya no se usa)
-- function Atr_SetupTooltipHooks()

function Atr_ShowCraftingInfo(tip, skill, isReagent)
	-- Solo mostrar para el item principal de crafteo, no para los reagentes
	if not skill or skill == 0 or isReagent then
		return;
	end
	
	local materialCost, materialDetails = Atr_CalculateMaterialCost(skill);
	if not materialCost then
		return;
	end
	
	local numMade = GetTradeSkillNumMade(skill) or 1;
	local suggestedPrice = Atr_CalculateSuggestedPrice(materialCost, numMade);
	
	-- Añadir información de crafteo directamente al tooltip principal
	tip:AddLine(" ");
	tip:AddLine("|cFFFFAA00--- Información de Crafteo ---|r");
	
	-- Mostrar costo total de materiales
	tip:AddDoubleLine("|cFFFF8800Costo materiales:|r", "|cFFFFFFFF"..zc.priceToMoneyString(materialCost));
	
	-- Si se producen múltiples items, mostrar costo por unidad
	if numMade > 1 then
		local costPerUnit = materialCost / numMade;
		tip:AddDoubleLine("|cFFFF8800Costo por unidad:|r", "|cFFFFFFFF"..zc.priceToMoneyString(costPerUnit));
	end
	
	-- Mostrar precio sugerido
	if suggestedPrice then
		-- Para encantamientos, obtener el nombre del pergamino
		local itemLink = GetTradeSkillItemLink(skill);
		local itemName = nil;
		if itemLink then
			itemName = GetItemInfo(itemLink);
		end
		
		local isEnchanting = Atr_IsEnchantingRecipe(skill);
		if isEnchanting and itemName then
			local scrollName = Atr_GetEnchantScrollName(itemName);
			if scrollName then
				-- Obtener precio actual del pergamino en subasta
				local currentScrollPrice = Atr_GetAuctionPrice(scrollName);
				if currentScrollPrice and currentScrollPrice > 0 then
					tip:AddDoubleLine("|cFF88FF88Precio pergamino:|r", "|cFFFFFFFF"..zc.priceToMoneyString(currentScrollPrice));
					
					-- Mostrar comparación de beneficio
					local potentialProfit = currentScrollPrice - (materialCost / numMade);
					if potentialProfit > 0 then
						tip:AddDoubleLine("|cFF00FF00Beneficio:|r", "|cFF00FF00+"..zc.priceToMoneyString(potentialProfit));
					else
						tip:AddDoubleLine("|cFFFF4444Pérdida:|r", "|cFFFF4444"..zc.priceToMoneyString(math.abs(potentialProfit)));
					end
				else
					tip:AddDoubleLine("|cFF88FF88Precio sugerido:|r", "|cFF88FF88"..zc.priceToMoneyString(suggestedPrice));
				end
			end
		else
			tip:AddDoubleLine("|cFF88FF88Precio sugerido:|r", "|cFF88FF88"..zc.priceToMoneyString(suggestedPrice));
		end
	end
	
	-- Mostrar desglose de materiales
	local showDetailedBreakdown = IsShiftKeyDown();
	local maxMaterialsToShow = showDetailedBreakdown and #materialDetails or math.min(4, #materialDetails);
	
	if #materialDetails > 0 then
		tip:AddLine(" ");
		tip:AddLine("|cFFFFAA00Materiales:|r");
		
		for i = 1, maxMaterialsToShow do
			local material = materialDetails[i];
			if material and material.unitPrice > 0 then
				local materialLine = string.format("|cFFAAAAAA%dx %s|r", material.quantity, material.name);
				local priceLine = zc.priceToMoneyString(material.totalPrice);
				tip:AddDoubleLine(materialLine, "|cFFFFFFFF"..priceLine);
			end
		end
		
		-- Mostrar indicador si hay más materiales
		if not showDetailedBreakdown and #materialDetails > 4 then
			tip:AddLine("|cFFAAAAAA... y "..(#materialDetails - 4).." más (Shift)|r");
		elseif not showDetailedBreakdown then
			tip:AddLine("|cFFAAAAAA(Shift para detalles)|r");
		end
	end
	
	-- IMPORTANTE: Forzar que el tooltip se redimensione para mostrar todo el contenido
	if tip == GameTooltip then
		-- Forzar recalculación del tamaño del tooltip
		tip:Show();
		
		-- Verificar límites de pantalla después del redimensionado
		local screenWidth = UIParent:GetWidth();
		local screenHeight = UIParent:GetHeight();
		
		local tipLeft = tip:GetLeft() or 0;
		local tipTop = tip:GetTop() or 0;
		local tipWidth = tip:GetWidth() or 0;
		local tipHeight = tip:GetHeight() or 0;
		
		-- Reposicionar si se sale de la pantalla
		local needsRepositioning = false;
		local newX, newY = tipLeft, tipTop;
		
		-- Verificar límite derecho
		if tipLeft + tipWidth > screenWidth then
			newX = screenWidth - tipWidth - 10;
			needsRepositioning = true;
		end
		
		-- Verificar límite izquierdo
		if tipLeft < 0 then
			newX = 10;
			needsRepositioning = true;
		end
		
		-- Verificar límite inferior
		if tipTop - tipHeight < 0 then
			newY = tipHeight + 10;
			needsRepositioning = true;
		end
		
		-- Verificar límite superior
		if tipTop > screenHeight then
			newY = screenHeight - 10;
			needsRepositioning = true;
		end
		
		-- Reposicionar si es necesario
		if needsRepositioning then
			tip:ClearAllPoints();
			tip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", newX, newY);
		end
	end
end

-----------------------------------------

hooksecurefunc (GameTooltip, "SetBagItem",
	function(tip, bag, slot)
		local _, num = GetContainerItemInfo(bag, slot);
		ShowTipWithPricing (tip, GetContainerItemLink(bag, slot), num);
	end
);

hooksecurefunc (GameTooltip, "SetAuctionItem",
	function (tip, type, index)
		local _, _, num = GetAuctionItemInfo(type, index);
		ShowTipWithPricing (tip, GetAuctionItemLink(type, index), num);
	end
);

hooksecurefunc (GameTooltip, "SetAuctionSellItem",
	function (tip)
		local name, _, count = GetAuctionSellItemInfo();
		local __, link = GetItemInfo(name);
		ShowTipWithPricing (tip, link, num);
	end
);


hooksecurefunc (GameTooltip, "SetLootItem",
	function (tip, slot)
		if LootSlotIsItem(slot) then
			local link, _, num = GetLootSlotLink(slot);
			ShowTipWithPricing (tip, link, num);
		end
	end
);

hooksecurefunc (GameTooltip, "SetLootRollItem",
	function (tip, slot)
		local _, _, num = GetLootRollItemInfo(slot);
		ShowTipWithPricing (tip, GetLootRollItemLink(slot), num);
	end
);


hooksecurefunc (GameTooltip, "SetInventoryItem",
	function (tip, unit, slot)
		ShowTipWithPricing (tip, GetInventoryItemLink(unit, slot), GetInventoryItemCount(unit, slot));
	end
);

hooksecurefunc (GameTooltip, "SetGuildBankItem",
	function (tip, tab, slot)
		local _, num = GetGuildBankItemInfo(tab, slot);
		ShowTipWithPricing (tip, GetGuildBankItemLink(tab, slot), num);
	end
);

hooksecurefunc (GameTooltip, "SetTradeSkillItem",
	function (tip, skill, id)
		local link = GetTradeSkillItemLink(skill);
		local num  = GetTradeSkillNumMade(skill);
		local isReagent = false;
		
		if id then
			link = GetTradeSkillReagentItemLink(skill, id);
			num = select (3, GetTradeSkillReagentInfo(skill, id));
			isReagent = true;
		end

		ShowTipWithPricing (tip, link, num);
		
		-- Agregar información de crafteo solo para el item principal
		if not isReagent then
			Atr_ShowCraftingInfo(tip, skill, isReagent);
		end
	end
);

hooksecurefunc (GameTooltip, "SetTradePlayerItem",
	function (tip, id)
		local _, _, num = GetTradePlayerItemInfo(id);
		ShowTipWithPricing (tip, GetTradePlayerItemLink(id), num);
	end
);

hooksecurefunc (GameTooltip, "SetTradeTargetItem",
	function (tip, id)
		local _, _, num = GetTradeTargetItemInfo(id);
		ShowTipWithPricing (tip, GetTradeTargetItemLink(id), num);
	end
);

hooksecurefunc (GameTooltip, "SetQuestItem",
	function (tip, type, index)
		local _, _, num = GetQuestItemInfo(type, index);
		ShowTipWithPricing (tip, GetQuestItemLink(type, index), num);
	end
);

hooksecurefunc (GameTooltip, "SetQuestLogItem",
	function (tip, type, index)
		local num, _;
		if type == "choice" then
			_, _, num = GetQuestLogChoiceInfo(index);
		else
			_, _, num = GetQuestLogRewardInfo(index)
		end

		ShowTipWithPricing (tip, GetQuestLogItemLink(type, index), num);
	end
);

hooksecurefunc (GameTooltip, "SetInboxItem",
	function (tip, index, attachIndex)
		local _, _, num = GetInboxItem(index, attachIndex);
		ShowTipWithPricing (tip, GetInboxItemLink(index, attachIndex), num);
	end
);

hooksecurefunc (GameTooltip, "SetSendMailItem",
	function (tip, id)
		local name, _, num = GetSendMailItem(id)
		local name, link = GetItemInfo(name);
		ShowTipWithPricing (tip, link, num);
	end
);

hooksecurefunc (GameTooltip, "SetHyperlink",
	function (tip, itemstring, num)
		local name, link = GetItemInfo (itemstring);
		ShowTipWithPricing (tip, link, num);
	end
);

hooksecurefunc (ItemRefTooltip, "SetHyperlink",
	function (tip, itemstring)
		local name, link = GetItemInfo (itemstring);
		ShowTipWithPricing (tip, link);
	end
);

-----------------------------------------
-- Sistema de cálculo de costos de materiales para profesiones
-----------------------------------------

function Atr_CalculateMaterialCost(skill)
	-- Calcular el costo total de los materiales para una receta
	if not skill or skill == 0 then
		return nil, {};
	end
	
	local totalCost = 0;
	local materialDetails = {};
	local allMaterialsHavePrice = true;
	
	local numReagents = GetTradeSkillNumReagents(skill);
	if not numReagents or numReagents == 0 then
		return nil, {};
	end
	
	for i = 1, numReagents do
		local rname, _, rnum = GetTradeSkillReagentInfo(skill, i);
		if rname and rnum then
			local materialPrice = Atr_GetAuctionPrice(rname);
			
			if not materialPrice or materialPrice <= 0 then
				-- Si no tenemos precio de subasta, intentar conseguir precio de vendor
				local rlink = GetTradeSkillReagentItemLink(skill, i);
				if rlink then
					local _, _, _, _, _, _, _, _, _, _, itemVendorPrice = GetItemInfo(rlink);
					materialPrice = itemVendorPrice or 0;
				end
			end
			
			if materialPrice and materialPrice > 0 then
				local materialTotalCost = materialPrice * rnum;
				totalCost = totalCost + materialTotalCost;
				
				table.insert(materialDetails, {
					name = rname,
					quantity = rnum,
					unitPrice = materialPrice,
					totalPrice = materialTotalCost
				});
			else
				allMaterialsHavePrice = false;
				table.insert(materialDetails, {
					name = rname,
					quantity = rnum,
					unitPrice = 0,
					totalPrice = 0
				});
			end
		end
	end
	
	if not allMaterialsHavePrice then
		return nil, materialDetails;
	end
	
	return totalCost, materialDetails;
end

-----------------------------------------

function Atr_CalculateSuggestedPrice(materialCost, numMade)
	-- Calcular precio sugerido basado en costo de materiales
	if not materialCost or materialCost <= 0 or not numMade or numMade <= 0 then
		return nil;
	end
	
	-- Obtener margen de beneficio configurado (por defecto 20%)
	local profitMargin = 0.20;
	if AUCTIONATOR_SAVEDVARS and AUCTIONATOR_SAVEDVARS.CRAFT_PROFIT_MARGIN then
		profitMargin = AUCTIONATOR_SAVEDVARS.CRAFT_PROFIT_MARGIN / 100;
	end
	
	-- Calcular costo por unidad producida
	local costPerUnit = materialCost / numMade;
	
	-- Aplicar margen de beneficio
	local suggestedPrice = costPerUnit * (1 + profitMargin);
	
	-- Redondear a un valor razonable
	suggestedPrice = math.ceil(suggestedPrice);
	
	return suggestedPrice;
end

-----------------------------------------

function Atr_GetEnchantScrollName(enchantName)
	-- Convertir nombre de encantamiento a nombre de pergamino
	-- Esta función mapea nombres de encantamientos a sus pergaminos correspondientes
	
	if not enchantName then
		return nil;
	end
	
	-- Tabla de mapeo de encantamientos conocidos a pergaminos
	-- Se puede expandir según sea necesario
	local enchantScrollMap = {
		-- Ejemplos para encantamientos comunes
		["Enchant Weapon - Minor Beastslayer"] = "Pergamino de Encantamiento de arma: Verdugo de bestias menor",
		["Enchant Bracer - Minor Health"] = "Pergamino de Encantamiento de brazal: Salud menor",
		["Enchant Chest - Minor Health"] = "Pergamino de Encantamiento de pecho: Salud menor",
		["Enchant Weapon - Minor Striking"] = "Pergamino de Encantamiento de arma: Golpe menor",
		["Enchant 2H Weapon - Minor Impact"] = "Pergamino de Encantamiento de arma de 2 manos: Impacto menor",
		["Enchant Bracer - Minor Deflection"] = "Pergamino de Encantamiento de brazal: Desviación menor",
		["Enchant Chest - Minor Absorption"] = "Pergamino de Encantamiento de pecho: Absorción menor",
		-- Agregar más mapeos según sea necesario
	};
	
	-- Buscar mapeo directo
	if enchantScrollMap[enchantName] then
		return enchantScrollMap[enchantName];
	end
	
	-- Si no hay mapeo directo, intentar generar el nombre del pergamino
	-- Patrón común: "Pergamino de " + nombre del encantamiento
	local scrollName = "Pergamino de " .. enchantName;
	
	return scrollName;
end

-----------------------------------------

function Atr_IsEnchantingRecipe(skill)
	-- Verificar si una receta es de encantamiento
	if not skill then
		return false;
	end
	
	-- Verificar si estamos en la ventana de encantamiento
	local tradeskillTitle = GetTradeSkillLine();
	if tradeskillTitle and string.find(string.lower(tradeskillTitle), "encant") then
		return true;
	end
	
	return false;
end










