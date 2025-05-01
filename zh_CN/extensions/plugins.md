# 插件

EMQX 允许用户通过创建用 Erlang 编写的插件来自定义业务逻辑或实现其他协议。本页涵盖了 EMQX 插件的开发、安装和管理过程。

## 什么是插件？

插件是运行在 EMQX 节点中的 Erlang 应用程序。

为了加载到节点中，插件必须编译成一个发布包（一个 `.tar.gz` 文件）。然后，可以通过 Dashboard、REST API 或 CLI 接口将这个发布包导入到 EMQX 中。

插件加载后，可以进行以下操作：

- 配置
- 启动或停止
- 卸载

启动时，插件通常会将一些功能注册为 EMQX 的 *回调*，以修改或扩展 EMQX 的行为。

## 开发 EMQX 插件

本节提供了开发自定义 EMQX 插件的指导，以创建一个自定义的访问控制插件作为示例，为您逐步介绍插件开发。

### 前提条件

在开始之前，请确保您具备以下条件：

- 了解 EMQX [钩子](./hooks.md)。
- 一个正常工作的构建环境（例如 `build_essential`），包括 `make`。
- 与您要目标的 EMQX 版本相同主版本的 Erlang/OTP。更多信息，请参见 Docker 中的 `org.opencontainers.image.otp.version` 属性，或参考所使用版本的 `.tool-versions` 文件（例如 https://github.com/emqx/emqx/blob/e5.9.0-beta.4/.tool-versions）。建议使用 [ASDF](https://asdf-vm.com/) 来管理 Erlang/OTP 版本。
- [rebar3](https://www.rebar3.org/)。

### 创建插件

EMQX 提供了一个 [emqx-plugin-template](https://github.com/emqx/emqx-plugin-template)，简化了自定义 EMQX 插件的创建。要创建新插件，您需要将 `emqx-plugin-template` 安装为 `rebar3` 模板。

1. 以 Linux 系统为例，使用以下命令下载 `emqx-plugin-template`：

   ```shell
   mkdir -p ~/.config/rebar3/templates
   pushd ~/.config/rebar3/templates
   git clone https://github.com/emqx/emqx-plugin-template
   popd
   ```

   ::: tip

   如果已设置 `REBAR_CACHE_DIR` 环境变量，模板的目录应为 `$REBAR_CACHE_DIR/.config/rebar3/templates`。 [这是相关问题](https://github.com/erlang/rebar3/issues/2762)。

   :::

2. 使用此命令生成您的自定义插件：

   ```shell
   rebar3 new emqx-plugin my_emqx_plugin
   ```

   此命令将在 `my_emqx_plugin` 目录下创建插件的工作框架。

3. 执行以下命令生成插件的发布包：

   ```shell
   $ cd my_emqx_plugin
   $ make rel
   ```

   这将生成插件发布包：`_build/default/emqx_plugin/my_emqx_plugin-1.0.0.tar.gz`。此包可以用于插件的安装和配置。

### 插件结构

该命令创建了一个标准的 Erlang 应用程序，并将 `emqx` 作为依赖项，结构如下：

```shell
$ tree my_emqx_plugin
my_emqx_plugin
├── LICENSE
├── Makefile
├── README.md
├── erlang_ls.config
├── priv
│   ├── config.hocon.example
│   ├── config_i18n.json.example
│   ├── config_schema.avsc.enterprise.example
│   └── config_schema.avsc.example
├── rebar.config
├── scripts
│   ├── ensure-rebar3.sh
│   └── get-otp-vsn.sh
└── src
    ├── my_emqx_plugin_app.erl
    ├── my_emqx_plugin.app.src
    ├── my_emqx_plugin_cli.erl
    ├── my_emqx_plugin.erl
    └── my_emqx_plugin_sup.erl

4 directories, 16 files
```

`src`：包含插件的 OTP 应用程序代码。

`priv`：存放插件的配置文件和配置架构（包含示例文件）。

`rebar.config`：用于构建应用程序并将其打包成发布包的 `rebar3` 配置文件。

`Makefile`：构建插件的入口。

`scripts`：`Makefile` 的辅助脚本。

`README.md`：文档占位符。

`LICENSE`：插件的示例许可证文件。

审查 `rebar.config` 文件并根据插件需求进行必要的调整。

**注意**: 由于示例依赖 `emqx`，所以这个插件需要一个定制版本的 `rebar3`，它将通过提供的 `./scripts/ensure-rebar3.sh` 脚本安装。

#### `rebar.config`

`rebar.config` 文件用于构建插件并将其打包成发布包。

最重要的部分包括：

- 依赖项（`deps`）部分；
- 发布部分（`relx`）；
- 插件描述部分（`emqx_plugin`）。

在 `deps` 部分，您可以添加插件依赖的其他 OTP 应用程序。

```
{deps,
    [
        ...
        %% 这是我插件的依赖
        {map_sets, "1.1.0"}
    ]}.
```

模板将 `map_sets` 作为插件的唯一依赖项。如果不需要，您可以删除它。有关依赖项的更多信息，请参考 [`rebar3` 的依赖文档](https://www.rebar3.org/docs/configuration/dependencies/)。

在 `relx` 部分，您需要指定发布的名称和版本，并列出要包含在发布包中的应用程序。

```
{relx, [ {release, {my_emqx_plugin, "1.0.0"},
            [ my_emqx_plugin
            , map_sets
            ]}
       ...
       ]}.
```

通常，您需要将 `deps` 部分中的运行时依赖项应用添加到发布中。

发布的名称和版本非常重要，因为它们用于在安装到 EMQX 时识别插件。它们形成插件的唯一标识符（`my_emqx_plugin-1.0.0`），用于在 API 或 CLI 中调用该插件。

在插件描述部分，您可以指定插件的其他信息。

```
{emqx_plugrel,
  [ {authors, ["Your Name"]}
  , {builder,
      [ {name, "Your Name"}
      , {contact, "your_email@example.cpm"}
      , {website, "http://example.com"}
      ]}
  , {repo, "https://github.com/emqx/emqx-plugin-template"}
  , {functionality, ["Demo"]}
  , {compatibility,
      [ {emqx, "~> 5.0"}
      ]}
  , {description, "Another amazing EMQX plugin"}
  ]
}
```

#### `src` 目录

`src` 目录包含插件的 OTP 应用程序代码。

##### `my_emqx_plugin.app.src`

这是一个标准的 Erlang 应用程序描述文件，会被编译成 `my_emqx_plugin.app` 文件并打包到发布包中。

- 应用程序的版本不必与发布版本匹配，可以使用不同的版本方案。
- 特别注意 `applications` 部分。由于插件是 OTP 应用程序，启动、停止和重启操作将与插件的应用程序相对应。如果插件依赖于其他应用程序，需在 `applications` 部分列出它们。

##### `my_emqx_plugin_app.erl`

这是插件 OTP 应用程序的主模块，执行 [`application` 行为](https://www.erlang.org/doc/man/application.html)，即 `start/2` 和 `stop/1` 函数，用于启动和停止插件的应用程序及其监督树。

`start/2` 函数通常执行以下活动：

- 钩住 EMQX 的钩子点。
- 注册 CLI 命令。
- 启动监督树。

可选地，`_app.erl` 模块可以实现 `on_config_changed/2` 和 `on_health_check/1` 回调函数。

- `on_config_changed/2` 会在插件的配置通过 Dashboard、API 或 CLI 更改时调用。
- `on_health_check/1` 会在请求插件状态时调用，插件可以通过此函数报告其健康状况。

##### 其他文件

`my_emqx_plugin_cli.erl` 模块实现插件的 CLI 命令。当注册后，CLI 命令可以通过 `emqx ctl` 命令调用。

`my_emqx_plugin_sup.erl` 实现插件的标准监督器。

`my_emqx_plugin.erl` 是插件的主模块，负责实现插件的逻辑。在示例中，它实现了几个简单的钩子和日志记录。插件还可以添加其他模块。

::: tip 注意

应用程序模块和文件可以任意命名，唯一的要求是：

- 应用程序的名称必须与插件名称相同。
- 应用程序模块（`_app`）必须命名为 `{plugin_name}_app`。

:::

#### `priv` 目录

`priv` 目录包含插件的配置文件和配置架构。

##### `config.hocon`

该文件包含插件的初始配置，使用 [HOCON 格式](https://github.com/lightbend/config/blob/master/HOCON.md)。您可以参考 `config.hocon.example` 来快速入门。

##### `config_schema.avsc`

该文件定义了插件配置的架构，使用 [Avro 格式](https://avro.apache.org/docs/1.11.1/specification/)。当该文件存在时，每次更新插件配置时，EMQX 会根据此架构验证配置。如果 `config.hocon` 不符合架构要求，构建发布包时会失败。

此外，该文件可以包含 UI 提示，使得可以通过 EMQX Dashboard 进行交互式配置。有关参考，请查看 `config_schema.avsc.enterprise.example`。

##### `config_i18n.json`

该文件包含插件配置 UI 的翻译，使用 JSON 格式。例如：

```
{
  "$key": {
    "zh": "中文翻译",
    "en": "English translation"
  },
  ...
}
```

翻译可以在 `config_schema.avsc` 中的 UI 提示中引用。有关更多信息，请参见 `config_i18n.json.example` 和 `config_schema.avsc.enterprise.example`。

### 发布包结构

当插件被构建成发布包时，包的结构如下：

```
└── my_emqx_plugin-1.1.0.tar.gz
    ├── map_sets-1.1.0
    ├── my_emqx_plugin-0.1.0
    ├── README.md
    └── release.json
```

该 tar 包包括编译后的应用程序（如 `rebar.config` 中的 `relx` 部分所列），`README.md` 文件以及包含插件元数据的 `release.json` 文件。

```
{
    "hidden": false,
    "name": "my_emqx_plugin",
    "description": "Another amazing EMQX plugin.",
    "authors": "Anonymous",
    "builder": {
        "name": "Anonymous",
        "contact": "anonymous@example.org",
        "website": "http://example.com"
    },
    "repo": "https://github.com/emqx/emqx-plugin-template",
    "functionality": "Demo",
    "compatibility": {
        "emqx": "~> 5.7"
    },
    "git_ref": "unknown",
    "built_on_otp_release": "27",
    "emqx_plugrel_vsn": "0.5.1",
    "git_commit_or_build_date": "2025-04-29",
    "metadata_vsn": "0.2.0",
    "rel_apps": [
        "my_emqx_plugin-0.1.0",
        "map_sets-1.1.0"
    ],
    "rel_vsn": "1.1.0",
    "with_config_schema": true
}
```

## 插件生命周期

在 EMQX 中，插件有三种主要状态：

- `installed`（已安装）：插件已安装，其配置和代码已加载，但插件的应用尚未启动。
- `started`（已启动）：插件已安装并且其应用程序已启动。
- `uninstalled`（已卸载）：插件已卸载。

### 安装流程

插件的安装流程如下：

1. 通过 Dashboard、API 或 CLI 上传插件包（即通过 `make rel` 命令生成的 tar 包）。
2. 插件包会被分发到 EMQX 集群中的每个节点。
3. 在每个节点上执行以下操作：
   - 插件包被保存到 EMQX 根目录下的 `plugins` 子目录中（可通过 `plugins.install_dir` 配置项覆盖）：`$EMQX_ROOT/plugins/my_emqx_plugin-1.0.0.tar.gz`。
   - 插件包会被解压到同一目录下：`$EMQX_ROOT/plugins/my_emqx_plugin-1.0.0/`。
   - 插件的初始配置文件（主插件应用的 `config.hocon`）会被复制到 `$EMQX_DATA_DIR/plugins/my_emqx_plugin/config.hocon`。
   - 如果存在 Avro 模式文件（schema），则会加载该配置模式。
   - 插件的代码会被加载进节点，但不会启动。
   - 插件会在 EMQX 配置文件中注册为 `disabled`（禁用状态）（`plugins.states` 配置项）。

::: tip

对于插件，只有启用状态（`enable` 标志的 `true` 或 `false`）存储在 EMQX 配置文件中。插件的详细配置保存在各节点的 `$EMQX_DATA_DIR/plugins/my_emqx_plugin/config.hocon` 文件中。

:::

### 配置插件

插件安装完成后，可以通过 Dashboard 或 API 进行配置。当配置发生变化时：

- 系统会根据 Avro 模式（如果存在）验证配置的合法性。
- 新配置会同步到集群中所有节点。
- 插件的 `on_config_changed/2` 回调函数会被调用。如果插件接受新配置，配置将持久化到 `$EMQX_DATA_DIR/plugins/my_emqx_plugin/config.hocon` 文件中。

::: tip

即使插件应用程序尚未启动，`on_config_changed/2` 回调函数也会被调用。

:::

::: tip

`on_config_changed/2` 回调会在集群中的每个节点上调用。因此，避免在此函数中实现依赖环境的判断逻辑，例如不要检查某个网络资源是否可用。否则可能导致部分节点成功接收新配置，而其他节点失败。对于这类可用性检查，请使用 `on_health_check/1` 回调函数，并在资源不可用时上报为非健康状态。

:::

### 启动插件

插件可以通过 Dashboard、API 或 CLI 手动启动。启动时：

- 插件的应用程序会启动。
- 插件在 EMQX 配置中注册为 `enabled`（启用状态） (`plugins.states`)。

当插件启动并请求其信息时，`on_health_check/1` 回调函数会被调用，用于获取插件的健康状态。

### 停止插件

插件停止时：

- 插件的应用程序会停止。
- 插件在 EMQX 配置中注册为 `disabled`（禁用状态） (`plugins.states`)。

尽管插件的应用程序已停止，但其代码仍会保留在节点中，因为已停止的插件仍然可以进行配置。

### 卸载流程

插件的卸载流程如下：

1. 如果插件正在运行，先将其停止。
2. 从节点中卸载插件代码。
3. 删除插件包相关文件（配置文件会保留）。
4. 从 EMQX 配置中移除该插件的注册信息（`plugins.states`）。

### 节点加入集群

当一个新的 EMQX 节点加入集群时，可能尚未安装任何插件及其配置，因为插件文件和配置是保存在各个节点本地文件系统中的。

新加入的节点将执行以下操作：

- 节点加入集群时，会接收全局的 EMQX 配置（作为集群加入流程的一部分）。
- 通过这些配置，节点知道当前有哪些插件已安装和启用。
- 节点会向其他节点请求插件及其实际配置。
- 节点安装这些插件，并启动已启用的插件。

## 安装插件包

EMQX 支持通过 Dashboard 和 CLI 安装插件包。然而，为了增强安全性，通过 Dashboard 安装插件现在需要先获得显式授权。

### 通过 Dashboard 安装插件包

::: tip 重要安全更新

出于安全考虑，EMQX 现在要求在通过 Dashboard 安装插件之前进行显式授权。

- 安装前必须先授予权限。
- 允许状态是临时的，安装完成后将自动撤销。
- 在集群环境中，必须在所有节点上授予权限。

:::

1. 在 CLI 中显式允许插件安装：

   ```bash
   emqx ctl plugins allow $NAME-$VSN
   ```

   - `{NAME}`：插件名称（例如 `my_emqx_plugin`）。
   - `{VSN}`：插件版本（例如 `1.2.3`）。

   执行此命令后，即可在 Dashboard 中继续安装插件。

2. 在 Dashboard 中安装插件包：

   - 进入**管理** -> **插件**页面。
   - 点击 **+ 安装插件**按钮，打开插件安装页面。
   - 通过点击上传按钮或拖放方式上传插件包。
   - 点击**安装**按钮完成安装。

#### 撤销插件安装权限

如果要撤销对已允许插件的安装权限，可以执行以下操作：

1. 卸载插件（如果已安装）。

2. 显式禁止该插件，执行以下命令：

   ```bash
   emqx ctl plugins disallow $NAME-$VSN
   ```

### 通过 CLI 安装插件包

如果需要直接通过 CLI 安装已编译的插件包，可以使用以下命令：

```bash
./bin/emqx ctl plugins install {pluginName}
```

### 通过 API 安装插件包

要通过 API 安装插件，请按以下步骤操作：

1. 允许插件安装。运行以下命令以启用插件的安装：

```
emqx ctl plugins allow {pluginName}
```

2. 安装插件。使用 `curl` 发送 POST 请求来安装插件：

```
$ curl -u $KEY:$SECRET -X POST http://$EMQX_HOST:18083/api/v5/plugins/install -H "Content-Type: multipart/form-data" -F "plugin=@{pluginName}.tar.gz"
```

3. 检查插件列表。运行以下命令验证插件是否安装成功：

```
$ curl -u $KEY:$SECRET http://$EMQX_HOST:18083/api/v5/plugins | jq
```

4. 启动/停止插件。使用以下命令来启动或停止插件：

```
$ curl -s -u $KEY:$SECRET -X PUT "http://$EMQX_HOST:18083/api/v5/plugins/{pluginName}/start"
$ curl -s -u $KEY:$SECRET -X PUT "http://$EMQX_HOST:18083/api/v5/plugins/{pluginName}/stop"
```

## 卸载插件

如果不再需要某个插件，可以通过 Dashboard 或 CLI 卸载将其移除。

- 通过 Dashboard 卸载插件：

  - 在插件列表页面，点击**操作**列的**更多**菜单下的**卸载**按钮。

- 通过 CLI 卸载插件：

  ```bash
  ./bin/emqx ctl plugins uninstall {pluginName}
  ```

<!-- **注意**:（企业版）插件需要在热升级后重新安装。 -->

## 管理插件

插件安装后，可以通过 Dashboard、API 或 CLI 进行管理。本节将介绍如何维护插件。

### 实现插件

要实现插件，通常需要完成以下逻辑：

- 实现钩子（hooks）和 CLI 命令。
- 处理配置更新。
- 处理健康检查。

#### 实现钩子和 CLI 命令

EMQX 为各种事件定义了钩子点（hookpoints）。任何应用程序（包括插件）都可以为这些钩子点注册回调，以响应事件或修改默认行为。

最常用的钩子点可以在插件框架文件中找到。完整的钩子点列表、其参数和预期的返回值，可以在 [EMQX 代码](https://github.com/emqx/emqx/blob/master/apps/emqx/src/emqx_hookpoints.erl) 中查看。

要为钩子点注册回调，请使用 `emqx_hooks:add/3` 函数。您需要提供：

- 钩子点名称。
- 回调模块和函数，可能包含 EMQX 将传递的附加参数。
- 回调的优先级（通常使用 `?HP_HIGHEST` 确保它首先被调用）。

要取消注册回调，请使用 `emqx_hooks:del/2` 函数，并提供钩子点名称和回调模块/函数。

例如，要为 `client.authenticate` 和 `client.authorize` 钩子点注册/取消注册回调：

```
-module(my_emqx_plugin).
...
hook() ->
  emqx_hooks:add('client.authenticate', {?MODULE, on_client_authenticate, []}, ?HP_HIGHEST),
  emqx_hooks:add('client.authorize', {?MODULE, on_client_authorize, []}, ?HP_HIGHEST).

unhook() ->
  emqx_hooks:del('client.authenticate', {?MODULE, on_client_authenticate}),
  emqx_hooks:del('client.authorize', {?MODULE, on_client_authorize}).
```

通常，我们希望钩子与插件一起启用和禁用，因此可以在插件应用的 `start/2` 和 `stop/1` 函数中调用 `hook/unhook`：

```
start(_StartType, _StartArgs) ->
    {ok, Sup} = my_emqx_plugin_sup:start_link(),
    my_emqx_plugin:hook(),

    {ok, Sup}.

stop(_State) ->
    my_emqx_plugin:unhook().
```

回调函数的签名可以在 [钩子点规范](https://github.com/emqx/emqx/blob/master/apps/emqx/src/emqx_hookpoints.erl) 中找到。例如：

```
-callback 'client.authorize'(
    emqx_types:clientinfo(), emqx_types:pubsub(), emqx_types:topic(), allow | deny
) ->
    fold_callback_result(#{result := allow | deny, from => term()}).

-callback 'client.authenticate'(emqx_types:clientinfo(), ignore) ->
    fold_callback_result(
        ignore
        | ok
        | {ok, map()}
        | {ok, map(), binary()}
        | {continue, map()}
        | {continue, binary(), map()}
        | {error, term()}
    ).
```

以下是回调函数实现的示例：

```
%% 只允许客户端 ID 与字符 A-Z、a-z、0-9 和下划线匹配的连接。
on_client_authenticate(_ClientInfo = #{clientid := ClientId}, Result) ->
  case re:run(ClientId, "^[A-Za-z0-9_]+$", [{capture, none}]) of
    match -> {ok, Result};
    nomatch -> {stop, {error, banned}}
  end.
%% 客户端只能订阅格式为 /room/{clientid} 的主题，但可以向任何主题发送消息。
on_client_authorize(_ClientInfo = #{clientid := ClientId}, subscribe, Topic, Result) ->
  case emqx_topic:match(Topic, <<"/room/", ClientId/binary>>) of
    true -> {ok, Result};
    false -> stop
  end;
on_client_authorize(_ClientInfo, _Pub, _Topic, Result) -> {ok, Result}.
```

在框架应用中，钩子通过 `my_emqx_plugin:load/1` 注册，并通过 `my_emqx_plugin:unload/0` 卸载。

#### 处理配置更新

当用户更新插件的配置时，插件应用的 `on_config_changed/2` 回调函数会被调用。

在此回调中，通常需要执行以下操作：

- 验证新配置。
- 如果插件正在运行，响应配置变更。

在验证配置时，请记住应用程序可能尚未启动。因此，应尽量使用无状态检查，避免环境相关的检查，因为不同节点的环境可能会导致不一致。

如果插件正在运行，则可以应用配置更改。通常的操作模式如下：

- 在应用启动时，启动一个 `gen_server` 进程来处理配置。
- 该进程（例如 `my_emqx_plugin_config_server`）读取当前配置并初始化其状态。
- `on_config_changed/2` 回调函数验证配置，并将新配置发送给 `my_emqx_plugin_config_server`。
- 如果进程正在运行，它会更新其状态；如果未运行，则不会执行任何操作。

#### 处理健康检查

`on_health_check/1` 回调会在 EMQX 请求插件状态时调用。插件可以返回其健康状态：

- 如果插件健康，返回 `ok`。
- 如果插件不健康，返回 `{error, Reason}`，并附上描述问题的二进制原因。

对于依赖外部资源的插件，这个回调非常重要，因为这些资源可能会变得不可用。

有关更多细节，请参见框架应用中的 `my_emqx_plugin_app:on_health_check/1`。

::: tip

虽然此函数仅在插件运行时调用，但由于并发原因，它也可能在插件启动或停止时被调用。

:::

### 升级插件

EMQX 不允许同时安装同一插件的多个版本。

要安装新版本的插件：

- 必须首先卸载旧版本。
- 然后安装新版本。

插件配置会在安装过程中保留。
