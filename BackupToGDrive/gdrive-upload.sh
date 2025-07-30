#!/bin/zsh

# Upload a file to Google Drive using a service account and resumable upload.
# Designed for future use with Shared Drives (required by service accounts).
# Dependencies: curl, jq, openssl (optional, for encrypted archive), zsh

# -------------------------
# CONFIGURATION
# -------------------------
SERVICE_ACCOUNT_JSON="path/to/service-account.json"   # Replace with your service account key
FILE_TO_UPLOAD="encrypted_archive.tar.gz"             # File you want to upload
TARGET_PARENT_ID="your_folder_or_drive_id_here"       # Shared Drive folder or root ID
TARGET_FILENAME="backup_$(date +%Y%m%d_%H%M%S).tar.gz" # archive filename in gdrive

VERBOSE=0  # Set to 1 for debug logs

# -------------------------
# HELPER: Logging
# -------------------------
log() {
  echo "[INFO] $1"
}

debug() {
  [[ $VERBOSE -eq 1 ]] && echo "[DEBUG] $1"
}

error() {
  echo "[ERROR] $1" >&2
}

# -------------------------
# STEP 1: Extract Access Token
# -------------------------
log "Fetching OAuth access token..."

ACCESS_TOKEN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{
    "scope": "https://www.googleapis.com/auth/drive.file",
    "aud": "https://oauth2.googleapis.com/token",
    "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer"
  }' \
  --data-urlencode "assertion=$(openssl dgst -sha256 -sign <(jq -r '.private_key' "$SERVICE_ACCOUNT_JSON") \
    -outform DER | base64 -w 0)" \
  https://oauth2.googleapis.com/token | jq -r '.access_token')

if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == "null" ]]; then
  error "Failed to obtain access token."
  exit 1
fi

debug "Access Token: $ACCESS_TOKEN"

# -------------------------
# STEP 2: Start Resumable Upload Session
# -------------------------
log "Initiating resumable upload session..."

RESPONSE_HEADERS=$(mktemp)
UPLOAD_URL=$(curl -s -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json; charset=UTF-8" \
  -H "X-Upload-Content-Type: application/gzip" \
  -H "X-Upload-Content-Length: $(stat -f%z "$FILE_TO_UPLOAD")" \
  -d '{
        "name": "'"$TARGET_FILENAME"'",
        "parents": ["'"$TARGET_PARENT_ID"'"]
      }' \
  -D "$RESPONSE_HEADERS" \
  "https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable" \
  -o /dev/null)

UPLOAD_URL=$(grep -i '^location:' "$RESPONSE_HEADERS" | cut -d' ' -f2 | tr -d '\r\n')

if [[ -z "$UPLOAD_URL" ]]; then
  error "Failed to retrieve upload URL. Headers:"
  cat "$RESPONSE_HEADERS"
  exit 1
fi

debug "Upload URL: $UPLOAD_URL"
rm -f "$RESPONSE_HEADERS"

# -------------------------
# STEP 3: Upload File
# -------------------------
log "Uploading file: $FILE_TO_UPLOAD"

UPLOAD_RESPONSE=$(curl -s -X PUT "$UPLOAD_URL" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/gzip" \
  --upload-file "$FILE_TO_UPLOAD")

FILE_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.id')

if [[ -z "$FILE_ID" || "$FILE_ID" == "null" ]]; then
  error "File upload failed or no file ID returned."
  debug "Upload response: $UPLOAD_RESPONSE"
  exit 1
fi

log "Upload complete. File ID: $FILE_ID"

# -------------------------
# STEP 4: (Optional) Share with Your Google Account
# -------------------------
# Future usage: Share the file with your own account for access
# curl -s -X POST \
#   -H "Authorization: Bearer $ACCESS_TOKEN" \
#   -H "Content-Type: application/json" \
#   -d '{
#         "role": "reader",
#         "type": "user",
#         "emailAddress": "you@example.com"
#       }' \
#   "https://www.googleapis.com/drive/v3/files/$FILE_ID/permissions"

log "Backup process finished successfully."

# -------------------------
# NOTES / TODO
# -------------------------
# This script assumes a Shared Drive context (required for service accounts)
# Keep service account keys safe; rotate periodically
# Consider adding retry logic for network faults or large file uploads
# If needed, test manual file upload in your Drive UI for permission/debug help

