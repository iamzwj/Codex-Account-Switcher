#!/bin/zsh
set -eu
cd -- "${0:A:h}"
app="Codex 账号切换.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Codex 账号切换</string>
<key>CFBundleIdentifier</key><string>local.codex.accounts</string>
<key>CFBundleExecutable</key><string>CodexAccounts</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>AppIcon.icns</string>
<key>CFBundleVersion</key><string>1</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
swiftc -module-cache-path "${TMPDIR:-/tmp}/codex-accounts-swift-cache" -parse-as-library Accounts.swift -o "$app/Contents/MacOS/CodexAccounts"
cp codex-accounts "$app/Contents/Resources/codex-accounts"
icon_work=$(mktemp -d)
trap 'rm -rf -- "$icon_work"' EXIT
swift -module-cache-path "${TMPDIR:-/tmp}/codex-accounts-swift-cache" AppIcon.swift "$icon_work/master.png"
for pixels in 16 32 64 128 256 512 1024; do
    sips -z "$pixels" "$pixels" "$icon_work/master.png" --out "$icon_work/$pixels.png" >/dev/null
done
python3 - "$icon_work" "$app/Contents/Resources/AppIcon.icns" <<'PYICON'
from pathlib import Path
import struct
import sys

source, output = map(Path, sys.argv[1:])
chunks = []
for size, kind in [(16, b'icp4'), (32, b'icp5'), (64, b'icp6'), (128, b'ic07'),
                   (256, b'ic08'), (512, b'ic09'), (1024, b'ic10')]:
    png = (source / f'{size}.png').read_bytes()
    chunks.append(struct.pack('>4sI', kind, 8 + len(png)) + png)
data = b''.join(chunks)
output.write_bytes(struct.pack('>4sI', b'icns', 8 + len(data)) + data)
PYICON
if xattr -p com.apple.FinderInfo "$app" >/dev/null 2>&1; then
    xattr -d com.apple.FinderInfo "$app"
fi
codesign --force --sign - "$app"
swift -module-cache-path "${TMPDIR:-/tmp}/codex-accounts-swift-cache" -e '
import AppKit
let path = CommandLine.arguments[1]
guard let icon = NSImage(contentsOfFile: CommandLine.arguments[2]),
      NSWorkspace.shared.setIcon(icon, forFile: path, options: []) else {
    fatalError("Unable to set the Finder icon")
}
' "$app" "$icon_work/master.png"
touch "$app"
