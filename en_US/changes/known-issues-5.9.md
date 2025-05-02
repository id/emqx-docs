# Known Issues in EMQX 5.9

## e5.9.0

| Since version | Issue                                                        | Workaround                                                   | Status                    |
| ------------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------- |
| 5.4.0         | **TLS listener started with default configuration cannot be hot-updated to use tlsv1.3 only.**<br />May fail with error like `incompatible,[client_renegotiation,{versions,['tlsv1.3']}]` | Disable the listener, then re-enable it after config change. | Will be resolved in 5.9.x |
| 5.0.0         | **Node Crash if Linux monotonic clock steps backward**<br />In certain virtual Linux environments, the operating system is unable to keep the clocks monotonic, which may cause Erlang VM to exit with the message `OS monotonic time stepped backwards!`. | For such environments, you may set the `+c` flag to `false` in `etc/vm.args`. |                           |
| 5.3.0         | **Limitation in SAML-Based SSO**<br />EMQX Dashboard supports Single Sign-On based on the Security Assertion Markup Language (SAML) 2.0 standard and integrates with Okta and OneLogin as identity providers. However, the SAML-based SSO currently does not support a certificate signature verification mechanism and is incompatible with Azure Entra ID due to its complexity. | -                                                            |                           |
