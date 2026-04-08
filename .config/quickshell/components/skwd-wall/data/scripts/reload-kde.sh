#!/bin/sh
SCHEME="${1:-SkwdMatugen}"

command -v kwriteconfig6 >/dev/null || exit 0

kwriteconfig6 --file kdeglobals --group General --key ColorScheme "$SCHEME"
kwriteconfig6 --file kdeglobals --group General --key ColorSchemeHash ''
command -v gdbus >/dev/null && gdbus emit --session \
    --object-path /KGlobalSettings \
    --signal org.kde.KGlobalSettings.notifyChange 0 2 2>/dev/null
