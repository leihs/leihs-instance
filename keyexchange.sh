#!/bin/bash
set -e

LOGFILE="/tmp/startup.log"
exec >> $LOGFILE 2>&1  # Redirect stdout and stderr to log file

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$(hostname)] Running startup.sh"

USER_HOME="/root"
KEY_DIR="/shared-keys"
PUB_KEY_FILE="$KEY_DIR/$(hostname).pub"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Exporting own public key to $PUB_KEY_FILE"
cp "$USER_HOME/.ssh/id_rsa.pub" "$PUB_KEY_FILE" || {
  echo "ERROR: Failed to copy public key"
  exit 1
}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for other container's key..."
TIMEOUT=300  # Timeout in seconds
START_TIME=$(date +%s)

while [ $(ls "$KEY_DIR"/*.pub 2>/dev/null | wc -l) -lt 2 ]; do
  CURRENT_TIME=$(date +%s)
  ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
  if [ $ELAPSED_TIME -ge $TIMEOUT ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Timeout reached while waiting for keys"
    exit 1
  fi
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Still waiting for keys, found $(ls $KEY_DIR/*.pub | wc -l)"
  sleep 1
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Found keys: $(ls $KEY_DIR/*.pub)"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Adding other containers' public keys to authorized_keys"
for key in "$KEY_DIR"/*.pub; do
  if [[ "$key" != "$PUB_KEY_FILE" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Adding key $key"
    cat "$key" >> "$USER_HOME/.ssh/authorized_keys"
  fi
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting permissions on .ssh directory and authorized_keys"
chown -R root:root "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"
chmod 600 "$USER_HOME/.ssh/authorized_keys"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting SSH server"
if ! pgrep -x sshd > /dev/null; then
    exec /usr/sbin/sshd -D
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSH server already running"
fi
exit 0
