mock_provider "grafana" {}

run "reader_has_no_edit_role" {
  command = plan

  variables {
    org_id = 1
  }

  assert {
    condition = (
      grafana_service_account.argus.role == "Viewer" &&
      grafana_service_account.argus.org_id == "1" &&
      grafana_service_account.argus.name == "svc-argus-grafana-alert-reader" &&
      !grafana_service_account.argus.is_disabled
    )
    error_message = "Argus must be the enabled Viewer in the explicitly selected organization."
  }
}

run "reject_missing_organization" {
  command = plan

  variables {
    org_id = 0
  }

  expect_failures = [var.org_id]
}
