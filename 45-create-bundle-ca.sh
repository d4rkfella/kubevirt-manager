#!/bin/bash

set -euo pipefail

OUTPUT_FILE="/etc/ssl/certs/bundled/combined-ca-certificates.crt"

CERTS_DIR="/etc/ssl/certs"

> "$OUTPUT_FILE"

add_cert_to_bundle() {
    local cert_file="$1"
    if [[ -f "$cert_file" ]]; then
        if openssl x509 -in "$cert_file" -outform PEM > /dev/null 2>&1; then
            if ! grep -qF "$(openssl x509 -in "$cert_file" -outform PEM)" "$OUTPUT_FILE"; then
                echo "Adding $cert_file to the bundle..."
                cat "$cert_file" >> "$OUTPUT_FILE"
            else
                echo "Skipping $cert_file (already in the bundle)"
            fi
        else
            echo "Splitting $cert_file into individual certificates..."
            awk '
                /-----BEGIN CERTIFICATE-----/ { filename = "cert-" ++i ".crt" }
                { print > filename }
            ' "$cert_file"

            for split_file in cert-*.crt; do
                if [[ -f "$split_file" ]]; then
                    add_cert_to_bundle "$split_file"
                    rm "$split_file"
                fi
            done
        fi
    else
        echo "Warning: $cert_file does not exist"
    fi
}

for cert_file in "$CERTS_DIR"/*.{crt,pem}; do
    if [[ -f "$cert_file" ]]; then
        add_cert_to_bundle "$cert_file"
    fi
done

echo "Certificates have been combined into $OUTPUT_FILE"
