local addonName, addonTable = ...; 
local zc = addonTable.zc;

KM_NULL_STATE	= 0;
KM_PREQUERY		= 1;
KM_INQUERY		= 2;
KM_POSTQUERY	= 3;
KM_ANALYZING	= 4;
KM_SETTINGSORT	= 5;

local AUCTION_CLASS_WEAPON = 1;
local AUCTION_CLASS_ARMOR  = 2;

local gAllScans = {};

local BIGNUM = 999999999999;

local ATR_SORTBY_NAME_ASC = 0;
local ATR_SORTBY_NAME_DES = 1;
local ATR_SORTBY_PRICE_ASC = 2;
local ATR_SORTBY_PRICE_DES = 3;

-----------------------------------------

AtrScan = {};
AtrScan.__index = AtrScan;

-----------------------------------------

AtrSearch = {};
AtrSearch.__index = AtrSearch;

-----------------------------------------

function Atr_NewSearch (itemName, exact, rescanThreshold, callback)

	local srch = {};
	setmetatable (srch, AtrSearch);
	srch:Init (itemName, exact, rescanThreshold, callback);

	return srch;
end

-----------------------------------------

function AtrSearch:Init (searchText, exact, rescanThreshold, callback)

	if (searchText == nil) then
		searchText = "";
	end

	self.origSearchText = searchText;
	
	if (not exact) then
		if (zc.StringStartsWith (searchText, "\"") and zc.StringEndsWith (searchText, "\"")) then
			searchText = string.sub (searchText, 2, searchText:len()-1);
			exact = true;
		end
	end		

	self.searchText			= searchText;
	self.exact				= exact;
	self.processing_state	= KM_NULL_STATE
	self.current_page		= -1
	self.items				= {};
	self.query				= Atr_NewQuery();
	self.sortedScans		= nil;
	self.sortHow			= ATR_SORTBY_PRICE_ASC;
	self.callback			= callback;
	
	if (exact) then	

		if (rescanThreshold and rescanThreshold > 0) then
			local scan = Atr_FindScan (searchText);
			if (scan and (time() - scan.whenScanned) <= rescanThreshold) then
				self.items[searchText] = scan;
			end
		end
		
		if (not self.items[searchText]) then		
			self.items[searchText] = Atr_FindScanAndInit (searchText);
		end
		
	end
	
end

-----------------------------------------

function Atr_FindScanAndInit (itemName)

	return Atr_FindScan (itemName, true);
end

-----------------------------------------

function Atr_FindScan (itemName, init)

	if (itemName == nil or itemName == "") then
		itemName = "nil";
	end

	local itemNameLC = string.lower (itemName);

	if (gAllScans[itemNameLC] == nil) then

		local scn = {};
		setmetatable (scn, AtrScan);
		scn:Init (itemName);

		gAllScans[itemNameLC] = scn;
	elseif (init) then
		gAllScans[itemNameLC]:Init (itemName);
	end
	
	return gAllScans[itemNameLC];
end

-----------------------------------------

function Atr_ClearScanCache ()

--	zc.msg_red ("Clearing Scan Cache");

	for a,v in pairs (gAllScans) do
		if (a ~= "nil") then
			gAllScans[a] = nil;
		end
	end

end

-----------------------------------------

function AtrScan:Init (itemName)
	self.itemName			= itemName;
	self.itemLink			= nil;
	self.scanData			= {};
	self.sortedData			= {};
	self.whenScanned		= 0;
	self.lowprices			= {BIGNUM, BIGNUM, BIGNUM};
	self.absoluteBest		= nil;
	self.itemClass			= 0;
	self.itemSubclass		= 0;
	self.yourBestPrice		= nil;
	self.yourWorstPrice		= nil;
	self.numYourSingletons	= 0;
	self.itemTextColor 		= { 1.0, 1.0, 1.0 };
	self.searchWasExact		= false;
	
	self:UpdateItemLink (Atr_GetItemLink (itemName));
end

-----------------------------------------

function AtrScan:UpdateItemLink (itemLink)

	self.itemLink = itemLink;
	
	if (itemLink) then
	
		Atr_AddToItemLinkCache (self.itemName, itemLink);

		local _, _, quality, _, _, sType, sSubType = GetItemInfo(itemLink);

		self.itemQuality	= quality;
		self.itemClass		= Atr_ItemType2AuctionClass (sType);
		self.itemSubclass	= Atr_SubType2AuctionSubclass (self.itemClass, sSubType);	

		self.itemTextColor = { 1.0, 1.0, 1.0 };

		if (quality == 0)	then	self.itemTextColor = { 0.6, 0.6, 0.6 };	end
		if (quality == 2)	then	self.itemTextColor = { 0.2, 1.0, 0.0 };	end
		if (quality == 3)	then	self.itemTextColor = { 0.0, 0.5, 1.0 };	end
		if (quality == 4)	then	self.itemTextColor = { 0.7, 0.3, 1.0 };	end
	end

end


-----------------------------------------

function AtrSearch:NumScans()

	if (self.sortedScans) then
		return #self.sortedScans;
	end

	local count = 0;
	for name,scn in pairs (self.items) do
		count = count + 1;
	end

	return count;
end

-----------------------------------------

function AtrSearch:NumSortedScans()

	if (self.sortedScans) then
		return #self.sortedScans;
	end

	return 0;
end

-----------------------------------------

function AtrSearch:GetFirstScan()

	if (self.sortedScans) then
		return self.sortedScans[1];
	end

	for name,scn in pairs (self.items) do
		return scn;
	end
	
	return nil;

end


-----------------------------------------

function AtrSearch:Start ()

	if (self.searchText == "") then
		return;
	end
	
	if (Atr_IsCompoundSearch (self.searchText)) then
			
		local _, itemClass = Atr_ParseCompoundSearch (self.searchText);
	
		if (itemClass == 0) then
			Atr_Error_Display (ZT("The first part of this compound\n\nsearch is not a valid category."));
			return;
		end

		self.sortHow = ATR_SORTBY_PRICE_DES;

	end
	
	self.processing_state = KM_SETTINGSORT;
	
	SortAuctionClearSort ("list");

	BrowseName:SetText (self.searchText);		-- not necessary but nice when user switches to Browse tab

	self.current_page		= 0;
	self.processing_state	= KM_PREQUERY;

	self:Continue();
	
