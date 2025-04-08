# Ingest MQTT Data into Disk Log
::: tip

The Disk Log data integration is an EMQX Enterprise edition feature.

:::

Disk Log integration allows events to be written to disk similar to rotating logs in [JSON Lines](https://jsonlines.org/) format.  This allows retaining events for troubleshooting or historical tracking.

This page provides a detailed introduction to the data integration between EMQX with Disk Log, and offers practical guidance on the rule and Sink creation.

## How It Works

When using Disk Log integration, you set up a directory where log files will be kept, and configure the maximum file size and number to trigger log rotation.  When the maximum file size is reached, a new log file is opened for writing new entries.  When the maximum number of files is reached, the oldest file is truncated and opened for writing new entries.  At least one full entry is written to each log file, even if that single entry surpasses the maximum file size.

## Before You Start

This section introduces the preparations required before creating a Disk Log Sink in EMQX.

### Prerequisites

- Understanding of [rules](./rules.md).
- Understanding of [data integration](./data-bridges.md).

### Create a directory for log files

Ensure that the directory you use for Disk Log files is readable and writable by the EMQX application operating system user.

## Create a Connector

Before adding the Disk Log Sink, you need to create the corresponding connector.

1. Go to the Dashboard **Integration** -> **Connector** page.
2. Click the **Create** button in the top right corner.
3. Select **Disk Log** as the connector type and click next.
4. Enter the connector name, a combination of upper and lowercase letters and numbers. Here, enter `my-disk-log`.
5. Enter the connector parameters.
   - **Log Filepath**: Where EMQX will write log files to.
   - **Maximum File Size**: Maximum file size before a new file is opened for writing.
   - **Maximum Number of Files**: Maximum number of files before rotating over older logs.
6. Before clicking **Create**, you can click **Test Connectivity** to test if the connector can write logs to the configured path.
7. Click the **Create** button at the bottom to complete the connector creation.

You have now completed the connector creation and will proceed to create a rule and Sink for specifying the data to be written into Disk Log.

## Create a Rule with Disk Log Sink

This section demonstrates how to create a rule in EMQX to process messages from the source MQTT topic `t/#` and write the processed results to local log files through the configured Sink.

1. Go to the Dashboard **Integration** -> **Rules** page.

2. Click the **Create** button in the top right corner.

3. Enter the rule ID `my_rule`, and input the following rule SQL in the SQL editor:

   ```sql
   SELECT
     *
   FROM
       "t/#"
   ```

   ::: tip

   If you are new to SQL, you can click **SQL Examples** and **Enable Debug** to learn and test the rule SQL results.

   :::

4. Add an action, select `Disk Log` from the **Action Type** dropdown list, keep the action dropdown as the default `create action` option, or choose a previously created Disk Log action from the action dropdown. Here, create a new Sink and add it to the rule.

5. Enter the Sink's name and description.

6. Select the `my-disk-log` connector created earlier from the connector dropdown. You can also click the create button next to the dropdown to quickly create a new connector in the pop-up box. The required configuration parameters can be found in [Create a Connector](#create-a-connector).

7. Configure the **Message Template**, which must render to a valid JSON object, and the desired **Write Mode** (async or sync).

8. Expand **Advanced Settings** and configure the advanced setting options as needed (optional). For more details, refer to [Advanced Settings](#advanced-settings).

9. Use the default values for the remaining settings. Click the **Create** button to complete the Sink creation. After successful creation, the page will return to the rule creation, and the new Sink will be added to the rule actions.

10. Back on the rule creation page, click the **Create** button to complete the entire rule creation process.

You have now successfully created the rule. You can see the newly created rule on the **Rules** page and the new Disk Log Sink on the **Actions (Sink)** tab.

You can also click **Integration** -> **Flow Designer** to view the topology. The topology visually shows how messages under the topic `t/#` are written to Disk Log after being parsed by the rule `my_rule`.

## Test the Rule

This section shows how to test the rule configured with the direct upload method.

Use MQTTX to publish a message to the topic `t/1`:

```bash
mqttx pub -i emqx_c -t t/1 -m '{ "msg": "Hello Disk Log" }'
```

After sending a few messages, check the configured Disk Log directory for the last changed file and check its contents to see the produced event.

## Advanced Settings

This section delves into the advanced configuration options available for the Disk Log Sink. In the Dashboard, when configuring the Sink, you can expand **Advanced Settings** to adjust the following parameters based on your specific needs.

| Field Name                | Description                                                  | Default Value  |
| ------------------------- | ------------------------------------------------------------ | -------------- |
| **Buffer Pool Size**      | Specifies the number of buffer worker processes, which are allocated to manage the data flow between EMQX and Disk Log. These workers temporarily store and process data before sending it to the disk log, crucial for optimizing performance and throughput. | `16`           |
| **Request TTL**           | The "Request TTL" (Time To Live) configuration setting specifies the maximum duration, in seconds, that a request is considered valid once it enters the buffer. This timer starts ticking from the moment the request is buffered. If the request stays in the buffer for a period exceeding this TTL setting or if it is sent but does not receive a timely response or acknowledgment for being persisted by Disk Log, the request is deemed to have expired. |                |
| **Health Check Interval** | Specifies the time interval (in seconds) for the Sink to perform automatic health checks on Disk log. | `15`           |
| **Max Buffer Queue Size** | Specifies the maximum number of bytes that can be buffered by each buffer worker process in the Disk Log Sink. The buffer workers temporarily store data before sending it to Disk Log, acting as intermediaries to handle the data stream more efficiently. Adjust this value based on system performance and data transmission requirements. | `256`          |
| **Query Mode**            | Allows you to choose between `synchronous` or `asynchronous` request modes to optimize message transmission according to different requirements. In asynchronous mode, writing to Disk Log does not block the MQTT message publishing process. However, this may lead to clients receiving messages before they are written to Disk Log. | `Asynchronous` |
| **Batch Size**            | Specifies the maximum size of data batches written from EMQX to Disk Log in a single batch operation. By adjusting the size, you can fine-tune the efficiency and performance of data transfer between EMQX and Disk Log.<br />If the "Batch Size" is set to "1," data records are sent individually, without being grouped into batches.  This Action tends to benefit from generous batching sizes. | `1000`                   |
| **Inflight  Window**     | "In-flight queue requests" refer to requests that have been initiated but have not yet received a response or acknowledgment. This setting controls the maximum number of in-flight queue requests that can exist simultaneously during Sink communication with Disk Log. <br/>When **Request Mode** is set to `asynchronous`, the "Request In-flight Queue Window" parameter becomes particularly important. If strict sequential processing of messages from the same MQTT client is crucial, then this value should be set to `1`. | `100`          |
