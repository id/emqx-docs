# Multi-tenancy

## Enabling multi-tenancy

To be able to use multi-tenancy features, we must first tell EMQX how to define the tenant namespace a client belongs to.  This is done by setting the special `tns` client attribute for each client.

As an example, if we want to extract the client's `username` as the namespace, we could use the following configuration:

```hcl
mqtt.client_attrs_init = [{expression = username, set_as_attr = tns}]
```

## Configuring multi-tenancy

Most of multi-tenancy (MT) features are only configurable via the HTTP REST API.

To define namespace (NS) specific configuration, the NS must first be explicitly created
using the `POST /mt/ns/:namespace` API, replacing the `:namespace` parameter with the NS
name.  To delete a managed namespace, use the `DELETE /mt/ns/:namespace` API.

Once the NS is created, it may be configured with `PUT /mt/ns/:namespace/config` API.

:::: tip

Always check the corresponding Swagger API documentation for detailed and up-to-date
request and response endpoint schemas.  These are served by the Dashboard listeners at
`/api-docs`.

::::

### Rate limiter

It is possible to configure extra rate limiters that are specific to a managed NS.  Such
rate limiters compose with existing rate limiters for zones and listeners.

There are two kinds of rate limiters: **client** and **tenant**.

**Tenant** rate limiters have tokens that are **shared** between all clients in the NS.
If this kind is configured for a NS, it _composes_ with any existing _zone_ rate limiters.
That is: both zone and NS Tenant rate limiters apply to the clients at the same time.

**Client** rate limiters have tokens that are **exclusive** to each client in the NS.  If
this kind is configured for a NS, it _replaces_ with any existing _listener_ rate
limiters.  That is: listener rate limiters are ignored when this configuration is enabled.

Each kind, in turn, can define limits for **numbers of messages** and for **byte
throughput**.  These apply for the number/size of published messages, as well as the
number of topics a client may subscribe to in a time interval.  See the main [Rate
Limit](../rate-limit/rate-limit.md) section for more details.

:::: warning

If clients connect to a NS **before** it is made explicitly managed, they will **not**
pick up certain configurations made later to the NS, such as _rate limiters_.  These
clients must be manually kicked out if one wants them to abide to the new rate limiters.

::::


#### Examples

Let's say we want to configure some specific rate limits for clients in the `ns1` NS.  We
also want to configure the maximum number of sessions this NS can hold.

To do so, we first ensure this NS is explicitly managed:

```
# No request body is needed
POST /mt/ns/ns1
```

Once it's created, we set its desired configuration:

```
PUT /mt/ns/ns1/config
```

Request body:
```json
{
  "limiter": {
    "client": {
      "bytes": {
        "rate": "10MB/10s",
        "burst": "200MB/1m"
      },
      "messages": {
        "rate": "3000/1s",
        "burst": "40/30s"
      }
    },
    "tenant": {
      "bytes": {
        "rate": "20MB/10s",
        "burst": "300MB/1m"
      },
      "messages": {
        "rate": "5000/1s",
        "burst": "60/30s"
      }
    }
  },
  "session": {
    "max_sessions": 100
  }
}
```

Let's say, now, that we wish to _disable_ the NS rate limiters.  We do so by updating the
configuration again and setting the limiter kinds to `"disabled"`:

```
PUT /mt/ns/ns1/config
```

Request body:
```json
{
  "limiter": {
    "client": "disabled",
    "tenant": "disabled"
  }
}
```