end

-----------------------------------------

function AtrSearch:Abort ()

	if (self.processing_state == KM_NULL_STATE) then
		return;
	end

	self.processing_state = KM_NULL_STATE;
	self:Init();
end

-----------------------------------------

function AtrSearch:CheckForDuplicatePage ()

	local isDup = self.query:CheckForDuplicatePage(self.current_page);

	if (isDup) then
--		zc.msg_red ("DUPLICATE PAGE FOUND: ", "  current_page: ", self.current_page, "  numDupPages: ", self.query.numDupPages);

		self.current_page	= self.current_page - 1;   -- requery the page
		
		self.processing_state = KM_PREQUERY;
	end
		
	return isDup;
end


-----------------------------------------

function AtrSearch:AnalyzeResultsPage()

	self.processing_state = KM_ANALYZING;

	if (self.query.numDupPages > 10) then 	 -- hopefully this will never happen but need check to avoid looping
		return true;						 -- done
	end


	local numBatchAuctions, totalAuctions = GetNumAuctionItems("list");

	if (self.current_page == 1 and totalAuctions > 2000) then -- give Blizz servers a break
		Atr_Error_Display (ZT("Too many results\n\nPlease narrow your search"));
		return true;  -- done
	end

	if (totalAuctions >= 50) then
		Atr_SetMessage (string.format (ZT("Scanning auctions: page %d"), self.current_page));
	end

	-- analyze

	local numNilOwners = 0;

	if (numBatchAuctions > 0) then

		local x;

		for x = 1, numBatchAuctions do

			local name, texture, count, quality, canUse, level, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, owner = GetAuctionItemInfo("list", x);

			if (owner == nil) then
				numNilOwners = numNilOwners + 1;
			end
			
			local exactMatch = zc.StringSame (name, self.searchText);

			if (exactMatch or not self.exact) then

				if (self.items[name] == nil) then
					self.items[name] = Atr_FindScanAndInit (name);
				end
				
				local curpage = (tonumber(self.current_page)-1);

				local scn = self.items[name];

				scn:AddScanItem (name, count, buyoutPrice, owner, 1, curpage);
				
				if (scn.itemLink == nil or self.itemClass == nil) then
					scn:UpdateItemLink (GetAuctionItemLink("list", x));
				end

				if (self.callback) then
					self.callback (x, numBatchAuctions, count, buyoutPrice, owner);
				end
				
			end
		end
	end
	
	local done = (numBatchAuctions < 50);

	if (not done) then
		self.processing_state = KM_PREQUERY;
	end
	
	return done;
end

-----------------------------------------

function AtrScan:AddScanItem (name, stackSize, buyoutPrice, owner, numAuctions, curpage)

	local sd = {};
	local i;

	if (numAuctions == nil) then
		numAuctions = 1;
	end

	for i = 1, numAuctions do
		sd["stackSize"]		= stackSize;
		sd["buyoutPrice"]	= buyoutPrice;
		sd["owner"]			= owner;
		sd["pagenum"]		= curpage;

		tinsert (self.scanData, sd);
		
		local itemPrice = math.floor (buyoutPrice / stackSize);

		Atr_AddToLowPrices (self.lowprices, itemPrice);
	end

end


-----------------------------------------

function AtrScan:AddSDXToScan (price, owner, volume)	-- helper function for AddExternalDataToScan

	local sd = {};

	if (price and price > 0) then
		sd["stackSize"]		= 1;
		sd["buyoutPrice"]	= price;
		sd["owner"]			= owner;

		if (volume) then
			sd["volume"] = volume;
		end

		tinsert (self.scanData, sd);
	end
	
end

-----------------------------------------

function AtrScan:AddExternalDataToScan ()

	if (self.itemLink == nil) then
		return;
	end

	-- Wowecon

	if (Wowecon and Wowecon.API) then
	
		local priceG, volG = Wowecon.API.GetAuctionPrice_ByLink (self.itemLink, Wowecon.API.GLOBAL_PRICE)
		local priceS, volS = Wowecon.API.GetAuctionPrice_ByLink (self.itemLink, Wowecon.API.SERVER_PRICE)

		self:AddSDXToScan (priceG, "__wowEconG", volG);
		self:AddSDXToScan (priceS, "__wowEconS", volS);
		
	end
	
	-- GoingPrice Wowhead
	
	local id = zc.ItemIDfromLink (self.itemLink);
	
	id = tonumber(id);

	if (GoingPrice_Wowhead_Data and GoingPrice_Wowhead_Data[id] and GoingPrice_Wowhead_SV._index) then
		local index = GoingPrice_Wowhead_SV._index["Buyout price"];

		if (index ~= nil) then
			local price = GoingPrice_Wowhead_Data[id][index];
		
			self:AddSDXToScan (price, "__wowHead");
		end
	end

	-- GoingPrice Allakhazam
	
	if (GoingPrice_Allakhazam_Data and GoingPrice_Allakhazam_Data[id] and GoingPrice_Allakhazam_SV._index) then
		local index = GoingPrice_Allakhazam_SV._index["Median"];

		if (index ~= nil) then
			local price = GoingPrice_Allakhazam_Data[id][index];
		
			self:AddSDXToScan (price, "__allakhazam");
		end
	end

	-- most recent historical price
	
	local price = Atr_Process_Historydata();
	if (price ~= nil) then
		self:AddSDXToScan (price, "__atrLast");
	end

end

-----------------------------------------

function AtrScan:SubtractScanItem (name, stackSize, buyoutPrice)

	local sd;
	local i;

	for i,sd in ipairs (self.scanData) do
		
		if (sd.stackSize == stackSize and sd.buyoutPrice == buyoutPrice) then
			
			tremove (self.scanData, i);
			return;
		end
	end

end

-----------------------------------------

function Atr_IsCompoundSearch (searchString)
	
	return zc.StringContains (searchString, ">") or zc.StringContains (searchString, "/");
end

