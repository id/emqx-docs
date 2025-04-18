# Namespace

Starting from EMQX 5.9.0, the Namespace feature allows users to logically isolate MQTT clients, topics, authentication rules, and traffic limits within a single EMQX cluster. This feature enables scalable deployments where multiple client groups (such as business units, applications, or customers) share the same infrastructure while remaining logically separated.

::: tip Note

This feature is referred to as Namespace in EMQX 5.9, even though it follows multi-tenancy design principles.

:::

## What Is a Namespace

A Namespace is a logical boundary in EMQX used to group MQTT clients and apply isolation policies. It is identified by the special client attribute `tns` (tenant namespace), which can be extracted from connection metadata such as the username or Server Name Indication (SNI).

Namespaces can be used to control:

- Topic isolation using automatic topic prefixing (mountpoint)
- Client ID isolation to avoid clashes between tenants
- Authentication and authorization policies per namespace
- Per-namespace client count limits and connection tracking
- Logging metadata enrichment with namespace information
- Rate limiting per namespace

## Enable Namespace

To enable namespace features, EMQX must first know how to determine which namespace a client belongs to. This is done by setting the special `tns` (tenant namespace) client attribute.

You can extract the `tns` attribute from connection metadata, such as the client’s username, SNI, or other fields.

For example, to use the client's username as the namespace identifier, you can use the following configuration:

```hcl
mqtt.client_attrs_init = [{expression = username, set_as_attr = tns}]
```

## Manage Namespace

Most of the namespace features are only configurable via the [REST API](../admin/api.md).

::: tip

Always check the corresponding Swagger API documentation for detailed and up-to-date request and response endpoint schemas. These are served by the Dashboard listeners at `/api-docs`.

:::

### Create a Namespace

Before applying namespace-specific configuration, the namespace must be explicitly created using the `POST /mt/ns/<namespace>` API. Replace `<namespace>` with the desired namespace ID. No request body is required.

### Configure Namespace

After the namespace is created, it can be configured using the `PUT /mt/ns/<namespace>/config` API.

Use this endpoint to set rate limits, session limits, and other namespace-specific settings. For example configurations, see the [Quick Start](#configure-rate-limiter-per-namespace) section below.

### Delete a Namespace

To remove a namespace and its associated configuration, you can use the `DELETE /mt/ns/<namespace>` API.

::: tip Note

Before deleting a namespace, ensure that all active clients associated with the namespace are properly disconnected. EMQX provides an API to bulk kick all sessions under a namespace, and this process should be triggered automatically when deleting a managed namespace.

:::

## Quick Start: Configure Rate Limiter per Namespace

You can configure per-namespace rate limiters to control traffic and message flow for specific client groups. These limiters work in conjunction with EMQX's existing rate-limiting existing rate limiters for zones and listeners, depending on the type of limiter configured.

### Limiter Types

In a managed namespace, there are two types of rate limiters:

**Tenant rate limiters**: Assign tokens that are **shared** across all clients within a namespace (NS). When this type of limiter is configured, it composes with any existing zone-level rate limiters, meaning both the zone and the namespace tenant rate limiters apply to clients simultaneously.

**Client rate limiters**: Assign tokens that are **exclusive** to each client within the NS. When this type of limiter is configured, it replaces any existing listener-level rate limiters, meaning the listener rate limiters are ignored while the namespace client limiter takes effect.

Both limiter types can define limits for:

- **Message rate limits**: the maximum number of messages a client or tenant can publish over a given time period
- **Byte throughput limits**: the maximum allowed size for message payloads over time
- **Subscription rate limits**: the maximum number of topics a client can subscribe to within a specified time window

::: tip

For more details, refer to the [Rate Limit](../rate-limit/rate-limit.md) documentation.

:::

## Configuration Example

Suppose you want to configure some specific rate limits for clients in the `ns1` namespace. You also want to limit the maximum number of concurrent sessions allowed in this namespace.

### Create the Namespace

Before applying any configuration, ensure the namespace is explicitly managed:

```bash
# No request body is needed
POST /mt/ns/ns1
```

::: tip Important Notice

If clients connect to a namespace before it is explicitly managed, they will not inherit configurations such as rate limiters applied later. To enforce new settings, those clients must be manually disconnected and reconnected.

:::

### Configure Rate Limits and Session Limits

Once the namespace is created, apply the configuration using:

```
PUT /mt/ns/ns1/config
```

**Request body:**

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

This configuration applies both client-specific and shared tenant-wide rate limits and sets a maximum of 100 sessions for the namespace.

### Disable Namespace Rate Limiters

If you want to remove rate limiting entirely, you can update the configuration again and set the limiter types to `"disabled"`:

```
PUT /mt/ns/ns1/config
```

**Request body:**

```json
{
  "limiter": {
    "client": "disabled",
    "tenant": "disabled"
  }
}
```
