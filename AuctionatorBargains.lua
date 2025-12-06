-- AuctionatorBargains.lua
-- Sistema de búsqueda automática de ofertas basado en historial de precios

local addonName, addonTable = ...; 
local zc = addonTable.zc;

-----------------------------------------
-- Función auxiliar para crear un timer (reemplazo de C_Timer.After para Classic)
-----------------------------------------
local function Atr_Timer_After(delay, func)
	local frame = CreateFrame("Frame");
	local elapsed = 0;
	frame:SetScript("OnUpdate", function(self, dt)
		elapsed = elapsed + dt;
		if elapsed >= delay then
			self:SetScript("OnUpdate", nil);
			func();
		end
	end);
end

-- Variables globales
local isScanning = false;
local scanResults = {};
local currentScanPage = 0;
local totalScanPages = 0;

-- Configuración de descuento (valor por defecto 30%)
-- Se guarda automáticamente en las variables globales de Auctionator
if not AUCTIONATOR_BARGAIN_DISCOUNT then
    AUCTIONATOR_BARGAIN_DISCOUNT = 30;
end

-- Función para guardar la configuración
local function Atr_SaveBargainConfig()
    -- Se guarda automáticamente al ser una variable global de Auctionator
    if AUCTIONATOR_DB then
        AUCTIONATOR_DB.bargain_discount = AUCTIONATOR_BARGAIN_DISCOUNT;
    end
end

-- Función para cargar la configuración
local function Atr_LoadBargainConfig()
    if AUCTIONATOR_DB and AUCTIONATOR_DB.bargain_discount then
        AUCTIONATOR_BARGAIN_DISCOUNT = AUCTIONATOR_DB.bargain_discount;
    end
end

-- Función para obtener el threshold actual (convierte % a decimal)
local function Atr_GetBargainThreshold()
    return (100 - AUCTIONATOR_BARGAIN_DISCOUNT) / 100;
end

-- Constante para items por página (en caso de que no exista en Classic)
local ITEMS_PER_PAGE = NUM_AUCTION_ITEMS_PER_PAGE or 50;

-- Verificación de compatibilidad con WoW Classic
local function Atr_VerifyClassicCompatibility()
    -- Verificar APIs esenciales
    if not QueryAuctionItems then
        Atr_Debug("Error: QueryAuctionItems no disponible");
        return false;
    end
    if not GetNumAuctionItems then
        Atr_Debug("Error: GetNumAuctionItems no disponible");
        return false;
    end
    if not GetAuctionItemInfo then
        Atr_Debug("Error: GetAuctionItemInfo no disponible");
        return false;
    end
    return true;
end

-----------------------------------------
-- Función para obtener el precio histórico promedio de un item
-----------------------------------------
function Atr_GetItemHistoricalPrice(itemName)
	if not itemName then
		return nil;
	end
	
	-- Buscar en la base de datos del historial de Auctionator
	if AUCTIONATOR_PRICING_HISTORY and AUCTIONATOR_PRICING_HISTORY[itemName] then
		local priceData = AUCTIONATOR_PRICING_HISTORY[itemName];
		if priceData and priceData.price and priceData.price > 0 then
			return priceData.price;
		end
	end
	
	-- Buscar en la base de datos del scan completo
	if gAtrFullScanDB and gAtrFullScanDB[itemName] then
		local scanData = gAtrFullScanDB[itemName];
		if scanData and scanData.price and scanData.price > 0 then
			return scanData.price;
		end
	end
	
	-- Buscar en AUCTIONATOR_PRICE_DATABASE si existe
	if AUCTIONATOR_PRICE_DATABASE and AUCTIONATOR_PRICE_DATABASE[itemName] then
		local dbData = AUCTIONATOR_PRICE_DATABASE[itemName];
		if dbData and dbData.price and dbData.price > 0 then
			return dbData.price;
		end
	end
	
	return nil;
end

-----------------------------------------
-- Función para verificar si un item es una ganga
-----------------------------------------
function Atr_IsItemBargain(itemName, currentPrice, stackSize)
	if not itemName or not currentPrice or currentPrice <= 0 then
		return false;
	end
	
	local historicalPrice = Atr_GetItemHistoricalPrice(itemName);
	if not historicalPrice then
		return false;
	end
	
	-- Calcular precio por unidad
	local pricePerUnit = currentPrice;
	if stackSize and stackSize > 1 then
		pricePerUnit = currentPrice / stackSize;
	end
	
	local historicalPricePerUnit = historicalPrice;
	
	-- Verificar si es una ganga usando el threshold configurable
	local threshold = Atr_GetBargainThreshold();
	local discountThreshold = historicalPricePerUnit * threshold;
	
	if pricePerUnit <= discountThreshold then
		local discountPercent = math.floor(((historicalPricePerUnit - pricePerUnit) / historicalPricePerUnit) * 100);
		return true, discountPercent, historicalPricePerUnit;
	end
	
	return false;
