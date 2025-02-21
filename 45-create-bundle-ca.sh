#!/bin/sh

set -eu

OUTPUT_FILE="/etc/ssl/certs/combined-ca-certificates.crt"

CERTS_DIR="/etc/ssl/certs"

> "$OUTPUT_FILE"

add_cert_to_bundle() {
    local cert_file="$1"
    if [[ -f "$cert_file" ]]; then
        if ! grep -qF "$(openssl x509 -in "$cert_file" -outform PEM)" "$OUTPUT_FILE"; then
            echo "Adding $cert_file to the bundle..."
            cat "$cert_file" >> "$OUTPUT_FILE"
        else
            echo "Skipping $cert_file (already in the bundle)"
        fi
    else
        echo "Warning: $cert_file does not exist"
    fi
}

for cert_file in "$CERTS_DIR"/*.{crt,pem}; do
    add_cert_to_bundle "$cert_file"
done

echo "Certificates have been combined into $OUTPUT_FILE"
