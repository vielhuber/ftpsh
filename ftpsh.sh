#!/bin/bash

# read environment file

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

randomHex() {
    local bytes="$1"
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex "$bytes" && return
    fi
    if [ -r /dev/urandom ]; then
        LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom | head -c $((bytes * 2))
        echo
        return
    fi
    printf '%s%s%s' "$RANDOM" "$(date +%s%N)" "$$" | cksum | awk '{print $1}'
}

# parse flags (allow any order)
DOWNLOAD_MODE=false
DOWNLOAD_FILE=""
ENV_FILE="$SCRIPT_DIR/.env"

while [[ "$1" =~ ^-- ]]; do
    case "$1" in
        --download)
            DOWNLOAD_MODE=true
            if [ -z "$2" ]; then
                echo "Error: --download requires a filename argument"
                echo "Example: ./ftpsh.sh --download backup.tar.gz"
                exit 1
            fi
            DOWNLOAD_FILE="$2"
            shift 2
            ;;
        --env)
            if [ -z "$2" ]; then
                echo "Error: --env requires a filename argument"
                echo "Example: ./ftpsh.sh --env my-project.env git status"
                exit 1
            fi
            # check if absolute path or relative
            if [[ "$2" = /* ]]; then
                ENV_FILE="$2"
            else
                ENV_FILE="$SCRIPT_DIR/$2"
            fi
            shift 2
            ;;
        *)
            echo "Error: Unknown flag $1"
            exit 1
            ;;
    esac
done

if [ -f "$ENV_FILE" ]; then
    # env file exists, load variables
    set -a
    source "$ENV_FILE"
    set +a
fi
# if env file doesn't exist or is not set, environment variables should be already set

# check variables
if [ -z "$HOST" ] || [ -z "$PORT" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$REMOTE_PATH" ] || [ -z "$WEB_URL" ]; then
    echo "Error: At least one required variable missing in environment!"
    echo "Required: HOST, PORT, USERNAME, PASSWORD, REMOTE_PATH, WEB_URL"
    exit 1
fi

# map variables to old names for script compatibility
SFTP_HOST="$HOST"
SFTP_PORT="$PORT"
SFTP_USER="$USERNAME"
SFTP_PASS="$PASSWORD"
REMOTE_PATH="$REMOTE_PATH"
WEB_URL="$WEB_URL"

# automatically detect protocol (if not set in .env)
if [ -z "$PROTOCOL" ]; then
    if [ "$SFTP_PORT" = "21" ]; then
        PROTOCOL="ftp"
    else
        PROTOCOL="sftp"
    fi
fi

# delete command depending on protocol
if [ "$PROTOCOL" = "ftp" ]; then
    DELETE_CMD="DELE"
else
    DELETE_CMD="RM"
fi

# handle download mode or regular command mode
if [ "$DOWNLOAD_MODE" = true ]; then
    # download mode: directly download file via http with progress
    curl --progress-bar \
        "$WEB_URL/$DOWNLOAD_FILE"
    exit $?
fi

# command from arguments (all arguments are the command)
CMD_ARGS=("$@")

# build command from remaining arguments
# simply join with spaces - the remote shell interprets them
CMD="${CMD_ARGS[*]}"

if [ -z "$CMD" ]; then
    echo "Error: No command specified!"
    echo "Example: ./ftpsh.sh git status"
    echo "         ./ftpsh.sh --env my-project.env git status"
    echo "         ./ftpsh.sh --download backup.tar.gz > backup.tar.gz"
    exit 1
fi

# generate random filename (security through obscurity)
RAND_NAME="exec_$(randomHex 16).php"
LOCAL_FILE="/tmp/$RAND_NAME"
UPLOADED=false

cleanup() {
    if [ "$UPLOADED" = true ]; then
        curl -u "$SFTP_USER:$SFTP_PASS" \
            -s -S --connect-timeout 10 --max-time 30 \
            -Q "$DELETE_CMD $REMOTE_PATH/$RAND_NAME" \
            "$PROTOCOL://$SFTP_HOST:$SFTP_PORT/" > /dev/null 2>&1
    fi
    if [ -f "$LOCAL_FILE" ]; then
        rm "$LOCAL_FILE"
    fi
}

trap cleanup EXIT
trap 'cleanup; trap - EXIT; exit 130' INT
trap 'cleanup; trap - EXIT; exit 143' TERM

# generate random security token (additional protection)
SECURITY_TOKEN=$(randomHex 32)
CREATED_AT=$(date +%s)
TTL=60

# base64 encode the command to avoid issues with special characters (' " $) in php string
CMD_B64=$(echo -n "$CMD" | base64 | tr -d '\n')

# create php file
cat << EOF > "$LOCAL_FILE"
<?php
// security: short-lived token-based access protection
if (time() - $CREATED_AT > $TTL) {
    if (is_file(__FILE__)) {
        unlink(__FILE__);
    }
    http_response_code(410);
    die('Expired');
}

\$token = \$_SERVER['HTTP_X_FTPSH_TOKEN'] ?? '';
if (!hash_equals('$SECURITY_TOKEN', \$token)) {
    http_response_code(403);
    die('Access denied');
}

set_time_limit(0);
// try to increase memory limit (e.g. to 512mb or -1 for unlimited)
ini_set('memory_limit', '512M');

// some git/system commands need a home variable
putenv("HOME=" . __DIR__);
// set pwd to current directory (for \${pwd} in command)
putenv("PWD=" . __DIR__);

// decode and execute command
\$command = base64_decode('$CMD_B64', true);
if (\$command === false) {
    if (is_file(__FILE__)) {
        unlink(__FILE__);
    }
    http_response_code(500);
    die('Invalid command');
}
if (is_file(__FILE__)) {
    unlink(__FILE__);
}
passthru(\$command . ' 2>&1');
?>
EOF

# upload file via ftp/sftp (curl -t)
# -s for silent, -s for show error
curl -u "$SFTP_USER:$SFTP_PASS" \
    -T "$LOCAL_FILE" \
    -s -S --fail --connect-timeout 10 --max-time 60 \
    "$PROTOCOL://$SFTP_HOST:$SFTP_PORT/$REMOTE_PATH/"

if [ $? -ne 0 ]; then
    echo "Error uploading payload."
    exit 1
fi
UPLOADED=true

# standard mode: call file via http and output result directly
curl -s -S --fail --connect-timeout 10 --max-time 120 -H "X-Ftpsh-Token: $SECURITY_TOKEN" "$WEB_URL/$RAND_NAME"
CURL_STATUS=$?
cleanup
trap - EXIT INT TERM
exit $CURL_STATUS
