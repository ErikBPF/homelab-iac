# Disposable AdGuard config lifecycle

**Status:** Implemented — stock provider lifecycle green

The pinned AdGuard provider must create, read, update, refresh without drift,
and delete one `adguardhome_config` resource against a disposable local AdGuard
Home container. DHCP remains explicitly disabled throughout. No command may
contact Discovery, read repository state, or use non-dummy credentials.

The test fails closed when no local container runtime is available. All
container data and OpenTofu state live in a temporary directory and are removed
on exit. Test output reports phases only, never provider payloads.

The stock provider is the required production lane. Setting
`ADGUARD_PROVIDER_DEV_BINARY` to an executable local provider binary enables an
isolated OpenTofu CLI development override for the GREEN lane. The override and
symlink exist only under the test temporary directory.

Provider `ErikBPF/adguardhome` 0.1.7 passes the complete disposable lifecycle when
the test uses a normal refreshed plan. An earlier refresh-only assertion
mistook state refresh (`-detailed-exitcode` 2) for actionable configuration
drift; it was not a valid admission failure. No provider fork is required by
this contract.
