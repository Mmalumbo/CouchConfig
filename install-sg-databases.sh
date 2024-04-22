#!/bin/bash

# Constants
ERROR=31
WARN=32
INFO=36

FILE_PATH="./sg-databases.json"

# Function to update or insert a database
# $1 - URL, $2 - Database, $3 - API Key
function upsert_database() {
    curl --silent --location --request PUT "${1}" --header 'Content-Type: application/json' --data-raw "${2}" --header "apikey: ${3}"
}

# Function to log messages
# $1 - color, $2 - message
function log() {
    echo "\033[0;${1}m${2}\033[0m"
}

# Function to handle the response
# $1 - response, $2 - database_name
function handle_response() {
    if [[ $response == *"error"* ]]; then
        error_message=$(echo $1 | jq -r '.error')
        log $ERROR "Error: ${error_message} \n"
    else
        log $INFO "Database ${2} processed successfully \n"
    fi
}

# Check if jq is installed
if ! command -v jq &> /dev/null
then
    log $ERROR "ERROR: jq is not installed. Please install it and run the script again."
    exit 1
fi

# Check if the correct number of arguments are provided
if [[ $# -ne 4 ]]; then
    log $ERROR "ERROR: Incorrect number of arguments."
    log $INFO "Usage: $0 -u <SG_URL> -U <SYNC_USER> -p <SYNC_PASSWORD> -k <API_KEY>"
    exit 1
fi

# Gey the arguments and valiables definitions
SG_URL=$1
SYNC_USER=$2 # NOTE: this variable is no longer used
SYNC_USER_PASSWORD=$3 # NOTE: This variable is no longer used
API_KEY=$4

# Check if file exists
if [[ -f "${FILE_PATH}" ]]; then
    # Get length of the array
    length=$(jq '. | length' $FILE_PATH)

    if [[ $length -eq 0 ]]; then
        log $ERROR "No databases found in the file"
        exit 1
    fi

    # Loop through the array
    for ((i = 0; i < length; i++)); do
        DATABASE=$(jq -c ".[$i]" $FILE_PATH)

        DATABASE_NAME=$(echo $DATABASE | jq -r '.name')
        URL="${SG_URL}/${DATABASE_NAME}/"

        log $INFO "Processing database: ${DATABASE_NAME} at ${URL}"

        # check if the database Exists
        response=$(curl --silent --location --request GET "${URL}" --header "apikey: ${API_KEY}" --output /dev/null --write-out "%{http_code}")
        if [ "$response" -eq 200 ]; then
            log $INFO "Updating the database ${DATABASE_NAME}"

            URL="${SG_URL}/${DATABASE_NAME}/_config"
            response=$(upsert_database "${URL}" "${DATABASE}" "${API_KEY}")

            handle_response "$response" "$DATABASE_NAME"
        elif [ "$response" -eq 404 ]; then
            log $INFO "Creating the database ${DATABASE_NAME}"

            response=$(upsert_database "${URL}" "${DATABASE}" "${API_KEY}")

            handle_response "$response" "$DATABASE_NAME"
        else
            log $ERROR "API error occurred"
            log $ERROR "We could not process the database ${DATABASE_NAME} \n"
            continue
        fi
    done
else
    log $ERROR "Error: File ${FILE_PATH} does not exist"
    exit 1
fi