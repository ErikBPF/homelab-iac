variable "models" {
  description = "LiteLLM models keyed by stable logical alias."
  type = map(object({
    custom_llm_provider            = string
    base_model                     = string
    pricing_base_model             = optional(string, "")
    team_id                        = optional(string, "")
    model_api_key                  = string
    model_api_base                 = string
    mode                           = string
    input_cost_per_million_tokens  = optional(number, 0)
    output_cost_per_million_tokens = optional(number, 0)
    input_cost_per_second          = optional(number)
    additional_litellm_params      = optional(map(string), {})
    # API-backed model_info metadata.
    context_limit      = optional(number)
    output_limit       = optional(number)
    input_modalities   = optional(set(string), [])
    output_modalities  = optional(set(string), [])
    supports_reasoning = optional(bool, false)
    supports_tools     = optional(bool, false)
    privacy_tier       = string
    lifecycle          = string
    # Discovery model_info metadata exposed by the pinned provider.
    max_tokens               = optional(number)
    supports_vision          = optional(bool)
    input_cost_per_character = optional(number)
    default_voice            = optional(string)
    probe_language           = optional(string)
    probe_text               = optional(string)
    probe_skip               = optional(bool)
  }))

  validation {
    condition = alltrue([
      for alias, model in var.models :
      length(trimspace(alias)) > 0 &&
      length(trimspace(model.custom_llm_provider)) > 0 &&
      length(trimspace(model.base_model)) > 0
    ])
    error_message = "Every model requires a logical alias, custom_llm_provider, and base_model."
  }

  validation {
    condition = alltrue([
      for model in values(var.models) :
      (model.context_limit == null || model.context_limit > 0) &&
      (model.output_limit == null || model.output_limit >= 0) &&
      (model.context_limit == null || model.output_limit == null || model.output_limit <= model.context_limit) &&
      (model.max_tokens == null || model.max_tokens >= 0) &&
      (model.input_cost_per_character == null || model.input_cost_per_character >= 0) &&
      (model.input_cost_per_second == null || model.input_cost_per_second >= 0) &&
      model.input_cost_per_million_tokens >= 0 &&
      model.output_cost_per_million_tokens >= 0
    ])
    error_message = "Context limits must be positive, token limits may be zero, output_limit must not exceed context_limit, and prices must be non-negative."
  }

  validation {
    condition = alltrue([
      for model in values(var.models) :
      contains(["chat", "completion", "embedding"], model.mode) || contains([
        "image_generation",
        "moderation",
        "audio_transcription",
        "audio_speech",
        "rerank",
      ], model.mode)
    ])
    error_message = "mode must be one of the eight modes supported by the pinned LiteLLM provider."
  }

  validation {
    condition = alltrue(flatten([
      for model in values(var.models) : [
        for modality in setunion(model.input_modalities, model.output_modalities) :
        contains(["text", "image", "audio", "video", "pdf"], modality)
      ]
    ]))
    error_message = "Modalities must be text, image, audio, video, or pdf."
  }

  validation {
    condition = alltrue([
      for model in values(var.models) :
      contains(["confidential", "non-confidential"], model.privacy_tier)
    ])
    error_message = "privacy_tier must be confidential or non-confidential."
  }

  validation {
    condition = alltrue([
      for model in values(var.models) :
      contains(["canary", "manual", "production", "retired"], model.lifecycle)
    ])
    error_message = "lifecycle must be explicitly canary, manual, production, or retired."
  }

  validation {
    condition = alltrue([
      for model in values(var.models) :
      !contains(["chat", "completion"], model.mode) ||
      (contains(model.input_modalities, "text") && contains(model.output_modalities, "text"))
    ])
    error_message = "Conversational models must accept and produce text."
  }
}

variable "yaml_model_list_cutoff" {
  description = "HITL marker: true only after Discovery's legacy YAML model_list is removed."
  type        = bool
  default     = false
}
