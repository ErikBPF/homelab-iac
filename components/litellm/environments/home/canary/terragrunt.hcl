include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//model"
}

# Disposable proof only. This does not replace or modify a production route.
inputs = {
  models = {
    tf-canary-big-pickle = {
      custom_llm_provider = "openai"
      base_model          = "big-pickle"
      # LiteLLM OSS model administration requires proxy-admin bootstrap auth;
      # team-scoped model ownership is Enterprise-only. Keep the field for a
      # future licensed deployment; the provider omits this empty value.
      team_id                        = ""
      model_api_key                  = "os.environ/OPENCODE_ZEN_KEY"
      model_api_base                 = "https://opencode.ai/zen/v1"
      mode                           = "chat"
      input_cost_per_million_tokens  = 0
      output_cost_per_million_tokens = 0
      additional_litellm_params      = {}
      # API-backed model_info metadata.
      context_limit      = 200000
      output_limit       = 32000
      input_modalities   = ["text"]
      output_modalities  = ["text"]
      supports_reasoning = true
      supports_tools     = true
      privacy_tier       = "non-confidential"
      lifecycle          = "canary"
    }
  }
}
