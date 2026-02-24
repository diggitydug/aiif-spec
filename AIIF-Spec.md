# AI Interface Format (AIIF) Specification — Version 1.0

**Status:** Final Standard  
**Version:** 1.0  
**Date:** 2026-02-23  
**License:** Apache 2.0

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [High-Level Concepts](#2-high-level-concepts)
3. [AIIF Document Structure](#3-aiif-document-structure)
4. [Endpoint Object Specification](#4-endpoint-object-specification)
5. [Parameter Specification](#5-parameter-specification)
6. [Schema Specification](#6-schema-specification)
7. [Error Specification](#7-error-specification)
8. [Behavioral Rules for AI Agents](#8-behavioral-rules-for-ai-agents)
9. [Required AIIF Implementation Endpoints](#9-required-aiif-implementation-endpoints)
10. [Examples (Non-Normative)](#10-examples-non-normative)
11. [Versioning and Compatibility](#11-versioning-and-compatibility)
12. [Conformance Checklist](#12-conformance-checklist)
13. [Security Considerations](#13-security-considerations)
14. [License](#14-license)

---

## 1. Introduction

### 1.1 What is AIIF?

The **AI Interface Format (AIIF)** is a machine-readable API documentation standard designed specifically for consumption by AI agents and large language models (LLMs). AIIF defines a compact, deterministic, and declarative contract format that describes an API's endpoints, parameters, request/response schemas, and error structures in a way that minimizes token consumption while maximizing agent accuracy.

### 1.2 Purpose

Modern AI agents increasingly need to interact with external APIs as part of automated workflows. Existing API documentation formats such as OpenAPI (Swagger) were designed primarily for human developers and developer tooling. They carry significant verbosity, optional complexity, and structural ambiguity that increases token cost and degrades LLM reasoning accuracy.

AIIF addresses these limitations by providing:

- A **minimal, predictable** contract format that an AI agent can consume in a single context window.
- **Unambiguous field semantics** that reduce hallucinated endpoint calls and parameter guesses.
- A **compact JSON structure** optimized for embedding directly in system prompts or agent tool schemas.
- **Normative behavioral rules** that define exactly how a conforming agent MUST interact with an API.

### 1.3 Design Philosophy

AIIF is designed around four core principles:

| Principle | Description |
|---|---|
| **Compact** | Every field has a purpose. There are no optional decorative fields. |
| **Deterministic** | Field names and semantics are fixed. Implementers do not choose their own vocabulary. |
| **Declarative** | AIIF describes *what* an API does, not *how* it is implemented. |
| **Embeddable** | A complete AIIF document SHOULD be small enough to include in an LLM system prompt. |

### 1.4 Relationship to OpenAPI

AIIF is **not** a replacement for OpenAPI. OpenAPI remains the authoritative standard for human-readable API documentation, SDK generation, and developer tooling. AIIF is a **complementary, LLM-first alternative** intended to serve AI agent use cases where token efficiency and behavioral predictability are the primary concerns. An API MAY expose both an OpenAPI specification and an AIIF document simultaneously.

### 1.5 Goals and Purpose

AIIF is designed to be a compact, deterministic, machine-readable API contract optimized specifically for AI agents. The goals of this specification are:

- **Minimal, LLM-friendly contract:** AIIF includes only the information an agent needs to call an API correctly, with intentionally compact structure to reduce token usage.
- **Deterministic and unambiguous behavior:** AIIF defines strict rules for parameters, request schemas, response schemas, and errors so agents do not infer undocumented behavior.
- **Consistent agent-to-API interaction:** AIIF provides a shared contract format that any API can expose and any agent can consume.
- **Selective documentation retrieval:** AIIF-compliant APIs MUST expose `GET /ai-docs`, `GET /ai-docs/{endpoint}`, and `GET /ai-docs/summary` so agents can fetch only the documentation needed for the current task.
- **Explicit authentication guidance:** APIs with protected endpoints MUST provide agent-consumable authentication flow documentation so agents can acquire, apply, and refresh credentials deterministically.
- **Predictable tooling:** AIIF is intentionally constrained so generators, SDKs, and agent frameworks can implement parsing and validation with minimal ambiguity.
- **Language and framework agnostic:** AIIF is implementation-neutral and portable across ecosystems.
- **Complementary to existing standards:** AIIF coexists with OpenAPI and focuses on AI-relevant contract details rather than replacing human-oriented standards.
- **Normative agent behavior:** AIIF uses RFC 2119 language to define how agents SHOULD and MUST behave when calling APIs.
- **Versioned evolution:** AIIF defines compatibility and unknown-field handling rules so the format can evolve without unnecessary breakage.

### 1.6 Non-Goals

To preserve minimalism and deterministic parsing, AIIF intentionally does not attempt to:

- Replace OpenAPI or full human developer documentation.
- Encode implementation internals, SDK ergonomics, or service deployment details.
- Support arbitrary custom field vocabularies that change core semantics.

---

## 2. High-Level Concepts

### 2.1 Endpoint Definitions

An **endpoint** in AIIF represents a single callable operation on the API. Each endpoint is identified by a unique name, an HTTP method, and a path. Endpoints are the primary unit of interaction for AI agents.

### 2.2 Parameter Definitions

**Parameters** describe the inputs to an endpoint. A parameter has a defined location (`path`, `query`, or `body`), a type, a required/optional flag, and a description. Parameters MUST be described exhaustively; agents MUST NOT infer parameters that are not documented.

### 2.3 Request and Response Schemas

**Schemas** define the structure of request bodies and response payloads. Schemas in AIIF use a simplified type system derived from JSON Schema, restricted to the subset most relevant to API contracts. Schemas MAY be defined inline within an endpoint or referenced by name from the top-level `schemas` map.

### 2.4 Error Schemas

**Errors** define the structured error responses an endpoint may return. Each error has a machine-readable code, a human-readable message, and a description. Agents MUST handle all documented error codes for any endpoint they call.

### 2.5 Behavioral Rules

AIIF includes a normative section of **behavioral rules** that govern how conforming AI agents interact with an API described by AIIF. These rules use RFC 2119 normative language (MUST, SHOULD, MAY).

### 2.6 Versioning Model

AIIF versions follow **semantic versioning** with major and minor components (e.g., `1.0`, `1.1`, `2.0`). A minor version increment (`1.0` → `1.1`) indicates backward-compatible additions. A major version increment (`1.x` → `2.0`) indicates breaking changes. The `aiif_version` field in every AIIF document MUST identify the AIIF specification version it conforms to.

---

## 3. AIIF Document Structure

### 3.1 Top-Level Object

An AIIF document is a single JSON object with the following top-level fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `aiif_version` | string | REQUIRED | The version of the AIIF specification this document conforms to (e.g., `"1.0"`). |
| `info` | object | REQUIRED | Metadata about the API. See [Section 3.2](#32-info-object). |
| `auth` | object | OPTIONAL | Authentication scheme description. See [Section 3.3](#33-auth-object). |
| `endpoints` | array | REQUIRED | Array of endpoint definition objects. See [Section 4](#4-endpoint-object-specification). |
| `schemas` | object | OPTIONAL | Map of reusable schema definitions keyed by name. See [Section 6](#6-schema-specification). |
| `errors` | object | OPTIONAL | Map of reusable error definitions keyed by code. See [Section 7](#7-error-specification). |
| `agent_rules` | array | OPTIONAL | Global, non-endpoint-specific behavioral guidance for agents, expressed as plain-English instruction strings. See [Section 3.6](#36-global-agent-rules-embedded-plain-language). |

### 3.2 Info Object

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | REQUIRED | The name of the API. |
| `description` | string | REQUIRED | A concise description of what the API does. |
| `base_url` | string | REQUIRED | The base URL for all API endpoints (e.g., `"https://api.example.com/v1"`). |
| `version` | string | OPTIONAL | The version of the API itself (distinct from the AIIF spec version). |

### 3.3 Auth Object

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | string | REQUIRED | Authentication type. One of: `"none"`, `"api_key"`, `"bearer"`, `"basic"`, `"oauth2"`. |
| `description` | string | REQUIRED | Human-readable description of how to authenticate. |
| `header` | string | OPTIONAL | The header name used to pass credentials (e.g., `"Authorization"`, `"X-API-Key"`). |
| `scheme` | string | OPTIONAL | For `bearer` type, the scheme prefix (e.g., `"Bearer"`). |
| `instructions` | array | OPTIONAL | Plain-English authentication instructions for agents. |
| `acquire` | object | OPTIONAL | Structured description of how to obtain an access token or credential. See Section 3.3.1. |
| `apply` | object | OPTIONAL | Structured description of how credentials are attached to API calls. See Section 3.3.1. |
| `refresh` | object | OPTIONAL | Structured description of token refresh or re-authentication behavior. See Section 3.3.1. |

For `type` values that require per-session credentials (for example `bearer` or `oauth2`), implementations SHOULD include `instructions`, `acquire`, and `apply`.

### 3.3.1 Auth Flow Sub-Objects

**`acquire` object fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `endpoint_path` | string | REQUIRED | Path of the endpoint used to acquire credentials (e.g., `"/auth/token"`). |
| `method` | string | REQUIRED | HTTP method used for credential acquisition (typically `"POST"`). |
| `request` | object | OPTIONAL | Request schema or field guidance required to acquire credentials. |
| `response_token_field` | string | OPTIONAL | Response field containing the access token (e.g., `"access_token"`). |
| `response_expires_in_field` | string | OPTIONAL | Response field containing token TTL in seconds (e.g., `"expires_in"`). |
| `response_refresh_token_field` | string | OPTIONAL | Response field containing refresh token (e.g., `"refresh_token"`). |

**`apply` object fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `location` | string | REQUIRED | Where to send credential material. One of: `"header"`, `"query"`, `"cookie"`. |
| `name` | string | REQUIRED | Header/query/cookie key name (e.g., `"Authorization"`, `"api_key"`). |
| `prefix` | string | OPTIONAL | Prefix before credential value when applicable (e.g., `"Bearer"`). |

**`refresh` object fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `strategy` | string | REQUIRED | One of: `"reauthenticate"`, `"refresh_token"`. |
| `endpoint_path` | string | OPTIONAL | Path for refresh requests when strategy is `"refresh_token"`. |
| `method` | string | OPTIONAL | HTTP method for refresh endpoint (typically `"POST"`). |
| `before_expiry_seconds` | number | OPTIONAL | How long before expiry the client SHOULD refresh credentials. |

### 3.4 Top-Level Structure Example

```json
{
  "aiif_version": "1.0",
  "info": {
    "name": "Example API",
    "description": "A sample API demonstrating AIIF structure.",
    "base_url": "https://api.example.com/v1",
    "version": "2.3.1"
  },
  "auth": {
    "type": "bearer",
    "description": "Include a valid JWT in the Authorization header.",
    "header": "Authorization",
    "scheme": "Bearer",
    "instructions": [
      "Acquire an access token from /auth/token before calling protected endpoints.",
      "Send the token in the Authorization header as Bearer <token>.",
      "Refresh credentials before expiry or when unauthorized is returned."
    ],
    "acquire": {
      "endpoint_path": "/auth/token",
      "method": "POST",
      "response_token_field": "access_token",
      "response_expires_in_field": "expires_in",
      "response_refresh_token_field": "refresh_token"
    },
    "apply": {
      "location": "header",
      "name": "Authorization",
      "prefix": "Bearer"
    },
    "refresh": {
      "strategy": "refresh_token",
      "endpoint_path": "/auth/refresh",
      "method": "POST",
      "before_expiry_seconds": 60
    }
  },
  "endpoints": [],
  "schemas": {},
  "errors": {},
  "agent_rules": [
    "Do not call endpoints that are not explicitly listed in endpoints.",
    "If a 429 response is returned and Retry-After is missing, wait at least 1 second before retrying.",
    "Do not retry 422 responses until request inputs are corrected."
  ]
}
```

### 3.5 Deterministic Conformance Profile

To ensure predictable machine parsing across implementations:

1. Field names and casing defined by this specification MUST be used exactly as written.
2. The top-level `endpoints` array MUST NOT contain duplicate `name` values.
3. The top-level `endpoints` array MUST NOT contain duplicate (`method`, `path`) pairs.
4. Within an endpoint, `params` entries MUST be unique by (`name`, `location`).
5. Implementations SHOULD return endpoints in a stable order across `/ai-docs` and `/ai-docs/summary` responses.
6. Parsers and agents MUST ignore unknown fields, consistent with [Section 11.4](#114-handling-unknown-fields).

### 3.6 Global Agent Rules (Embedded, Plain-Language)

Some behavioral instructions are global and not tied to a specific endpoint (for example: fallback retry delay for `429` responses when `Retry-After` is absent, or explicit prohibition against inferring undocumented endpoints).

To reduce ambiguity and avoid secondary references, implementations SHOULD publish these rules inline in API responses via `agent_rules`.

Implementations SHOULD keep `agent_rules` consistent across `GET /ai-docs`, `GET /ai-docs/summary`, and `GET /ai-docs/{endpoint}` responses.

Global rules in `agent_rules` MUST NOT weaken or contradict normative requirements in [Section 8](#8-behavioral-rules-for-ai-agents).

**Recommended minimal `agent_rules` shape:**

```json
[
  "Do not infer or guess undocumented endpoints.",
  "If you receive HTTP 429 and Retry-After is not provided, wait at least 1 second before retrying.",
  "Require explicit user confirmation before destructive operations such as DELETE or PUT."
]
```

---

## 4. Endpoint Object Specification

### 4.1 Endpoint Fields

Each element of the `endpoints` array MUST be an object with the following fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | REQUIRED | A unique, machine-readable identifier for the endpoint (e.g., `"get_user"`). MUST be unique within the document. MUST use snake_case. |
| `method` | string | REQUIRED | HTTP method. One of: `"GET"`, `"POST"`, `"PUT"`, `"PATCH"`, `"DELETE"`. MUST be uppercase. |
| `path` | string | REQUIRED | The URL path relative to `base_url`. Path parameters MUST be enclosed in curly braces (e.g., `"/users/{user_id}"`). The (`method`, `path`) pair MUST be unique within the document. |
| `description` | string | REQUIRED | A concise, one-to-two sentence description of what the endpoint does. |
| `auth_required` | boolean | OPTIONAL | Whether this endpoint requires authentication credentials. If omitted and top-level `auth.type` is not `"none"`, agents SHOULD assume `true`. |
| `params` | array | OPTIONAL | Array of parameter objects. See [Section 5](#5-parameter-specification). |
| `request` | object | OPTIONAL | The request body schema. MUST be omitted for `GET` and `DELETE` methods unless semantically necessary. See [Section 6](#6-schema-specification). |
| `request_content_type` | string | OPTIONAL | Content type for request body serialization (e.g., `"application/json"`). If `request` is present and this field is omitted, agents SHOULD default to `"application/json"`. |
| `response_content_type` | string | OPTIONAL | Content type for successful response parsing (e.g., `"application/json"`). If omitted, agents SHOULD default to `"application/json"`. |
| `response` | object | REQUIRED | The success response schema. See [Section 6](#6-schema-specification). |
| `errors` | array | OPTIONAL | Array of error code strings referencing entries in the top-level `errors` map, or inline error objects. |
| `examples` | array | OPTIONAL | Array of example objects. See [Section 4.3](#43-example-object). |

### 4.2 Normative Endpoint Example

```json
{
  "name": "get_user",
  "method": "GET",
  "path": "/users/{user_id}",
  "description": "Retrieve a single user by their unique identifier.",
  "auth_required": true,
  "response_content_type": "application/json",
  "params": [
    {
      "name": "user_id",
      "location": "path",
      "type": "string",
      "required": true,
      "description": "The unique identifier of the user."
    }
  ],
  "response": {
    "$ref": "#/schemas/User"
  },
  "errors": ["not_found", "unauthorized"],
  "examples": [
    {
      "title": "Fetch user by ID",
      "request": {
        "params": { "user_id": "usr_abc123" }
      },
      "response": {
        "id": "usr_abc123",
        "name": "Alice Smith",
        "email": "alice@example.com",
        "created_at": "2025-01-15T10:30:00Z"
      }
    }
  ]
}
```

### 4.3 Example Object

| Field | Type | Required | Description |
|---|---|---|---|
| `title` | string | REQUIRED | A short label for the example. |
| `request` | object | OPTIONAL | Example request values. MAY include `params`, `headers`, and `body` sub-keys. |
| `response` | object | REQUIRED | The expected successful response value. |

---

## 5. Parameter Specification

### 5.1 Parameter Object Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | REQUIRED | The parameter name as it appears in the URL or request body. |
| `location` | string | REQUIRED | Location of the parameter. MUST be one of: `"path"`, `"query"`, `"body"`. |
| `type` | string | REQUIRED | The data type. MUST be one of the AIIF primitive types (see [Section 6.1](#61-primitive-types)). |
| `required` | boolean | REQUIRED | Whether the parameter is required. Path parameters MUST always have `required: true`. |
| `description` | string | REQUIRED | A concise description of the parameter's purpose and any constraints. |
| `enum` | array | OPTIONAL | If present, the parameter value MUST be one of the listed values. |
| `minimum` | number | OPTIONAL | Minimum numeric value allowed (for `number` type). |
| `maximum` | number | OPTIONAL | Maximum numeric value allowed (for `number` type). |
| `min_length` | number | OPTIONAL | Minimum string length allowed (for `string` type). |
| `max_length` | number | OPTIONAL | Maximum string length allowed (for `string` type). |
| `pattern` | string | OPTIONAL | Regex pattern the value MUST match (for `string` type). |
| `format` | string | OPTIONAL | Semantic string format hint (e.g., `"email"`, `"date-time"`, `"uri"`). |
| `default` | any | OPTIONAL | The default value used if the parameter is omitted (only valid when `required` is `false`). |

Implementations MAY accept legacy `in` as an alias for `location` for backward compatibility, but producers SHOULD emit `location`.

### 5.2 Parameter Examples

**Path parameter:**
```json
{
  "name": "user_id",
  "location": "path",
  "type": "string",
  "required": true,
  "pattern": "^usr_[a-zA-Z0-9]+$",
  "description": "The unique identifier of the user."
}
```

**Query parameter with enum:**
```json
{
  "name": "status",
  "location": "query",
  "type": "string",
  "required": false,
  "description": "Filter results by order status.",
  "enum": ["pending", "active", "completed", "cancelled"],
  "default": "active"
}
```

**Query parameter with numeric type:**
```json
{
  "name": "limit",
  "location": "query",
  "type": "number",
  "required": false,
  "minimum": 1,
  "maximum": 100,
  "description": "Maximum number of results to return. Must be between 1 and 100.",
  "default": 20
}
```

---

## 6. Schema Specification

### 6.1 Primitive Types

AIIF supports the following primitive types:

| Type | Description |
|---|---|
| `string` | A UTF-8 text value. |
| `number` | A numeric value (integer or floating-point). |
| `boolean` | A true/false value. |
| `object` | A JSON object with named properties. |
| `array` | An ordered list of values. |
| `null` | An explicit null value. |

### 6.2 Schema Object Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | string | REQUIRED (unless `$ref` is used) | The primitive type of this schema. |
| `description` | string | OPTIONAL | A concise description of this schema or field. |
| `properties` | object | OPTIONAL | For `object` type: a map of property names to schema objects. |
| `required` | array | OPTIONAL | For `object` type: an array of property names that are required. |
| `items` | object | OPTIONAL | For `array` type: the schema of each element in the array. |
| `enum` | array | OPTIONAL | An array of allowed values. The schema value MUST be one of these. |
| `$ref` | string | OPTIONAL | A reference to a named schema in the top-level `schemas` map. Format: `"#/schemas/{SchemaName}"`. When `$ref` is present, all other fields MUST be omitted. |

### 6.3 Simple Schema Example

```json
{
  "type": "object",
  "description": "A user account.",
  "properties": {
    "id": {
      "type": "string",
      "description": "Unique user identifier."
    },
    "name": {
      "type": "string",
      "description": "Full display name."
    },
    "email": {
      "type": "string",
      "description": "Email address."
    },
    "active": {
      "type": "boolean",
      "description": "Whether the account is active."
    },
    "created_at": {
      "type": "string",
      "description": "ISO 8601 timestamp of account creation."
    }
  },
  "required": ["id", "name", "email", "active"]
}
```

### 6.4 Array Schema Example

```json
{
  "type": "array",
  "description": "A paginated list of users.",
  "items": {
    "$ref": "#/schemas/User"
  }
}
```

### 6.5 Reference Example

```json
{
  "$ref": "#/schemas/User"
}
```

### 6.6 Complex Nested Schema Example

```json
{
  "type": "object",
  "description": "An order placed by a customer.",
  "properties": {
    "order_id": {
      "type": "string",
      "description": "Unique order identifier."
    },
    "status": {
      "type": "string",
      "description": "Current order status.",
      "enum": ["pending", "confirmed", "shipped", "delivered", "cancelled"]
    },
    "items": {
      "type": "array",
      "description": "Line items in the order.",
      "items": {
        "type": "object",
        "properties": {
          "sku": { "type": "string", "description": "Product SKU." },
          "quantity": { "type": "number", "description": "Number of units." },
          "unit_price": { "type": "number", "description": "Price per unit in USD." }
        },
        "required": ["sku", "quantity", "unit_price"]
      }
    },
    "total": {
      "type": "number",
      "description": "Total order amount in USD."
    }
  },
  "required": ["order_id", "status", "items", "total"]
}
```

### 6.7 Named Schemas (Top-Level `schemas` Map)

Named schemas are defined in the top-level `schemas` object and referenced with `$ref`. This avoids duplication when the same structure is returned by multiple endpoints.

```json
{
  "schemas": {
    "User": {
      "type": "object",
      "properties": {
        "id": { "type": "string", "description": "Unique user identifier." },
        "name": { "type": "string", "description": "Full display name." },
        "email": { "type": "string", "description": "Email address." }
      },
      "required": ["id", "name", "email"]
    },
    "UserList": {
      "type": "array",
      "items": { "$ref": "#/schemas/User" }
    }
  }
}
```

---

## 7. Error Specification

### 7.1 Error Object Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `code` | string | REQUIRED | A unique, machine-readable error code in snake_case (e.g., `"not_found"`). MUST be unique within the document. |
| `http_status` | number | REQUIRED | The HTTP status code associated with this error (e.g., `404`). |
| `message` | string | REQUIRED | A short, human-readable error message (e.g., `"Resource not found"`). |
| `description` | string | REQUIRED | A more detailed description of when this error occurs and how an agent should respond. |

### 7.2 Common Error Definitions Example

```json
{
  "errors": {
    "unauthorized": {
      "code": "unauthorized",
      "http_status": 401,
      "message": "Unauthorized",
      "description": "The request did not include valid authentication credentials. The agent MUST check that a valid bearer token is present before retrying."
    },
    "forbidden": {
      "code": "forbidden",
      "http_status": 403,
      "message": "Forbidden",
      "description": "The authenticated identity does not have permission to perform this operation. The agent MUST NOT retry this request without obtaining elevated credentials."
    },
    "not_found": {
      "code": "not_found",
      "http_status": 404,
      "message": "Not Found",
      "description": "The requested resource does not exist. The agent SHOULD verify the identifier before retrying."
    },
    "validation_error": {
      "code": "validation_error",
      "http_status": 422,
      "message": "Validation Error",
      "description": "One or more request parameters failed validation. The response body will include a list of field-level errors. The agent MUST correct the identified fields before retrying."
    },
    "rate_limited": {
      "code": "rate_limited",
      "http_status": 429,
      "message": "Too Many Requests",
      "description": "The client has exceeded the request rate limit. The agent MUST wait for the duration specified in the Retry-After response header before issuing another request."
    },
    "internal_error": {
      "code": "internal_error",
      "http_status": 500,
      "message": "Internal Server Error",
      "description": "An unexpected server-side error occurred. The agent MAY retry the request after a short delay using exponential backoff, but MUST limit retries to three attempts."
    }
  }
}
```

### 7.3 Referencing Errors in Endpoints

An endpoint's `errors` field is an array of error code strings that reference entries in the top-level `errors` map:

```json
{
  "name": "delete_user",
  "method": "DELETE",
  "path": "/users/{user_id}",
  "description": "Permanently delete a user account.",
  "params": [
    {
      "name": "user_id",
      "location": "path",
      "type": "string",
      "required": true,
      "description": "The unique identifier of the user to delete."
    }
  ],
  "response": {
    "type": "object",
    "properties": {
      "deleted": { "type": "boolean", "description": "Confirms the deletion." }
    },
    "required": ["deleted"]
  },
  "errors": ["unauthorized", "forbidden", "not_found"]
}
```

---

## 8. Behavioral Rules for AI Agents

This section contains normative rules that govern how AI agents MUST interact with APIs described by AIIF documents. The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this section are to be interpreted as described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

### 8.1 Endpoint Discovery

1. An agent MUST NOT call any endpoint that is not explicitly defined in the `endpoints` array of the AIIF document, except AIIF documentation endpoints defined in Section 9 and authentication endpoints explicitly defined in the `auth` object.
2. An agent MUST NOT infer or guess the existence of endpoints based on naming patterns, conventions, or prior knowledge.
3. An agent MUST use the `GET /ai-docs/summary` endpoint (see [Section 9](#9-required-aiif-implementation-endpoints)) to discover available endpoints before attempting to call any operation.

### 8.2 Parameter Compliance

4. An agent MUST supply all parameters marked `required: true` for every request.
5. An agent MUST NOT supply parameters that are not defined in the endpoint's `params` array.
6. An agent MUST use parameter values that conform to the declared `type` and any declared constraints (`enum`, `minimum`, `maximum`, `min_length`, `max_length`, `pattern`, `format`).
7. An agent MUST place each parameter in the location declared by the `location` field (`path`, `query`, or `body`).
8. An agent SHOULD use the `default` value of an optional parameter when no other value is contextually appropriate.

### 8.3 Request Body Compliance

9. An agent MUST supply a request body only when the endpoint defines a `request` schema.
10. An agent MUST construct the request body to conform to the declared `request` schema, including all fields listed in the schema's `required` array.
11. An agent MUST NOT include fields in the request body that are not defined in the `request` schema.

### 8.4 Response Handling

12. An agent MUST parse API responses according to the endpoint's declared `response` schema and `response_content_type` when provided.
13. An agent SHOULD treat any fields present in the response but absent from the schema as informational and MUST NOT rely on them for decision-making.
14. An agent MUST validate that a successful response matches the expected shape before extracting values from it.

### 8.5 Error Handling

15. An agent MUST handle all error codes listed in an endpoint's `errors` array.
16. An agent MUST NOT retry a request that returned a `403 Forbidden` error without first obtaining elevated credentials.
17. An agent MUST NOT retry a request that returned a `422 Validation Error` without first correcting the identified input fields.
18. An agent MUST respect `Retry-After` headers when encountering `429 Too Many Requests` responses.
19. An agent SHOULD implement exponential backoff when retrying after `500 Internal Server Error` responses, with a maximum of three retry attempts.

### 8.6 Authentication

20. An agent MUST include authentication credentials as specified in the `auth` object for every request to a protected endpoint.
21. An agent MUST NOT log, store, or transmit authentication credentials in any output visible to end users.
22. An agent MUST treat an `unauthorized` error as a signal to refresh or re-obtain credentials before retrying.
23. If `auth.type` is not `"none"`, an agent SHOULD fetch `GET /ai-docs/auth` before the first protected operation call.
24. If `auth.acquire` is present, an agent MUST follow it to obtain credentials before protected calls.
25. If `auth.refresh.before_expiry_seconds` is provided, an agent SHOULD refresh credentials before token expiry by at least the specified lead time.
26. If endpoint `auth_required` is present, an agent MUST honor it when deciding whether to attach credentials.
27. If endpoint `auth_required` is absent and top-level `auth.type` is not `"none"`, an agent SHOULD assume the endpoint is protected.

### 8.7 Scope Limitation

28. An agent MUST limit its API interactions to the operations required to fulfill the task it has been given.
29. An agent MUST NOT call destructive operations (e.g., `DELETE`, `PUT`) unless explicitly instructed to do so.
30. An agent SHOULD prefer read-only (`GET`) operations when exploring an API's state prior to taking action.

### 8.8 Global Rule Consumption

31. An agent SHOULD consume global behavior guidance from `agent_rules` (if present) before executing endpoint calls.
32. An agent MUST treat each instruction in `agent_rules` as an API-specific constraint that complements endpoint-level contract details.
33. If any `agent_rules` instruction conflicts with normative requirements in this specification, the normative requirements in this specification MUST take precedence.
34. If a `429` response is returned without a `Retry-After` header, an agent SHOULD follow applicable plain-English guidance in `agent_rules`; otherwise, the agent SHOULD wait at least one second before retrying.

---

## 9. Required AIIF Implementation Endpoints

Any API that claims AIIF compliance MUST expose the following three core endpoints in addition to its functional API. For APIs with `auth.type` other than `"none"`, `GET /ai-docs/auth` is also REQUIRED. These endpoints are defined relative to the API's `base_url`.

### 9.1 `GET /ai-docs`

**Purpose:** Returns the full AIIF document for the API.

**Requirements:**
- The response MUST be a valid AIIF document conforming to [Section 3](#3-aiif-document-structure).
- The response MUST be returned with `Content-Type: application/json`.
- The response MUST include all defined endpoints, schemas, and errors.
- The response SHOULD include `agent_rules` to publish non-endpoint-specific behavioral guidance.
- The response MUST NOT require authentication.

**Response Schema:**
```json
{
  "type": "object",
  "description": "A complete AIIF document.",
  "properties": {
    "aiif_version": { "type": "string" },
    "info": { "$ref": "#/schemas/Info" },
    "auth": { "$ref": "#/schemas/Auth" },
    "endpoints": { "type": "array", "items": { "$ref": "#/schemas/Endpoint" } },
    "schemas": { "type": "object" },
    "errors": { "type": "object" },
    "agent_rules": { "type": "array", "items": { "type": "string" } }
  },
  "required": ["aiif_version", "info", "endpoints"]
}
```

### 9.2 `GET /ai-docs/{endpoint}`

**Purpose:** Returns the AIIF definition for a single endpoint by name.

**Path Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `endpoint` | string | The `name` of the endpoint to retrieve (e.g., `get_user`). |

**Requirements:**
- The response MUST include the full endpoint definition object as defined in [Section 4](#4-endpoint-object-specification).
- The response MUST include all schemas referenced (directly or transitively) by the endpoint's `request`, `response`, and inline parameter schemas, resolved into an inline `schemas` map.
- The response MUST include all error definitions referenced by the endpoint's `errors` array, resolved into an inline `errors` map.
- The response SHOULD include `agent_rules` to preserve API-wide behavior guidance when agents load a single endpoint contract.
- The `endpoint` path parameter MUST be matched against endpoint `name` exactly (case-sensitive).
- If the requested endpoint name does not exist, the implementation MUST return an HTTP `404` response.
- The response MUST be returned with `Content-Type: application/json`.
- The response MUST NOT require authentication.

**Purpose for Agents:** Allows an agent to retrieve only the contract for a specific operation, reducing token consumption when the full AIIF document is too large to include in context.

**Response Schema:**
```json
{
  "type": "object",
  "properties": {
    "endpoint": {
      "type": "object",
      "description": "The full endpoint definition."
    },
    "schemas": {
      "type": "object",
      "description": "All schemas referenced by this endpoint."
    },
    "errors": {
      "type": "object",
      "description": "All error definitions referenced by this endpoint."
    },
    "agent_rules": {
      "type": "array",
      "description": "Optional global behavior guidance for agents.",
      "items": { "type": "string" }
    }
  },
  "required": ["endpoint"]
}
```

### 9.3 `GET /ai-docs/summary`

**Purpose:** Returns a lightweight summary of the API for fast agent discovery.

**Requirements:**
- The response MUST include one entry per defined endpoint.
- Each entry MUST include: `name`, `method`, `path`, `description`, and `auth_required`.
- Endpoint entries SHOULD be returned in the same stable order as the `endpoints` array in `GET /ai-docs`.
- The response SHOULD include `agent_rules` so agents can load global behavior guidance during initial discovery.
- For APIs with protected endpoints, the response SHOULD include `auth_docs_path` (recommended: `"/ai-docs/auth"`).
- The response MUST be returned with `Content-Type: application/json`.
- The response MUST NOT require authentication.

**Purpose for Agents:** Allows an agent to efficiently survey all available operations and determine which endpoint(s) are relevant to its task before fetching full endpoint details.

**Response Schema:**
```json
{
  "type": "object",
  "properties": {
    "api": { "type": "string", "description": "The API name from info.name." },
    "base_url": { "type": "string", "description": "The API base URL." },
    "auth_docs_path": { "type": "string", "description": "Optional path to authentication documentation endpoint." },
    "agent_rules": { "type": "array", "description": "Optional global behavior guidance for agents.", "items": { "type": "string" } },
    "endpoints": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "method": { "type": "string" },
          "path": { "type": "string" },
          "description": { "type": "string" },
          "auth_required": { "type": "boolean" }
        },
        "required": ["name", "method", "path", "description", "auth_required"]
      }
    }
  },
  "required": ["api", "base_url", "endpoints"]
}
```

**Example Response:**
```json
{
  "api": "User Management API",
  "base_url": "https://api.example.com/v1",
  "auth_docs_path": "/ai-docs/auth",
  "agent_rules": [
    "Do not infer endpoints not listed in this document.",
    "If a 429 response has no Retry-After header, wait at least 1 second before retrying."
  ],
  "endpoints": [
    {
      "name": "list_users",
      "method": "GET",
      "path": "/users",
      "description": "Returns a paginated list of all users.",
      "auth_required": true
    },
    {
      "name": "get_user",
      "method": "GET",
      "path": "/users/{user_id}",
      "description": "Retrieve a single user by their unique identifier.",
      "auth_required": true
    },
    {
      "name": "create_user",
      "method": "POST",
      "path": "/users",
      "description": "Create a new user account.",
      "auth_required": true
    }
  ]
}
```

### 9.4 `GET /ai-docs/auth` (Required for Protected APIs)

**Purpose:** Returns API authentication instructions and flow metadata for agent clients.

**Requirements:**
- If `auth.type` is not `"none"`, this endpoint MUST be exposed.
- The response MUST be returned with `Content-Type: application/json`.
- The response MUST include `type`, `instructions`, and when applicable `acquire`, `apply`, and `refresh`.
- The response MUST NOT require authentication.

**Response Schema:**
```json
{
  "type": "object",
  "properties": {
    "type": { "type": "string" },
    "description": { "type": "string" },
    "instructions": { "type": "array", "items": { "type": "string" } },
    "acquire": { "type": "object" },
    "apply": { "type": "object" },
    "refresh": { "type": "object" }
  },
  "required": ["type", "description"]
}
```

---

## 10. Examples (Non-Normative)

To keep the normative specification compact and token-efficient, complete examples are maintained in a separate document:

- See **AIIF Examples**: `AIIF-Examples.md`
- See **Minimal Compliant AIIF Example**: `AIIF-Minimal-Compliant.aiif.json`

The examples document is informative and does not override any MUST/SHOULD/MAY requirements in this specification.

---

## 11. Versioning and Compatibility

### 11.1 AIIF Spec Versioning

AIIF spec versions follow the format `MAJOR.MINOR` (e.g., `1.0`, `1.1`, `2.0`). The `aiif_version` field in every AIIF document MUST contain the version of the specification it was authored against.

### 11.2 Minor Version Changes (Backward-Compatible)

A minor version increment (e.g., `1.0` → `1.1`) indicates a backward-compatible change. Examples include:

- Addition of new optional fields to existing objects.
- Addition of new allowed values to existing enumerations.
- Clarification of normative language that does not alter agent behavior.

Agents and implementations conforming to version `1.0` MUST be able to parse and process a document labeled `1.1` without modification, ignoring any unrecognized optional fields.

### 11.3 Major Version Changes (Breaking)

A major version increment (e.g., `1.x` → `2.0`) indicates a breaking change. Examples include:

- Removal or renaming of required fields.
- Changes to the semantics of existing fields.
- Changes to the structure of the AIIF document itself.

Implementations MUST NOT attempt to process an AIIF document whose major version differs from the version they were built against without explicit support for that major version.

### 11.4 Handling Unknown Fields

- Parsers and agents MUST silently ignore fields that are not defined in the version of the AIIF specification they support.
- Parsers and agents MUST NOT raise errors or fail to process an AIIF document solely because it contains additional, unrecognized fields.
- This forward-compatibility rule applies to minor and patch-level additions only; it does not apply across major versions.

### 11.5 Implementation Versioning

An API implementation SHOULD advertise the AIIF version it supports via the `aiif_version` field in its `/ai-docs` response. Agents SHOULD check the `aiif_version` before processing an AIIF document to confirm compatibility.

---

## 12. Conformance Checklist

This checklist is non-normative guidance for fast implementation validation. A conforming implementation still depends on the normative MUST/SHOULD/MAY rules in this specification.

For machine-oriented validation workflows, see: `AIIF-Conformance-Checklist.json`.

### 12.1 API Implementation Checklist

- [ ] `GET /ai-docs`, `GET /ai-docs/{endpoint}`, and `GET /ai-docs/summary` are exposed and return `application/json`.
- [ ] For protected APIs (`auth.type` is not `none`), `GET /ai-docs/auth` is exposed and returns `application/json`.
- [ ] `GET /ai-docs` returns a valid AIIF document with required top-level fields (`aiif_version`, `info`, `endpoints`).
- [ ] Endpoint `name` values are unique across `endpoints`.
- [ ] Endpoint (`method`, `path`) pairs are unique across `endpoints`.
- [ ] Each endpoint's `params` entries are unique by (`name`, `location`).
- [ ] `/ai-docs/{endpoint}` returns referenced `schemas` and `errors` for that endpoint.
- [ ] `/ai-docs/{endpoint}` matches endpoint names exactly (case-sensitive).
- [ ] `/ai-docs/summary` includes `name`, `method`, `path`, `description`, `auth_required` for each endpoint.
- [ ] For protected APIs, `/ai-docs/summary` includes `auth_docs_path`.
- [ ] `agent_rules` is embedded as a plain-English string array and kept consistent across docs responses when present.
- [ ] For bearer/oauth2 auth, the `auth` object includes clear instructions plus structured acquire/apply metadata.
- [ ] Endpoints use `auth_required` where protected/public behavior differs from top-level defaults.
- [ ] Parameter constraints (`minimum`, `maximum`, `min_length`, `max_length`, `pattern`, `format`) are published where needed to avoid inference.
- [ ] Endpoints use `response_content_type` when success responses are not JSON; otherwise JSON default behavior is clear.
- [ ] Unknown optional fields do not break parser compatibility.

### 12.2 Agent/Client Checklist

- [ ] The agent discovers available operations from `/ai-docs/summary` before calling endpoints.
- [ ] The agent never calls undocumented endpoints or undocumented parameters.
- [ ] The agent enforces required params and schema-required fields before requests.
- [ ] The agent follows parameter locations exactly (`path`, `query`, `body`).
- [ ] The agent validates successful response shape against the declared `response` schema.
- [ ] The agent handles listed endpoint errors explicitly (`errors` array).
- [ ] The agent respects `Retry-After` for `429` and applies fallback wait when missing.
- [ ] The agent does not retry `422` without correcting input.
- [ ] The agent does not retry `403` without changed authorization.
- [ ] For protected APIs, the agent loads `/ai-docs/auth` and follows documented credential acquire/apply/refresh flow.
- [ ] The agent uses endpoint `auth_required` (or default auth behavior when omitted) to decide whether credentials must be attached.
- [ ] The agent honors `response_content_type` (or defaults to JSON when omitted) when parsing successful responses.
- [ ] The agent treats `agent_rules` instructions as API-specific constraints unless they conflict with normative spec rules.

### 12.3 Release Readiness (Recommended)

- [ ] At least one end-to-end agent flow test passes (discover → load endpoint contract → execute call).
- [ ] At least one negative-path test passes for each major error class (`401/403/404/422/429/500`).
- [ ] Example payloads in `AIIF-Examples.md` remain aligned with current normative field definitions.

---

## 13. Security Considerations

AIIF documentation endpoints are valuable for agent interoperability but MUST be implemented with standard API security controls.

### 13.1 Data Exposure and Documentation Hygiene

- Implementations MUST NOT include secrets, private keys, credentials, internal hostnames, or non-public infrastructure details in AIIF responses.
- Implementations SHOULD expose only contract-level information needed for correct API usage.
- Implementations SHOULD treat AIIF payloads as externally visible documentation and review them through security and privacy controls.

### 13.2 Access Control and Authorization

- Exposing AIIF documentation endpoints (`/ai-docs*`) MUST NOT bypass normal authorization checks on functional API endpoints.
- APIs SHOULD enforce least-privilege access scopes and role checks regardless of what agent documentation is available.
- For sensitive APIs, implementations SHOULD consider access controls or scoped visibility for AIIF docs while keeping enough metadata for safe agent operation.

### 13.3 Abuse, Enumeration, and Rate Limiting

- Implementations SHOULD apply rate limits and abuse detection to AIIF endpoints similarly to functional endpoints.
- Implementations SHOULD monitor for endpoint enumeration, credential stuffing, and automation abuse patterns.
- Implementations SHOULD return consistent error envelopes and avoid leaking unnecessary operational detail in error messages.

### 13.4 Authentication Flow Hardening

- For protected APIs, implementations SHOULD provide explicit token TTL and refresh behavior in `auth.refresh`.
- Access tokens SHOULD be short-lived; refresh tokens (if used) SHOULD be rotatable and revocable.
- Implementations SHOULD protect auth endpoints against replay and brute-force abuse using standard controls (rate limiting, lockouts, and anomaly detection).

### 13.5 Agent Safety Expectations

- Agents MUST follow documented auth and endpoint constraints and MUST NOT infer undocumented privileged operations.
- Agents MUST avoid logging credentials or sensitive token material.
- Agents SHOULD prefer read-only operations for discovery and require explicit confirmation for destructive operations.

---

## 14. License

The AI Interface Format (AIIF) Specification is licensed under the **Apache License, Version 2.0**.

You may obtain a copy of the license at:

> https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, the specification is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

---

*AIIF Spec v1.0 — Copyright 2026 The AIIF Contributors — Apache 2.0*
