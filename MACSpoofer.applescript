-- MAC Spoofer para macOS
-- Equivalente a Technitium MAC Address Changer (TMAC) para Windows
-- Cambia (spoof) la dirección MAC de adaptadores de red en macOS

on run
    -- Obtener lista de interfaces con nombre amigable
    set parsed to ""
    try
        set parsed to do shell script "/usr/sbin/networksetup -listallhardwareports | awk '/^Hardware Port:/{name=substr($0,index($0,\":\")+2)} /^Device:/{print name \"  [\" $2 \"]\"}'"
    on error errMsg
        display alert "Error" message "No se pudo obtener la lista de interfaces: " & errMsg
        return
    end try

    set ifaceChoices to paragraphs of parsed
    -- eliminar líneas vacías
    set cleanChoices to {}
    repeat with c in ifaceChoices
        if (c as string) is not "" then set end of cleanChoices to (c as string)
    end repeat
    if (count of cleanChoices) is 0 then
        display alert "Sin interfaces" message "No se encontraron interfaces de red."
        return
    end if

    set chosen to choose from list cleanChoices with prompt "Selecciona la interfaz de red a modificar:" with title "MAC Spoofer (TMAC para Mac)" OK button name "Seleccionar" cancel button name "Salir"
    if chosen is false then return
    set chosenStr to item 1 of chosen

    -- extraer device entre corchetes
    set dev to ""
    try
        set AppleScript's text item delimiters to "["
        set t1 to text item 2 of chosenStr
        set AppleScript's text item delimiters to "]"
        set dev to text item 1 of t1
        set AppleScript's text item delimiters to ""
    on error
        set AppleScript's text item delimiters to ""
        display alert "Error" message "No se pudo identificar la interfaz."
        return
    end try

    -- MAC actual
    set currentMac to ""
    try
        set currentMac to do shell script "ifconfig " & dev & " | awk '/ether/{print $2; exit}'"
    end try
    if currentMac is "" then set currentMac to "(no disponible)"

    -- directorio de datos
    set dataDir to (path to home folder as text) & "Library:Application Support:MACSpoofer:"
    do shell script "mkdir -p " & quoted form of (POSIX path of (path to home folder) & "Library/Application Support/MACSpoofer")

    set origFile to (POSIX path of (path to home folder)) & "Library/Application Support/MACSpoofer/" & dev & ".mac"

    -- menú de acción
    set actionChoice to choose from list {"Cambiar MAC (aleatoria)", "Cambiar MAC (manual)", "Restaurar MAC original", "Ver información / estado", "Hacer persistente (LaunchDaemon)"} with prompt "Interfaz: " & dev & "   MAC actual: " & currentMac with title "MAC Spoofer" OK button name "Ejecutar" cancel button name "Atrás"
    if actionChoice is false then
        -- volver al inicio
        run
        return
    end if
    set actionStr to item 1 of actionChoice

    if actionStr is "Ver información / estado" then
        set info to do shell script "ifconfig " & dev & " | head -20"
        display dialog info with title "Info " & dev buttons {"OK"} default button "OK"
        run
        return
    end if

    if actionStr is "Cambiar MAC (aleatoria)" then
        -- generar MAC aleatoria con primer octeto 02 (localmente administrada, mejor compatibilidad WiFi)
        set newMac to do shell script "echo \"02:$(/usr/bin/openssl rand -hex 5 | /usr/bin/sed 's/../&:/g; s/:$//')\""
    else if actionStr is "Cambiar MAC (manual)" then
        set dlg to display dialog "Ingresa la nueva MAC address (formato xx:xx:xx:xx:xx:xx):" default answer "" with title "MAC manual"
        set newMac to text returned of dlg
        -- validar
        set valid to do shell script "echo " & quoted form of newMac & " | grep -E '^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$' >/dev/null 2>&1 && echo OK || echo BAD"
        if valid is not "OK" then
            display alert "MAC inválida" message "Formato esperado: 00:11:22:33:44:55"
            run
            return
        end if
    else if actionStr is "Restaurar MAC original" then
        -- leer original guardado
        set origMac to ""
        try
            set origMac to do shell script "cat " & quoted form of origFile
        end try
        if origMac is "" then
            -- intentar obtener del sistema (no siempre disponible)
            set origMac to currentMac
        end if
        if origMac is "" or origMac is "(no disponible)" then
            display alert "Sin original" message "No hay MAC original guardada para " & dev & ". Conecta y vuelve a intentar."
            run
            return
        end if
        set newMac to origMac
    else if actionStr is "Hacer persistente (LaunchDaemon)" then
        -- guardar MAC actual como persistente
        set persistMac to currentMac
        if persistMac is "(no disponible)" or persistMac is "" then
            display alert "Sin MAC" message "No se pudo determinar la MAC actual."
            run
            return
        end if
        -- pedir confirmación de MAC a persistir
        set dlg to display dialog "MAC a hacer persistente:" default answer persistMac with title "Persistencia"
        set persistMac to text returned of dlg
        -- crear plist
        set plistPath to "/Library/LaunchDaemons/com.macspoofer." & dev & ".plist"
        set plistContent to "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
  <key>Label</key>
  <string>com.macspoofer." & dev & "</string>
  <key>ProgramArguments</key>
  <array>
    <string>/sbin/ifconfig</string>
    <string>" & dev & "</string>
    <string>ether</string>
    <string>" & persistMac & "</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>"
        try
            do shell script "echo " & quoted form of plistContent & " > " & quoted form of plistPath & " && chmod 644 " & quoted form of plistPath & " && chown root:wheel " & quoted form of plistPath & " && launchctl load -w " & quoted form of plistPath with administrator privileges
            display notification "LaunchDaemon instalado para " & dev with title "MAC Spoofer"
        on error errMsg
            display alert "Error" message errMsg
        end try
        run
        return
    end if

    -- guardar original si no existe
    try
        do shell script "test -f " & quoted form of origFile & " || echo " & quoted form of currentMac & " > " & quoted form of origFile
    end try

    -- detectar si es Wi-Fi
    set isWifi to false
    try
        do shell script "/usr/sbin/networksetup -getairportpower " & dev
        set isWifi to true
    end try

    -- aplicar cambio
    try
        if isWifi then
            -- método Sequoia/Tahoe: apagar/encender y aplicar de inmediato
            do shell script "/usr/sbin/networksetup -setairportpower " & dev & " off; /usr/sbin/networksetup -setairportpower " & dev & " on; /sbin/ifconfig " & dev & " ether " & newMac with administrator privileges
        else
            do shell script "/sbin/ifconfig " & dev & " down; /sbin/ifconfig " & dev & " ether " & newMac & "; /sbin/ifconfig " & dev & " up" with administrator privileges
        end if
        -- verificar
        set appliedMac to do shell script "/sbin/ifconfig " & dev & " | awk '/ether/{print $2; exit}'"
        if appliedMac is newMac then
            display notification "MAC cambiada a " & newMac with title "MAC Spoofer"
            display dialog "MAC de " & dev & " cambiada a:" & return & newMac & return & return & "Verificado: " & appliedMac & return & return & "Nota: el cambio no persiste tras reiniciar salvo que uses 'Hacer persistente'." buttons {"OK"} default button "OK" with title "Éxito"
        else
            display alert "No se aplicó" message "ifconfig reporta " & appliedMac & " (esperado " & newMac & ")." & return & return & "Prueba: desactiva 'Dirección Wi-Fi privada' en Ajustes del Sistema → Wi-Fi → (red) → Detalles, y reintenta. Algunos adaptadores no permiten spoof."
        end if
    on error errMsg
        display alert "Error al aplicar" message errMsg & return & return & "En macOS la WiFi puede bloquear el cambio. Prueba con primer octeto 02 (ya usado en aleatoria) o desactiva 'Dirección Wi-Fi privada' en Ajustes del Sistema."
    end try

    run
end run