end

-----------------------------------------
-- Función para escanear una página en busca de gangas
-----------------------------------------
function Atr_ScanPageForBargains()
	if not isScanning then
		return;
	end
	
	local numItems = GetNumAuctionItems("list");
	if numItems == 0 then
		return;
	end
	
	for i = 1, numItems do
		local name, texture, count, quality, canUse, level, minBid, minIncrement, 
			  buyoutPrice, bidAmount, highBidder, owner, saleStatus = GetAuctionItemInfo("list", i);
		
		if name and buyoutPrice and buyoutPrice > 0 and quality >= 2 then -- Solo uncommon o mejor
			local isBargain, discountPercent, historicalPrice = Atr_IsItemBargain(name, buyoutPrice, count);
			
			if isBargain then
				local itemLink = GetAuctionItemLink("list", i);
				
				-- Agregar a los resultados
				table.insert(scanResults, {
					name = name,
					itemLink = itemLink,
					currentPrice = buyoutPrice,
					historicalPrice = historicalPrice,
					discountPercent = discountPercent,
					count = count,
					quality = quality,
					index = i
				});
			end
		end
	end
	
	-- Continuar con la siguiente página
	currentScanPage = currentScanPage + 1;
	if currentScanPage < totalScanPages then
		-- Escanear siguiente página después de un breve delay
		Atr_Timer_After(1.5, function()
			if isScanning then
				local canQuery, canQueryAll = CanSendAuctionQuery();
				if canQuery then
					QueryAuctionItems("", "", "", nil, nil, nil, currentScanPage);
				else
					-- Si no podemos hacer query, terminar el escaneo
					Atr_FinishBargainScan();
				end
			end
		end);
	else
		-- Escaneo completado
		Atr_FinishBargainScan();
	end
end

-----------------------------------------
-- Función para finalizar el escaneo y mostrar resultados
-----------------------------------------
function Atr_FinishBargainScan()
	isScanning = false;
	
	-- Actualizar el botón
	if Atr_BargainButton then
		local buttonText = "Buscar Ofertas";
		if ZT then
			buttonText = ZT("Search Bargains");
		end
		Atr_BargainButton:SetText(buttonText);
		Atr_BargainButton:Enable();
	end
	
	-- Mostrar resultados
	if #scanResults > 0 then
		Atr_ShowBargainResults();
	else
		local msg = "No se encontraron ofertas interesantes en este momento.";
		if ZT then
			msg = ZT("No bargains found at this time.");
		end
		if zc and zc.msg_anm then
			zc.msg_anm(msg);
		else
			print(msg);
		end
	end
end

