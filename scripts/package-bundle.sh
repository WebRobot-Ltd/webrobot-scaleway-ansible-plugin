#!/usr/bin/env bash
# Package this plugin as a WebRobot marketplace bundle ZIP.
#
# Output: <pluginId>-<version>.zip in dist/, ready to be uploaded via
#   `webrobot bundle upload dist/<pluginId>-<version>.zip`
# or the marketplace UI at /dashboard/plugins/bundles.
#
# Bundle layout (consumed by the WebRobot vm-adapter-loader init container):
#   <root>/
#   ├── manifest.json
#   └── ansible/
#       └── roles/
#           └── <ansibleRole>/        (must match manifest.components[].ansibleRole)
#               ├── tasks/main.yml
#               └── meta/main.yml

set -euo pipefail

cd "$(dirname "$0")/.."

PLUGIN_ID=$(python3 -c 'import json; print(json.load(open("manifest.json"))["pluginId"])')
VERSION=$(python3 -c 'import json; print(json.load(open("manifest.json"))["version"])')
ROLE_NAME=$(python3 -c 'import json; print(json.load(open("manifest.json"))["components"][0]["ansibleRole"])')
OUT="dist/${PLUGIN_ID}-${VERSION}.zip"

mkdir -p dist
rm -f "$OUT"

# Sanity check — the role dir must exist where the loader expects it.
test -d "ansible/roles/${ROLE_NAME}" \
  || { echo "ERROR: ansible/roles/${ROLE_NAME}/ not found"; exit 1; }
test -f "ansible/roles/${ROLE_NAME}/tasks/main.yml" \
  || { echo "ERROR: tasks/main.yml missing in ${ROLE_NAME}"; exit 1; }

zip -r "$OUT" \
  manifest.json \
  ansible/ \
  README.md \
  LICENSE \
  -x '*/.git/*' '*/.git*' '*/.DS_Store' 'dist/*' 'scripts/*' '*.swp'

echo "✓ packaged: $OUT"
echo "  upload:    webrobot bundle upload $OUT"
echo "  pluginId:  $PLUGIN_ID"
echo "  version:   $VERSION"
echo "  role:      $ROLE_NAME"
