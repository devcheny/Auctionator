# Auctionator - Addon para Casa de Subastas (WoW 3.3.5)

## Descripción
Auctionator es un addon mejorado para gestionar la casa de subastas de World of Warcraft. Esta versión personalizada incluye funcionalidades adicionales como visualización de ganancias potenciales, cálculo de precios promedio, escaneo completo multi-página y compartición de datos entre personajes.

---

## Instalación

1. Copia la carpeta `Auctionator` en: `WoW\Interface\AddOns\`
2. Reinicia el juego o ejecuta `/reload` si ya estás dentro
3. Abre la casa de subastas para activar el addon

---

## Características Principales

### 🔍 **Escaneo Completo de la Casa de Subastas**
- Escanea **todas las páginas** de la casa de subastas (no solo las primeras 50)
- Construye una base de datos de precios actualizada
- Muestra progreso en tiempo real con porcentaje y tiempo estimado
- Recomendación: Ejecutar cada vez que necesites precios actualizados

**Cómo usar:**
1. Abre la casa de subastas
2. Ve a la pestaña de búsqueda de Auctionator
3. Click en "Full Scan"
4. Espera a que complete (verás el progreso en pantalla)

**Limitación de Blizzard:** Solo puedes hacer un escaneo completo cada 15 minutos.

---

### 💰 **Visualización de Ganancias Totales**
Muestra cuánto ganarás si todas tus subastas activas se venden.

**Ubicación:** Parte inferior de la pestaña "Subastas" (Auctions)

**Información mostrada:**
- Total bruto (precio de compra directa de todas tus subastas)
- Total neto (después de restar la comisión del 5% de la casa de subastas)
- Formato con iconos de monedas de WoW (oro, plata, cobre)

**Actualización:** Se actualiza automáticamente cuando:
- Abres la pestaña de subastas
- Se actualizan tus subastas activas
- Creas o cancelas una subasta

---

### 📊 **Información de Precios en Tooltips**
Cuando pasas el cursor sobre un objeto, verás información adicional:

- **Vendor** (Vendedor): Precio de venta a NPCs
- **Auction** (Subasta): Último precio visto en la casa de subastas
- **Media en subasta**: Promedio de los últimos 10 precios registrados
- **Disenchant** (Desencantar): Valor estimado del desencantado

**Ventaja de la media:** Menos susceptible a fluctuaciones temporales de precios.

---

### 🔄 **Compartir Datos Entre Personajes**

Por defecto, cada facción (Horda/Alianza) tiene su propia base de datos. Puedes activar la compartición para que todos tus personajes del mismo reino vean los mismos datos.

**Comandos:**

```
/atr share          # Ver estado actual
/atr share on       # Activar compartición (Horda + Alianza)
/atr share off      # Desactivar compartición (separar por facción)
```

**Después de cambiar:** Ejecuta `/reload` para aplicar.

**Compartir entre cuentas diferentes:**
Los datos se guardan en: `WoW\WTF\Account\TU_CUENTA\SavedVariables\Auctionator.lua`

Para compartir entre cuentas:
1. Cierra el juego en ambas cuentas
2. Copia el archivo `Auctionator.lua` de la cuenta con datos
3. Pégalo en la carpeta de SavedVariables de la otra cuenta
4. Sobrescribe si pregunta

---

## Comandos de Chat

```
/atr share              # Gestionar compartición de datos
/atr share on           # Activar compartición entre facciones
/atr share off          # Desactivar compartición

/atr clear fullscandb   # Borrar base de datos de escaneo
/atr clear posthistory  # Borrar historial de publicaciones

/atr mem                # Ver uso de memoria de addons

