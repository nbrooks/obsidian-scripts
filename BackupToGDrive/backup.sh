#!/bin/sh


### Setup script flags

# TODO

BACKUP_DATE=$(date -u +"%Y-%m-%d-%H%M-Z")

### Load script properties

PROPS_FILE="$1"

if [ ! -f "$PROPS_FILE" ]; then
  echo "File '$PROPS_FILE' does not exist"
  exit
fi

# Source the properties file
source "$PROPS_FILE"

## Debug Properties
echo "PATH_TO_OBSIDIAN_VAULT='$PATH_TO_OBSIDIAN_VAULT'"
echo "PATH_TO_BACKUP_FOLDER='$PATH_TO_BACKUP_FOLDER'"

# TODO Remove
echo $PATH_TO_ENCRYPTION_KEY
echo $KEY_GDRIVE


### Find vault location

if [ ! -d "$PATH_TO_OBSIDIAN_VAULT" ]; then
  echo "Directory '$PATH_TO_OBSIDIAN_VAULT' does not exist"
  exit
fi

if [ ! -r "$PATH_TO_OBSIDIAN_VAULT" ]; then
  echo "Directory '$PATH_TO_OBSIDIAN_VAULT' is not accessible"
  exit
fi

echo "Vault located. Beginning backup process."


### Compress and encrypt

tar zcvf - '$PATH_TO_OBSIDIAN_VAULT' | openssl enc -aes-256-cbc -pbkdf2 -iter 10000 -kfile '$PATH_TO_ENCRYPTION_KEY' -salt -out Obs-Backup-$BACKUP_DATE.tar.gz


### Transfer to Repo (SCP, HTTPS)

## https://developers.google.com/workspace/drive/api/guides/about-sdk
## gdrive-upload.sh

### Clean-up local tar.gz file