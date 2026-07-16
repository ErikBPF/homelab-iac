# Test contract

**Status:** Green

`tests/adguard-config-lifecycle.sh` selects Docker, then Podman, starts the exact
fixture image on loopback, and waits for its local control endpoint. It copies
only the dummy fixture configuration into temporary storage.

The OpenTofu fixture pins `ErikBPF/adguardhome` 0.1.6 and declares one
`adguardhome_config` while omitting disabled DHCP. The required sequence is:

1. init and validate;
2. apply the initial dummy config;
3. refreshed normal plan with zero actionable changes;
4. update one harmless DNS setting while DHCP stays disabled;
5. refreshed normal plan with zero actionable changes;
6. destroy.

Any provider rejection, actionable drift, missing cleanup, non-local endpoint,
or enabled DHCP is a test failure. Fork provider 0.1.6 completes the sequence.

When `ADGUARD_PROVIDER_DEV_BINARY` is set, init still resolves the declared
stock provider and lock metadata first; subsequent validate/lifecycle commands
use only the isolated CLI development override. The supplied binary must be an
executable local file. Omitting the variable exercises the pinned stock
provider and is the required green admission path.
