#!/bin/sh
# 1Panel / Docker entrypoint for routatic-proxy.
#
# Prepares a runtime config from the baked-in example config, then starts the
# proxy headless. Two things happen here:
#
#   1. The loader requires a non-empty global api_key. When only a Zen key is
#      supplied, we copy it into the global slot so startup validation passes.
#   2. When OCGO_MODE=zen, the primary model chain plus every fallback entry is
#      rewritten to the opencode-zen provider, so a Zen-only key avoids the
#      opencode-go endpoint entirely.
set -e

CONFIG="${ROUTATIC_PROXY_CONFIG:-/etc/routatic-proxy/config.json}"
MODE="${OCGO_MODE:-go}"

if [ ! -f "$CONFIG" ]; then
    echo "config not found at $CONFIG" >&2
    exit 1
fi

# The proxy validates that a global api_key exists. If the operator only set a
# Zen key, mirror it into the global slot so validation does not abort startup.
if [ -z "$ROUTATIC_PROXY_API_KEY" ] && [ -n "$ROUTATIC_PROXY_OPENCODE_ZEN_API_KEY" ]; then
    ROUTATIC_PROXY_API_KEY="$ROUTATIC_PROXY_OPENCODE_ZEN_API_KEY"
    export ROUTATIC_PROXY_API_KEY
    echo "no global api_key set; using the OpenCode Zen key for startup validation"
fi

if [ "$MODE" = "zen" ]; then
    jq '
      .models.default        |= (.provider="opencode-zen" | .model_id="deepseek-v4-flash-free")
    | .models.fast           |= (.provider="opencode-zen" | .model_id="deepseek-v4-flash-free")
    | .models.background     |= (.provider="opencode-zen" | .model_id="deepseek-v4-flash-free")
    | .models.complex        |= (.provider="opencode-zen" | .model_id="claude-sonnet-4.5")
    | .models.think          |= (.provider="opencode-zen" | .model_id="glm-5.2")
    | .models.long_context   |= (.provider="opencode-zen" | .model_id="mimo-v2.5-free")
    | .fallbacks |= with_entries(.value |= map(.provider="opencode-zen"))
    ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
    echo "OCGO_MODE=zen: rewrote primary + fallback models to opencode-zen"
fi

exec routatic-proxy start --headless
