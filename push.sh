#!/bin/bash

# StackGuardian Template Push Script
# This script pushes local template information from .sg folder back to StackGuardian API
# It uses the PATCH method to update the template with local changes

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
    log "[ERROR] $1" >&2
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

# Function to make API calls with PATCH method
api_patch_call() {
    local url="$1"
    local data="$2"
    local response
    
    debug "Making PATCH API call to: $url"
    
    local org_id
    org_id=$(echo "$SG_TEMPLATE_ID" | cut -d'/' -f2)

    debug "API call headers:"
    debug "  Authorization: apikey ${SG_TOKEN:0:5}... (masked)"
    debug "  x-sg-orgid: $org_id"
    debug "  Content-Type: application/json"
    
    response=$(curl -s -X PATCH \
        -H "Authorization: apikey ${SG_TOKEN}" \
        -H "x-sg-orgid: $org_id" \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$url")

    debug "API response received (first 200 characters): ${response:0:200}..."
    
    # Check if response contains error
    if echo "$response" | jq -e '.errors' > /dev/null 2>&1; then
        error "API error: $(echo "$response" | jq -r '.errors')"
    fi
    
    echo "$response"
}

# Function to convert YAML to JSON
yaml_to_json() {
    yq eval -o json
}

# Function to read local files and prepare data for API update
prepare_template_data() {
    local long_description=""
    local schema_data=""
    local ui_schema_data=""
    
    # Determine file extensions based on YAML flag
    local schema_ext="json"
    local ui_ext="json"
    if [[ "$USE_YAML" == true ]]; then
        schema_ext="yaml"
        ui_ext="yaml"
    fi

    # Create a base payload
    local payload
    payload=$(jq -n \
        --arg schemaData "" \
        --arg uiSchemaData "" \
        '{
            "InputSchemas": [{
                "type": "FORM_JSONSCHEMA",
                "encodedData": $schemaData,
                "uiSchemaData": $uiSchemaData
            }]
        }')

    # Conditionally add LongDescription
    if [[ -f "${SG_BASE_PATH}/documentation.md" ]]; then
        long_description=$(cat "${SG_BASE_PATH}/documentation.md")
        debug "Read documentation.md (${#long_description} characters)"
        payload=$(echo "$payload" | jq --arg longDesc "$long_description" '.LongDescription = $longDesc')
    else
        log "Warning: ${SG_BASE_PATH}/documentation.md not found" >&2
    fi

    # Read schema file and encode it
    if [[ -f "${SG_BASE_PATH}/schema.${schema_ext}" ]]; then
        if [[ "$USE_YAML" == true ]]; then
            schema_data=$(cat "${SG_BASE_PATH}/schema.${schema_ext}" | yaml_to_json | base64)
        else
            schema_data=$(cat "${SG_BASE_PATH}/schema.${schema_ext}" | base64)
        fi
        debug "Read and encoded schema.${schema_ext} (${#schema_data} characters)"
        payload=$(echo "$payload" | jq --arg schemaData "$schema_data" '.InputSchemas[0].encodedData = $schemaData')
    else
        error "${SG_BASE_PATH}/schema.${schema_ext} not found"
    fi

    # Read ui file and encode it
    if [[ -f "${SG_BASE_PATH}/ui.${ui_ext}" ]]; then
        if [[ "$USE_YAML" == true ]]; then
            ui_schema_data=$(cat "${SG_BASE_PATH}/ui.${ui_ext}" | yaml_to_json | base64)
        else
            ui_schema_data=$(cat "${SG_BASE_PATH}/ui.${ui_ext}" | base64)
        fi
        debug "Read and encoded ui.${ui_ext} (${#ui_schema_data} characters)"
        payload=$(echo "$payload" | jq --arg uiSchemaData "$ui_schema_data" '.InputSchemas[0].uiSchemaData = $uiSchemaData')
    else
        error "${SG_BASE_PATH}/ui.${ui_ext} not found"
    fi

    echo "$payload"
}

# Main execution
main() {
    # Parse command line arguments
    parse_args "$@"
    
    log "Running StackGuardian Template Push..."
    
    # Validate environment variables
    check_env_vars
    
    # Check if base path exists
    if [[ ! -d "$SG_BASE_PATH" ]]; then
        error "Base path $SG_BASE_PATH does not exist"
    fi
    
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

    # Validate template status before updating
    log "Validating template status..."
    local template_details_url="${SG_BASE_URL}/api/v1/templatetypes/IAC${final_template_id}"
    local template_details
    template_details=$(api_call "$template_details_url")

    
    local is_public
    is_public=$(echo "$template_details" | jq -r '.msg.IsPublic')

    if [[ "$is_public" == "1" ]]; then
        error "Cannot update a published template revision."
    fi

    log "Template is not published. Proceeding with update."

    # Prepare data for API update
    log "Preparing template data from ${SG_BASE_PATH}"
    local template_data
    template_data=$(prepare_template_data)
    
    debug "Prepared template data (first 200 characters): ${template_data:0:200}..."
    
    # Update template with local changes using PATCH method
    local template_update_url="${SG_BASE_URL}/api/v1/templatetypes/IAC${final_template_id}"
    debug "Template update URL: $template_update_url"

    local update_response
    update_response=$(api_patch_call "$template_update_url" "$template_data")
    
    debug "Template update response (first 200 characters): ${update_response:0:200}..."
    
    log "Template push completed successfully"
}

# Run main function
main "$@"