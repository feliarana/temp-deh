#!/bin/bash

# Check if enough arguments are passed, otherwise display usage message
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <DB_NAME> <USERNAME> <PASSWORD> <HOST> <PORT>"
    exit 1
fi

# Assign arguments to variables
DB_NAME=$1
USERNAME=$2
PASSWORD=$3
HOST=$4
PORT=$5
BACKUP_DIR="~/db_backups/backup_files"

# Format timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Backup filename
BACKUP_FILENAME="$DB_NAME"_"$TIMESTAMP".sql

# Full path to backup file
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILENAME"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Export password to use in pg_dump without prompt
export PGPASSWORD="$PASSWORD"

# Create backup
pg_dump -h "$HOST" -p "$PORT" -U "$USERNAME" -F p -d "$DB_NAME" > "$BACKUP_PATH"

# Clear the exported password
unset PGPASSWORD

echo "Backup created successfully at $BACKUP_PATH"

