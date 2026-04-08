#!/bin/sh
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/skwd-wall"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/skwd"
COLORS="$CACHE/colors.json"
OUTPUT="$CONFIG/ext/omp/skwd.omp.json"

[ -f "$COLORS" ] || exit 0
command -v jq >/dev/null || exit 0

mkdir -p "$(dirname "$OUTPUT")"

jq '{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "version": 3,
  "final_space": true,
  "console_title_template": "{{ .Shell }} in {{ .Folder }}",
  "palette": {
    "primary": .primary,
    "on-primary": .primaryText,
    "primary-container": .primaryContainer,
    "on-primary-container": .primaryContainerText,
    "tertiary": .tertiary,
    "on-tertiary": .tertiaryText,
    "tertiary-container": .tertiaryContainer,
    "on-tertiary-container": .tertiaryContainerText,
    "surface": .surface,
    "surface-variant": .surfaceVariant,
    "on-surface-variant": .surfaceVariantText,
    "error": .error,
    "on-error": .errorText,
    "outline": .outline
  },
  "blocks": [
    {
      "type": "prompt", "alignment": "left",
      "segments": [
        {"type":"time","style":"powerline","powerline_symbol":"\ue0b8","foreground":"p:on-primary","background":"p:primary","template":" {{ .CurrentDate | date \"15:04\" }} "},
        {"type":"path","style":"powerline","powerline_symbol":"\ue0b8","foreground":"p:on-tertiary","background":"p:tertiary","template":" \uf413 {{ .Path }} ","properties":{"style":"agnoster_short","max_depth":3}},
        {"type":"git","style":"powerline","powerline_symbol":"\ue0b8","foreground":"p:on-primary","background":"p:primary","template":" \ue0a0 {{ .HEAD }}{{ if .Working.Changed }} \uf044 {{ .Working.String }}{{ end }}{{ if .Staging.Changed }} \uf046 {{ .Staging.String }}{{ end }} ","properties":{"branch_icon":"","fetch_status":true,"fetch_stash_count":true}},
        {"type":"status","style":"powerline","powerline_symbol":"\ue0b8","foreground":"p:on-error","background":"p:error","template":" \uf00d {{ .Code }} "}
      ]
    },
    {
      "type": "prompt", "alignment": "right", "overflow": "hide",
      "segments": [
        {"type":"executiontime","style":"powerline","powerline_symbol":"\ue0ba","invert_powerline":true,"foreground":"p:on-surface-variant","background":"p:surface-variant","template":" \uf252 {{ .FormattedMs }} ","properties":{"threshold":2000,"style":"roundrock"}}
      ]
    },
    {
      "type": "prompt", "alignment": "left", "newline": true,
      "segments": [
        {"type":"text","style":"plain","foreground":"p:primary","template":"❯ "}
      ]
    }
  ]
}' "$COLORS" > "$OUTPUT"