/reload                 # Recargar interfaz (aplicar cambios)
```

---

## Configuración

### **Ajustes Básicos**
Accede a la configuración desde la casa de subastas:
- Click en el botón "Config" (Configurar)
- Ajusta descuentos, comportamiento de bolsas, etc.

### **Tooltips (Herramientas)**
Configura qué información mostrar en los tooltips:
- Precios de vendedor
- Precios de subasta
- Información de desencantado
- Detalles de desencantado (requiere tecla modificadora)

### **Duración de Subastas**
Establece la duración por defecto de tus subastas:
- 12 horas
- 24 horas
- 48 horas

---

## Funcionalidades de Venta

### **Vender Objetos**
1. Abre la casa de subastas
2. Ve a la pestaña de Auctionator
3. Arrastra el objeto al área de venta
4. El addon sugiere automáticamente un precio competitivo
5. Ajusta cantidad, duración y precio si lo deseas
6. Click en "Create Auction" (Crear Subasta)

### **Cancelar Subastas**
- Botón "Cancel Auctions" en la pestaña de subastas
- Cancela rápidamente subastas que han sido superadas en precio

---

## Funcionalidades de Búsqueda

### **Búsqueda Rápida**
- Escribe el nombre del objeto en el campo de búsqueda
- Usa `"nombre exacto"` (entre comillas) para búsquedas exactas
- Resultados ordenables por nombre o precio

### **Listas de Compras**
Crea listas de objetos que compras frecuentemente:
1. Click en "Shopping Lists"
2. Crea una nueva lista
3. Agrega objetos
4. Busca todos los objetos de la lista con un click

---

## Solución de Problemas

### **El botón de escaneo está deshabilitado**
- Blizzard limita los escaneos completos a 1 cada 15 minutos
- El addon muestra cuándo podrás escanear de nuevo

### **No veo las ganancias en la pestaña de subastas**
- Asegúrate de estar en la pestaña "Auctions" (tercera pestaña)
- Ejecuta `/reload` para reiniciar el addon

### **Los tooltips no muestran precios**
- Asegúrate de haber hecho al menos un escaneo completo
- Verifica la configuración de tooltips en Config

### **El escaneo solo muestra 50-200 items**
- Esto puede ocurrir si el servidor tiene limitaciones
- El addon intenta escanear todas las páginas automáticamente
- Los mensajes en chat te dirán cuántos items se escanearon

### **Errores de Lua**
- Ejecuta `/reload` para reiniciar
- Si persiste, desactiva otros addons que modifiquen la casa de subastas
- Revisa que la versión del addon sea compatible con WoW 3.3.5

---

## Archivos de Datos

Los datos del addon se guardan en:
```
WoW\WTF\Account\TU_CUENTA\SavedVariables\Auctionator.lua
```

**Contenido:**
- `AUCTIONATOR_PRICE_DATABASE`: Base de datos de precios escaneados
- `AUCTIONATOR_PRICING_HISTORY`: Historial de tus publicaciones
- `AUCTIONATOR_SHOPPING_LISTS`: Tus listas de compras
- `AUCTIONATOR_SAVEDVARS`: Configuración del addon
- `AUCTIONATOR_LAST_SCAN_TIME`: Último escaneo completo

**Backup:** Se recomienda hacer copias de seguridad periódicas de este archivo.

---

## Mejoras Personalizadas en Esta Versión

### ✨ **Nuevas Funcionalidades**

1. **Escaneo Multi-Página Completo**
   - Escanea todas las páginas de la casa de subastas
   - Muestra progreso en tiempo real con % y tiempo estimado
   - Mensajes informativos en chat sobre el progreso

2. **Visualización de Ganancias Totales**
   - Frame en la pestaña de subastas mostrando ganancias potenciales
   - Cálculo automático del 5% de comisión
   - Iconos de moneda de WoW para mejor visualización

3. **Precio Promedio en Tooltips**
   - Línea adicional "Media en subasta" en tooltips
   - Calcula el promedio de los últimos 10 precios registrados
   - Útil para identificar tendencias de precios

4. **Sistema de Compartición de Datos**
   - Compartir base de datos entre Horda y Alianza
   - Comando `/atr share` para gestionar
   - Migración automática de datos existentes

5. **Mejoras de Interfaz**
   - Frame de ganancias con diseño limpio (sin bordes molestos)
   - Fuente optimizada para mejor legibilidad
   - Formato de dinero con iconos nativos de WoW

---

## Créditos

**Autor Original:** Zirco, Cheny  
**Versión Personalizada:** DevCheny  
**Traducción Española:** Comunidad  

**Modificaciones Personalizadas:**
- Sistema de escaneo multi-página completo
- Visualización de ganancias totales
- Cálculo de precios promedio
- Sistema de compartición entre facciones
- Mejoras de interfaz y usabilidad

---

## Licencia

Este addon es una modificación del Auctionator original. Todos los derechos del código original pertenecen a sus respectivos autores.

---

## Soporte

Para reportar problemas o sugerencias de esta versión personalizada, contacta a DevCheny.

**Versión:** 3.3.5 Custom  
**Última actualización:** Diciembre 2025
