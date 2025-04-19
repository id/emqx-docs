# EMQX 5.9 中的不兼容变更

## 5.9.0

- [#14773](https://github.com/emqx/emqx/pull/14773) 速率限制相关配置项已发生变更。
  - 此更改与 5.1.0 之前的版本不兼容。
  - 此更改也与使用旧版本（5.1.0 之前）配置结构手动修改过的 limiter 配置不兼容。
  - 已移除未公开的配置接口 `/configs/limiter`。

- [#14703](https://github.com/emqx/emqx/pull/14703) `force_shutdown.max_heap_size` 的最大允许值已更改为 `128GB`。
