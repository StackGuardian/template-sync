#!/bin/bash

# StackGuardian Template Sync Script
# This script fetches template information from StackGuardian API and syncs it with local files
# README.md is intentionally left untouched - only documentation.md is updated with LongDescription

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Debug logging function
debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        log "[DEBUG] $1" >&2
    fi
}

# Log function for consistent messaging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling function
error() {
    log "[ERROR] $1"
    exit 1
}

# Parse command line arguments
parse_args() {
    USE_YAML=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --yaml)
                USE_YAML=true
                shift
                ;;
            *)
                handle_error "Unknown option: $1"
                ;;
        esac
    done
}

# Check if required environment variables are set
check_env_vars() {
    local missing_vars=()
    
    [[ -z "${SG_TOKEN:-}" ]] && missing_vars+=("SG_TOKEN")
    [[ -z "${SG_TEMPLATE_ID:-}" ]] && missing_vars+=("SG_TEMPLATE_ID")
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        error "Missing required environment variables: ${missing_vars[*]}"
    fi
    
    # Set default values if not provided
    SG_BASE_PATH="${SG_BASE_PATH:-.sg}"
    SG_BASE_URL="${SG_BASE_URL:-https://api.app.stackguardian.io}"
    
    debug "Environment variables set:"
    debug "  SG_TOKEN: ${SG_TOKEN:0:5}... (masked)"
    debug "  SG_TEMPLATE_ID: $SG_TEMPLATE_ID"
    debug "  SG_BASE_PATH: $SG_BASE_PATH"
    debug "  SG_BASE_URL: $SG_BASE_URL"
    debug "  USE_YAML: $USE_YAML"
}

# Function to make API calls
api_call() {
    local url="$1"
    local org_id
    org_id=$(echo "$SG_TEMPLATE_ID" | cut -d'/' -f2)
    local response
    
    debug "Making API call to: $url"
    
    debug "API call headers:"
    debug "  Authorization: apikey ${SG_TOKEN:0:5}... (masked)"
    debug "  x-sg-orgid: $org_id"
    
    response=$(curl -s -H "Authorization: apikey ${SG_TOKEN}" \
        -H "x-sg-orgid: $org_id" \
        "$url")
    
    debug "API response received (first 200 characters): ${response:0:200}..."
    
    # Check if response contains error
    if echo "$response" | jq -e '.errors' > /dev/null 2>&1; then
        error "API error: $(echo "$response" | jq -r '.errors')"
    fi
    
    echo "$response"
}

# Function to extract and save LongDescription to documentation.md
save_documentation() {
    local details="$1"
    local long_description
    
    long_description=$(echo "$details" | jq -r '.msg.LongDescription // empty')
    
    if [[ -n "$long_description" ]]; then
        debug "LongDescription content (first 200 characters): ${long_description:0:200}..."
        echo "$long_description" > "${SG_BASE_PATH}/documentation.md"
        log "Saved LongDescription to ${SG_BASE_PATH}/documentation.md"
    else
        log "No LongDescription found, documentation.md not updated"
    fi
}

# Function to convert JSON to YAML
json_to_yaml() {
    yq eval -P -o yaml
}

# Function to extract and save schema data
save_schema_data() {
    local details="$1"

    debug "Processing schema data extraction by index"

    # Function to save JSON data
    save_json() {
        local data="$1"
        local file_path="$2"
        echo "$data" | base64 -d | jq '.' > "$file_path"
    }
    
    # Determine file extensions based on YAML flag
    local schema_ext="json"
    local ui_ext="json"
    if [[ "$USE_YAML" == true ]]; then
        schema_ext="yaml"
        ui_ext="yaml"
    fi
    
    # Extract and decode encodedData from InputSchemas[0].encodedData (for schema.json/yaml)
    local ui_schema_data
    ui_schema_data=$(echo "$details" | jq -r '.msg.InputSchemas[0].encodedData // empty')
    debug "uiSchemaData length: ${#ui_schema_data}"
    
    if [[ -n "$ui_schema_data" ]]; then
        if [[ "$USE_YAML" == true ]]; then
            echo "$ui_schema_data" | base64 -d | json_to_yaml > "${SG_BASE_PATH}/schema.${schema_ext}"
            log "Saved uiSchemaData to ${SG_BASE_PATH}/schema.${schema_ext}"
        else
            echo "$ui_schema_data" | base64 -d | jq '.' > "${SG_BASE_PATH}/schema.${schema_ext}"
            log "Saved uiSchemaData to ${SG_BASE_PATH}/schema.${schema_ext}"
        fi
    else
        log "No uiSchemaData found in InputSchemas[0].encodedData"
    fi
    
    # Extract and decode uiSchemaData from InputSchemas[0].uiSchemaData (for ui.json/yaml)
    local schema_data
    schema_data=$(echo "$details" | jq -r '.msg.InputSchemas[0].uiSchemaData // empty')
    debug "encodedData length: ${#schema_data}"
    
    if [[ -n "$schema_data" ]]; then
        if [[ "$USE_YAML" == true ]]; then
            echo "$schema_data" | base64 -d | json_to_yaml > "${SG_BASE_PATH}/ui.${ui_ext}"
            log "Saved encodedData to ${SG_BASE_PATH}/ui.${ui_ext}"
        else
            echo "$schema_data" | base64 -d | jq '.' > "${SG_BASE_PATH}/ui.${ui_ext}"
            log "Saved encodedData to ${SG_BASE_PATH}/ui.${ui_ext}"
        fi
    else
        log "No encodedData found in InputSchemas[0].uiSchemaData"
    fi
}

# Main execution
main() {
    # Parse command line arguments
    parse_args "$@"
    
    log "Running StackGuardian Template Sync..."
    
    # Validate environment variables
    check_env_vars
    
    # Ensure base path exists
    debug "Ensuring base path exists: $SG_BASE_PATH"
    mkdir -p "$SG_BASE_PATH"
    
    # Resolve Template ID if revision is not specified
    local final_template_id="$SG_TEMPLATE_ID"
    if [[ ! "$SG_TEMPLATE_ID" =~ :[0-9]+$ ]]; then
        log "Revision not specified in SG_TEMPLATE_ID, resolving latest..."
        local template_list_url="${SG_BASE_URL}/api/v1/templatetypes/IAC/templates/listall/?TemplateId=${SG_TEMPLATE_ID}"
        debug "Template list URL: $template_list_url"
        local template_list
        template_list=$(api_call "$template_list_url")

        debug "Template list response (first 200 characters): ${template_list:0:200}..."

        # Extract latest revision's TemplateId
        final_template_id=$(echo "$template_list" | jq -r '.msg[-1].TemplateId')

        debug "Resolved latest TemplateId: $final_template_id"

        if [[ -z "$final_template_id" || "$final_template_id" == "null" ]]; then
            error "Could not determine latest TemplateId for ${SG_TEMPLATE_ID}"
        fi
    else
        log "Revision specified in SG_TEMPLATE_ID, using it directly."
    fi

    log "Using TemplateId: $final_template_id"

    # Fetch details for the final revision
    local template_details_url="${SG_BASE_URL}/api/v1/templatetypes/IAC${final_template_id}"
    debug "Template details URL: $template_details_url"
    local latest_revision_details
    latest_revision_details=$(api_call "$template_details_url")
    
    debug "Template details response (first 200 characters): ${latest_revision_details:0:200}..."

    # Extract and save data to files
    debug "Saving documentation.md"
    save_documentation "$latest_revision_details"
    
    debug "Saving schema data"
    save_schema_data "$latest_revision_details"
    
    log "Template sync completed successfully"
}

# Run main function
main "$@"