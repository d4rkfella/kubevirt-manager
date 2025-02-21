#!/bin/bash

set -euo pipefail

# Output file for the combined certificates
OUTPUT_FILE="/etc/ssl/certs/bundled/combined-ca-certificates.crt"

CERTS_DIR="/etc/ssl/certs"

> "$OUTPUT_FILE"

add_certs_to_bundle() {
    local cert_file="$1"
    if [[ -f "$cert_file" ]]; then
        if openssl crl2pkcs7 -nocrl -certfile "$cert_file" | openssl pkcs7 -print_certs -text -noout > /dev/null 2>&1; then
            echo "Adding certificates from $cert_file to the bundle..."
            cat "$cert_file" >> "$OUTPUT_FILE"
        else
            echo "Warning: $cert_file is not a valid PEM-encoded certificate or bundle"
        fi
    else
        echo "Warning: $cert_file does not exist"
    fi
}

for cert_file in "$CERTS_DIR"/*.{crt,pem}; do
    if [[ -f "$cert_file" ]]; then
        add_certs_to_bundle "$cert_file"
    fi
done

echo "Certificates have been combined into $OUTPUT_FILE"
