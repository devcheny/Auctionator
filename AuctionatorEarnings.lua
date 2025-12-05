-- AuctionatorEarnings.lua
-- Funcionalidad para calcular y mostrar las ganancias totales de las subastas activas

local addonName, addonTable = ...; 
local zc = addonTable.zc;

local AuctionHouseCut = 0.05; -- La casa de subastas se queda con el 5% de las ventas

-----------------------------------------
-- Convierte precio a string con formato de oro/plata/cobre con iconos
-----------------------------------------
local function PriceToMoneyString(price)
	if not price or price == 0 then
		return "0|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t";
	end
	
	local gold = math.floor(price / 10000);
	local silver = math.floor((price % 10000) / 100);
	local copper = price % 100;
	
	local str = "";
	if gold > 0 then
		str = str .. gold .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t";
	end
	if silver > 0 then
		if str ~= "" then str = str .. " "; end
		str = str .. silver .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t";
	end
	if copper > 0 or str == "" then
		if str ~= "" then str = str .. " "; end
		str = str .. copper .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t";
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
		local msg = "No active auctions";
		if ZT then msg = ZT("No active auctions"); end
		return msg;
	end
	
	local text = string.format("Subastas activas: %d", numAuctions);
	if ZT then
		text = string.format(ZT("Active Auctions: %d"), numAuctions);
	end
	
	local lblTotal = "Total compra directa: ";
	local lblNet = "Ganancias netas: ";
	local lblFee = "Comisión CS (5%%): ";
	
	if ZT then
		lblTotal = ZT("Total Buyout: ");
		lblNet = ZT("Net Earnings: ");
		lblFee = ZT("AH Fee (5%%): ");
	end
	
	text = text .. "\n" .. lblTotal .. PriceToMoneyString(totalBuyout);
	text = text .. "\n" .. lblNet .. PriceToMoneyString(netEarnings);
	text = text .. "\n" .. lblFee .. PriceToMoneyString(totalBuyout - netEarnings);
	
	return text;
end

-----------------------------------------
-- Formatea solo el total neto para mostrar de forma compacta
-----------------------------------------
function Atr_GetEarningsShortText()
	local totalBuyout, netEarnings, numAuctions = Atr_CalculateTotalEarnings();
	
	local label = "Total si se venden: ";
	if ZT then
		label = ZT("Expected Earnings: ");
	end
	
	return label .. PriceToMoneyString(netEarnings);
end

-----------------------------------------
-- Actualiza el frame de ganancias si existe
-----------------------------------------
function Atr_UpdateEarningsDisplay()
	if not Atr_Earnings_Frame then
		return;
	end
	
	if not Atr_EarningsShort_Text then
		return;
	end
	
	-- Verificar que la casa de subastas esté abierta
	if not AuctionFrame or not AuctionFrame:IsShown() then
		Atr_Earnings_Frame:Hide();
		return;
	end
	
	-- Verificar si estamos en la pestaña de Auctions (index 3)
	local selectedTab = PanelTemplates_GetSelectedTab(AuctionFrame);
	if selectedTab ~= 3 then
		Atr_Earnings_Frame:Hide();
		return;
	end
	
	-- Forzar actualización de la lista de subastas
	local shortText = Atr_GetEarningsShortText();
	
	Atr_EarningsShort_Text:SetText(shortText);
	Atr_Earnings_Frame:Show();
end

-----------------------------------------
-- Hook para actualizar cuando cambian las subastas
-----------------------------------------
local function OnAuctionOwnedListUpdate()
	-- Solo actualizar si la casa de subastas está abierta
	if AuctionFrame and AuctionFrame:IsShown() then
		local selectedTab = PanelTemplates_GetSelectedTab(AuctionFrame);
		if selectedTab == 3 then
			Atr_UpdateEarningsDisplay();
		else
			-- Ocultar si no estamos en la pestaña correcta
			if Atr_Earnings_Frame then
				Atr_Earnings_Frame:Hide();
			end
		end
	else
		-- Ocultar si la casa de subastas no está abierta
		if Atr_Earnings_Frame then
			Atr_Earnings_Frame:Hide();
		end
	end
end

-- Registrar el hook
local earningsFrame = CreateFrame("Frame");
earningsFrame:RegisterEvent("AUCTION_OWNED_LIST_UPDATE");
earningsFrame:RegisterEvent("AUCTION_HOUSE_SHOW");
earningsFrame:RegisterEvent("AUCTION_HOUSE_CLOSED");
earningsFrame:SetScript("OnEvent", function(self, event, ...)
	if (event == "AUCTION_OWNED_LIST_UPDATE") then
		OnAuctionOwnedListUpdate();
	elseif (event == "AUCTION_HOUSE_SHOW") then
		-- Actualizar cuando se abre la casa de subastas
		OnAuctionOwnedListUpdate();
	elseif (event == "AUCTION_HOUSE_CLOSED") then
		-- Ocultar el frame cuando se cierra la casa de subastas
		if Atr_Earnings_Frame then
			Atr_Earnings_Frame:Hide();
		end
	end
end);

-----------------------------------------
-- Función de inicialización
-----------------------------------------
function Atr_InitEarningsDisplay()
	if Atr_Earnings_Frame and Atr_EarningsShort_Text then
		Atr_UpdateEarningsDisplay();
	end
end
