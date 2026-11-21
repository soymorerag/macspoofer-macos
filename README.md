# MAC Spoofer para macOS (equivalente a TMAC)

App macOS que replica las funciones principales de **Technitium MAC Address Changer (TMAC)** para Windows:
cambiar (spoof) la dirección MAC de adaptadores de red (wired/Wi-Fi), generar MAC aleatoria,
restaurar la MAC original y (opcional) hacer el cambio persistente tras reinicios.

## Instalación

1. Copia `MACSpoofer.app` a `/Applications` (o ejecútala desde donde esté).
2. Primera ejecución: clic derecho → **Abrir** (la app no está firmada/notarizada;
   macOS Gatekeeper la bloqueará con doble clic). Confirma "Abrir".
3. Concede permisos de administrador cuando se soliciten (se usa `sudo` internamente
   vía diálogo nativo de macOS).

## Uso

1. Abre la app.
2. Selecciona la interfaz de red (ej. `Wi-Fi [en0]`).
3. Elige acción:
   - **Cambiar MAC (aleatoria)** — genera MAC con primer octeto `02` (localmente administrada,
     mejor compatibilidad con Wi-Fi).
   - **Cambiar MAC (manual)** — introduce tu propia MAC `xx:xx:xx:xx:xx:xx`.
   - **Restaurar MAC original** — vuelve a la MAC guardada (o la actual si no hay guardada).
   - **Ver información / estado** — muestra `ifconfig` de la interfaz.
   - **Hacer persistente (LaunchDaemon)** — instala un LaunchDaemon que reaplica la MAC al arrancar.

## Notas importantes (macOS)

- El cambio con `ifconfig ether` **no persiste tras reiniciar** ni al resetear la interfaz,
  salvo que uses "Hacer persistente".
- En **Wi-Fi**, macOS 15+ usa "Dirección Wi-Fi privada" (randomización por red). Para que el
  spoof manual funcione, desactiva esa opción en Ajustes del Sistema → Wi-Fi → (tu red) →
  "Dirección Wi-Fi privada" → Desactivada, o usa primer octeto `02`.
- Algunos drivers de Wi-Fi (especialmente en Apple Silicon) ignoran el cambio de MAC;
  en ese caso usa un adaptador USB Ethernet o una VM.
- La MAC original se guarda en `~/Library/Application Support/MACSpoofer/<iface>.mac`.

## Alternativas existentes

Si prefieres una app ya mantenida: **LinkLiar** (open source, gratis) y **WiFiSpoof** (pago)
hacen lo mismo con GUI más completa.

## Desinstalación

Borra `MACSpoofer.app` y (si usaste persistencia) los LaunchDaemons:
`/Library/LaunchDaemons/com.macspoofer.*.plist`.

## Requisitos

- macOS 12+ (probado en macOS 26 Tahoe)
- Herramientas del sistema: `networksetup`, `ifconfig`, `osascript` (incluidas en macOS)
- Python 3 del sistema (solo para generar MAC aleatoria; `/usr/bin/python3`)
