include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//ratelimit"
}

# Zone rate limiting for public (tunnel + Access) endpoints. Depth behind CF
# Access: bounds abuse if a device service token / bearer leaks. Needs an API
# token with Zone > WAF (Rate Limiting) : Edit on the zone — the shared
# dual-scope token does not have it, so apply this with the same bootstrap token
# used for cloudflare/access (or a token that adds Zone WAF Edit).

inputs = {
  zone_id = "2c4ac8f72b5661f3d360d4dececbd4ba" # pastelariadev.com

  rules = {
    whisper = {
      description         = "whisper public STT — per-IP rate limit"
      expression          = "(http.host eq \"whisper.pastelariadev.com\")"
      period              = 60
      requests_per_period = 120 # a device syncs a handful of short clips; 120/min is generous
      mitigation_timeout  = 600
    }
  }
}