-----------------------------------------

function Atr_ParseCompoundSearch (searchString)

	local delim = "/";

	if (zc.StringContains (searchString, ">")) then
		delim = ">";
	end

	local tbl	= { strsplit (delim, searchString) };
	
	local queryString	= "";
	local itemClass		= 0;
	local itemSubclass	= 0;
	local minLevel		= nil;
	local maxLevel		= nil;
	local prevWasItemClass;
	local n;
	
	for n = 1,#tbl do
		local s = tbl[n];

		local handled = false;

		if (not handled and tonumber(s)) then
			if (minLevel == nil) then
				minLevel = tonumber(s);
			elseif (maxLevel == nil) then
				maxLevel = tonumber(s);
			end
			
			handled = true;
			prevWasItemClass = false;
		end
		
		if (not handled and prevWasItemClass and itemSubclass == 0) then
			itemSubclass = Atr_SubType2AuctionSubclass (itemClass, s);
			if (itemSubclass > 0) then
				handled = true;
				prevWasItemClass = false;
			end
		end
		
		if (not handled and itemClass == 0) then
			itemClass = Atr_ItemType2AuctionClass (s);
			if (itemClass > 0) then
				prevWasItemClass = true;
				handled = true;
			end
		end
		
		if (not handled) then
			queryString = s;
			handled = true;
		end
	end	

	return queryString, itemClass, itemSubclass, minLevel, maxLevel;
end

-----------------------------------------

function AtrSearch:Continue()

	if (CanSendAuctionQuery()) then

		self.processing_state = KM_IN_QUERY;

		local queryString = self.searchText;

--	zc.md (queryString.."  page:"..self.current_page);
		
		local itemClass		= 0;
		local itemSubclass	= 0;
		local minLevel		= nil;
		local maxLevel		= nil;
		
		if (self.exact) then
			local scn = self:GetFirstScan();
			itemClass		= scn.itemClass;
			itemSubclass	= scn.itemSubclass;
		end

		if (Atr_IsCompoundSearch(queryString)) then
		
			queryString, itemClass, itemSubclass, minLevel, maxLevel = Atr_ParseCompoundSearch (queryString);
		
		end

		queryString = zc.UTF8_Truncate (queryString,63);	-- attempting to reduce number of disconnects

		QueryAuctionItems (queryString, minLevel, maxLevel, nil, itemClass, itemSubclass, self.current_page, nil, nil);

		self.query_sent_when	= gAtr_ptime;
		self.processing_state	= KM_POSTQUERY;
		self.current_page		= self.current_page + 1;
	end

end

-----------------------------------------

local gSortScansBy;

-----------------------------------------

local function Atr_SortScans (x, y)

	if (gSortScansBy == ATR_SORTBY_NAME_ASC) then		return string.lower (x.itemName) < string.lower (y.itemName);	end
	if (gSortScansBy == ATR_SORTBY_NAME_DES) then		return string.lower (x.itemName) > string.lower (y.itemName);	end

	local xprice = 0;
	local yprice = 0;
	
	if (x.absoluteBest) then	xprice = zc.round(x.absoluteBest.buyoutPrice/x.absoluteBest.stackSize);		end;
	if (y.absoluteBest) then	yprice = zc.round(y.absoluteBest.buyoutPrice/y.absoluteBest.stackSize);		end;
	
	if (gSortScansBy == ATR_SORTBY_PRICE_ASC) then		return xprice < yprice;		end
	if (gSortScansBy == ATR_SORTBY_PRICE_DES) then		return xprice > yprice;		end

end

-----------------------------------------

function AtrSearch:Finish()

	local finishTime = time();
	
	self.processing_state	= KM_NULL_STATE;
	self.current_page		= -1;
	self.query_sent_when	= nil;
	
	self.sortedScans = nil;
	
	local wasExactSearch = (self:NumScans() == 1);		-- search returned only 1 item
	
	local x = 1;
	self.sortedScans = {};
	
	for name,scn in pairs (self.items) do
	
		self.sortedScans[x] = scn;
		x = x + 1;
		
		scn.whenScanned		= finishTime;
		scn.searchWasExact	= wasExactSearch;

		scn:CondenseAndSort ();

		-- update the fullscan DB
		
		local newprice = Atr_CalcNewDBprice (scn.itemName, scn.lowprices);
		
		if (newprice > 0) then
			if (scn.itemQuality + 1 >= AUCTIONATOR_SCAN_MINLEVEL) then
				gAtr_ScanDB[scn.itemName] = newprice;
			end
		end
	end
	
	Atr_ClearBrowseListings();
	
	gSortScansBy = self.sortHow;
	table.sort (self.sortedScans, Atr_SortScans);
	
end

-----------------------------------------

function AtrSearch:ClickPriceCol()

	if (self.sortHow == ATR_SORTBY_PRICE_ASC) then
		self.sortHow = ATR_SORTBY_PRICE_DES;
	else
		self.sortHow = ATR_SORTBY_PRICE_ASC;
	end

	gSortScansBy = self.sortHow;
	table.sort (self.sortedScans, Atr_SortScans);

end

-----------------------------------------

function AtrSearch:ClickNameCol()

	if (self.sortHow == ATR_SORTBY_NAME_ASC) then
		self.sortHow = ATR_SORTBY_NAME_DES;
	else
		self.sortHow = ATR_SORTBY_NAME_ASC;
	end

	gSortScansBy = self.sortHow;
	table.sort (self.sortedScans, Atr_SortScans);
end

-----------------------------------------

function AtrSearch:UpdateArrows()

	Atr_Col1_Heading_ButtonArrow:Hide();
	Atr_Col3_Heading_ButtonArrow:Hide();
	
	if (self.sortHow == ATR_SORTBY_PRICE_ASC) then
		Atr_Col1_Heading_ButtonArrow:Show();
		Atr_Col1_Heading_ButtonArrow:SetTexCoord(0, 0.5625, 0, 1.0);
	elseif (self.sortHow == ATR_SORTBY_PRICE_DES) then
		Atr_Col1_Heading_ButtonArrow:Show();
		Atr_Col1_Heading_ButtonArrow:SetTexCoord(0, 0.5625, 1.0, 0);
	elseif (self.sortHow == ATR_SORTBY_NAME_ASC) then
		Atr_Col3_Heading_ButtonArrow:Show();
		Atr_Col3_Heading_ButtonArrow:SetTexCoord(0, 0.5625, 0, 1.0);
	elseif (self.sortHow == ATR_SORTBY_NAME_DES) then
		Atr_Col3_Heading_ButtonArrow:Show();
		Atr_Col3_Heading_ButtonArrow:SetTexCoord(0, 0.5625, 1.0, 0);
	end
