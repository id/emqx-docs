# Schema Registry Example - External HTTP Server

::: tip Note

Schema Registry is an EMQX Enterprise feature.

:::

This page demonstrates how the schema registry and rule engine support message encoding and decoding using an External HTTP server that contains special logic.

## Expected API

The External HTTP server implementing the encoding/decoding API must provide a single `POST` endpoint that will handle the requests.  The request body is a JSON object with the following fields:

- `payload`: The base64 encoding of the value provided to the `schema_encode` or `schema_decode` functions in Rule Engine.  Such provided value must be a string.
- `type`: either the `encode` or the `decode` strings, depending on whether the function being evaluated is `schema_encode` or `schema_decode`, respectively.
- `schema_name`: a string that is the name of this External HTTP in EMQX configuration.
- `opts`: an arbitrary string that can be configured in EMQX to provide further options, which is passed unaltered to the HTTP server.

The successful response status code must be 200, and the response body must be the base64 encoding of the desired result.  Note that this base64 value must not be further JSON-encoded when replying to EMQX.

## Sample Scenario

A device publishes a binary message that we wish to encode or decode using custom logic that is not readily available in EMQX.

Let's say, for the sake of simplicity, that this custom logic consists of "XORing" the input payload with a fixed value, for both encoding and decoding.

<details>
<summary>Code for sample External HTTP Server</summary>

Ensure [Flask](https://flask.palletsprojects.com/en/stable/) is installed.

```sh
pip install Flask==3.1.0
```

```python
from flask import Flask, request
import base64

app = Flask(__name__)

@app.route("/serde", methods=['POST'])
def serde():
    # The input payload is base64 encoded
    body = request.get_json(force=True)
    print("incoming request:", body)
    payload64 = body.get("payload")
    payload = base64.b64decode(payload64)
    secret = 122
    response = bytes(b ^ secret for b in payload)
    # The respone must also be base64 encoded
    response64 = base64.b64encode(response)
    return response64
```

To run your server:

```sh
# This assumes your server is in the same directory in a file named `myapp.py`
flask --app myapp --debug run -h 0.0.0.0 -p 9500
```

</details>

### Create Schema

1. Go to the Dashboard, select **Integration** -> **Schema** from the left navigation menu.

2. Create an External HTTP server schema using the following parameters:

   - **Name**: `myhttp`

   - **Type**: `External HTTP`

   - **URL**: The full URI where your server is running.  For example: `http://server:9500/serde`.

3. Click **Create**.

### Create Rule

1. In the Dashboard, select **Integration** -> **Rules** from the navigation menu.

2. On the **Rules** page, click **Create** at the top right corner.

3. Use the schema you have just created to write the rule SQL statement:

   ```sql
   SELECT
     schema_encode('myhttp', payload) as encoded,
     schema_decode('myhttp', encoded) as decoded
   FROM
     "t/external_http"
   ```

   The key points here are `schema_encode('myhttp', payload)` and `schema_decode('myhttp', encoded)`.  Both will call the configured External HTTP server to encode/decode the given payload.

4. Click **Add Action**.  Select `Republish` from the drop-down list of the **Action** field.
5. In the **Topic** field, type `external_http/out` as the destination topic.
6. In the **Payload** field, type message content template: `${.}`.

This action sends the decoded message to the topic `external_http/out` in JSON format. `${.}` is a variable placeholder that will be replaced at runtime with the value of whole output of the rule.

### Check Rule Execution Results

1. In the Dashboard, select **Diagnose** -> **WebSocket Client**.
2. Fill in the connection information for the current EMQX instance.
   - If you run EMQX locally, you can use the default value.
   - If you have changed EMQX's default configuration. For example, the configuration change on authentication can require you to type in a username and password.
3. Click **Connect** to connect to the EMQX instance as an MQTT client.
4. In the **Subscription** area, type `external_http/out` in the **Topic** field and click **Subscribe**.

5. In the **Publish** are, type `t/external_http` in the **Topic** field, write any payload you wish, and click **Publish**.

6. Check that a message with the topic `external_http/out` is received on the Websocket side.  For example, if your payload was `hello`:

   ```json
   {"encoded":"\u0012\u001F\u0016\u0016\u0015","decoded":"hello"}
   ```
