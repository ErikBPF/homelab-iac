#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s --input SOURCE.json --output CATALOG.json\n' "$0" >&2
  exit 64
}

input=
output=
while [[ $# -gt 0 ]]; do
  case $1 in
    --input)
      [[ $# -ge 2 ]] || usage
      input=$2
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || usage
      output=$2
      shift 2
      ;;
    *) usage ;;
  esac
done

[[ -n $input && -n $output ]] || usage
[[ -f $input ]] || {
  printf 'Zen catalog source not found: %s\n' "$input" >&2
  exit 66
}

output_dir=$(dirname -- "$output")
mkdir -p "$output_dir"
tmp=$(mktemp "$output_dir/.zen-catalog.XXXXXX")
trap 'rm -f "$tmp"' EXIT

# models.dev is keyed by provider and model ID. Select only the exact OpenCode
# Zen provider; OpenCode Go and unrelated OpenAI-compatible providers are not
# part of this catalog.
jq -e -S '
  def source_models:
    if ((.["opencode"]?.models? // null) | type) == "object" then
      [.["opencode"].models | to_entries[] | .value + {id: (.value.id // .key)}]
    else
      error("expected models.dev opencode.models object")
    end;

  {
    source: "opencode-zen",
    models: (
      source_models
      | map({
          source_id: .id,
          context_limit: .limit.context,
          output_limit: .limit.output,
          input_price_per_million: .cost.input,
          output_price_per_million: .cost.output,
          input_modalities: (.modalities.input | sort),
          output_modalities: (.modalities.output | sort),
          supports_reasoning: .reasoning,
          supports_tools: .tool_call,
          is_free: (.cost.input == 0 and .cost.output == 0),
          privacy_tier: "unknown",
          lifecycle: (if (.deprecated == true or .status == "deprecated") then "deprecated" else "discovered" end)
        })
      | sort_by(.source_id)
    )
  }
  | if
      (.models | all(
        (.source_id | type) == "string" and length > 0 and
        (.context_limit | type) == "number" and .context_limit > 0 and
        (.output_limit | type) == "number" and .output_limit > 0 and
        .output_limit <= .context_limit and
        (.input_price_per_million | type) == "number" and .input_price_per_million >= 0 and
        (.output_price_per_million | type) == "number" and .output_price_per_million >= 0 and
        (.input_modalities | type) == "array" and
        (.output_modalities | type) == "array" and
        (.supports_reasoning | type) == "boolean" and
        (.supports_tools | type) == "boolean" and
        (.is_free | type) == "boolean"
      ))
    then .
    else error("normalized Zen model failed schema validation")
    end
' "$input" >"$tmp"

mv "$tmp" "$output"
trap - EXIT
