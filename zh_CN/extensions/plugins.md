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

它还包含一个示例模块，演示如何添加自定义 `emqx ctl` 命令 `emqx_cli_demo`。

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

### 测试您的开发环境

::: tip 提示
要使用可工作的开发环境，请参阅[从源代码安装](../deploy/install-source.md)。
:::

运行 `make rel` 以测试插件是否可以成功编译和打包，此时无需编写代码。

由于示例插件依赖 EMQX 主应用程序，它需要与依赖项一起下载然后作为主项目的一部分进行编译。请注意，编译过程可能需要较长时间才能完成。

### 定制示例项目

现在一切都工作正常了，您可以开始定制项目以满足您的需要。我们提供了一个核心模块，它注册了当前所有已知的[钩子](./hooks.md)。此代码位于 `src/my_emqx_plugin.erl` 中。您需要删除所有不需要的钩子，然后用自己的自定义代码实现剩余钩子的回调。

在下面的示例中，我们只需要两个钩子用于认证和访问控制，因此我们修改 `my_emqx_plugin:load/1` 如下:

```erlang
load(Env) ->
  emqx_hooks:add('client.authenticate', {?MODULE, on_client_authenticate, [Env]}, ?HP_HIGHEST),
  emqx_hooks:add('client.authorize', {?MODULE, on_client_authorize, [Env]}, ?HP_HIGHEST),
  ok.
```

我们使用 `on_client_authenticate/3` 进行客户端认证，使用 `on_client_authorize/5` 进行访问控制。

由于一个钩子函数可能同时被 EMQX 和定制插件挂载，因此在挂载到插件时，我们还需要指定执行顺序。`HP_HIGHEST` 指定当前钩子函数具有最高优先级，并首先执行。


#### 定制访问控制代码

```erlang
%% 只允许客户端ID名称匹配以下任一字符的连接: A-Z、a-z、0-9 和下划线。
on_client_authenticate(_ClientInfo = #{clientid := ClientId}, Result, _Env) ->
  case re:run(ClientId, "^[A-Za-z0-9_]+$", [{capture, none}]) of
    match -> {ok, Result};
    nomatch -> {stop, {error, banned}}
  end.
%% 只能订阅主题 /room/{clientid}，但可以向任何主题发送消息。
on_client_authorize(_ClientInfo = #{clientid := ClientId}, subscribe, Topic, Result, _Env) ->
  case emqx_topic:match(Topic, <<"/room/", ClientId/binary>>) of
    true -> {ok, Result};
    false -> stop
  end;
on_client_authorize(_ClientInfo, _Pub, _Topic, Result, _Env) -> {ok, Result}.
```

在上面的代码示例中，我们只允许匹配规范的客户端登录。这些客户端只能订阅主题 `/room/{clientid}`，从而建立一个简单的聊天室，即客户端可以向任何其他客户端发送消息，但每个客户端只能订阅与自己相关的主题。

::: tip

1. 确保先在配置中将 `authorization.no_match` 设置为 `deny`，即 EMQX 将拒绝任何未经授权的连接请求。
2. 在此示例中，我们演示了如何自定义一个访问控制插件，您也可以[基于文件设置类似的授权规则](../access-control/authz/file.md)。

:::

#### 打包定制的插件

通过 `rebar.config` 修改插件的版本信息:

```erlang
{relx, [ {release, {my_emqx_plugin, "1.0.0"}, %% this is the release version, different from app vsn in .app file
            [ my_emqx_plugin
            , map_sets
            ]}
       , {dev_mode, false}
       , {include_erts, false}
       ]}.

  %% Additional info about the plugin
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
}.
```

现在重新运行 release 命令:

```shell
make rel
...
===> Release successfully assembled: _build/default/rel/my_emqx_plugin
===> [emqx_plugrel] creating _build/default/emqx_plugrel/my_emqx_plugin-1.0.0.tar.gz
```

这将创建一个新的 EMQX 插件 tarball `my_emqx_plugin-1.0.0.tar.gz`，您现在可以上传并安装到运行中的 EMQX 集群中。

#### 为插件编写 Config Schema （可选）

我们在 EMQX v5.7.0 中引入了用于插件配置管理的 REST API 和用于配置验证的 Avro Schema，增强了在运行期间动态更新插件配置的能力。
此外如果编写了 Avro Schema 以验证插件的配置，需要同时提供与 Avro Schema 规则匹配的默认配置文件。该文件应位于 `priv/config.hocon`，

在运行时更新的配置，会以 hocon 格式写入 `data/plugins/<PLUGIN_NAME>/config.hocon` ，并在每次更新配置时将旧配置文件备份。


::: tip **提示**

您可以在项目目录中找到几个个示例文件：`priv/config.hocon.example`, `priv/config_schema.avsc.example`, `priv/config_schema.avsc.enterprise.example`, `priv/config_i18n.json.example`。
可以根据这些文件来编写支持配置及配置验证的 Plugin 。

注意 `priv/config_schema.avsc.enterprise.example`, `priv/config_i18n.json.example` 包含了 UI 声明及其国际化配置，使用 UI 声明渲染插件配置表单页面为企业版功能。

:::


