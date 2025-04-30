# Plugins

EMQX enables users to customize business logic or implement additional protocols by creating plugins written in Erlang. This guide covers the process of developing, installing, and managing plugins for EMQX.

## What is a Plugin?

A plugin is an Erlang application that operates within the EMQX nodes.

To be loaded into the nodes, a plugin must be compiled into a release (a single `.tar.gz` file). This release can then be imported into EMQX using the Dashboard, REST API, or CLI interfaces.

Once loaded, a plugin can be:

- Configured
- Started or stopped
- Unloaded

Upon startup, a plugin typically registers some of its functions as EMQX *callbacks* to modify or extend the behavior of EMQX.

## Develop EMQX Plugins

This section provides a step-by-step guide to developing custom EMQX plugins, using the creation of an access control plugin as an example.

### Prerequisites

Before you begin, make sure you have the following:

- Knowledge of EMQX [hooks](./hooks.md).
- A working build environment (e.g., `build_essential`), including `make`.
- Erlang/OTP of the same major version as the EMQX release you wish to target. For more information, see the `org.opencontainers.image.otp.version` attribute in the Docker or refer to the `.tool-versions` file for the used version (e.g., https://github.com/emqx/emqx/blob/e5.9.0-beta.4/.tool-versions). It's recommended to use [ASDF](https://asdf-vm.com/) to manage Erlang/OTP versions.
- [rebar3](https://www.rebar3.org/).

### Create a Plugin

EMQX provides an [emqx-plugin-template](https://github.com/emqx/emqx-plugin-template) to simplify the creation of custom EMQX plugins. To create a new plugin, you should install `emqx-plugin-template` as a `rebar3` template.

1. For a Linux system, use the following commands to download the `emqx-plugin-template`:

   ```shell
   $ mkdir -p ~/.config/rebar3/templates
   $ pushd ~/.config/rebar3/templates
   $ git clone https://github.com/emqx/emqx-plugin-template
   $ popd
   ```

   ::: tip

   If the `REBAR_CACHE_DIR` environment variable is set, the directory for templates should be `$REBAR_CACHE_DIR/.config/rebar3/templates`. [Here](https://github.com/erlang/rebar3/issues/2762) is a related issue.

   :::

2. Generate your customized plugin using the template with this command:

   ```shell
   $ rebar3 new emqx-plugin my_emqx_plugin
   ```

   This command will create a working skeleton for your plugin in the `my_emqx_plugin` directory.

3. Execute the following command to make a release of the plugin:

   ```shell
   $ cd my_emqx_plugin
   $ make rel
   ```

   This will create the plugin release: `_build/default/emqx_plugin/my_emqx_plugin-1.0.0.tar.gz`. This package can be used for provisioning/installation of the plugin.

### Plugin Structure

This command creates a standard Erlang application with `emqx` included as a dependency, structured as follows:

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

- `src`: Contains the code for the plugin’s OTP application.

- `priv`: Holds the plugin’s configuration files and schema (with example files).
- `rebar.config`: The `rebar3` configuration file used to build the application and package it into a release.
- `Makefile`: The entry point for building the plugin.
- `scripts`: Helper scripts for the `Makefile`.
- `README.md`: Documentation placeholder.
- `LICENSE`: Sample license file for the plugin.
- Review the `rebar.config` file and adjust it as necessary for your plugin's requirements.

The project also includes an example module demonstrating how to add custom `emqx ctl` commands (`emqx_cli_demo.erl`).

**Note:** As the template depends on `emqx`, it requires a custom version of `rebar3`, which you can install using the included `./scripts/ensure-rebar3.sh` script.

#### `rebar.config`

The `rebar.config` file is used to build the plugin and pack it into a release.

The most important sections are:

- Dependencies (`deps`) section;
- Release section (`relx`);
- Plugin description (`emqx_plugin`) section.

In the `deps` section, you can add dependencies to other OTP applications that your plugin depends on.

```
{deps,
    [
        ...
        %% this is my plugin's dependency
        {map_sets, "1.1.0"}
    ]}.
```

The template adds a single dependency to the plugin: `map_sets`. You can remove this if it's not required. For more details on dependencies, refer to the [`rebar3` dependency documentation](https://www.rebar3.org/docs/configuration/dependencies/).

In the `relx` section, you specify the release name and version, and the list of applications to be included in the release.

```
{relx, [ {release, {my_emqx_plugin, "1.0.0"},
            [ my_emqx_plugin
            , map_sets
            ]}
       ...
       ]}.
```

Normally, you would like to add the applications of the runtime dependencies from the `deps` section to the release.

The release name and version are important because they are used to identify the plugin when it is installed into EMQX. They form a single identifier for the plugin (`my_emqx_plugin-1.0.0`) by which it is addressed in the API or CLI.

In the plugin description section, you specify additional information about the plugin.

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

#### `src` Directory

The `src` directory contains the code of the plugin's OTP application.

##### `my_emqx_plugin.app.src`

This is a standard Erlang application description file, which is compiled into `my_emqx_plugin.app` in the release.

- The version of the application does not have to match the release version and can follow a different versioning scheme.
- Pay special attention to the `applications` section. Since the plugin is an OTP application, the start, stop, and restart operations will correspond to the plugin’s application. If the plugin depends on other applications, list them in the `applications` section.

##### `my_emqx_plugin_app.erl`

This is the main module implementing the [`application` behaviour](https://www.erlang.org/doc/man/application.html) ( `start/2` and `stop/1` functions) to start and stop the plugin's application and its supervison tree.

Common activities in the `start/2` function include:

- Hook into EMQX hookpoints.
- Register CLI commands.
- Start the supervision tree.

Optionally, the `_app.erl` module can implement the `on_config_changed/2` and `on_health_check/1` callback functions.

- `on_config_changed/2` is called when the plugin's configuration is changed via the Dashboard, API or CLI.
- `on_health_check/1` is called when the plugin's status is requested. A plugin can report its status from this function.

##### Other Files

The `my_emqx_plugin_cli.erl` module implements the CLI commands of the plugin. When registered, CLI commands are may be called via `emqx ctl` command.

`my_emqx_plugin_sup.erl` implements a typical supervisor for the plugin.

`my_emqx_plugin.erl` is the main module of the plugin implementing the plugin's logic. In the skeleton, it implements several demonstrational hooks with simple logging. Any other modules may be added to the plugin.

::: tip Note

The application modules and files may be arbitrarily named with the only requirements:

- The application name must be the same as the plugin name.
- The application module (`_app`) must be named as `{plugin_name}_app`.
  :::

#### `priv` Directory

The `priv` directory holds the plugin's configuration files and schema.

##### `config.hocon`

This file contains the plugin's initial configuration in [HOCON format](https://github.com/lightbend/config/blob/master/HOCON.md). You can use `config.hocon.example` for quick reference.

##### `config_schema.avsc`

This file defines the schema for the plugin's configuration in [Avro format](https://avro.apache.org/docs/1.11.1/specification/). When present, EMQX will validate the plugin's configuration against this schema whenever it's updated. The release build will fail if `config.hocon` does not conform to the schema.

Additionally, this file can include UI hints, enabling interactive configuration through the EMQX Dashboard. For reference, see `config_schema.avsc.enterprise.example`.

##### `config_i18n.json`

This file contains translations for the plugin's configuration UI in JSON format. For example:

```
{
  "$key": {
    "zh": "中文翻译",
    "en": "English translation"
  },
  ...
}
```

The translations are referenced in the `config_schema.avsc` in UI hints. See `config_i18n.json.example` and `config_schema.avsc.enterprise.example` for more information.

### Package Structure

When a plugin is built into a release, the package structure is as follows:

```
└── my_emqx_plugin-1.1.0.tar.gz
    ├── map_sets-1.1.0
    ├── my_emqx_plugin-0.1.0
    ├── README.md
    └── release.json
```

The tarball includes the compiled applications (as specified in the `relx` section of `rebar.config`), the `README.md` file, and `release.json`, which contains metadata about the plugin.

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

### Test Your Development Environment

If you are using the EMQX Open Source edition, ensure your development environment is correctly set up. You can refer to the information in [Install from Source Code](../deploy/install-source.md).

Execute the following command to verify if your plugin compiles and packages successfully:

```shell
$ make rel
```

At this stage, no additional coding is required.

Since the example plugin depends on the EMQX core application, you must download and compile it along with its dependencies. This step integrates the plugin into the main EMQX project. Be aware that this compilation process can be time-intensive.

### Customize the Example Project

After verifying that your setup works correctly, you can start tailoring the example project to meet your specific requirements. The initial template provides a core module at `src/my_emqx_plugin.erl`, which includes registration for all [currently known hooks](./hooks.md). Begin by removing any hooks that are not needed and implement your own logic in the callbacks for the ones you retain.

#### Example Customization for Authentication and Access Control

For instance, if you need hooks for authentication and access control, modify the `my_emqx_plugin:load/1` function as shown:

```erlang
load(Env) ->
  emqx_hooks:add('client.authenticate', {?MODULE, on_client_authenticate, [Env]}, ?HP_HIGHEST),
  emqx_hooks:add('client.authorize', {?MODULE, on_client_authorize, [Env]}, ?HP_HIGHEST),
  ok.
```

Here, `on_client_authenticate/3` handles client authentication, while `on_client_authorize/5` manages access control.

As one hook function may be mounted by both EMQX and customized plugins, you need to specify the execution order when mounting it to the plugin.  `HP_HIGHEST` specifies that the current hook function has the highest priority and is executed first.

#### Customize Access Control Code

Consider the following access control implementations:

```erlang
%% Only allow connections with client IDs that match any of the characters: A-Z, a-z, 0-9, and underscore.
on_client_authenticate(_ClientInfo = #{clientid := ClientId}, Result, _Env) ->
  case re:run(ClientId, "^[A-Za-z0-9_]+$", [{capture, none}]) of
    match -> {ok, Result};
    nomatch -> {stop, {error, banned}}
  end.
%% Clients can only subscribe to topics formatted as /room/{clientid}, but can send messages to any topics.
on_client_authorize(_ClientInfo = #{clientid := ClientId}, subscribe, Topic, Result, _Env) ->
  case emqx_topic:match(Topic, <<"/room/", ClientId/binary>>) of
    true -> {ok, Result};
    false -> stop
  end;
on_client_authorize(_ClientInfo, _Pub, _Topic, Result, _Env) -> {ok, Result}.
```

In the provided code example, only clients with a client ID matching the specified pattern can log in. These clients are restricted to subscribing only to the topic `/room/{clientid}`, effectively creating a simple chat room setup. While clients can send messages to any topic, they are limited to subscribing to topics that directly pertain to their own client ID.

::: tip

1. Ensure `authorization.no_match` is set to `deny` in your configuration to prevent unauthorized connections.
2. This example details customizing an access control plugin. Similar authorization rules can be based on files as detailed in the [File-Based Authorization documentation](../access-control/authz/file.md).

:::

#### Pack the Customized Plugin

Modify the version information of the plugin via `rebar.config`:

```erlang
{relx, [ {release, {my_emqx_plugin, "1.0.0"}, %% This is the release version, different from app vsn in .app file
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
}..
```

After updating the configuration, re-run the release command:

```shell
make rel
...
===> Release successfully assembled: _build/default/rel/my_emqx_plugin
===> [emqx_plugrel] creating _build/default/emqx_plugrel/my_emqx_plugin-1.0.0.tar.gz
```

This generates a new tarball, `my_emqx_plugin-1.0.0.tar.gz`, which you can upload and deploy to your EMQX cluster.

#### Write Configuration Schema for the Plugin (Optional)

EMQX version 5.7.0 introduced REST API for plugin configuration management and Avro Schema for configuration validation, enhancing the ability to update plugin configurations dynamically during runtime.
In addition, if you write an Avro Schema to validate the plugin's configuration, you are required to provide a default configuration file that matches the Avro Schema rules. This file should be located at `priv/config.hocon`.

Configuration updates made at runtime will be written in HOCON format to `data/plugins/<PLUGIN_NAME>/config.hocon`, and the old configuration file will be backed up each time the configuration is updated.


::: tip

Check out the example files in your project directory: `priv/config.hocon.example`, `priv/config_schema.avsc.example`, `priv/config_schema.avsc.enterprise.example` and `priv/config_i18n.json.example`.
Plugins that support configuration and configuration validation can be written based on these files.

Note that `priv/config_schema.avsc.enterprise.example` and `priv/config_i18n.json.example` contain the UI declarations and their internationalization configurations. Using UI declarations to render plugin configuration form pages is an EMQX Enterprise edition feature.

:::


Your plugin package needs to include an Avro Schema configuration file, located at the relative path `priv/config_schema.avsc`. This file must adhere to the [Apache Avro specification](https://avro.apache.org/docs/1.11.1/specification/).

Additionally, it also includes descriptive declarations about the UI. Specifically, an `$ui` field can be configured using the metadata of the Avro Schema. The EMQX Dashboard will generate a configuration form page based on the information provided in the `$ui` field.


#### Declarative UI Usage Reference (Optional)

::: tip

Using the declarative UI components is an EMQX Enterprise edition feature.

:::

Declarative UI components enable dynamic form rendering within the Dashboard, accommodating a variety of field types and custom components. Below is a description of the available components and their configurations.

UI declarations are used for dynamic form rendering, allowing the EMQX Dashboard to dynamically generate configuration forms, making it easier to configure and manage plugins. Various field types and custom components are supported. Below are the available components and their configuration descriptions.

There is also an **optional** internationalization (i18n) config file, located at `priv/config_i18n.json`. This file is structured as key-value pairs, for example: `{ "$msgid": { "zh": "消息", "en": "Message" } }`.
To support multiple languages in field names, descriptions, validation rule messages, and other UI elements in the `$ui` configuration, use `$msgid` prefixed with `$` in the relevant UI configurations.

**Configuration Item Descriptions**

- `component`<br />
  Required. Specifies the component type for displaying and configuring data of different values and types. Supported components include:

  | Component Name     | Description                                                  |
  | :----------------- | :----------------------------------------------------------- |
  | `input`            | Text input box for short texts or strings                    |
  | `input-password`   | Password input box that conceals input                       |
  | `input-number`     | Numeric input box allowing only numeric input                |
  | `input-textarea`   | Text area for longer text entries                            |
  | `input-array`      | Array input box for comma-separated values, supporting string and numeric arrays |
  | `switch`           | Toggle switch for boolean values                             |
  | `select`           | Dropdown selection box for enumerated types                  |
  | `code-editor`      | Code editor for specific formats (e.g., SQL, JSON)           |
  | `key-value-editor` | Editor for editing key-value pairs in Avro maps              |
  | `maps-editor`      | Editor for editing object arrays in Avro objects             |
- `label`<br />
  Required. Defines the field's label or name, supports `$msgid` for internationalization. If i18n is not configured, the original text will be displayed directly.
- `description`<br />
  Optional. Provides a detailed description of the field, supports `$msgid` for internationalization. If i18n is not configured, the original text will be displayed directly.
- `flex`<br />
  Required. Defines the proportion of the field in the grid layout; a full grid (24) spans an entire row, while a half grid (12) covers half a row.
- `required`<br />
  Optional. Indicates whether the field is mandatory.
- `format` (Applicable only for `code-editor` component)<br />
  Optional. Specifies the supported data formats, such as `sql` or `json`.
- `options` (Applicable only for `select` component)<br />
  Optional. Lists the selectable options, aligned with the symbols in the Avro Schema. Example:

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
- `items` (Applicable only for maps-editor component)<br />
  Optional. When using the maps-editor component, specify the field name and description of the items in the form. For example:

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
  Optional. Defines validation rules for the field, where multiple rules can be configured. Supported types include:

  - `pattern`: Requires a regular expression for validation.
  - `range`: Validates numeric input within a specified range. This validation can be configured with both a minimum value (`min`) and a maximum value (`max`), which can be set either together or independently.
  - `length`: Validates the character count of input, ensuring it falls within a specified range. This validation rule allows for the configuration of both a minimum length (`minLength`) and a maximum length (`maxLength`), which can be set either together or individually.
  - `message`: Specifies an error message to display when validation fails. This supports internationalization using `$msgid` to accommodate multiple languages.

**Example Validation Rules**:

The following are several example snippets. For more detailed examples, refer to `priv/config_schema.avsc.example`:

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

Including Avro Schema and i18n files in your plugin package ensures they are incorporated during plugin compilation and packaging. You can use the `emqx_plugins:get_config/1,2,3,4` function in your plugin code to retrieve configuration settings.

## Install Plugins

EMQX supports plugin installation via the Dashboard and CLI. However, due to security enhancements, plugin installation via the Dashboard now requires explicit permission before proceeding.

### Install Plugins via Dashboard

::: tip Important Security Update

For security reasons, EMQX now requires explicit authorization before plugin installation via the Dashboard.

- Installation permission must be granted before initiating the process.

- The allowed state is temporary and is automatically revoked after installation completes.

- If running in a clustered environment, permission must be granted on all nodes before installation.

  :::

1. Run the following command in the CLI to explicitly allow the plugin installation:

   ```bash
   emqx ctl plugins allow $NAME-$VSN
   ```

   - `{NAME}`: The name of your plugin (e.g., `my_emqx_plugin`).
   - `{VSN}`: The version of the plugin (e.g., `1.2.3`).

   Once this command is executed, you can proceed with the installation through the Dashboard.

2. Navigate to **Management** -> **Plugins** in the EMQX Dashboard. 
3. Click the **+ Install plugin** button to open the Install plugin page.
4. Upload the plugin package by clicking the upload button or by drag and drop.
5. Click the **Install** button to complete the installation.

To revoke permission for a previously allowed plugin, either:

1. Uninstall the plugin (if already installed).
2. Or explicitly disallow it using the following command:

```bash
emqx ctl plugins disallow $NAME-$VSN
```

### Install Plugins via CLI

To install a compiled plugin package directly via the CLI, use the following command:

```bash
./bin/emqx ctl plugins install {pluginName}
```

### Install Plugins via API

To install a plugin using the API, follow these steps:

1. Allow the installation. To enable the installation of the plugin, run the following command:

```
emqx ctl plugins allow {pluginName}
```

2. Install the plugin. Use `curl` to install the plugin by sending a POST request to the API:

```
$ curl -u $KEY:$SECRET -X POST http://$EMQX_HOST:18083/api/v5/plugins/install -H "Content-Type: multipart/form-data" -F "plugin=@{pluginName}.tar.gz"
```

3. Check plugin list. To verify if the plugin has been installed successfully, run:

```
$ curl -u $KEY:$SECRET http://$EMQX_HOST:18083/api/v5/plugins | jq
```

4. Start/stop the plugin. To start or stop the plugin, use the following commands:

```
$ curl -s -u $KEY:$SECRET -X PUT "http://$EMQX_HOST:18083/api/v5/plugins/{pluginName}/start"
$ curl -s -u $KEY:$SECRET -X PUT "http://$EMQX_HOST:18083/api/v5/plugins/{pluginName}/stop"
```

## Uninstall Plugins

If a plugin is no longer needed, you can uninstall it either via Dashboard or CLI.

To uninstall a plugin via Dashboard, click the **Uninstall** button under the **More** menu in the **Actions** column on the plugin list page.

To uninstall a plugin via CLI, you can use the following command:

```bash
./bin/emqx ctl plugins uninstall {pluginName}
```

<!-- **Note**: (EMQX enterprise) Plugins need to be reinstalled after hot upgrades. -->

## Manage Plugins

Once a plugin is installed, it can be managed through the Dashboard, API, or CLI. This section explains the various operations you can perform to start, stop, and maintain plugins.

### Start Plugins

The plugin is started manually via the Dashboard, API, or CLI. Upon starting:

- The plugin's applications is started.
- The plugin is registered as `enabled` in the EMQX config (`plugins.states`).

When the plugin is started and its information is requested, the `on_health_check/1` callback function is called to retreive the plugin's status.

### Stop Plugins

When the plugin is stopped:

- The plugin's applications are stopped.
- The plugin is registered as `disabled` in the EMQX config (`plugins.states`).

Although the plugin’s application is stopped, its code remains loaded on the node, as a stopped plugin can still be configured.

### Implement Plugins

To implement a plugin, the following logic is typically required:

- Implementing hooks and CLI commands.
- Handling configuration updates.
- Handling health checks.

#### Implement Hooks and CLI Commands

EMQX defines hookpoints for various events. Any application (including a plugin) can register callbacks for these hookpoints to react to events or modify default behavior.

The most commonly used hookpoints are available in the skeleton file. A complete list of hookpoints, their arguments, and expected return values is also provided in the [EMQX code](https://github.com/emqx/emqx/blob/master/apps/emqx/src/emqx_hookpoints.erl).

To register a callback for a hookpoint, use the `emqx_hooks:add/3` function. You need to provide:

- The hookpoint name.
- The callback module and function, potentially with additional arguments that EMQX will pass.
- The callback’s priority (usually `?HP_HIGHEST` to ensure it is called first).

To unregister a callback, use the `emqx_hooks:del/2` function with the hookpoint name and callback module/function.

For example, to register/unregister callbacks for `client.authenticate` and `client.authorize` hookpoints:

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

Typically, hooks should be enabled and disabled together with the plugin, so you can call `hook/unhook` in the `start/2` and `stop/1` functions of the plugin's application:

```
start(_StartType, _StartArgs) ->
    {ok, Sup} = my_emqx_plugin_sup:start_link(),
    my_emqx_plugin:hook(),

    {ok, Sup}.

stop(_State) ->
    my_emqx_plugin:unhook().
```

The signature of the callback functions is available in the [hookpoint specification](https://github.com/emqx/emqx/blob/master/apps/emqx/src/emqx_hookpoints.erl). For example:

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

Here is an example of callback function implementations:

```
%% Only allow connections with client IDs that match any of the characters: A-Z, a-z, 0-9, and underscore.
on_client_authenticate(_ClientInfo = #{clientid := ClientId}, Result) ->
  case re:run(ClientId, "^[A-Za-z0-9_]+$", [{capture, none}]) of
    match -> {ok, Result};
    nomatch -> {stop, {error, banned}}
  end.
%% Clients can only subscribe to topics formatted as /room/{clientid}, but can send messages to any topics.
on_client_authorize(_ClientInfo = #{clientid := ClientId}, subscribe, Topic, Result) ->
  case emqx_topic:match(Topic, <<"/room/", ClientId/binary>>) of
    true -> {ok, Result};
    false -> stop
  end;
on_client_authorize(_ClientInfo, _Pub, _Topic, Result) -> {ok, Result}.
```

In the skeleton app, hooks are registered via `my_emqx_plugin:load/1` and unregistered via `my_emqx_plugin:unload/0`.

#### Handle Configuration Updates

When a user updates the plugin's configuration, the `on_config_changed/2` callback function of the plugin's application is invoked.

In this callback, you typically need to:

- Validate the new configuration.
- React to the changes if the plugin is running.

While validating the configuration, keep in mind that the application may not yet be started. Therefore, use stateless checks and avoid environment-dependent checks that could cause inconsistencies across nodes.

If the plugin is running, you can apply the configuration changes. The usual pattern is as follows:

- On application start, a `gen_server` is initiated to handle the configuration.
- This server, e.g., `my_emqx_plugin_config_server`, reads the current configuration and initializes its state.
- The `on_config_changed/2` callback validates the configuration and sends the new configuration to the `my_emqx_plugin_config_server`.
- If the server is running, it updates its state with the new configuration; if not, no action is taken.

#### Handle Health Checks

The `on_health_check/1` callback is called when EMQX requests the plugin's status. The plugin can report its health as follows:

- Return `ok` if the plugin is healthy.
- Return `{error, Reason}` with a binary reason to indicate an issue with the plugin.

This callback is essential for plugins that rely on external resources that may become unavailable.

For more details, see `my_emqx_plugin_app:on_health_check/1` in the skeleton app.

::: tip

Although this function is invoked for running plugins, it may also be called during plugin startup or shutdown due to concurrency.

:::

### Upgrade Plugins

EMQX does not allow multiple versions of the same plugin to be installed simultaneously.

To install a new version of the plugin:

- The old version must first be uninstalled.
- The new version is then installed.

The plugin configuration is preserved across installations.