-----------------------------------------
-- Función para mostrar los resultados de gangas
-----------------------------------------
function Atr_ShowBargainResults()
	local msg = string.format("¡Encontradas %d ofertas interesantes!", #scanResults);
	if ZT then
		msg = string.format(ZT("Found %d bargains!"), #scanResults);
	end
	
	-- Mensaje principal
	if zc and zc.msg_anm then
		zc.msg_anm(msg);
	else
		print(msg);
	end
	
	-- Mostrar las mejores 5 ofertas
	local maxToShow = math.min(5, #scanResults);
	
	-- Ordenar por porcentaje de descuento
	table.sort(scanResults, function(a, b)
		return a.discountPercent > b.discountPercent;
	end);
	
	for i = 1, maxToShow do
		local bargain = scanResults[i];
		
		local currentPriceStr = "Precio desconocido";
		local historicalPriceStr = "Precio desconocido";
		
		if zc and zc.priceToMoneyString then
			currentPriceStr = zc.priceToMoneyString(bargain.currentPrice);
			historicalPriceStr = zc.priceToMoneyString(bargain.historicalPrice);
		else
			currentPriceStr = string.format("%d cobre", bargain.currentPrice);
			historicalPriceStr = string.format("%d cobre", bargain.historicalPrice);
		end
		
		local itemMsg = string.format("%s - %d%% descuento (%s vs %s)",
			bargain.itemLink or bargain.name,
			bargain.discountPercent,
			currentPriceStr,
			historicalPriceStr
		);
		
		if zc and zc.msg_anm then
			zc.msg_anm(itemMsg);
		else
			print(itemMsg);
		end
	end
	
	-- Limpiar resultados para el próximo escaneo
	scanResults = {};
end

-----------------------------------------
-- Función para iniciar el escaneo de gangas
-----------------------------------------
function Atr_StartBargainScan()
	-- Verificar compatibilidad primero
	if not Atr_VerifyClassicCompatibility() then
		if zc and zc.msg_anm then
			zc.msg_anm("Error: APIs necesarias no disponibles en esta versión de WoW");
		else
			print("Error: APIs necesarias no disponibles en esta versión de WoW");
		end
		return;
	end
	
	-- Mensaje de debug
	print("Auctionator: Iniciando búsqueda de ofertas...");
	
	if isScanning then
		if zc and zc.msg_anm then
			zc.msg_anm("Ya hay un escaneo en progreso...");
		else
			print("Ya hay un escaneo en progreso...");
		end
		return;
	end
	
	-- Verificar que podemos hacer queries
	local canQuery, canQueryAll = CanSendAuctionQuery();
	if not canQuery then
		local msg = "Debes esperar antes de poder escanear nuevamente.";
		if zc and zc.msg_anm then
			zc.msg_anm(msg);
		else
			print(msg);
		end
		return;
	end
	
	-- Verificar que tenemos bases de datos de precios
	local hasDB = false;
	if AUCTIONATOR_PRICING_HISTORY then
		local count = 0;
		for k,v in pairs(AUCTIONATOR_PRICING_HISTORY) do
			count = count + 1;
			if count > 0 then 
				hasDB = true;
				break;
			end
		end
	end
	
	if not hasDB then
		local msg = "No hay datos de precios históricos. Ejecuta un escaneo completo primero.";
		if zc and zc.msg_anm then
			zc.msg_anm(msg);
		else
			print(msg);
		end
		return;
	end
	
	-- Inicializar variables
	isScanning = true;
	scanResults = {};
	currentScanPage = 0;
	
	-- Actualizar botón
	if Atr_BargainButton then
		local scanningText = "Escaneando...";
		if ZT then
			scanningText = ZT("Scanning...");
		end
		Atr_BargainButton:SetText(scanningText);
		Atr_BargainButton:Disable();
	end
	
	-- Comenzar el escaneo con la primera página
	local msg = "Iniciando búsqueda de ofertas...";
	if zc and zc.msg_anm then
		zc.msg_anm(msg);
	else
		print(msg);
	end
	
	-- Query inicial para obtener el número total de páginas
	QueryAuctionItems("", "", "", nil, nil, nil, 0);
	
	-- Configurar el handler para cuando lleguen los datos
	Atr_Timer_After(2, function()
		local numItems, totalItems = GetNumAuctionItems("list");
		totalScanPages = math.ceil(totalItems / ITEMS_PER_PAGE) or 1;
		if totalScanPages > 20 then
			totalScanPages = 20; -- Limitar a 20 páginas para evitar timeouts
		end
		
		local scanMsg = string.format("Escaneando %d páginas en busca de ofertas...", totalScanPages);
		if zc and zc.msg_anm then
			zc.msg_anm(scanMsg);
		else
			print(scanMsg);
		end
		Atr_ScanPageForBargains();
	end);
end

-----------------------------------------
-- Función para mostrar/ocultar el botón de búsqueda de ofertas
-----------------------------------------
function Atr_ShowBargainButton()
	-- Debug: mensaje para verificar que se llama la función
	print("Auctionator: Mostrando botón de búsqueda de ofertas...");
	
	if Atr_BargainButton then
		Atr_BargainButton:Show();
		print("Auctionator: ¡Botón de búsqueda de ofertas mostrado!");
	else
		print("Auctionator: Error - Atr_BargainButton no existe en XML");
	end
end

-----------------------------------------
-- Función para ocultar el botón de búsqueda de ofertas
-----------------------------------------
function Atr_HideBargainButton()
	if Atr_BargainButton then
		Atr_BargainButton:Hide();
	end
end

-----------------------------------------
-- Función para mostrar tooltip dinámico del botón de gangas
-----------------------------------------
function Atr_ShowBargainButtonTooltip(button)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
	GameTooltip:SetText("Buscador de Ofertas", 1, 1, 1);
	GameTooltip:AddLine("Escanea la casa de subastas en busca de items con precios por debajo del promedio histórico.", 1, 1, 1, true);
	GameTooltip:AddLine(" ");
	
	local currentDiscount = AUCTIONATOR_BARGAIN_DISCOUNT or 30;
	local threshold = 100 - currentDiscount;
	GameTooltip:AddLine("Descuento mínimo configurado: " .. currentDiscount .. "%", 0.8, 0.8, 0.8);
	GameTooltip:AddLine("Busca items al " .. threshold .. "% o menos del precio histórico", 0.7, 0.7, 0.7);
	GameTooltip:AddLine(" ");
	GameTooltip:AddLine("Configurable en:", 0.6, 0.6, 1);
	GameTooltip:AddLine("• Opciones de Interfaz > Addons > Auctionator", 0.5, 0.8, 1);
	GameTooltip:AddLine("• Comando: '/atrbargain set [%]'", 0.5, 0.8, 1);
	GameTooltip:Show();
end

-----------------------------------------
-- Función para configurar el porcentaje de descuento
-----------------------------------------
function Atr_SetBargainDiscount(discountPercent)
	if discountPercent and discountPercent >= 5 and discountPercent <= 80 then
		AUCTIONATOR_BARGAIN_DISCOUNT = discountPercent;
		Atr_SaveBargainConfig(); -- Guardar configuración
		local msg = string.format("Descuento mínimo establecido en %d%%", discountPercent);
		if zc and zc.msg_anm then
			zc.msg_anm(msg);
		else
			print("Auctionator: " .. msg);
		end
		return true;
	else
		local errorMsg = "El porcentaje debe estar entre 5% y 80%";
		if zc and zc.msg_anm then
			zc.msg_anm(errorMsg);
		else
			print("Auctionator: " .. errorMsg);
		end
		return false;
	end
end

-----------------------------------------
-- Hook para cuando se abra la pestaña de Buy de Auctionator
-----------------------------------------
local function OnAuctionatorBuyShow()
	-- Delay para asegurar que todos los frames están cargados
	Atr_Timer_After(0.5, function()
		if Atr_Buy1_Button and Atr_Buy1_Button:IsShown() then
			Atr_ShowBargainButton();
		end
	end);
end

-----------------------------------------
-- Event handler principal
-----------------------------------------
local bargainFrame = CreateFrame("Frame");
bargainFrame:RegisterEvent("AUCTION_HOUSE_SHOW");
bargainFrame:RegisterEvent("ADDON_LOADED");
bargainFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE");
bargainFrame:RegisterEvent("AUCTION_HOUSE_CLOSED");

bargainFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local addonName = ...;
		if addonName == "Auctionator" then
			-- Inicialización del addon
		end
	elseif event == "AUCTION_HOUSE_SHOW" then
		OnAuctionatorBuyShow();
	elseif event == "AUCTION_HOUSE_CLOSED" then
		-- Limpiar el botón cuando se cierre
		if Atr_BargainButton then
			Atr_BargainButton:Hide();
		end
		-- Detener cualquier escaneo en progreso
		isScanning = false;
		scanResults = {};
	elseif event == "AUCTION_ITEM_LIST_UPDATE" then
		if isScanning then
			Atr_Timer_After(0.5, Atr_ScanPageForBargains);
		end
	end
end);

-- Hook adicional para detectar cambios de pestañas - ya no necesario porque se maneja en Auctionator.lua
-- El botón se crea directamente desde la función Atr_AuctionFrameTab_OnClick

-----------------------------------------
-- Comandos slash para configurar el umbral y debuggear
-----------------------------------------
SLASH_ATRBARGAIN1 = "/atrbargain";
SLASH_ATRBARGAIN2 = "/atrgangas";
SLASH_ATRBARGAIN3 = "/atrofertas";

function SlashCmdList.ATRBARGAIN(msg)
	if msg == "test" or msg == "crear" then
		print("Auctionator: Forzando visualización del botón...");
		Atr_ShowBargainButton();
	elseif msg == "scan" or msg == "escanear" then
		print("Auctionator: Iniciando escaneo manual...");
		Atr_StartBargainScan();
	elseif msg:match("^set%s+(%d+)$") or msg:match("^establecer%s+(%d+)$") then
		local percent = tonumber(msg:match("(%d+)"));
		if percent and percent >= 5 and percent <= 80 then
			AUCTIONATOR_BARGAIN_DISCOUNT = percent;
			Atr_SaveBargainConfig();
			print("Auctionator: Descuento mínimo establecido en " .. percent .. "%");
			print("Ahora buscaré items con precios " .. percent .. "% más baratos que el histórico");
			print("Ejemplo: Si un item cuesta 100g normalmente, buscaré ofertas a " .. (100 - percent) .. "g o menos");
		else
			print("Auctionator: El porcentaje debe estar entre 5% y 80%");
			print("Ejemplos: '/atrbargain set 30' para 30% de descuento");
		end
	elseif msg == "show" or msg == "mostrar" then
		if Atr_BargainButton then
			Atr_BargainButton:Show();
			print("Auctionator: Mostrando botón existente");
		else
			print("Auctionator: El botón no existe todavía");
		end
	elseif msg == "check" or msg == "verificar" then
		print("=== DIAGNÓSTICO SISTEMA DE GANGAS ===");
		
		-- Verificar compatibilidad con Classic
		if Atr_VerifyClassicCompatibility() then
			print("✓ APIs de WoW: Disponibles y compatibles");
		else
			print("✗ APIs de WoW: No disponibles o incompatibles");
		end
		
		-- Verificar AUCTIONATOR_PRICING_HISTORY
		if AUCTIONATOR_PRICING_HISTORY then
			local count = 0;
			for k,v in pairs(AUCTIONATOR_PRICING_HISTORY) do
				count = count + 1;
				if count <= 3 then -- Mostrar primeros 3
					print(string.format("- %s: %s", k, v.price or "sin precio"));
				end
			end
			print(string.format("AUCTIONATOR_PRICING_HISTORY: %d items", count));
		else
			print("AUCTIONATOR_PRICING_HISTORY: NO EXISTE");
		end
		
		-- Verificar gAtrFullScanDB
		if gAtrFullScanDB then
			local count = 0;
			for k,v in pairs(gAtrFullScanDB) do
				count = count + 1;
			end
			print(string.format("gAtrFullScanDB: %d items", count));
		else
			print("gAtrFullScanDB: NO EXISTE");
		end
		
		-- Verificar funciones
		print("zc.msg_anm existe:", zc and zc.msg_anm and "SÍ" or "NO");
		print("zc.priceToMoneyString existe:", zc and zc.priceToMoneyString and "SÍ" or "NO");
		print("CanSendAuctionQuery existe:", CanSendAuctionQuery and "SÍ" or "NO");
		
		-- Mostrar configuración actual
		print("=== CONFIGURACIÓN ACTUAL ===");
		print("Descuento mínimo configurado: " .. AUCTIONATOR_BARGAIN_DISCOUNT .. "%");
		local threshold = Atr_GetBargainThreshold();
		print("Umbral de precio: " .. math.floor(threshold * 100) .. "% del precio histórico");
		print("Ejemplo: Si un item cuesta 100g, buscaré ofertas a " .. math.floor(threshold * 100) .. "g o menos");
		
		print("===============================");
	elseif msg == "debug" then
		print("=== DEBUG AUCTIONATOR BARGAIN BUTTON ===");
		print("Atr_BargainButton existe:", Atr_BargainButton and "SÍ" or "NO");
		if Atr_BargainButton then
			print("Atr_BargainButton visible:", Atr_BargainButton:IsShown() and "SÍ" or "NO");
		end
		print("Atr_Buy1_Button existe:", Atr_Buy1_Button and "SÍ" or "NO");
		print("AuctionFrame visible:", AuctionFrame and AuctionFrame:IsShown() and "SÍ" or "NO");
		if AuctionFrame then
			local tab = PanelTemplates_GetSelectedTab(AuctionFrame);
			print("Pestaña actual:", tab);
		end
		print("isScanning:", isScanning and "SÍ" or "NO");
		print("=====================================");
	else
		local threshold = tonumber(msg);
		if threshold then
			Atr_SetBargainThreshold(threshold / 100); -- Convertir porcentaje a decimal
		else
			local showMsg = "=== COMANDOS DISPONIBLES ===";
			if zc and zc.msg_anm then
				zc.msg_anm(showMsg);
				zc.msg_anm("/atrbargain scan - Iniciar búsqueda de gangas");
				zc.msg_anm("/atrbargain set [%] - Establecer descuento mínimo (5-80%)");
				zc.msg_anm("/atrbargain check - Verificar bases de datos");
				zc.msg_anm("/atrbargain stop - Detener búsqueda");
				zc.msg_anm("Descuento actual: " .. AUCTIONATOR_BARGAIN_DISCOUNT .. "%");
			else
				print(showMsg);
				print("/atrbargain scan - Iniciar búsqueda de gangas");
				print("/atrbargain set [%] - Establecer descuento mínimo (5-80%)");
				print("/atrbargain check - Verificar bases de datos");
				print("/atrbargain stop - Detener búsqueda");
				print("Descuento actual: " .. AUCTIONATOR_BARGAIN_DISCOUNT .. "%");
			end
		end
	end
end

-----------------------------------------
-- Evento para cargar configuración al iniciar
-----------------------------------------
local configFrame = CreateFrame("Frame");
configFrame:RegisterEvent("ADDON_LOADED");
configFrame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "Auctionator" then
		Atr_LoadBargainConfig();
		self:UnregisterEvent("ADDON_LOADED");
	end
end);