#!/bin/bash

# read .env file

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    # .env exists, load variables from file
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "Warning: .env not found, using environment variables."
fi

# check variables
if [ -z "$HOST" ] || [ -z "$PORT" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$REMOTE_PATH" ] || [ -z "$WEB_URL" ]; then
    echo "Error: At least one required variable missing in .env!"
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

# command from arguments (all arguments are the command)
CMD_ARGS=("$@")

# build command from remaining arguments
# simply join with spaces - the remote shell interprets them
CMD="${CMD_ARGS[*]}"

if [ -z "$CMD" ]; then
    echo "Error: No command specified!"
    echo "Example: ./ftpsh.sh git status"
    exit 1
fi

# generate random filename (security through obscurity)
RAND_NAME="exec_$(date +%s)_$RANDOM.php"
LOCAL_FILE="/tmp/$RAND_NAME"

# generate random security token (additional protection)
SECURITY_TOKEN=$(echo $RANDOM$(date +%s%N)$RANDOM | md5sum | cut -c1-32)

# base64 encode the command to avoid issues with special characters (' " $) in php string
CMD_B64=$(echo -n "$CMD" | base64)

# create php file
# we set high time limit and redirect stderr (2) to stdout (1)
cat << EOF > "$LOCAL_FILE"
<?php
// security: token-based access protection
if (!isset(\$_GET['token']) || \$_GET['token'] !== '$SECURITY_TOKEN') {
    http_response_code(403);
    die('Access denied');
}

set_time_limit(0);
// try to increase memory limit (e.g. to 512mb or -1 for unlimited)
@ini_set('memory_limit', '512M');

// some git/system commands need a home variable
putenv("HOME=" . __DIR__);
// set pwd to current directory (for \${pwd} in command)
putenv("PWD=" . __DIR__);

// decode and execute command
passthru(base64_decode('$CMD_B64') . ' 2>&1');
unlink(__FILE__);
?>
EOF

# upload file via ftp/sftp (curl -t)
# -s for silent, -s for show error
curl -u "$SFTP_USER:$SFTP_PASS" \
    -T "$LOCAL_FILE" \
    -s -S \
    "$PROTOCOL://$SFTP_HOST:$SFTP_PORT/$REMOTE_PATH/"

if [ $? -ne 0 ]; then
    echo "Error uploading payload."
    rm "$LOCAL_FILE"
    exit 1
fi

# call file via http and output result (with security token)
# the result goes directly to stdout
curl -s "$WEB_URL/$RAND_NAME?token=$SECURITY_TOKEN"

# delete file via ftp/sftp (cleanup)
# the -q (quote) command sends commands before or after the transfer.
# since we don't transfer anything, we only use it for deletion.
curl -u "$SFTP_USER:$SFTP_PASS" \
    -s -S \
    -Q "$DELETE_CMD $REMOTE_PATH/$RAND_NAME" \
    "$PROTOCOL://$SFTP_HOST:$SFTP_PORT/" > /dev/null 2>&1

# clean up local file
rm "$LOCAL_FILE"
