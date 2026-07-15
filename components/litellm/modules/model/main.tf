resource "litellm_model" "this" {
  for_each = var.models

  model_name                     = each.key
  custom_llm_provider            = each.value.custom_llm_provider
  base_model                     = each.value.base_model
  team_id                        = each.value.team_id
  model_api_key                  = each.value.model_api_key
  model_api_base                 = each.value.model_api_base
  mode                           = each.value.mode
  input_cost_per_million_tokens  = each.value.input_cost_per_million_tokens
  output_cost_per_million_tokens = each.value.output_cost_per_million_tokens
  input_cost_per_second          = each.value.input_cost_per_second
  additional_litellm_params      = each.value.additional_litellm_params
  max_input_tokens               = each.value.context_limit
  max_output_tokens              = each.value.output_limit
  input_modalities               = sort(tolist(each.value.input_modalities))
  output_modalities              = sort(tolist(each.value.output_modalities))
  supports_reasoning             = each.value.supports_reasoning
  supports_function_calling      = each.value.supports_tools
  supports_vision                = each.value.supports_vision
  input_cost_per_character       = each.value.input_cost_per_character
  default_voice                  = each.value.default_voice
  probe_language                 = each.value.probe_language
  probe_text                     = each.value.probe_text
  probe_skip                     = each.value.probe_skip
  max_tokens                     = each.value.max_tokens
}