这需要您的插件包提供一个 Avro Schema 配置文件，它应位于 `priv/config_schema.avsc`。该文件应当遵守 Apache Avro 规范，详情请参阅 [Apache Avro Specification (1.11.1)](https://avro.apache.org/docs/1.11.1/specification/)。

此外它也同时也包含了关于 UI 的描述声明。即可以使用 Avro Schema 的 metadata 配置一个 `$ui` 字段，EMQX Dashborad 将根据 `$ui` 字段中提供的信息来生成一份配置表单页。

#### 声明式 UI 使用参考 （可选）

::: tip **提示**
声明式 UI 仅在 EMQX 企业版中使用。
:::

UI 声明被用于动态渲染表单，从而使 EMQX Dashboard 能够动态生成配置表单，方便插件的配置和管理。
支持各种字段类型和自定义组件。以下是可用组件及其配置说明。

此外还有一个**可选的**国际化配置文件以提供多语言支持， i18n 文件应位于 `priv/config_i18n.json`。它是一个键值对文件，如：`{ "$msgid": { "zh": "消息", "en": "Message" } }`。
如果 `$ui` 配置中的字段名称、描述、验证规则的消息等需要支持多语言，需要在对应的配置里使用以 `$` 开头的 `$msgid`。

**配置项说明**

- `component`<br />
  必填。为该字段配置一个组件，用于显示和配置不同值和类型的数据，以下为支持的组件列表：

  | 组件名             | 描述                                               |
  |:-------------------|:---------------------------------------------------|
  | `input`            | 用于简短文本或字符串的文本输入框                   |
  | `input-password`   | 隐藏输入内容的密码输入框                           |
  | `input-number`     | 只允许数字输入的数字输入框                         |
  | `input-textarea`   | 适用于较长的文本输入的文本域                       |
  | `input-array`      | 输入值以逗号分隔，支持字符串和数字数组的数组输入框 |
  | `switch`           | 用于布尔值输入的开关                               |
  | `select`           | 用于枚举类型的下拉选择框                           |
  | `code-editor`      | 支持特定格式的代码（如 SQL、JSON 等）的代码编辑器  |
  | `key-value-editor` | 用于编辑 Avro 中的 map 类型的键值对编辑器          |
  | `maps-editor`      | 用于编辑 Avro 中的对象数组类型的对象数组编辑器     |
- `label`<br />
  必填。字段的标签或名称，可使用 $msgid。若不配置 i18n，将直接显示原文。
- `description`<br />
  可选。字段的详细描述，可使用 $msgid。若不配置 i18n，将直接显示原文。
- `flex`<br />
  必填。定义字段在网格布局中占据的比例，满格（24）表示占据一整行，半格（12）表示占据半行。
- `required`<br />
  可选。指示字段是否为必填项。
- `format` (仅 code-editor 组件适用)<br />
  可选。代码编辑器支持的格式，目前支持的数据格式为 `sql` 或 `json`。
- `options` (仅 select 组件适用)<br />
  可选。定义枚举类型的可选项，应与 Avro Schema 中的 symbols 保持一致。示例：
  ```json
  [
    {
      "label": "$mysql",
      "value": "MySQL"
    },
    {
      "label": "$pgsql",
      "value": "postgreSQL"
    }
  ]
  ```
- `items` (仅 maps-editor 组件适用)<br />
  可选。当使用 maps-editor 组件时，指定表单内项目的字段名和描述。例如：
  ```json
  {
    "items": {
      "optionName": {
        "label": "$optionNameLabel",
        "description": "$optionDesc",
        "type": "string"
      },
      "optionValue": {
        "label": "$optionValueLabel",
        "description": "$optionValueDesc",
        "type": "string"
      }
    }
  }
  ```
- `rules`<br />
  可选。用于定义字段的校验规则，一个规则可以配置多个。目前支持下述类型：
  - `pattern`，正则表达式验证，需要配置一个正则表达式进行验证。正则表达式写在 pattern 字段里。
  - `range`，用来验证输入数字的大小范围，最小值 min，最大值 max，可以同时配置，也可以单独配置一个。
  - `length`，用来验证输入的字符长度大小的限制，最短长度 minLength，最大长度 maxLength，可以同时配置，也可以单独配置。
  - `message`，验证不通过时的错误消息：支持配置 i18n 的 `$msgid`。

**示例片段**

以下为几个示例片段，更详细的示例请参考 `priv/config_schema.avsc.example`：

```json
{
    "rules": [
    {
      "type": "pattern",
      "pattern": "^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])(\\.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9]))*$",
      "message": "$hostname_validate"
    }
  ]
}
```

```json
{
    "rules": [
    {
      "type": "range",
      "min": 1,
      "max": 65535,
      "message": "$port_range_validate"
    }
  ]
}
```

```json
{
    "rules": [
    {
      "type": "length",
      "minLength": 8,
      "maxLength": 128,
      "message": "$password_length_validate"
    },
    {
      "type": "pattern",
      "pattern": "^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d]*$",
      "message": "$password_validate"
    }
  ]
}
```

在插件编译打包时，如果您提供了 Avro Schema 文件及 i18n 文件，它们将被一同添加至 tarball 中。在您的插件代码中，可以使用函数 `emqx_plugins:get_config/1,2,3,4` 来获取插件配置。

## 安装插件

EMQX 支持通过 Dashboard 和 CLI 安装插件。然而，为了增强安全性，通过 Dashboard 安装插件现在需要先获得显式授权。

### 通过 Dashboard 安装插件

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

2. 在 Dashboard 中安装插件：

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

### 通过 CLI 安装插件

如果需要直接通过 CLI 安装已编译的插件包，可以使用以下命令：

```bash
./bin/emqx ctl plugins install {pluginName}
```

### 通过 API 安装插件

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

插件安装后，可以通过 Dashboard、API 或 CLI 进行管理。本节将介绍如何启动、停止和维护插件。

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
