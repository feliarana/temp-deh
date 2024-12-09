#!/bin/bash

# Check if enough arguments are passed, otherwise display usage message
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <DB_NAME> <USERNAME> <HOST> <PORT> <BACKUP_FILE_PATH>"
    exit 1
fi

# Assign arguments to variables
DB_NAME=$1
USERNAME=$2
HOST=$3
PORT=$4
BACKUP_FILE_PATH=$5

# Ensure the backup file exists
if [ ! -f "$BACKUP_FILE_PATH" ]; then
    echo "Error: Backup file does not exist at $BACKUP_FILE_PATH"
    exit 1
fi

# Export password to use in psql without prompt
# export PGPASSWORD="$PASSWORD"

# Create the db 
# psql -h "$HOST" -p "$PORT" -U "$USERNAME" -c "CREATE DATABASE \"restore1_$DB_NAME\""

# Restore the database
psql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "restore1_$DB_NAME" -f "$BACKUP_FILE_PATH"

echo "Database restored successfully from $BACKUP_FILE_PATH"
