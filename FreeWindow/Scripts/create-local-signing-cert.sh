#!/bin/bash
# create-local-signing-cert.sh — Create a stable local code-signing identity.
# Uses the same certificate for every build so macOS TCC can persist Accessibility
# grants across rebuilds (unlike ad-hoc signing which changes CDHash every time).
#
# Personal use on this Mac only. For Apple-issued certs, use ./Scripts/setup-signing.sh.
set -euo pipefail

CERT_NAME="FreeWindow Local Dev"
KEYCHAIN_PATH="${HOME}/Library/Keychains/login.keychain-db"
CERT_DIR="${HOME}/.freewindow/signing"
CERT_PEM="${CERT_DIR}/freewindow-local-dev.pem"
P12_PATH="${CERT_DIR}/freewindow-local-dev.p12"

mkdir -p "${CERT_DIR}"

if security find-certificate -c "${CERT_NAME}" "${KEYCHAIN_PATH}" &>/dev/null; then
    echo "🧹 Removing old local certificate: ${CERT_NAME}"
    security delete-certificate -c "${CERT_NAME}" "${KEYCHAIN_PATH}" 2>/dev/null || true
fi

echo "🔐 Creating local code-signing certificate: ${CERT_NAME}"

cat > "${CERT_DIR}/openssl-local.cnf" <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[ dn ]
CN = ${CERT_NAME}
O = FreeWindow
C = US

[ v3_req ]
basicConstraints = critical,CA:TRUE
keyUsage = critical,digitalSignature,keyCertSign
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 \
    -keyout "${CERT_DIR}/freewindow-local-dev.key" \
    -out "${CERT_PEM}" \
    -days 3650 -nodes \
    -config "${CERT_DIR}/openssl-local.cnf" \
    -extensions v3_req 2>/dev/null

openssl pkcs12 -export -legacy \
    -out "${P12_PATH}" \
    -inkey "${CERT_DIR}/freewindow-local-dev.key" \
    -in "${CERT_PEM}" \
    -passout pass:freewindow

security import "${P12_PATH}" \
    -k "${KEYCHAIN_PATH}" \
    -P freewindow \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    -A

# Trust this self-signed certificate for code signing on this user account.
# Without explicit trust, Gatekeeper/TCC can reject apps signed by it.
security add-trusted-cert \
    -r trustRoot \
    -p codeSign \
    -k "${KEYCHAIN_PATH}" \
    "${CERT_PEM}"

security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s -k "" "${KEYCHAIN_PATH}" 2>/dev/null || true

echo "✅ Created: ${CERT_NAME}"
security find-identity -v -p codesigning "${KEYCHAIN_PATH}" | grep "${CERT_NAME}" || true
echo ""
echo "Next: ./Scripts/build-dmg.sh && ./Scripts/install.sh"
echo "Then grant Accessibility to FreeWindow once in System Settings."
