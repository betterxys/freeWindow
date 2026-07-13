#!/bin/bash
# resolve-sign-identity.sh — Pick a stable codesign identity for FreeWindow.
# Ad-hoc signing (codesign --sign -) changes the binary hash every build, which
# forces users to toggle Accessibility off/on after each install. Apple Development
# or Developer ID signing binds TCC to bundle ID + team, so permission survives rebuilds.
#
# Usage: source Scripts/resolve-sign-identity.sh
# Sets SIGN_IDENTITY (empty = ad-hoc fallback).

resolve_sign_identity() {
    if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
        SIGN_IDENTITY="$CODESIGN_IDENTITY"
        return
    fi

    local identities
    identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

    # Prefer Developer ID for distribution, then Apple Development for local dev.
    SIGN_IDENTITY="$(printf '%s\n' "$identities" \
        | { grep -E 'Developer ID Application:' || true; } \
        | head -1 \
        | awk '{print $2}')"

    if [[ -z "$SIGN_IDENTITY" ]]; then
        SIGN_IDENTITY="$(printf '%s\n' "$identities" \
            | { grep -E 'Apple Development:' || true; } \
            | head -1 \
            | awk '{print $2}')"
    fi

    # Personal-use fallback. This must be a trusted local code-signing identity
    # created by create-local-signing-cert.sh; untrusted self-signed certs are
    # intentionally rejected by macOS/TCC.
    if [[ -z "$SIGN_IDENTITY" ]]; then
        SIGN_IDENTITY="$(printf '%s\n' "$identities" \
            | { grep -F 'FreeWindow Local Dev' || true; } \
            | head -1 \
            | awk '{print $2}')"
    fi
}

resolve_sign_identity
