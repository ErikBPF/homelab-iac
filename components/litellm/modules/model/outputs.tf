output "model_contract" {
  description = "Non-secret normalized contract metadata, including fields unsupported by provider v0.2.2."
  value = {
    for alias, model in var.models : alias => {
      custom_llm_provider            = model.custom_llm_provider
      base_model                     = model.base_model
      pricing_base_model             = model.pricing_base_model
      team_id                        = model.team_id
      model_api_base                 = model.model_api_base
      mode                           = model.mode
      input_cost_per_million_tokens  = model.input_cost_per_million_tokens
      output_cost_per_million_tokens = model.output_cost_per_million_tokens
      additional_litellm_params      = model.additional_litellm_params
      context_limit                  = model.context_limit
      output_limit                   = model.output_limit
      input_modalities               = sort(tolist(model.input_modalities))
      output_modalities              = sort(tolist(model.output_modalities))
      supports_reasoning             = model.supports_reasoning
      supports_tools                 = model.supports_tools
      privacy_tier                   = model.privacy_tier
      lifecycle                      = model.lifecycle
    }
  }
}

output "yaml_model_list_cutoff" {
  description = "Explicit handoff marker proving the legacy YAML model list has been disabled."
  value       = var.yaml_model_list_cutoff
}
