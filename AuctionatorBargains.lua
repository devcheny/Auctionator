-- AuctionatorBargains.lua
-- Sistema de búsqueda automática de ofertas basado en historial de precios

local addonName, addonTable = ...; 
local zc = addonTable.zc;

-- NO inicializar las variables aquí, se cargarán en ADDON_LOADED

print("DEBUG: AuctionatorBargains.lua cargado, esperando ADDON_LOADED para inicializar variables");

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

-- Función de depuración para verificar persistencia
function Atr_DebugPersistence()
    print("=== DEBUG PERSISTENCIA ===");
    print("AUCTIONATOR_SAVEDVARS existe:", AUCTIONATOR_SAVEDVARS ~= nil, "(tipo:", type(AUCTIONATOR_SAVEDVARS), ")");
    
    if AUCTIONATOR_SAVEDVARS then
        print("SAVEDVARS.BARGAIN_DISCOUNT:", AUCTIONATOR_SAVEDVARS.BARGAIN_DISCOUNT);
        print("SAVEDVARS.IDEAL_PRICES existe:", AUCTIONATOR_SAVEDVARS.IDEAL_PRICES ~= nil);
        print("SAVEDVARS.CURRENT_DEALS existe:", AUCTIONATOR_SAVEDVARS.CURRENT_DEALS ~= nil);
    end
    
    print("AUCTIONATOR_BARGAIN_DISCOUNT:", AUCTIONATOR_BARGAIN_DISCOUNT, "(tipo:", type(AUCTIONATOR_BARGAIN_DISCOUNT), ")");
    print("AUCTIONATOR_IDEAL_PRICES existe:", AUCTIONATOR_IDEAL_PRICES ~= nil, "(tipo:", type(AUCTIONATOR_IDEAL_PRICES), ")");
    print("AUCTIONATOR_CURRENT_DEALS existe:", AUCTIONATOR_CURRENT_DEALS ~= nil, "(tipo:", type(AUCTIONATOR_CURRENT_DEALS), ")");
    
    if AUCTIONATOR_IDEAL_PRICES then
        local count = 0;
        for itemName, data in pairs(AUCTIONATOR_IDEAL_PRICES) do
            count = count + 1;
            print("  - " .. itemName .. ": " .. (data.price or "nil") .. " oro, habilitado: " .. tostring(data.enabled), "(timestamp: " .. (data.timestamp or "nil") .. ")");
        end
        print("Total precios ideales:", count);
    else
        print("¡AUCTIONATOR_IDEAL_PRICES es nil!");
    end
    print("========================");
end

-- Función para agregar un precio ideal de prueba
function Atr_AddTestIdealPrice()
    if not AUCTIONATOR_IDEAL_PRICES then
        AUCTIONATOR_IDEAL_PRICES = {};
    end
    
    local testItem = "Poción de curación menor";
    AUCTIONATOR_IDEAL_PRICES[testItem] = {
        price = 0.5,
        enabled = true,
        timestamp = time()
    };
    
    print("DEBUG: Precio ideal de prueba agregado para:", testItem);
    Atr_SaveBargainConfig();
end

-- Comando para verificar persistencia
SLASH_ATRDEBUG1 = "/atrdebug";
SlashCmdList["ATRDEBUG"] = Atr_DebugPersistence;

-- Comando para agregar precio de prueba
SLASH_ATRTEST1 = "/atrtest";
SlashCmdList["ATRTEST"] = Atr_AddTestIdealPrice;

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

-- Sistema de precios ideales y ofertas del momento
if not AUCTIONATOR_IDEAL_PRICES then
    AUCTIONATOR_IDEAL_PRICES = {}; -- [itemName] = { price = number, enabled = true }
end

if not AUCTIONATOR_CURRENT_DEALS then
    AUCTIONATOR_CURRENT_DEALS = {}; -- Lista de ofertas encontradas
end

-- Variables para búsqueda individual de items
local currentItemSearch = {
    items = {},
    currentIndex = 0,
    isScanning = false,
    callback = nil
};

-- Función para guardar la configuración
function Atr_SaveBargainConfig()
    -- Usar el sistema de persistencia de Auctionator existente
    if not AUCTIONATOR_SAVEDVARS then
        AUCTIONATOR_SAVEDVARS = {};
        print("DEBUG: Inicializando AUCTIONATOR_SAVEDVARS");
    end
    
    -- Guardar en la estructura de Auctionator
    AUCTIONATOR_SAVEDVARS.BARGAIN_DISCOUNT = AUCTIONATOR_BARGAIN_DISCOUNT;
    AUCTIONATOR_SAVEDVARS.IDEAL_PRICES = AUCTIONATOR_IDEAL_PRICES;
    AUCTIONATOR_SAVEDVARS.CURRENT_DEALS = AUCTIONATOR_CURRENT_DEALS;
    
    local idealCount = 0;
    if AUCTIONATOR_IDEAL_PRICES then
        for _ in pairs(AUCTIONATOR_IDEAL_PRICES) do
            idealCount = idealCount + 1;
        end
    end
    
    print("DEBUG: Configuración guardada en AUCTIONATOR_SAVEDVARS - Descuento: " .. (AUCTIONATOR_BARGAIN_DISCOUNT or "N/A") .. "%, Precios ideales: " .. idealCount);
end