end

-----------------------------------------

function Atr_ClearBrowseListings()
	
	local start = time();

	while (time() - start < 5) do
	
		if (CanSendAuctionQuery()) then
			QueryAuctionItems("xyzzy", 43, 43, 0, 7, 0);
			break;
		end
	end

end

-----------------------------------------

function Atr_SortAuctionData (x, y)

	return x.itemPrice < y.itemPrice;

end

-----------------------------------------

function AtrScan:CondenseAndSort ()

	----- Condense the scan data into a table that has only a single entry per stacksize/price combo

	self.sortedData	= {};

	local i,sd;
	local conddata = {};

	for i,sd in ipairs (self.scanData) do

		local ownerCode = "x";
		local dataType  = "n";		-- normal
		
		if (sd.owner == UnitName("player")) then
			ownerCode = "y";
--		elseif (Atr_IsMyToon (sd.owner)) then
--			ownerCode = sd.owner;
		elseif (sd.owner == "__wowEconG") then
			dataType = "eg";
		elseif (sd.owner == "__wowEconS") then
			dataType = "es";
		elseif (sd.owner == "__wowHead") then
			dataType = "h";
		elseif (sd.owner == "__allakhazam") then
			dataType = "k";
		elseif (sd.owner == "__atrLast") then
			dataType = "a";
		end

		local key = "_"..sd.stackSize.."_"..sd.buyoutPrice.."_"..ownerCode..dataType;

		if (conddata[key]) then
			conddata[key].count		= conddata[key].count + 1;
			conddata[key].minpage 	= zc.Min (conddata[key].minpage, sd.pagenum);
			conddata[key].maxpage 	= zc.Max (conddata[key].maxpage, sd.pagenum);
		else
			local data = {};

			data.stackSize 		= sd.stackSize;
			data.buyoutPrice	= sd.buyoutPrice;
			data.itemPrice		= sd.buyoutPrice / sd.stackSize;
			data.minpage		= sd.pagenum;
			data.maxpage		= sd.pagenum;
			data.count			= 1;
			data.type			= dataType;
			data.yours			= (ownerCode == "y");
			
			if (ownerCode ~= "x" and ownerCode ~= "y") then
				data.altname = ownerCode;
			end
			
			if (sd.volume) then
				data.volume = sd.volume;
			end
			
			conddata[key] = data;
		end

	end

	----- create a table of these entries

	local n = 1;

	local i, v;

	for i,v in pairs (conddata) do
		self.sortedData[n] = v;
		n = n + 1;
	end

	-- sort the table by itemPrice

	table.sort (self.sortedData, Atr_SortAuctionData);

	-- analyze and store some info about the data

	self:AnalyzeSortData ();

end

-----------------------------------------

function AtrScan:AnalyzeSortData ()

	self.absoluteBest			= nil;
	self.bestPrices				= {};		-- a table with one entry per stacksize that is the cheapest auction for that particular stacksize
	self.numMatches				= 0;
	self.numMatchesWithBuyout	= 0;
	self.hasStack				= false;
	self.yourBestPrice			= nil;
	self.yourWorstPrice			= nil;
	self.numYourSingletons		= 0;

	local j, sd;

	----- find the best price per stacksize and overall -----

	for j,sd in ipairs(self.sortedData) do

		if (sd.type == "n") then

			self.numMatches = self.numMatches + 1;

			if (sd.itemPrice > 0) then

				self.numMatchesWithBuyout = self.numMatchesWithBuyout + 1;

				if (self.bestPrices[sd.stackSize] == nil or self.bestPrices[sd.stackSize].itemPrice >= sd.itemPrice) then
					self.bestPrices[sd.stackSize] = sd;
				end

				if (self.absoluteBest == nil or self.absoluteBest.itemPrice > sd.itemPrice) then
					self.absoluteBest = sd;
				end
				
				if (sd.yours) then
					if (self.yourBestPrice == nil or self.yourBestPrice > sd.itemPrice) then
						self.yourBestPrice = sd.itemPrice;
					end
					
					if (self.yourWorstPrice == nil or self.yourWorstPrice < sd.itemPrice) then
						self.yourWorstPrice = sd.itemPrice;
					end
					
					if (sd.stackSize == 1) then
						self.numYourSingletons = self.numYourSingletons + sd.count;
					end
				end
			end

			if (sd.stackSize > 1) then
				self.hasStack = true;
			end
		end
	end
end

-----------------------------------------

function AtrScan:FindInSortedData (stackSize, buyoutPrice)
	local j = 1;
	for j = 1,#self.sortedData do
		sd = self.sortedData[j];
		if (sd.stackSize == stackSize and sd.buyoutPrice == buyoutPrice and sd.yours) then
			return j;
		end
	end
	
	return 0;
end


-----------------------------------------

function AtrScan:FindMatchByStackSize (stackSize)

	local index = nil;

	local basedata = self.absoluteBest;

	if (self.bestPrices[stackSize]) then
		basedata = self.bestPrices[stackSize];
	end

	local numrows = #self.sortedData;

	local n;

	for n = 1,numrows do

		local data = self.sortedData[n];

		if (basedata and data.itemPrice == basedata.itemPrice and data.stackSize == basedata.stackSize and data.yours == basedata.yours) then
			index = n;
			break;
		end
	end

	return index;
	
end

-----------------------------------------

function AtrScan:FindMatchByYours ()

	local index = nil;

	local j;
	for j = 1,#self.sortedData do
		sd = self.sortedData[j];
		if (sd.yours) then
			index = j;
			break;
		end
	end

	return index;

