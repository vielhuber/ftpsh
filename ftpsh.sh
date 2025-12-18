#!/bin/bash


# --- .env einlesen ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Fehler: .env Datei nicht gefunden ($ENV_FILE)"
    exit 1
fi

# .env einlesen (exportiert Variablen)
set -a
source "$ENV_FILE"
set +a

# Variablen prüfen
if [ -z "$HOST" ] || [ -z "$PORT" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$REMOTE_PATH" ] || [ -z "$URL" ]; then
    echo "Fehler: Mindestens eine erforderliche Variable fehlt in .env!"
    echo "Benötigt: HOST, PORT, USERNAME, PASSWORD, REMOTE_PATH, URL"
    exit 1
fi

# Variablen zu alten Namen für Script-Kompatibilität
SFTP_HOST="$HOST"
SFTP_PORT="$PORT"
SFTP_USER="$USERNAME"
SFTP_PASS="$PASSWORD"
REMOTE_PATH="$REMOTE_PATH"
WEB_URL="$URL"

# Protokoll automatisch erkennen (falls nicht in .env gesetzt)
if [ -z "$PROTOCOL" ]; then
    if [ "$SFTP_PORT" = "21" ]; then
        PROTOCOL="ftp"
    else
        PROTOCOL="sftp"
    fi
fi

# Löschbefehl je nach Protokoll
if [ "$PROTOCOL" = "ftp" ]; then
    DELETE_CMD="DELE"
else
    DELETE_CMD="RM"
fi

# Befehl aus Argumenten (alle Argumente sind der Befehl)
CMD_ARGS=("$@")

# 1. Befehl aus verbleibenden Argumenten zusammenbauen
# Einfach mit Leerzeichen verbinden - die Remote-Shell interpretiert sie
CMD="${CMD_ARGS[*]}"

if [ -z "$CMD" ]; then
    echo "Fehler: Kein Befehl angegeben!"
    echo "Beispiel: ./sftpcall.sh --host server.com --username user --password pass --url https://example.com git status"
    exit 1
fi

# DEBUG: Befehl ausgeben
#echo "DEBUG: Befehl der ausgeführt wird:"
#echo "$CMD"
#echo "---"

# 2. Zufälligen Dateinamen generieren (Sicherheit durch Obscurity)
RAND_NAME="exec_$(date +%s)_$RANDOM.php"
LOCAL_FILE="/tmp/$RAND_NAME"

# 3. Den Befehl Base64 kodieren, um Probleme mit Sonderzeichen (' " $) im PHP-String zu vermeiden
CMD_B64=$(echo -n "$CMD" | base64)

# 4. PHP Datei erstellen
# Wir setzen Time Limit hoch und leiten STDERR (2) nach STDOUT (1) um
cat <<EOF > "$LOCAL_FILE"
<?php
set_time_limit(0);
// Versuchen, das Speicherlimit hochzusetzen (z.B. auf 512MB oder -1 für unbegrenzt)
@ini_set('memory_limit', '512M');

// Manche Git/System-Befehle brauchen eine HOME Variable
putenv("HOME=" . __DIR__);
// PWD auf aktuelles Verzeichnis setzen (für \${PWD} im Befehl)
putenv("PWD=" . __DIR__);

// Befehl dekodieren und ausführen
passthru(base64_decode('$CMD_B64') . ' 2>&1');
unlink(__FILE__);
?>
EOF

# 5. Datei per FTP/SFTP hochladen (curl -T)
# -s für silent, -S für show error
curl -u "$SFTP_USER:$SFTP_PASS" \
     -T "$LOCAL_FILE" \
     -s -S \
     "$PROTOCOL://$SFTP_HOST:$SFTP_PORT/$REMOTE_PATH/"

if [ $? -ne 0 ]; then
    echo "Fehler beim Hochladen der Payload."
    rm "$LOCAL_FILE"
    exit 1
fi

# 6. Datei per HTTP aufrufen und Ergebnis ausgeben
# Das Ergebnis landet direkt in stdout
curl -s "$WEB_URL/$RAND_NAME"

# 7. Datei per FTP/SFTP löschen (Aufräumen)
# Der Befehl -Q (Quote) sendet Befehle VOR oder NACH dem Transfer.
# Da wir nichts transferieren, nutzen wir es nur zum Löschen.
curl -u "$SFTP_USER:$SFTP_PASS" \
     -s -S \
     -Q "$DELETE_CMD $REMOTE_PATH/$RAND_NAME" \
     "$PROTOCOL://$SFTP_HOST:$SFTP_PORT/" > /dev/null 2>&1

# Lokale Datei aufräumen
rm "$LOCAL_FILE"