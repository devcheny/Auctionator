-- AuctionatorEarnings.lua
-- Funcionalidad para calcular y mostrar las ganancias totales de las subastas activas

local addonName, addonTable = ...; 
local zc = addonTable.zc;

local AuctionHouseCut = 0.05; -- La casa de subastas se queda con el 5% de las ventas

-----------------------------------------
-- Convierte precio a string con formato de oro/plata/cobre
-----------------------------------------
local function PriceToMoneyString(price)
	if not price or price == 0 then
		return "0|cffffd700g|r";
	end
	
	local gold = math.floor(price / 10000);
	local silver = math.floor((price % 10000) / 100);
	local copper = price % 100;
	
	local str = "";
	if gold > 0 then
		str = str .. gold .. "|cffffd700g|r";
	end
	if silver > 0 then
		if str ~= "" then str = str .. " "; end
		str = str .. silver .. "|cffc7c7cfs|r";
	end
	if copper > 0 or str == "" then
		if str ~= "" then str = str .. " "; end
		str = str .. copper .. "|cffeda55fc|r";
	end
	
	return str;
end

-----------------------------------------
-- Calcula el total de ganancias esperadas de todas las subastas activas
-----------------------------------------
function Atr_CalculateTotalEarnings()
	local totalBuyout = 0;
	local totalDeposit = 0;
	local numActiveAuctions = 0;
	
	local num = GetNumAuctionItems("owner");
	
	if (num == 0) then
		return 0, 0, 0;
	end
	
	for i = 1, num do
		local name, texture, count, quality, canUse, level, minBid, minIncrement, 
			  buyoutPrice, bidAmount, highBidder, owner, saleStatus = GetAuctionItemInfo("owner", i);
		
		if (name ~= nil and saleStatus == 0) then  -- saleStatus 0 = activa, 1 = vendida
			if (buyoutPrice and buyoutPrice > 0) then
				totalBuyout = totalBuyout + buyoutPrice;
				numActiveAuctions = numActiveAuctions + 1;
			end
			
			-- Obtener el depósito de la subasta
			local timeLeft = GetAuctionItemTimeLeft("owner", i);
			
			-- Intentar obtener el link del item para calcular el depósito
			local itemLink = GetAuctionItemLink("owner", i);
			if (itemLink) then
				-- El depósito ya fue pagado, pero podríamos mostrarlo para referencia
				-- Por ahora solo calculamos las ganancias brutas
			end
		end
	end
	
	-- Calcular ganancias netas (después del corte de la casa de subastas)
	local auctionHouseFee = totalBuyout * AuctionHouseCut;
	local netEarnings = totalBuyout - auctionHouseFee;
	
	return totalBuyout, netEarnings, numActiveAuctions;
end

-----------------------------------------
-- Formatea el total de ganancias para mostrar en la UI
-----------------------------------------
function Atr_GetEarningsText()
	local totalBuyout, netEarnings, numAuctions = Atr_CalculateTotalEarnings();
	
	if (numAuctions == 0) then
		return ZT("No active auctions");
	end
	
	local text = string.format(ZT("Active Auctions: %d"), numAuctions);
	text = text .. "\n" .. ZT("Total Buyout: ") .. PriceToMoneyString(totalBuyout);
	text = text .. "\n" .. ZT("Net Earnings: ") .. PriceToMoneyString(netEarnings);
	text = text .. "\n" .. ZT("AH Fee (5%%): ") .. PriceToMoneyString(totalBuyout - netEarnings);
	
	return text;
end

-----------------------------------------
-- Formatea solo el total neto para mostrar de forma compacta
-----------------------------------------
function Atr_GetEarningsShortText()
	local totalBuyout, netEarnings, numAuctions = Atr_CalculateTotalEarnings();
	
	if (numAuctions == 0) then
		return "";
	end
	
	return ZT("Expected Earnings: ") .. PriceToMoneyString(netEarnings);
end

-----------------------------------------
-- Actualiza el frame de ganancias si existe
-----------------------------------------
function Atr_UpdateEarningsDisplay()
	if (Atr_EarningsFrame and Atr_EarningsFrame:IsShown()) then
		local earningsText = Atr_GetEarningsText();
		if (Atr_EarningsFrame_Text) then
			Atr_EarningsFrame_Text:SetText(earningsText);
		end
	end
	
	-- También actualizar el texto corto si existe
	if (Atr_EarningsShort_Text) then
		local shortText = Atr_GetEarningsShortText();
		Atr_EarningsShort_Text:SetText(shortText);
	end
end

-----------------------------------------
-- Hook para actualizar cuando cambian las subastas
-----------------------------------------
local function OnAuctionOwnedListUpdate()
	if (Atr_IsModeActiveAuctions() or Atr_IsTabSelected(SELL_TAB)) then
		Atr_UpdateEarningsDisplay();
	end
end

-- Registrar el hook
local earningsFrame = CreateFrame("Frame");
earningsFrame:RegisterEvent("AUCTION_OWNED_LIST_UPDATE");
earningsFrame:SetScript("OnEvent", function(self, event, ...)
	if (event == "AUCTION_OWNED_LIST_UPDATE") then
		OnAuctionOwnedListUpdate();
	end
end);
