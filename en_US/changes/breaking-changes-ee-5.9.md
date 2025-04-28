# Incompatible Changes in EMQX 5.9

## 5.9.0

- [#14773](https://github.com/emqx/emqx/pull/14773) Rate limiting configuration options have been changed.
  - This change is incompatible with versions prior to 5.1.0
  - This change is also incompatible with manually modified limiter configurations that use structures from versions prior to 5.1.0
  - The undocumented endpoint `/configs/limiter` has been removed
  
- [#14703](https://github.com/emqx/emqx/pull/14703) Changed the maximum allowed value for `force_shutdown.max_heap_size` to `128GB`.

- [#14957](https://github.com/emqx/emqx/pull/14957) The way plugin configurations are updated has changed. The system now respects the result of the `on_config_changed` callback when updating a plugin's configuration. This change only affects new configuration updates made through the Dashboard. The result of the `on_config_changed` callback is still ignored for configurations that have already been stored in the cluster.

  Additionally, plugin apps are now loaded during plugin installation to ensure the `on_config_changed` callback is called even for stopped plugins.

