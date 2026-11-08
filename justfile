set positional-arguments
set dotenv-load

# Resolve only the existing config-manager credential through its OpenBao reader.
authentik-config-manager *args:
    @bin/authentik-config-manager "$@"
