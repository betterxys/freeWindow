#!/bin/bash
# setup-signing.sh — One-time setup so FreeWindow keeps Accessibility after rebuilds.
set -euo pipefail

echo "FreeWindow 权限持久化 — 签名证书设置"
echo "======================================"
echo ""
echo "原因：当前 ad-hoc 签名每次编译都会换二进制指纹，macOS 会当成新应用，"
echo "      辅助功能开关虽然开着却不生效，只能关→开一次。"
echo ""
echo "解决：使用稳定的代码签名证书，让权限绑定在 Bundle ID + 证书上，"
echo "      以后重装/升级一般不用再动开关。"
echo ""

IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
if printf '%s\n' "$IDENTITIES" | grep -qE 'Developer ID Application:|Apple Development:|FreeWindow Local Dev'; then
    echo "✅ 已有可用签名证书："
    printf '%s\n' "$IDENTITIES" | grep -E 'Developer ID Application:|Apple Development:|FreeWindow Local Dev'
    echo ""
    echo "直接重新构建即可："
    echo "  ./Scripts/build-dmg.sh && ./Scripts/install.sh"
    echo ""
    echo "首次用新证书安装后，在「辅助功能」里为 FreeWindow 授权一次；"
    echo "之后同机升级通常不用再关→开。"
    exit 0
fi

echo "⚠️  还没有可用的代码签名证书。"
echo ""
echo "仅本机自用（推荐）："
echo "  ./Scripts/create-local-signing-cert.sh"
echo ""
echo "公开分发："
echo "  使用 Apple Developer Program 的 Developer ID Application 证书，"
echo "  并对 App/DMG 做 notarization。"
echo ""
exit 1