end

-----------------------------------------

function AtrScan:FindCheapest ()

	local index = nil;

	local j;
	for j = 1,#self.sortedData do
		sd = self.sortedData[j];
		if (sd.itemPrice > 0) then
			index = j;
			break;
		end
	end

	return index;

end


-----------------------------------------

function AtrScan:GetNumAvailable ()

	local num = 0;

	local j, data;
	for j = 1,#self.sortedData do

		data = self.sortedData[j];
		num = num + (data.count * data.stackSize);
	end
	
	return num;
end

-----------------------------------------

function AtrScan:IsNil ()

	if (self.itemName == nil or self.itemName == "" or self.itemName == "nil") then
		return true;
	end
	
	return false;
end

-----------------------------------------

ATR_FS_NULL			= 0;
ATR_FS_STARTED		= 1;
ATR_FS_ANALYZING	= 2;
ATR_FS_CLEANING_UP	= 3;
ATR_FS_WAITING		= 4;

gAtr_FullScanState = ATR_FS_NULL;
gAtr_FullScan_CurrentPage = 0;
gAtr_FullScan_TotalPages = 0;
gAtr_FullScan_AllData = {};
gAtr_FullScan_StartTime = 0;
gAtr_FullScan_LastQueryTime = 0;
gAtr_FullScan_PageDelay = 0.4; -- Delay base entre páginas (segundos)
gAtr_FullScan_NextQueryTime = 0;
gAtr_FullScan_ScanTime = 0;


-----------------------------------------

function Atr_GetDBsize()

	local n = 0;
	local a,v;

	for a,v in pairs (gAtr_ScanDB) do
		n = n + 1;
	end
	
	return n;
end

-----------------------------------------

local gNumAdded, gNumUpdated;

-----------------------------------------

function Atr_FullScanStart()

	local canQuery,canQueryAll = CanSendAuctionQuery();
	
	-- Verificar si hay limitación de tiempo
	local timeBlocked = false;
	if (AUCTIONATOR_LAST_SCAN_TIME) then
		local timeSinceLastScan = time() - AUCTIONATOR_LAST_SCAN_TIME;
		if (timeSinceLastScan < 15*60) then
			timeBlocked = true;
			local remaining = math.ceil((15*60 - timeSinceLastScan) / 60);
			zc.msg_atr("|cffff0000Error:|r Debes esperar "..remaining.." minuto(s) antes de escanear de nuevo.");
			return;
		end
	end
	
	if (not canQuery and not canQueryAll) then
		zc.msg_atr("|cffff0000Error:|r No se puede consultar la casa de subastas en este momento.");
		zc.msg_atr("|cffaaaaaa- Asegúrate de estar cerca de un subastador|r");
		zc.msg_atr("|cffaaaaaa- Espera unos segundos y vuelve a intentar|r");
		return;
	end
	
	Atr_FullScanStatus:SetText (ZT("Scanning").."...");
	Atr_FullScanProgress:SetText("");
	Atr_FullScanStartButton:Disable();
	Atr_FullScanDone:Disable();

	gAtr_FullScanState = ATR_FS_STARTED;

	SortAuctionClearSort ("list");

	gNumAdded = 0;
	gNumUpdated = 0;
	gAtr_FullScan_CurrentPage = 0;
	gAtr_FullScan_TotalPages = 0;
	gAtr_FullScan_AllData = {}; -- Acumular datos de todas las páginas
	gAtr_FullScan_StartTime = time();
	gAtr_FullScan_LastQueryTime = time();
	gAtr_FullScan_NextQueryTime = time();

	-- Aplicar delay configurado por el usuario si existe
	if (AUCTIONATOR_SAVEDVARS and AUCTIONATOR_SAVEDVARS.SCAN_PAGE_DELAY) then
		gAtr_FullScan_PageDelay = AUCTIONATOR_SAVEDVARS.SCAN_PAGE_DELAY;
	end

	zc.msg_atr("|cff00ff00Escaneo iniciado con paginación inteligente|r");
	
	QueryAuctionItems ("", nil, nil, 0, 0, 0, 0, nil, nil);

end

-----------------------------------------

function Atr_CalcNewDBprice (name, prices)
		
	if (prices[1] ~= BIGNUM) then
		return prices[1];
	end

	return 0;
	
end

-----------------------------------------

function Atr_AddToLowPrices (lowprices, itemPrice)
	
	if (itemPrice > 0) then
		if (itemPrice < lowprices[1]) then
			if (lowprices[1] < lowprices[2]) then
				lowprices[2] = lowprices[1];
			end
			lowprices[1] = itemPrice;
			return true;
		elseif (itemPrice < lowprices[2]) then
			lowprices[2] = itemPrice;
			return true;
		end
	end

	return false;
end




-----------------------------------------

local gScanDetails = {}

-----------------------------------------

function Atr_FullScanMoreDetails ()

	zc.msg (" ");
	zc.msg_atr (ZT("Auctions scanned")..": |cffffffff", gScanDetails.numBatchAuctions, " |r("..gScanDetails.totalItems, "items)");
	zc.msg_atr ("|cffa335ee   "..ZT("Epic items")..": |r",		gScanDetails.numEachQual[5]);
	zc.msg_atr ("|cff0070dd   "..ZT("Rare items")..": |r",		gScanDetails.numEachQual[4]);
	zc.msg_atr ("|cff1eff00   "..ZT("Uncommon items")..": |r",	gScanDetails.numEachQual[3]);
	zc.msg_atr ("|cffffffff   "..ZT("Common items")..": |r",		gScanDetails.numEachQual[2]);
	zc.msg_atr ("|cff9d9d9d   "..ZT("Poor items")..": |r",		gScanDetails.numEachQual[1]);
	
	
	if (gScanDetails.numRemoved[4] > 0) then		zc.msg_atr (ZT("Rare items").." "..ZT("removed from database")..": |cffffffff",		gScanDetails.numRemoved[4]);		end
	if (gScanDetails.numRemoved[3] > 0) then		zc.msg_atr (ZT("Uncommon items").." "..ZT("removed from database")..": |cffffffff",	gScanDetails.numRemoved[3]);		end
	if (gScanDetails.numRemoved[2] > 0) then		zc.msg_atr (ZT("Common items").." "..ZT("removed from database")..": |cffffffff",	gScanDetails.numRemoved[2]);		end
	if (gScanDetails.numRemoved[1] > 0) then		zc.msg_atr (ZT("Poor items").." "..ZT("removed from database")..": |cffffffff",		gScanDetails.numRemoved[1]);		end
	
	zc.msg_atr (ZT("Items added to database")..": |cffffffff", gScanDetails.gNumAdded);
	zc.msg_atr (ZT("Items updated in database")..": |cffffffff", gScanDetails.gNumUpdated);
	zc.msg_atr (ZT("Items ignored")..": |cffffffff", gScanDetails.totalItems - (gScanDetails.gNumAdded + gScanDetails.gNumUpdated));
	zc.msg (" ");