-- Función para cargar la configuración
function Atr_LoadBargainConfig()
    print("DEBUG: Atr_LoadBargainConfig iniciando...");
    
    -- Asegurar que AUCTIONATOR_SAVEDVARS existe
    if not AUCTIONATOR_SAVEDVARS then
        AUCTIONATOR_SAVEDVARS = {};
        print("DEBUG: AUCTIONATOR_SAVEDVARS no existía, inicializando");
    end
    
    print("DEBUG: Estado de AUCTIONATOR_SAVEDVARS:", AUCTIONATOR_SAVEDVARS ~= nil);
    
    -- Cargar desde AUCTIONATOR_SAVEDVARS si existe
    if AUCTIONATOR_SAVEDVARS.BARGAIN_DISCOUNT then
        AUCTIONATOR_BARGAIN_DISCOUNT = AUCTIONATOR_SAVEDVARS.BARGAIN_DISCOUNT;
        print("DEBUG: Descuento cargado desde SAVEDVARS:", AUCTIONATOR_BARGAIN_DISCOUNT);
    else
        AUCTIONATOR_BARGAIN_DISCOUNT = 25;
        AUCTIONATOR_SAVEDVARS.BARGAIN_DISCOUNT = AUCTIONATOR_BARGAIN_DISCOUNT;
        print("DEBUG: Inicializando descuento por defecto: 25%");
    end
    
    if AUCTIONATOR_SAVEDVARS.IDEAL_PRICES then
        AUCTIONATOR_IDEAL_PRICES = AUCTIONATOR_SAVEDVARS.IDEAL_PRICES;
        print("DEBUG: Precios ideales cargados desde SAVEDVARS");
    else
        AUCTIONATOR_IDEAL_PRICES = {};
        AUCTIONATOR_SAVEDVARS.IDEAL_PRICES = AUCTIONATOR_IDEAL_PRICES;
        print("DEBUG: Inicializando tabla de precios ideales vacía");
    end
    
    if AUCTIONATOR_SAVEDVARS.CURRENT_DEALS then
        AUCTIONATOR_CURRENT_DEALS = AUCTIONATOR_SAVEDVARS.CURRENT_DEALS;
        print("DEBUG: Ofertas actuales cargadas desde SAVEDVARS");
    else
        AUCTIONATOR_CURRENT_DEALS = {};
        AUCTIONATOR_SAVEDVARS.CURRENT_DEALS = AUCTIONATOR_CURRENT_DEALS;
        print("DEBUG: Inicializando tabla de ofertas actuales vacía");
    end
    
    -- Contar precios ideales cargados
    local idealCount = 0;
    for itemName, data in pairs(AUCTIONATOR_IDEAL_PRICES) do
        idealCount = idealCount + 1;
        print("DEBUG: Precio ideal cargado -", itemName, ":", data.price, "oro, habilitado:", data.enabled);
    end
    
    print("DEBUG: Configuración final - Descuento: " .. AUCTIONATOR_BARGAIN_DISCOUNT .. "%, Precios ideales: " .. idealCount);
    
    -- Limpiar ofertas antiguas al cargar
    if Atr_CleanOldDeals then
        Atr_CleanOldDeals();
    end
    
    -- Actualizar slider si está disponible
    if Atr_UpdateBargainDiscountSlider then
        Atr_UpdateBargainDiscountSlider();
    end
    
    print("DEBUG: Atr_LoadBargainConfig completado");
end

-- Función para establecer precio ideal de un item
function Atr_SetIdealPrice(itemName, price)
    if not itemName or not price or price <= 0 then
        return false;
    end
    
    AUCTIONATOR_IDEAL_PRICES[itemName] = {
        price = price,
        enabled = true,
        timestamp = time()
    };
    
    return true;
end

-- Función para obtener precio ideal de un item
function Atr_GetIdealPrice(itemName)
    if AUCTIONATOR_IDEAL_PRICES[itemName] and AUCTIONATOR_IDEAL_PRICES[itemName].enabled then
        return AUCTIONATOR_IDEAL_PRICES[itemName].price;
    end
    return nil;
end

-- Función para agregar una oferta a la lista del momento
local function Atr_AddCurrentDeal(itemName, price, seller, timeLeft, buyoutPrice)
    local deal = {
        itemName = itemName,
        price = price,
        seller = seller,
        timeLeft = timeLeft,
        buyoutPrice = buyoutPrice,
        timestamp = time(),
        idealPrice = Atr_GetIdealPrice(itemName)
    };
    
    table.insert(AUCTIONATOR_CURRENT_DEALS, deal);
end

-- Función para limpiar ofertas antiguas (más de 1 hora)
-- Función para limpiar ofertas antiguas
function Atr_CleanOldDeals()
    local currentTime = time();
    local i = 1;
    while i <= #AUCTIONATOR_CURRENT_DEALS do
        if currentTime - AUCTIONATOR_CURRENT_DEALS[i].timestamp > 3600 then -- 1 hora
            table.remove(AUCTIONATOR_CURRENT_DEALS, i);
        else
            i = i + 1;
        end
    end
end
local function Atr_SearchSingleItem(itemName, callback)
    if not itemName or currentItemSearch.isScanning then
        if callback then callback(false, "Ya hay una búsqueda en curso o item inválido"); end
        return false;
    end
    
    currentItemSearch.isScanning = true;
    currentItemSearch.callback = callback;
    
    -- Limpiar ofertas antiguas antes de buscar
    Atr_CleanOldDeals();
    
    print("Buscando ofertas para: " .. itemName);
    
    -- Realizar consulta específica del item
    QueryAuctionItems(itemName, nil, nil, nil, nil, nil, false);
    
    return true;
end

-- Función para procesar resultados de búsqueda individual
local function Atr_ProcessSingleItemResults(itemName)
    if not GetNumAuctionItems or not currentItemSearch.isScanning then
        return;
    end
    
    local numAuctions = GetNumAuctionItems("list");
    local idealPrice = Atr_GetIdealPrice(itemName);
    local foundDeals = 0;
    
    if idealPrice then
        for i = 1, numAuctions do
            local name, texture, count, quality, canUse, level, minBid, minIncrement, buyout, bidAmount, highBidder, owner = GetAuctionItemInfo("list", i);
            
            if name and name == itemName and buyout > 0 then
                local unitPrice = buyout / count;
                
                -- Si el precio por unidad es menor o igual al ideal
                if unitPrice <= idealPrice then
                    Atr_AddCurrentDeal(name, unitPrice, owner or "Desconocido", "Desconocido", buyout);
                    foundDeals = foundDeals + 1;
                end
            end
        end
    end
    
    currentItemSearch.isScanning = false;
    
    if currentItemSearch.callback then
        currentItemSearch.callback(true, foundDeals .. " ofertas encontradas para " .. itemName);
    end
    
    return foundDeals;
end

