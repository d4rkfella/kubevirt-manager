#!/bin/bash

set -euo pipefail

OUTPUT_FILE="/etc/ssl/certs/bundled/combined-ca-certificates.crt"

CERTS_DIR="/etc/ssl/certs"

FINGERPRINTS_FILE=$(mktemp)

> "$OUTPUT_FILE"

get_fingerprint() {
    echo "$1" | openssl x509 -noout -fingerprint -sha256 | sed 's/://g' | awk -F= '{print $2}'
}

add_certs_to_bundle() {
    local cert_file="$1"
    if [[ -f "$cert_file" ]]; then
        if openssl crl2pkcs7 -nocrl -certfile "$cert_file" | openssl pkcs7 -print_certs -text -noout > /dev/null 2>&1; then
            echo "Processing certificates from $cert_file..."
            openssl crl2pkcs7 -nocrl -certfile "$cert_file" | \
            openssl pkcs7 -print_certs -text -noout | \
            awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' | \
            while read -r line; do
                if [[ "$line" == *"END CERTIFICATE"* ]]; then
                    local fingerprint
                    fingerprint=$(get_fingerprint "$cert")
                    if ! grep -q "$fingerprint" "$FINGERPRINTS_FILE"; then
                        echo "$fingerprint" >> "$FINGERPRINTS_FILE"
                        echo "$cert" >> "$OUTPUT_FILE"
                    else
                        echo "Duplicate certificate found in $cert_file with fingerprint: $fingerprint"
                        echo "Skipping duplicate certificate:"
                        echo "$cert"
                        echo "-----"
                    fi
                    cert=""
                else
                    cert+="$line"$'\n'
                fi
            done
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

rm -f "$FINGERPRINTS_FILE"

echo "Certificates have been combined into $OUTPUT_FILE"