end

-----------------------------------------

function Atr_FullScanAnalyze()

	local numBatchAuctions, totalAuctions = GetNumAuctionItems("list");
	
	-- Calcular total de páginas en la primera consulta
	if (gAtr_FullScan_CurrentPage == 0) then
		gAtr_FullScan_TotalPages = math.ceil(totalAuctions / 50); -- 50 items por página
		
		-- Calcular delays inteligentes según el tamaño del escaneo
		local avgDelay = gAtr_FullScan_PageDelay;
		if (gAtr_FullScan_TotalPages > 500) then
			-- Escaneos muy grandes (25000+ subastas): optimizado para <15min
			avgDelay = 0.7;
			gAtr_FullScan_PageDelay = 0.5; -- Aumentar delay base
		elseif (gAtr_FullScan_TotalPages > 200) then
			-- Escaneos grandes (10000+ subastas): balance entre velocidad y seguridad
			avgDelay = 0.6;
			gAtr_FullScan_PageDelay = 0.45;
		elseif (gAtr_FullScan_TotalPages > 100) then
			-- Escaneos medianos (5000+ subastas)
			avgDelay = 0.5;
			gAtr_FullScan_PageDelay = 0.4;
		else
			-- Escaneos pequeños: más rápido
			avgDelay = 0.35;
			gAtr_FullScan_PageDelay = 0.25;
		end
		
		local estimatedTime = math.ceil(gAtr_FullScan_TotalPages * avgDelay);
		local estimatedMinutes = math.floor(estimatedTime / 60);
		local estimatedSeconds = estimatedTime % 60;
		
		local timeStr;
		if (estimatedMinutes > 0) then
			timeStr = estimatedMinutes.."m "..estimatedSeconds.."s";
		else
			timeStr = estimatedSeconds.."s";
		end
		
		-- Mensaje según tamaño del escaneo
		if (gAtr_FullScan_TotalPages > 500) then
			zc.msg_atr("|cffff8800⚠ Escaneo masivo:|r "..totalAuctions.." subastas, "..gAtr_FullScan_TotalPages.." páginas (~"..timeStr..")");
		elseif (gAtr_FullScan_TotalPages > 100) then
			zc.msg_atr("|cffaaffaa"..totalAuctions.." subastas|r en "..gAtr_FullScan_TotalPages.." páginas (~"..timeStr..")");
		else
			zc.msg_atr("|cffaaffaa"..totalAuctions.." subastas|r en "..gAtr_FullScan_TotalPages.." páginas");
		end
	end
	
	-- Verificar si recibimos datos
	if (numBatchAuctions == 0 and gAtr_FullScan_CurrentPage < gAtr_FullScan_TotalPages) then
		-- Ir directo al procesamiento si no hay más datos pero no hemos llegado al final
		gAtr_FullScan_CurrentPage = gAtr_FullScan_TotalPages;
	end

	-- Acumular datos de esta página
	for x = 1, numBatchAuctions do
		local name, texture, count, quality, canUse, level, minBid, minIncrement, buyoutPrice = GetAuctionItemInfo("list", x);
		if (name ~= nil and buyoutPrice ~= nil) then
			-- Filtrar por nivel de calidad mínimo: no acumular objetos por debajo del umbral
			local qx = (quality or 0) + 1;
			if (qx >= AUCTIONATOR_SCAN_MINLEVEL) then
				table.insert(gAtr_FullScan_AllData, {name=name, count=count, quality=quality, buyoutPrice=buyoutPrice});
			end
		end
	end

	gAtr_FullScan_CurrentPage = gAtr_FullScan_CurrentPage + 1;
	
	-- Calcular progreso y tiempo
	local progress = 0;
	if (gAtr_FullScan_TotalPages > 0) then
		progress = math.floor((gAtr_FullScan_CurrentPage / gAtr_FullScan_TotalPages) * 100);
	end
	local elapsed = time() - gAtr_FullScan_StartTime;
	local remaining = 0;
	if (gAtr_FullScan_CurrentPage > 0 and gAtr_FullScan_CurrentPage < gAtr_FullScan_TotalPages) then
		local timePerPage = elapsed / gAtr_FullScan_CurrentPage;
		remaining = math.ceil((gAtr_FullScan_TotalPages - gAtr_FullScan_CurrentPage) * timePerPage);
	end
	
	-- Actualizar UI con progreso
	Atr_FullScanStatus:SetText(ZT("Scanning").."...");
	
	local progressText = progress.."%";
	if (gAtr_FullScan_TotalPages > 0) then
		progressText = progressText .. " ("..gAtr_FullScan_CurrentPage.."/"..gAtr_FullScan_TotalPages..")";
	end
	if (remaining > 0) then
		local remMin = math.floor(remaining / 60);
		local remSec = remaining % 60;
		if (remMin > 0) then
			progressText = progressText.." (~"..remMin.."m "..remSec.."s)";
		else
			progressText = progressText.." (~"..remSec.."s)";
		end
	end
	Atr_FullScanProgress:SetText(progressText);
	
	-- Mostrar progreso en chat (solo checkpoints importantes)
	if (gAtr_FullScan_TotalPages > 20) then
		if (progress == 25 or progress == 50 or progress == 75) then
			zc.msg_atr("|cffaaffaa"..progress.."%|r completado ("..gAtr_FullScan_CurrentPage.."/"..gAtr_FullScan_TotalPages.." páginas)");
		end
	end

	-- Si hay más páginas, preparar siguiente consulta con delay
	if (gAtr_FullScan_CurrentPage < gAtr_FullScan_TotalPages and numBatchAuctions > 0) then
		-- Calcular delay variable para parecer más humano
		local baseDelay = gAtr_FullScan_PageDelay;
		local randomVariation = math.random(-100, 300) / 1000; -- Variación aleatoria mayor
		local totalDelay = baseDelay + randomVariation;
		
		-- Sistema de pausas progresivas para escaneos grandes (optimizado para <15min)
		if (gAtr_FullScan_TotalPages > 500) then
			-- Escaneos masivos (37000+ subastas): pausas optimizadas
			if (gAtr_FullScan_CurrentPage % 20 == 0) then
				totalDelay = totalDelay + math.random(150, 300) / 1000; -- Pausa cada 20 páginas
			end
			if (gAtr_FullScan_CurrentPage % 100 == 0) then
				totalDelay = totalDelay + math.random(500, 1000) / 1000; -- Pausa media cada 100
			end
		elseif (gAtr_FullScan_TotalPages > 200) then
			-- Escaneos grandes: pausas moderadas
			if (gAtr_FullScan_CurrentPage % 25 == 0) then
				totalDelay = totalDelay + math.random(200, 400) / 1000;
			end
			if (gAtr_FullScan_CurrentPage % 50 == 0) then
				totalDelay = totalDelay + math.random(400, 800) / 1000;
			end
		else
			-- Escaneos pequeños/medianos: pausas ligeras
			if (gAtr_FullScan_CurrentPage % 30 == 0) then
				totalDelay = totalDelay + math.random(150, 300) / 1000;
			end
		end
		
		gAtr_FullScanState = ATR_FS_WAITING;
		gAtr_FullScan_NextQueryTime = time() + totalDelay;
		return;
	end

	-- Todas las páginas escaneadas, procesar datos
	gAtr_FullScanState = ATR_FS_ANALYZING;
	Atr_FullScanStatus:SetText (ZT("Processing"));
	Atr_FullScanProgress:SetText("");
	
	gAtr_FullScan_ScanTime = time() - gAtr_FullScan_StartTime;
	local scanMin = math.floor(gAtr_FullScan_ScanTime / 60);
	local scanSec = math.floor(gAtr_FullScan_ScanTime % 60);
	local timeText = string.format("%.0fs", gAtr_FullScan_ScanTime);
	if (scanMin > 0) then
		timeText = scanMin.."m "..scanSec.."s";
	end
	zc.msg_atr("|cff00ff00✓ Escaneo completado:|r "..#gAtr_FullScan_AllData.." items en "..timeText);

	local lowprices = {};
	local x;
	
	local qualities = {};
	
	local totalItems = #gAtr_FullScan_AllData;
	
	if (totalItems > 0) then

		for x = 1, totalItems do

			local itemData = gAtr_FullScan_AllData[x];
			local name = itemData.name;
			local count = itemData.count;
			local quality = itemData.quality;
			local buyoutPrice = itemData.buyoutPrice;

			qualities[name] = quality;
			
			local itemPrice = math.floor (buyoutPrice / count);
			
			if (itemPrice > 0) then
				if (not lowprices[name]) then
					lowprices[name] = {BIGNUM,BIGNUM,BIGNUM};		-- one extra for later
				end
				
				Atr_AddToLowPrices (lowprices[name], itemPrice);
			end

			if (x % 100 == 0) then
				Atr_FullScanStatus:SetText (ZT("Processing").." ("..x.." / "..totalItems..")");
			end
		end
	end

	local numEachQual = {0, 0, 0, 0, 0, 0, 0, 0, 0};
	local totalUniqueItems = 0;
	local numRemoved = { 0, 0, 0, 0, 0, 0, 0, 0 };
	
	for name,prices in pairs (lowprices) do
		
		local newprice = Atr_CalcNewDBprice (name, prices);
		
		if (newprice > 0) then
		
			local qx = qualities[name] + 1;
			
			numEachQual[qx]	= numEachQual[qx] + 1;
			totalUniqueItems		= totalUniqueItems + 1;
			
			if (qx < AUCTIONATOR_SCAN_MINLEVEL and gAtr_ScanDB[name]) then
				numRemoved[qx] = numRemoved[qx] + 1;
				gAtr_ScanDB[name] = nil;
				zc.md ("removed: |cffbbbbbb", name, "   ("..qx..")");
			end
			
			if (qx >= AUCTIONATOR_SCAN_MINLEVEL) then

				if (gAtr_ScanDB[name] == nil) then
					gNumAdded = gNumAdded + 1;
				else
					gNumUpdated = gNumUpdated + 1;
				end

				gAtr_ScanDB[name] = newprice;
			end
		end
	end

	gScanDetails.numBatchAuctions		= #gAtr_FullScan_AllData;
	gScanDetails.totalItems				= totalUniqueItems;
	gScanDetails.numEachQual			= numEachQual;
	gScanDetails.numRemoved				= numRemoved;
	gScanDetails.gNumAdded				= gNumAdded;
	gScanDetails.gNumUpdated			= gNumUpdated;


	-- Bargains check comentado ya que requeriría mantener referencias a los items de auction
	-- if (Atr_PrintBargains and Atr_CheckForBargain and totalItems > 0) then
	-- 	Atr_PrintBargains();
	-- end
	
	zc.msg_atr("|cff00ff00✓ Base de datos actualizada:|r "..gNumAdded.." items añadidos, "..gNumUpdated.." actualizados.");
	
	gAtr_FullScanState = ATR_FS_CLEANING_UP;

	Atr_FullScanMoreDetails();

	Atr_FullScanStatus:SetText (ZT("Cleaning up"));

	Atr_FullScanStartButton:Enable();
	Atr_FullScanDone:Enable();
	Atr_FullScanStatus:SetText ("");
	Atr_FullScanProgress:SetText("");
	
	local scanMin = math.floor(gAtr_FullScan_ScanTime / 60);
	local scanSec = math.floor(gAtr_FullScan_ScanTime % 60);
	local timeText = string.format("%.2fs", gAtr_FullScan_ScanTime);
	if (scanMin > 0) then
		timeText = scanMin.."m "..scanSec.."s";
	end

	Atr_FSR_scanned_count:SetText	(#gAtr_FullScan_AllData .. " ("..gAtr_FullScan_TotalPages.." " .. ZT("pages") .. ")");
	Atr_FSR_time_count:SetText(timeText);
	Atr_FSR_added_count:SetText		(gNumAdded);
	Atr_FSR_updated_count:SetText	(gNumUpdated);
	Atr_FSR_ignored_count:SetText	(totalUniqueItems - (gNumAdded + gNumUpdated));
	
	Atr_FullScanResults:Show();
	
	Atr_FullScanResults:SetBackdropColor (0.3, 0.3, 0.4);
	
	AUCTIONATOR_LAST_SCAN_TIME = time();
	
	Atr_UpdateFullScanFrame ();

	Atr_ClearBrowseListings();
	
	lowprices = {};
	gAtr_FullScan_AllData = {};
	collectgarbage ("collect");
end

-----------------------------------------

function auctionator_AuctionFrameBrowse_Update ()

	return auctionator_orig_AuctionFrameBrowse_Update ();

end

-----------------------------------------

function Atr_ShowFullScanFrame()

	Atr_FullScanHTML:Show();
	Atr_FullScanResults:Hide();

	Atr_FullScanFrame:Show();
	Atr_FullScanFrame:SetBackdropColor(0,0,0,100);
	
	Atr_UpdateFullScanFrame();
	Atr_FullScanStatus:SetText ("");
	Atr_FullScanProgress:SetText("");

	local expText = "<html><body>"
					.."<p>"
					..ZT("Scanning is entirely optional.")
					.."<br/><br/>"
					..ZT("SCAN_EXPLANATION")
					.."</p>"
					.."</body></html>"
					;



	Atr_FullScanHTML:SetText (expText);
	Atr_FullScanHTML:SetSpacing (3);
end

-----------------------------------------

function Atr_UpdateFullScanFrame()

	Atr_FullScanDBsize:SetText (Atr_GetDBsize());
	
	if (AUCTIONATOR_LAST_SCAN_TIME) then
		Atr_FullScanDBwhen:SetText (date ("%A, %B %d at %I:%M %p", AUCTIONATOR_LAST_SCAN_TIME));
	else
		Atr_FullScanDBwhen:SetText (ZT("Never"));
	end

	local canQuery,canQueryAll = CanSendAuctionQuery();

	if (canQueryAll) then
		Atr_FullScanStatus:SetText ("");
		Atr_FullScanStartButton:Enable();
		Atr_FullScanNext:SetText("|cff00ff00Sí|r");
	else	
		Atr_FullScanStartButton:Disable();

		if (AUCTIONATOR_LAST_SCAN_TIME) then
			local whenSeconds = 15*60 - (time() - AUCTIONATOR_LAST_SCAN_TIME);
		
			if (whenSeconds <= 0) then
				-- Puede escanear pero CanSendAuctionQuery devuelve false por otra razón
				Atr_FullScanNext:SetText("|cff00ff00Sí|r");
				Atr_FullScanStartButton:Enable();
			elseif (whenSeconds < 60) then
				Atr_FullScanNext:SetText ("|cffff8800"..whenSeconds.."s|r");
			else
				local whenMinutes = math.ceil(whenSeconds / 60);
				if (whenMinutes == 1) then
					Atr_FullScanNext:SetText ("|cffff8800~1 min|r");
				else
					Atr_FullScanNext:SetText ("|cffff8800~"..whenMinutes.." min|r");
				end
			end
		else
			Atr_FullScanNext:SetText("|cff00ff00Sí|r");
		end
	end
end

-----------------------------------------

function Atr_FullScanFrameIdle()

	if (gAtr_FullScanState == ATR_FS_WAITING) then
		-- Verificar si es hora de hacer la siguiente consulta
		local currentTime = time();
		if (currentTime >= gAtr_FullScan_NextQueryTime) then
			local canQuery = CanSendAuctionQuery();
			if (canQuery) then
				gAtr_FullScanState = ATR_FS_STARTED;
				gAtr_FullScan_LastQueryTime = currentTime;
				QueryAuctionItems ("", nil, nil, 0, 0, 0, gAtr_FullScan_CurrentPage, nil, nil);
			else
				-- Si no podemos consultar aún, esperar un poco más y avisar si se repite
				if (gAtr_FullScan_ThrottleWarned ~= true) then
					zc.msg_atr("|cffff8800Se detecta limitación del servidor|r. Aumenta el delay en Opciones > Scanning si vuelve a ocurrir.");
					gAtr_FullScan_ThrottleWarned = true;
				end
				gAtr_FullScan_NextQueryTime = currentTime + 0.5;
			end
		end
	end

	if (gAtr_FullScanState == ATR_FS_CLEANING_UP) then
	
		Atr_FullScanStatus:SetText ("Cleaning up");
		
		if (GetNumAuctionItems("list") < 100) then
		
			Atr_FullScanStatus:SetText (ZT("Scan complete"));
			PlaySound("AuctionWindowClose");
			
			gAtr_FullScanState = ATR_FS_NULL;
			
			-- Resetear variables de escaneo
			gAtr_FullScan_CurrentPage = 0;
			gAtr_FullScan_TotalPages = 0;
			gAtr_FullScan_LastQueryTime = 0;
			gAtr_FullScan_NextQueryTime = 0;
			
			-- Actualizar el frame para habilitar el botón
			Atr_UpdateFullScanFrame();
		end
	
	end
	
	if (gAtr_FullScanState == ATR_FS_STARTED) then

		local btext = Atr_FullScanStatus:GetText ();
		
		if (btext) then
			if (string.len (btext) > 25) then
				Atr_FullScanStatus:SetText (ZT("Scanning")..".");
			else
				Atr_FullScanStatus:SetText (btext..".");
			end
		end
	end
	
end