-- Función para buscar ofertas de toda la lista de compra seleccionada
function Atr_SearchShoppingListDeals()
    local selectedItems = Atr_GetCurrentShoppingListItems();
    
    if not selectedItems or #selectedItems == 0 then
        print("No hay items en la lista de compra seleccionada");
        return;
    end
    
    currentItemSearch.items = {};
    currentItemSearch.currentIndex = 0;
    
    -- Filtrar solo items que tengan precio ideal configurado
    for _, itemName in ipairs(selectedItems) do
        if Atr_GetIdealPrice(itemName) then
            table.insert(currentItemSearch.items, itemName);
        end
    end
    
    if #currentItemSearch.items == 0 then
        print("No hay items con precio ideal configurado en la lista");
        return;
    end
    
    print("Iniciando búsqueda de " .. #currentItemSearch.items .. " items con precio ideal...");
    Atr_SearchNextItem();
end

-- Función para buscar el siguiente item en la cola
function Atr_SearchNextItem()
    if currentItemSearch.currentIndex >= #currentItemSearch.items then
        print("Búsqueda de ofertas completada. Revisar lista de ofertas del momento.");
        Atr_ShowCurrentDeals();
        return;
    end
    
    currentItemSearch.currentIndex = currentItemSearch.currentIndex + 1;
    local itemName = currentItemSearch.items[currentItemSearch.currentIndex];
    
    Atr_SearchSingleItem(itemName, function(success, message)
        print(message);
        -- Continuar con el siguiente item después de un breve delay
        Atr_Timer_After(1, Atr_SearchNextItem);
    end);
end

-- Función para mostrar ofertas del momento
function Atr_ShowCurrentDeals()
    Atr_CleanOldDeals(); -- Limpiar ofertas antiguas
    
    if #AUCTIONATOR_CURRENT_DEALS == 0 then
        print("|cffff8000=== OFERTAS DEL MOMENTO ===|r");
        print("No hay ofertas disponibles actualmente.");
        print("Tip: Usa /atrideal para configurar precios ideales.");
        return;
    end
    
    print("|cffff8000=== OFERTAS DEL MOMENTO (" .. #AUCTIONATOR_CURRENT_DEALS .. " ofertas) ===|r");
    
    -- Ordenar ofertas por diferencia de precio (mejores ofertas primero)
    local sortedDeals = {};
    for i, deal in ipairs(AUCTIONATOR_CURRENT_DEALS) do
        table.insert(sortedDeals, deal);
    end
    
    table.sort(sortedDeals, function(a, b)
        local discountA = ((a.idealPrice - a.price) / a.idealPrice) * 100;
        local discountB = ((b.idealPrice - b.price) / b.idealPrice) * 100;
        return discountA > discountB;
    end);
    
    for i, deal in ipairs(sortedDeals) do
        local discount = math.floor(((deal.idealPrice - deal.price) / deal.idealPrice) * 100);
        local priceColor = "|cff00ff00"; -- Verde para buenos precios
        if discount < 10 then
            priceColor = "|cffffff00"; -- Amarillo para descuentos menores
        end
        
        print(string.format("%s%d. %s|r - %s%s|r (Ideal: %s) [%d%% desc.] - %s",
            priceColor,
            i,
            deal.itemName,
            priceColor,
            Atr_FormatPrice(deal.price * 100), -- Convertir a copper
            Atr_FormatPrice(deal.idealPrice * 100),
            discount,
            deal.seller
        ));
    end
    
    print("|cffff8000========================|r");
end

-- Función para limpiar todas las ofertas del momento
function Atr_ClearCurrentDeals()
    AUCTIONATOR_CURRENT_DEALS = {};
    print("Lista de ofertas del momento limpiada.");
end

-- Función para obtener el threshold actual (convierte % a decimal)
local function Atr_GetBargainThreshold()
    return (100 - AUCTIONATOR_BARGAIN_DISCOUNT) / 100;
end

-- Función para obtener los items de la shopping list activa
function Atr_GetCurrentShoppingListItems()
    local items = {};
    
    -- Debugging: verificar todas las fuentes posibles
    print("=== DEBUG: Verificando shopping lists ===");
    print("_G.gCurrentSList existe:", _G.gCurrentSList and "SÍ" or "NO");
    print("AUCTIONATOR_SHOPPING_LISTS existe:", AUCTIONATOR_SHOPPING_LISTS and "SÍ" or "NO");
    
    -- Método 1: Intentar con gCurrentSList
    if _G.gCurrentSList and _G.gCurrentSList.items then
        print("Usando gCurrentSList - Lista:", _G.gCurrentSList.name or "Sin nombre");
        print("Items en gCurrentSList:", #_G.gCurrentSList.items);
        for _, itemName in ipairs(_G.gCurrentSList.items) do
            if itemName and itemName ~= "" then
                table.insert(items, itemName);
                print("  - " .. itemName);
            end
        end
    -- Método 2: Usar AUCTIONATOR_SHOPPING_LISTS directamente
    elseif AUCTIONATOR_SHOPPING_LISTS and #AUCTIONATOR_SHOPPING_LISTS > 0 then
        print("Usando AUCTIONATOR_SHOPPING_LISTS - Listas disponibles:", #AUCTIONATOR_SHOPPING_LISTS);
        -- Buscar la lista activa usando el dropdown
        local selectedValue = 1; -- Por defecto la primera
        if Atr_DropDownSL and UIDropDownMenu_GetSelectedValue then
            selectedValue = UIDropDownMenu_GetSelectedValue(Atr_DropDownSL) or 1;
        end
        
        local selectedList = AUCTIONATOR_SHOPPING_LISTS[selectedValue];
        if selectedList and selectedList.items then
            print("Lista seleccionada:", selectedList.name or "Sin nombre");
            print("Items en lista seleccionada:", #selectedList.items);
            for _, itemName in ipairs(selectedList.items) do
                if itemName and itemName ~= "" then
                    table.insert(items, itemName);
                    print("  - " .. itemName);
                end
            end
        end
    else
        print("No se encontraron shopping lists disponibles");
    end
    
    print("Total items encontrados:", #items);
    print("=== FIN DEBUG ===");
    
    return items;
end

-- Función para verificar si un item está en la shopping list
local function Atr_IsItemInShoppingList(itemName)
    -- Método 1: Intentar con gCurrentSList
    if _G.gCurrentSList and _G.gCurrentSList.items then
        for _, listItem in ipairs(_G.gCurrentSList.items) do
            if listItem and zc.StringSame(itemName, listItem) then
                return true;
            end
        end
    end
    
    -- Método 2: Usar AUCTIONATOR_SHOPPING_LISTS directamente
    if AUCTIONATOR_SHOPPING_LISTS and #AUCTIONATOR_SHOPPING_LISTS > 0 then
        local selectedValue = 1;
        if Atr_DropDownSL and UIDropDownMenu_GetSelectedValue then
            selectedValue = UIDropDownMenu_GetSelectedValue(Atr_DropDownSL) or 1;
        end
        
        local selectedList = AUCTIONATOR_SHOPPING_LISTS[selectedValue];
        if selectedList and selectedList.items then
            for _, listItem in ipairs(selectedList.items) do
                if listItem and zc.StringSame(itemName, listItem) then
                    return true;
                end
            end
        end
    end
    
    return false;
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
		
		if name and buyoutPrice and buyoutPrice > 0 then
			-- Solo verificar items que están en la shopping list
			if Atr_IsItemInShoppingList(name) then
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
	
	-- Verificar que hay una shopping list seleccionada con items
	local shoppingItems = Atr_GetCurrentShoppingListItems();
	if #shoppingItems == 0 then
		if zc and zc.msg_anm then
			zc.msg_anm("No hay items en la lista de compra seleccionada");
		else
			print("Auctionator: No hay items en la lista de compra seleccionada");
		end
		return;
	end
	
	-- Mensaje de debug
	local listName = "Lista desconocida";
	if _G.gCurrentSList and _G.gCurrentSList.name then
		listName = _G.gCurrentSList.name;
	elseif AUCTIONATOR_SHOPPING_LISTS and #AUCTIONATOR_SHOPPING_LISTS > 0 then
		local selectedValue = 1;
		if Atr_DropDownSL and UIDropDownMenu_GetSelectedValue then
			selectedValue = UIDropDownMenu_GetSelectedValue(Atr_DropDownSL) or 1;
		end
		local selectedList = AUCTIONATOR_SHOPPING_LISTS[selectedValue];
		if selectedList and selectedList.name then
			listName = selectedList.name;
		end
	end
	print("Auctionator: Buscando ofertas para " .. #shoppingItems .. " items de '" .. listName .. "'...");
	
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
	-- Solo mostrar en la pestaña Buy (BUY_TAB = 3)
	if Atr_IsTabSelected and Atr_IsTabSelected(3) then -- BUY_TAB
		if Atr_BargainButton then
			Atr_BargainButton:Show();
		end
	else
		if Atr_BargainButton then
			Atr_BargainButton:Hide();
		end
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
-- Función para verificar y actualizar visibilidad de los botones
-----------------------------------------
local function Atr_UpdateBargainButtonVisibility()
	-- Verificar si estamos en la casa de subastas
	if not AuctionFrame or not AuctionFrame:IsShown() then
		if Atr_BargainButton then Atr_BargainButton:Hide(); end
		if Atr_DealsButton then Atr_DealsButton:Hide(); end
		if Atr_ShowDealsButton then Atr_ShowDealsButton:Hide(); end
		return;
	end
	
	-- Solo mostrar en la pestaña Buy de Auctionator
	if Atr_IsTabSelected and Atr_IsTabSelected(3) then -- BUY_TAB = 3
		if Atr_BargainButton then Atr_BargainButton:Show(); end
		if Atr_DealsButton then Atr_DealsButton:Show(); end
		if Atr_ShowDealsButton then Atr_ShowDealsButton:Show(); end
	else
		if Atr_BargainButton then Atr_BargainButton:Hide(); end
		if Atr_DealsButton then Atr_DealsButton:Hide(); end
		if Atr_ShowDealsButton then Atr_ShowDealsButton:Hide(); end
	end
end

-----------------------------------------
-- Función para mostrar tooltip dinámico del botón de gangas
-----------------------------------------
function Atr_ShowBargainButtonTooltip(button)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
	GameTooltip:SetText("Buscador de Ofertas", 1, 1, 1);
	GameTooltip:AddLine("Busca ofertas de los items en tu lista de compra seleccionada.", 1, 1, 1, true);
	GameTooltip:AddLine(" ");
	
	-- Mostrar información de la shopping list con métodos alternativos
	local currentList = _G.gCurrentSList;
	local listName = "Sin lista";
	local itemCount = 0;
	
	if currentList and currentList.items then
		listName = currentList.name or "Sin nombre";
		itemCount = #currentList.items;
	elseif AUCTIONATOR_SHOPPING_LISTS and #AUCTIONATOR_SHOPPING_LISTS > 0 then
		local selectedValue = 1;
		if Atr_DropDownSL and UIDropDownMenu_GetSelectedValue then
			selectedValue = UIDropDownMenu_GetSelectedValue(Atr_DropDownSL) or 1;
		end
		local selectedList = AUCTIONATOR_SHOPPING_LISTS[selectedValue];
		if selectedList then
			listName = selectedList.name or "Sin nombre";
			itemCount = selectedList.items and #selectedList.items or 0;
		end
	end
	
	GameTooltip:AddLine("Lista activa: " .. listName, 0.8, 1, 0.8);
	GameTooltip:AddLine("Items en la lista: " .. itemCount, 0.7, 0.7, 0.7);
	
	if itemCount == 0 then
		GameTooltip:AddLine("⚠ No hay items en la lista", 1, 0.5, 0.5);
	end
	
	GameTooltip:AddLine(" ");
	local currentDiscount = AUCTIONATOR_BARGAIN_DISCOUNT or 30;
	local threshold = 100 - currentDiscount;
	GameTooltip:AddLine("Descuento mínimo: " .. currentDiscount .. "%", 0.8, 0.8, 0.8);
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
			-- Cargar configuración de bargains
			Atr_LoadBargainConfig();
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
		elseif currentItemSearch.isScanning then
			-- Procesar resultados de búsqueda individual
			local currentItemName = currentItemSearch.items[currentItemSearch.currentIndex];
			if currentItemName then
				Atr_Timer_After(0.5, function()
					Atr_ProcessSingleItemResults(currentItemName);
				end);
			end
		end
	end
end);

-- Hook adicional para detectar cambios de pestañas - ya no necesario porque se maneja en Auctionator.lua
-- El botón se crea directamente desde la función Atr_AuctionFrameTab_OnClick

-----------------------------------------
-- Funciones para el campo de precio ideal en la UI
-----------------------------------------

-- Función llamada cuando cambia el texto del campo precio ideal
function Atr_IdealPriceOnTextChanged(editBox)
    local text = editBox:GetText();
    -- Validar que solo contenga números y puntos
    if text and text ~= "" then
        local filteredText = text:gsub("[^%d%.]", "");
        if filteredText ~= text then
            editBox:SetText(filteredText);
        end
    end
end

-- Función llamada cuando se presiona Enter en el campo precio ideal
function Atr_IdealPriceOnEnterPressed(editBox)
    local priceText = editBox:GetText();
    
    if not priceText or priceText == "" then
        return;
    end
    
    -- Parsear diferentes formatos de precio (ej: "5g", "50s", "123c", "1.5g", etc.)
    local price = Atr_ParsePriceInput(priceText);
    
    if not price or price <= 0 then
        print("Precio inválido. Usa formato como: 5g, 50s, 123c, o 1.5g");
        editBox:SetText("");
        return;
    end
    
    -- Obtener el nombre del item de la entrada correspondiente
    local entryButton = editBox:GetParent():GetParent();
    local itemName = Atr_GetItemNameFromEntry(entryButton);
    
    if itemName then
        -- Convertir precio a formato decimal (oro)
        local priceInGold = price / 10000;
        
        if Atr_SetIdealPrice(itemName, priceInGold) then
            print("Precio ideal configurado: " .. itemName .. " = " .. Atr_FormatPrice(price));
            -- Actualizar la visualización del precio
            Atr_UpdateIdealPriceDisplay(editBox, price);
            Atr_SaveBargainConfig(); -- Guardar inmediatamente
        else
            print("Error al configurar precio ideal.");
            editBox:SetText("");
        end
    else
        print("No se pudo determinar el item.");
        editBox:SetText("");
    end
end

-- Función helper para parsear entrada de precio del usuario
function Atr_ParsePriceInput(text)
    if not text or text == "" then
        return nil;
    end
    
    text = text:lower():trim();
    local copper = 0;
    
    -- Formato con g, s, c (ej: "1g50s25c", "5g", "50s", "123c")
    local gold = text:match("([%d%.]+)g");
    local silver = text:match("([%d%.]+)s"); 
    local copperStr = text:match("([%d%.]+)c");
    
    if gold then
        copper = copper + (tonumber(gold) * 10000);
    end
    if silver then
        copper = copper + (tonumber(silver) * 100);
    end
    if copperStr then
        copper = copper + tonumber(copperStr);
    end
    
    -- Si no hay sufijos, asumir que es oro
    if not gold and not silver and not copperStr then
        local num = tonumber(text);
        if num then
            copper = num * 10000; -- Asumir oro
        end
    end
    
    return math.floor(copper);
end

-- Función para obtener el nombre del item de una entrada
function Atr_GetItemNameFromEntry(entryButton)
    if not entryButton then
        return nil;
    end
    
    -- Buscar el texto del item en la entrada
    local entryText = entryButton:GetName() .. "_EntryText";
    local textFrame = _G[entryText];
    
    if textFrame then
        local text = textFrame:GetText();
        if text then
            -- Extraer el nombre del item (quitar cantidad y otros modificadores)
            -- Formato típico: "Nombre del Item x5" o "Nombre del Item"
            local itemName = text:match("^(.-)%s*x?%d*$");
            if itemName and itemName ~= "" then
                return itemName:trim();
            end
            
            -- Fallback: usar todo el texto si no se puede parsear
            return text:trim();
        end
    end
    
    return nil;
end

-- Función para colorear el campo de precio según si es una buena oferta
function Atr_ColorIdealPriceField(editBox, itemName, currentPrice)
    if not editBox or not itemName then
        return;
    end
    
    local idealPrice = Atr_GetIdealPrice(itemName);
    if not idealPrice or not currentPrice then
        editBox:SetTextColor(1, 1, 1); -- Blanco por defecto
        return;
    end
    
    -- Comparar precio actual con precio ideal
    local idealPriceCopper = idealPrice * 10000;
    
    if currentPrice <= idealPriceCopper then
        editBox:SetTextColor(0, 1, 0); -- Verde: buen precio
    elseif currentPrice <= idealPriceCopper * 1.2 then
        editBox:SetTextColor(1, 1, 0); -- Amarillo: precio aceptable
    else
        editBox:SetTextColor(1, 0.5, 0.5); -- Rojo claro: precio alto
    end
end

-- Función para actualizar la visualización del precio ideal
function Atr_UpdateIdealPriceDisplay(editBox, price)
    if price and price > 0 then
        -- Mostrar el precio en formato más legible
        if price >= 10000 then
            -- Si es mayor a 1 oro, mostrar en formato oro
            local gold = price / 10000;
            editBox:SetText(string.format("%.2fg", gold));
        elseif price >= 100 then
            -- Si es mayor a 1 plata, mostrar en formato plata
            local silver = price / 100;
            editBox:SetText(string.format("%.1fs", silver));
        else
            -- Mostrar en cobre
            editBox:SetText(string.format("%dc", price));
        end
    else
        editBox:SetText("");
    end
end

-- Función helper para formatear precios en formato legible (oro/plata/cobre)
function Atr_FormatPrice(copper)
    if not copper or copper <= 0 then
        return "0c";
    end
    
    local gold = math.floor(copper / 10000);
    local silver = math.floor((copper % 10000) / 100);
    local copperAmount = copper % 100;
    
    local result = "";
    
    if gold > 0 then
        result = gold .. "g";
        if silver > 0 then
            result = result .. " " .. silver .. "s";
        end
        if copperAmount > 0 then
            result = result .. " " .. copperAmount .. "c";
        end
    elseif silver > 0 then
        result = silver .. "s";
        if copperAmount > 0 then
            result = result .. " " .. copperAmount .. "c";
        end
    else
        result = copperAmount .. "c";
    end
    
    return result;
end

-- Función helper para remover espacios al inicio y final de strings
if not string.trim then
    function string.trim(s)
        return (s:gsub("^%s*(.-)%s*$", "%1"));
    end
end

-- Hook para actualizar precios ideales cuando se actualice la lista de Auctionator
local function Atr_HookAuctionatorDisplay()
    -- Hook a la función que actualiza la visualización de Auctionator
    if Atr_RedisplayAuctions then
        local original_Atr_RedisplayAuctions = Atr_RedisplayAuctions;
        
        Atr_RedisplayAuctions = function(...)
            -- Llamar la función original
            original_Atr_RedisplayAuctions(...);
            
            -- Actualizar precios ideales después de un pequeño delay
            Atr_Timer_After(0.1, Atr_LoadIdealPricesInEntries);
        end
    end
end

-- Hook para mostrar la interfaz de precio ideal cuando se busque un item
local function Atr_HookSearchFunction()
    if Atr_Search_Onclick then
        local original_Atr_Search_Onclick = Atr_Search_Onclick;
        
        Atr_Search_Onclick = function(...)
            -- Llamar la función original
            original_Atr_Search_Onclick(...);
            
            -- Obtener el texto de búsqueda y mostrar la interfaz de precio ideal
            Atr_Timer_After(0.5, function()
                local searchText = "";
                if Atr_Search_Box and Atr_Search_Box:GetText() then
                    searchText = Atr_Search_Box:GetText():trim();
                end
                
                if searchText and searchText ~= "" then
                    Atr_ShowIdealPriceForItem(searchText);
                else
                    Atr_HideIdealPriceInterface();
                end
            end);
        end
    end
end

-- Función para inicializar los hooks cuando el addon esté listo
local function Atr_InitializeIdealPriceHooks()
    Atr_Timer_After(2, function()
        Atr_HookAuctionatorDisplay();
        Atr_HookSearchFunction();
        print("Sistema de precios ideales inicializado en la interfaz.");
    end);
end

-- Función para cargar precios ideales en las entradas visibles
function Atr_LoadIdealPricesInEntries()
    for i = 1, 15 do -- Auctionator tiene 15 entradas
        local entryName = "AuctionatorEntry" .. i;
        local entry = _G[entryName];
        
        if entry and entry:IsShown() then
            local itemName = Atr_GetItemNameFromEntry(entry);
            if itemName then
                local idealPrice = Atr_GetIdealPrice(itemName);
                local editBox = _G[entryName .. "_IdealPrice"];
                
                if editBox and idealPrice then
                    Atr_UpdateIdealPriceDisplay(editBox, idealPrice * 100); -- Convertir a copper
                elseif editBox then
                    editBox:SetText(""); -- Limpiar si no hay precio ideal
                end
            end
        end
    end
end

-- Función para cargar precios ideales en las entradas visibles
function Atr_LoadIdealPricesInEntries()
    for i = 1, 15 do -- Auctionator tiene 15 entradas
        local entryName = "AuctionatorEntry" .. i;
        local entry = _G[entryName];
        
        if entry and entry:IsShown() then
            local itemName = Atr_GetItemNameFromEntry(entry);
            if itemName then
                local idealPrice = Atr_GetIdealPrice(itemName);
                local editBox = _G[entryName .. "_IdealPrice"];
                
                if editBox and idealPrice then
                    Atr_UpdateIdealPriceDisplay(editBox, idealPrice * 100); -- Convertir a copper
                elseif editBox then
                    editBox:SetText(""); -- Limpiar si no hay precio ideal
                end
            end
        end
    end
end

-----------------------------------------
-- Comandos slash para precios ideales
-----------------------------------------
SLASH_ATRIDEAL1 = "/atrideal";
SLASH_ATRIDEAL2 = "/precioideal";

function SlashCmdList.ATRIDEAL(msg)
	local itemName, priceStr = msg:match("^(.-)%s+([%d%.]+)$");
	
	if itemName and priceStr then
		local price = tonumber(priceStr);
		if price and price > 0 then
			if Atr_SetIdealPrice(itemName, price) then
				print("Precio ideal configurado: " .. itemName .. " = " .. Atr_FormatPrice(price * 100));
			else
				print("Error al configurar precio ideal.");
			end
		else
			print("Precio invalido. Usa: /atrideal [NombreItem] [Precio]");
		end
	elseif msg == "list" or msg == "lista" then
		local count = 0;
		print("|cffff8000=== PRECIOS IDEALES CONFIGURADOS ===|r");
		for itemName, data in pairs(AUCTIONATOR_IDEAL_PRICES) do
			if data.enabled then
				count = count + 1;
				print(count .. ". " .. itemName .. " - " .. Atr_FormatPrice(data.price * 100));
			end
		end
		if count == 0 then
			print("No hay precios ideales configurados.");
		end
		print("|cffff8000================================|r");
	elseif msg == "clear" or msg == "limpiar" then
		AUCTIONATOR_IDEAL_PRICES = {};
		print("Precios ideales limpiados.");
	else
		print("|cffff8000=== COMANDOS DE PRECIO IDEAL ===|r");
		print("/atrideal [Item] [Precio] - Configurar precio ideal");
		print("/atrideal list - Ver precios configurados");
		print("/atrideal clear - Limpiar todos los precios");
		print("Ejemplo: /atrideal [Copper Ore] 25");
		print("|cffff8000============================|r");
	end
end
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
	elseif msg == "shoplist" or msg == "lista" then
		print("Auctionator: Buscando ofertas en lista de compra...");
		Atr_SearchShoppingListDeals();
	elseif msg == "ofertas" or msg == "deals" then
		Atr_ShowCurrentDeals();
	elseif msg == "clear" or msg == "limpiar" then
		Atr_ClearCurrentDeals();
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
		
		-- Mostrar información de la shopping list
		print("=== LISTA DE COMPRA ACTIVA ===");
		local currentList = _G.gCurrentSList;
		if currentList and currentList.items then
			local itemCount = #currentList.items;
			print("Lista seleccionada: " .. (currentList.name or "Sin nombre"));
			print("Items en la lista: " .. itemCount);
			if itemCount > 0 then
				print("Primeros items:");
				for i = 1, math.min(5, itemCount) do
					print("  " .. i .. ". " .. (currentList.items[i] or "Item vacío"));
				end
				if itemCount > 5 then
					print("  ... y " .. (itemCount - 5) .. " más");
				end
			else
				print("⚠ No hay items en la lista");
			end
		else
			print("⚠ No hay lista de compra seleccionada");
		end
		
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
			if Atr_IsTabSelected then
				print("¿En pestaña Buy (3)?", Atr_IsTabSelected(3) and "SÍ" or "NO");
			end
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
				zc.msg_anm("/atrbargain shoplist - Buscar ofertas en lista de compra");
				zc.msg_anm("/atrbargain ofertas - Mostrar ofertas del momento");
				zc.msg_anm("/atrbargain clear - Limpiar ofertas del momento");
				zc.msg_anm("/atrbargain set [%] - Establecer descuento mínimo (5-80%)");
				zc.msg_anm("/atrbargain check - Verificar bases de datos");
				zc.msg_anm("/atrbargain stop - Detener búsqueda");
				zc.msg_anm("Descuento actual: " .. AUCTIONATOR_BARGAIN_DISCOUNT .. "%");
			else
				print(showMsg);
				print("/atrbargain scan - Iniciar búsqueda de gangas");
				print("/atrbargain shoplist - Buscar ofertas en lista de compra");
				print("/atrbargain ofertas - Mostrar ofertas del momento");
				print("/atrbargain clear - Limpiar ofertas del momento");
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
configFrame:RegisterEvent("VARIABLES_LOADED");
configFrame:RegisterEvent("AUCTION_HOUSE_SHOW");
configFrame:RegisterEvent("AUCTION_HOUSE_CLOSED");

configFrame:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" and addonName == "Auctionator" then
		Atr_LoadBargainConfig();
		-- Inicializar hooks para precios ideales
		Atr_InitializeIdealPriceHooks();
	elseif event == "VARIABLES_LOADED" then
		-- Cargar configuración después de que todas las SavedVariables estén disponibles
		Atr_LoadBargainConfig();
	elseif event == "AUCTION_HOUSE_SHOW" then
		-- Actualizar visibilidad cuando se abra la casa de subastas
		Atr_Timer_After(0.1, Atr_UpdateBargainButtonVisibility);
	elseif event == "AUCTION_HOUSE_CLOSED" then
		-- Ocultar botones cuando se cierre la casa de subastas
		if Atr_BargainButton then Atr_BargainButton:Hide(); end
		if Atr_DealsButton then Atr_DealsButton:Hide(); end
		if Atr_ShowDealsButton then Atr_ShowDealsButton:Hide(); end
		-- Ocultar interfaz de precio ideal
		Atr_HideIdealPriceInterface();
	end
end);

-----------------------------------------
-- Hook para detectar cambios de pestaña
-----------------------------------------
-- Sistema de verificación continua de pestaña activa
-----------------------------------------
local lastActiveTab = nil;
local visibilityCheckFrame = CreateFrame("Frame");

visibilityCheckFrame:SetScript("OnUpdate", function(self, elapsed)
	-- Solo verificar si la casa de subastas está abierta
	if not AuctionFrame or not AuctionFrame:IsShown() then
		lastActiveTab = nil;
		return;
	end
	
	-- Obtener pestaña actual
	local currentTab = PanelTemplates_GetSelectedTab(AuctionFrame);
	
	-- Si cambió la pestaña, actualizar visibilidad
	if currentTab ~= lastActiveTab then
		lastActiveTab = currentTab;
		Atr_Timer_After(0.1, Atr_UpdateBargainButtonVisibility);
	end
end);

-----------------------------------------
-- Funciones para la interfaz de precio ideal del item buscado
-----------------------------------------

-- Variable para almacenar el item actual buscado
local currentSearchedItem = nil;

-- Función para actualizar el precio ideal del item actual
function Atr_UpdateIdealPriceForCurrentItem()
    print("DEBUG: Atr_UpdateIdealPriceForCurrentItem llamado");
    print("DEBUG: currentSearchedItem =", currentSearchedItem);
    
    if not currentSearchedItem then
        print("DEBUG: No hay currentSearchedItem, saliendo");
        return;
    end
    
    -- FORZAR CORRECCIÓN DE ETIQUETAS PRIMERO
    Atr_FixIdealPriceLabels();
    
    local goldBox = _G["Atr_IdealPrice_GoldBox"];
    local silverBox = _G["Atr_IdealPrice_SilverBox"];
    local copperBox = _G["Atr_IdealPrice_CopperBox"];
    
    print("DEBUG: Campos encontrados - Gold:", goldBox ~= nil, "Silver:", silverBox ~= nil, "Copper:", copperBox ~= nil);
    
    if goldBox and silverBox and copperBox then
        -- FORZAR LIMPIEZA COMPLETA SIEMPRE
        goldBox:SetText("");
        silverBox:SetText("");
        copperBox:SetText("");
        print("DEBUG: Campos limpiados");
        
        -- Esperar un frame antes de establecer valores
        local function setValues()
            print("DEBUG: setValues ejecutándose");
            local idealPrice = Atr_GetIdealPrice(currentSearchedItem);
            print("DEBUG: Precio ideal obtenido:", idealPrice);
            
            if idealPrice then
                -- Verificar que el precio no sea decimal problemático
                if idealPrice < 0 or idealPrice > 9999999 then
                    -- Precio inválido, limpiar
                    print("DEBUG: Precio inválido, limpiando");
                    Atr_SetIdealPrice(currentSearchedItem, nil);
                    return;
                end
                
                -- Conversión más robusta
                local totalCopper = math.floor(idealPrice * 10000 + 0.5);
                local copperValue = totalCopper % 100;
                local silverValue = math.floor((totalCopper % 10000) / 100);
                local goldValue = math.floor(totalCopper / 10000);
                
                print("DEBUG: Precio " .. currentSearchedItem .. " = " .. goldValue .. "g " .. silverValue .. "s " .. copperValue .. "c");
                
                -- Solo establecer valores si son válidos y enteros
                if goldValue > 0 and goldValue == math.floor(goldValue) then
                    goldBox:SetText(tostring(goldValue));
                    print("DEBUG: Gold establecido a:", goldValue);
                end
                if silverValue > 0 and silverValue == math.floor(silverValue) and silverValue <= 99 then
                    silverBox:SetText(tostring(silverValue));
                    print("DEBUG: Silver establecido a:", silverValue);
                end
                if copperValue > 0 and copperValue == math.floor(copperValue) and copperValue <= 99 then
                    copperBox:SetText(tostring(copperValue));
                    print("DEBUG: Copper establecido a:", copperValue);
                end
                
                -- Verificación adicional después de establecer
                Atr_Timer_After(0.1, function()
                    if copperBox:GetText() and string.find(copperBox:GetText(), "%.") then
                        print("DEBUG: ¡Decimal detectado después de establecer valor! Limpiando...");
                        copperBox:SetText("");
                    end
                    -- Verificar etiquetas también
                    Atr_FixIdealPriceLabels();
                end);
            else
                print("DEBUG: No hay precio ideal para", currentSearchedItem);
            end
        end
        
        -- Ejecutar en el próximo frame para evitar conflictos
        Atr_Timer_After(0.01, setValues);
    else
        print("DEBUG: Algunos campos no encontrados");
    end
end

-- Función para limpiar el precio ideal desde la interfaz
function Atr_ClearIdealPriceFromUI()
    if not currentSearchedItem then
        return;
    end
    
    -- Limpiar el precio ideal
    if AUCTIONATOR_IDEAL_PRICES[currentSearchedItem] then
        AUCTIONATOR_IDEAL_PRICES[currentSearchedItem] = nil;
        print("Precio ideal eliminado para: " .. currentSearchedItem);
        
        -- Limpiar los campos de entrada
        local goldBox = _G["Atr_IdealPrice_GoldBox"];
        local silverBox = _G["Atr_IdealPrice_SilverBox"];
        local copperBox = _G["Atr_IdealPrice_CopperBox"];
        
        if goldBox then goldBox:SetText(""); end
        if silverBox then silverBox:SetText(""); end
        if copperBox then copperBox:SetText(""); end
        
        -- Guardar cambios
        Atr_SaveBargainConfig();
        
        -- Actualizar las entradas de resultados
        Atr_LoadIdealPricesInEntries();
    end
end
function Atr_SaveIdealPriceFromUI()
    print("DEBUG: Atr_SaveIdealPriceFromUI llamado");
    print("DEBUG: currentSearchedItem =", currentSearchedItem);
    
    if not currentSearchedItem then
        print("No hay item seleccionado para configurar precio ideal.");
        return;
    end
    
    local goldBox = _G["Atr_IdealPrice_GoldBox"];
    local silverBox = _G["Atr_IdealPrice_SilverBox"];
    local copperBox = _G["Atr_IdealPrice_CopperBox"];
    
    if not goldBox or not silverBox or not copperBox then
        print("DEBUG: No se encontraron los campos de entrada");
        return;
    end
    
    -- Obtener valores de los campos (convertir texto vacío a 0)
    local goldText = goldBox:GetText() or "";
    local silverText = silverBox:GetText() or "";
    local copperText = copperBox:GetText() or "";
    
    print("DEBUG: Valores de campos - Gold:", goldText, "Silver:", silverText, "Copper:", copperText);
    
    local gold = tonumber(goldText) or 0;
    local silver = tonumber(silverText) or 0;
    local copper = tonumber(copperText) or 0;
    
    print("DEBUG: Valores convertidos - Gold:", gold, "Silver:", silver, "Copper:", copper);
    
    -- Validar rangos de monedas
    if gold < 0 then gold = 0; end
    if silver < 0 then silver = 0; elseif silver > 99 then silver = 99; end
    if copper < 0 then copper = 0; elseif copper > 99 then copper = 99; end
    
    -- Convertir a cobre total
    local totalCopper = gold * 10000 + silver * 100 + copper;
    
    print("DEBUG: Total en cobre:", totalCopper);
    
    if totalCopper <= 0 then
        print("El precio debe ser mayor que 0");
        return;
    end
    
    -- Convertir precio a formato decimal (oro)
    local priceInGold = totalCopper / 10000;
    
    print("DEBUG: Precio en oro (decimal):", priceInGold);
    
    if Atr_SetIdealPrice(currentSearchedItem, priceInGold) then
        print("Precio ideal configurado: " .. currentSearchedItem .. " = " .. Atr_FormatPrice(totalCopper));
        Atr_SaveBargainConfig(); -- Guardar inmediatamente
        
        -- Actualizar la interfaz con los valores validados
        goldBox:SetText(gold > 0 and tostring(gold) or "");
        silverBox:SetText(silver > 0 and tostring(silver) or "");
        copperBox:SetText(copper > 0 and tostring(copper) or "");
        
        -- Actualizar también los campos en las entradas de resultados
        Atr_LoadIdealPricesInEntries();
    else
        print("Error al configurar precio ideal.");
        goldBox:SetText("");
        silverBox:SetText("");
        copperBox:SetText("");
    end
end

-- Función para mostrar la interfaz de precio ideal cuando se busca un item
function Atr_ShowIdealPriceForItem(itemName)
    print("DEBUG: Atr_ShowIdealPriceForItem llamado con:", itemName);
    
    if not itemName or itemName == "" then
        print("DEBUG: Item vacío, ocultando interfaz");
        Atr_HideIdealPriceInterface();
        return;
    end
    
    currentSearchedItem = itemName;
    print("DEBUG: currentSearchedItem establecido a:", currentSearchedItem);
    
    local frame = _G["Atr_IdealPrice_Frame"];
    if frame then
        print("DEBUG: Frame encontrado, mostrando");
        frame:Show();
        
        -- FORZAR CORRECCIÓN DE ETIQUETAS SIEMPRE
        Atr_FixIdealPriceLabels();
        
        Atr_UpdateIdealPriceForCurrentItem();
    else
        print("DEBUG: Frame Atr_IdealPrice_Frame NO encontrado!");
    end
end

-- Nueva función para corregir las etiquetas de moneda
function Atr_FixIdealPriceLabels()
    local goldLabel = _G["Atr_IdealPrice_GoldLabel"];
    local silverLabel = _G["Atr_IdealPrice_SilverLabel"];
    local copperLabel = _G["Atr_IdealPrice_CopperLabel"];
    
    if goldLabel then
        goldLabel:SetText("g");
    end
    if silverLabel then
        silverLabel:SetText("s");
    end
    if copperLabel then
        copperLabel:SetText("c");
        print("DEBUG: Etiqueta de cobre corregida a 'c'");
    end
end

-- Función callback para cambio de texto en campos de precio
function Atr_IdealPriceOnTextChanged(self)
    -- Validar que solo contenga números enteros
    local text = self:GetText();
    
    -- Si contiene un punto decimal, limpiar completamente
    if text and string.find(text, "%.") then
        self:SetText("");
        print("DEBUG: Campo " .. (self:GetName() or "unknown") .. " contenía decimales, limpiado");
        return;
    end
    
    if text and text ~= "" then
        -- Eliminar caracteres no numéricos y decimales
        local numericOnly = string.gsub(text, "[^0-9]", "");
        if numericOnly ~= text then
            self:SetText(numericOnly);
            print("DEBUG: Campo " .. (self:GetName() or "unknown") .. " limpiado de: " .. text .. " a: " .. numericOnly);
        end
        
        -- Limitar valores según el tipo de campo
        local value = tonumber(numericOnly) or 0;
        if self:GetName() == "Atr_IdealPrice_GoldBox" then
            -- Sin límite específico para el oro, pero debe ser entero
            if value ~= math.floor(value) then
                self:SetText(tostring(math.floor(value)));
            end
        elseif self:GetName() == "Atr_IdealPrice_SilverBox" or self:GetName() == "Atr_IdealPrice_CopperBox" then
            -- Limitar plata y cobre a 99 y debe ser entero
            if value > 99 then
                self:SetText("99");
                print("DEBUG: Campo " .. self:GetName() .. " limitado a 99");
            elseif value ~= math.floor(value) then
                self:SetText(tostring(math.floor(value)));
            end
        end
    end
end

-- Nueva función para compatibilidad con el sistema de tres campos (alias)
function Atr_SaveIdealPriceFromMoneyUI()
    Atr_SaveIdealPriceFromUI();
end

-- Función para forzar limpieza de campos de precio ideal
function Atr_ForceCleanIdealPriceFields()
    local goldBox = _G["Atr_IdealPrice_GoldBox"];
    local silverBox = _G["Atr_IdealPrice_SilverBox"];
    local copperBox = _G["Atr_IdealPrice_CopperBox"];
    
    if goldBox then
        local text = goldBox:GetText();
        if text and text ~= "" then
            local cleanText = string.gsub(text, "[^0-9]", "");
            goldBox:SetText(cleanText);
        end
    end
    
    if silverBox then
        local text = silverBox:GetText();
        if text and text ~= "" then
            local cleanText = string.gsub(text, "[^0-9]", "");
            local value = tonumber(cleanText) or 0;
            if value > 99 then value = 99; end
            silverBox:SetText(value > 0 and tostring(value) or "");
        end
    end
    
    if copperBox then
        local text = copperBox:GetText();
        if text and text ~= "" then
            local cleanText = string.gsub(text, "[^0-9]", "");
            local value = tonumber(cleanText) or 0;
            if value > 99 then value = 99; end
            copperBox:SetText(value > 0 and tostring(value) or "");
        end
    end
end

-- Función callback para OnShow de los campos de precio
function Atr_IdealPriceOnShow(self)
    if self then
        -- Forzar limpieza inmediata sin importar el contenido
        self:SetText("");
        
        -- También limpiar cualquier texto que pueda quedar
        if self.text then
            self.text = "";
        end
        
        -- Mensaje de depuración
        if self:GetName() == "Atr_IdealPrice_CopperBox" then
            print("DEBUG: CopperBox limpiado en OnShow");
        end
    end
end

-- Función para limpiar precios ideales problemáticos (comando de consola)
function Atr_CleanIdealPrices()
    local cleaned = 0;
    if AUCTIONATOR_IDEAL_PRICES then
        for itemName, data in pairs(AUCTIONATOR_IDEAL_PRICES) do
            if data.price and (data.price < 0 or data.price > 9999999 or data.price ~= math.floor(data.price * 10000) / 10000) then
                AUCTIONATOR_IDEAL_PRICES[itemName] = nil;
                cleaned = cleaned + 1;
            end
        end
    end
    print("Limpiados " .. cleaned .. " precios ideales problemáticos.");
    Atr_SaveBargainConfig();
end

-- Comando de consola para limpiar precios
SLASH_ATRCLEANPRICES1 = "/atrclean";
SlashCmdList["ATRCLEANPRICES"] = Atr_CleanIdealPrices;

-- Comando de consola para corregir etiquetas
SLASH_ATRFIXLABELS1 = "/atrfix";
SlashCmdList["ATRFIXLABELS"] = function()
    Atr_FixIdealPriceLabels();
    print("Etiquetas de precio ideal corregidas.");
end;

-- Función para ocultar la interfaz de precio ideal
function Atr_HideIdealPriceInterface()
    currentSearchedItem = nil;
    
    local frame = _G["Atr_IdealPrice_Frame"];
    if frame then
        frame:Hide();
    end
end

-- Aplicar el hook cuando el addon se cargue completamente
Atr_Timer_After(1, function()
	-- Verificar si el botón existe y forzar una actualización inicial
	if Atr_BargainButton then
		Atr_UpdateBargainButtonVisibility();
	end
end);