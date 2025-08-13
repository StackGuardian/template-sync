#!/bin/bash

# StackGuardian Template Push Script
# This script pushes local template information from .sg folder back to StackGuardian API
# It uses the PATCH method to update the template with local changes

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Debug logging function
debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [DEBUG] $1" >&2
    fi
}

# Log function for consistent messaging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling function
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Check if required environment variables are set
check_env_vars() {
    local missing_vars=()
    
    [[ -z "${SG_TOKEN:-}" ]] && missing_vars+=("SG_TOKEN")
    [[ -z "${SG_ORG:-}" ]] && missing_vars+=("SG_ORG")
    [[ -z "${SG_TEMPLATE:-}" ]] && missing_vars+=("SG_TEMPLATE")
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        handle_error "Missing required environment variables: ${missing_vars[*]}"
    fi
    
    # Set default values if not provided
    SG_BASE_PATH="${SG_BASE_PATH:-.sg}"
    SG_BASE_URL="${SG_BASE_URL:-https://api.app.stackguardian.io}"
    
    debug "Environment variables set:"
    debug "  SG_TOKEN: ${SG_TOKEN:0:5}... (masked)"
    debug "  SG_ORG: $SG_ORG"
    debug "  SG_TEMPLATE: $SG_TEMPLATE"
    debug "  SG_BASE_PATH: $SG_BASE_PATH"
    debug "  SG_BASE_URL: $SG_BASE_URL"
}

# Function to make API calls with PATCH method
api_patch_call() {
    local url="$1"
    local data="$2"
    local response
    
    debug "Making PATCH API call to: $url"
    
    debug "API call headers:"
    debug "  Authorization: apikey ${SG_TOKEN:0:5}... (masked)"
    debug "  X-Sg-Orgid: $SG_ORG"
    debug "  Content-Type: application/json"
    
    response=$(curl -s -X PATCH \
        -H "Authorization: apikey ${SG_TOKEN}" \
        -H "X-Sg-Orgid: ${SG_ORG}" \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$url")
    
    debug "API response received (first 200 characters): ${response:0:200}..."
    
    # Check if response contains error
    if echo "$response" | jq -e '.errors' > /dev/null 2>&1; then
        handle_error "API error: $(echo "$response" | jq -r '.errors')"
    fi
    
    echo "$response"
}

# Function to read local files and prepare data for API update
prepare_template_data() {
    local long_description=""
    local schema_data=""
    local ui_schema_data=""
    
    # Read documentation.md
    if [[ -f "${SG_BASE_PATH}/documentation.md" ]]; then
        long_description=$(cat "${SG_BASE_PATH}/documentation.md")
        debug "Read documentation.md (${#long_description} characters)"
    else
        log "Warning: ${SG_BASE_PATH}/documentation.md not found"
    fi
    
    # Read schema.json and encode it
    if [[ -f "${SG_BASE_PATH}/schema.json" ]]; then
        schema_data=$(cat "${SG_BASE_PATH}/schema.json" | base64)
        debug "Read and encoded schema.json (${#schema_data} characters)"
    else
        log "Warning: ${SG_BASE_PATH}/schema.json not found"
    fi
    
    # Read ui.json and encode it
    if [[ -f "${SG_BASE_PATH}/ui.json" ]]; then
        ui_schema_data=$(cat "${SG_BASE_PATH}/ui.json" | base64)
        debug "Read and encoded ui.json (${#ui_schema_data} characters)"
    else
        log "Warning: ${SG_BASE_PATH}/ui.json not found"
    fi
    
    # Create JSON payload for the API
    local payload
    payload=$(jq -n \
        --arg longDesc "$long_description" \
        --arg schemaData "$schema_data" \
        --arg uiSchemaData "$ui_schema_data" \
        '{
            "LongDescription": $longDesc,
            "InputSchemas": [{
                "type": "FORM_JSONSCHEMA",
                "encodedData": $schemaData,
                "uiSchemaData": $uiSchemaData
            }]
        }')
    
    echo "$payload"
}

# Main execution
main() {
    log "Running StackGuardian Template Push..."
    
    # Validate environment variables
    check_env_vars
    
    # Check if base path exists
    if [[ ! -d "$SG_BASE_PATH" ]]; then
        handle_error "Base path $SG_BASE_PATH does not exist"
    fi
    
    # Prepare data for API update
    log "Preparing template data from ${SG_BASE_PATH}"
    local template_data
    template_data=$(prepare_template_data)
    
    debug "Prepared template data (first 200 characters): ${template_data:0:200}..."
    
    # Fetch template summary to get latest revision
    local template_summary_url="${SG_BASE_URL}/api/v1/templatetypes/IAC/${SG_ORG}/${SG_TEMPLATE}/"
    debug "Template summary URL: $template_summary_url"
    
    local template_summary
    template_summary=$(curl -s -H "Authorization: apikey ${SG_TOKEN}" \
        -H "X-Sg-Orgid: ${SG_ORG}" \
        "$template_summary_url")
    
    debug "Template summary response (first 200 characters): ${template_summary:0:200}..."
    
    # Extract latest revision
    local latest_revision
    latest_revision=$(( $(echo "$template_summary" | jq -r '.msg.NextRevision') - 1 ))
    
    debug "Calculated latest revision: $latest_revision"
    
    if [[ $latest_revision -lt 0 ]]; then
        handle_error "Invalid latest revision: $latest_revision"
    fi
    
    log "Latest revision: $latest_revision"
    
    # Update template with local changes using PATCH method
    local template_update_url="${SG_BASE_URL}/api/v1/templatetypes/IAC/${SG_ORG}/${SG_TEMPLATE}:${latest_revision}/"
    debug "Template update URL: $template_update_url"
    
    local update_response
    update_response=$(api_patch_call "$template_update_url" "$template_data")
    
    debug "Template update response (first 200 characters): ${update_response:0:200}..."
    
    log "Template push completed successfully"
}

# Run main function
main "$@"