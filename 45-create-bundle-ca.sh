#!/bin/bash

set -euo pipefail

OUTPUT_FILE="/tmp/ssl/certs/bundled/combined-ca-certificates.crt"
CERTS_DIR="/etc/ssl/certs"
FINGERPRINTS_FILE=$(mktemp)

# Create the output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Clear the output file
> "$OUTPUT_FILE"

# Function to get the SHA-256 fingerprint of a certificate
get_fingerprint() {
    echo "$1" | openssl x509 -noout -fingerprint -sha256 | sed 's/://g' | awk -F= '{print $2}'
}

# Function to validate a certificate
validate_certificate() {
    echo "$1" | openssl x509 -noout > /dev/null 2>&1
    return $?
}

# Function to add certificates from a file to the bundle
add_certs_to_bundle() {
    local cert_file="$1"
    if [[ -f "$cert_file" ]]; then
        echo "Processing certificates from $cert_file..."
        # Extract certificates using awk
        awk '
            /BEGIN CERTIFICATE/,/END CERTIFICATE/ {
                print $0
            }
        ' "$cert_file" | while read -r line; do
            if [[ "$line" == *"END CERTIFICATE"* ]]; then
                cert+="$line"
                # Validate the certificate
                if validate_certificate "$cert"; then
                    local fingerprint
                    fingerprint=$(get_fingerprint "$cert")
                    echo "Found valid certificate with fingerprint: $fingerprint"
                    if ! grep -q "$fingerprint" "$FINGERPRINTS_FILE"; then
                        echo "$fingerprint" >> "$FINGERPRINTS_FILE"
                        echo "$cert" >> "$OUTPUT_FILE"
                        echo "Added certificate to bundle."
                    else
                        echo "Duplicate certificate found in $cert_file with fingerprint: $fingerprint"
                        echo "Skipping duplicate certificate."
                    fi
                else
                    echo "Invalid certificate found in $cert_file. Skipping."
                fi
                cert=""
            else
                cert+="$line"$'\n'  # Add a newline for all lines except END CERTIFICATE
            fi
        done
    else
        echo "Warning: $cert_file does not exist"
    fi
}

# Process all .crt and .pem files in the CERTS_DIR
for cert_file in "$CERTS_DIR"/*.{crt,pem}; do
    if [[ -f "$cert_file" ]]; then
        add_certs_to_bundle "$cert_file"
    fi
done

# Clean up the fingerprints file
rm -f "$FINGERPRINTS_FILE"

echo "Certificates have been combined into $OUTPUT_FILE"
