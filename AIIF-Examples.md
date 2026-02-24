# AI Interface Format (AIIF) Examples — Version 1.0

**Status:** Informative (Non-Normative)  
**Version:** 1.0  
**Date:** 2026-02-23

---

This document contains non-normative examples for AIIF v1.0.

- Normative requirements are defined only in `AIIF-Spec.md`.
- If an example conflicts with the normative specification, the specification takes precedence.

---

## 1. Full Example AIIF Document

The following is a complete, realistic AIIF document for a minimal User Management API with three endpoints.

```json
{
  "aiif_version": "1.0",
  "info": {
    "name": "User Management API",
    "description": "Manages user accounts including creation, retrieval, and deletion.",
    "base_url": "https://api.example.com/v1",
    "version": "1.0.0"
  },
  "auth": {
    "type": "bearer",
    "description": "All requests must include a valid JWT bearer token in the Authorization header.",
    "header": "Authorization",
    "scheme": "Bearer"
  },
  "agent_rules": [
    "Do not call endpoints that are not explicitly listed in endpoints.",
    "If a 429 response is returned and Retry-After is missing, wait at least 1 second before retrying.",
    "Do not retry 422 responses until request inputs are corrected.",
    "Require explicit user confirmation before destructive operations such as DELETE or PUT."
  ],
  "endpoints": [
    {
      "name": "list_users",
      "method": "GET",
      "path": "/users",
      "description": "Returns a paginated list of all users in the system.",
      "auth_required": true,
      "response_content_type": "application/json",
      "params": [
        {
          "name": "limit",
          "location": "query",
          "type": "number",
          "required": false,
          "description": "Maximum number of users to return (1–100).",
          "minimum": 1,
          "maximum": 100,
          "default": 20
        },
        {
          "name": "offset",
          "location": "query",
          "type": "number",
          "required": false,
          "description": "Number of users to skip for pagination.",
          "minimum": 0,
          "default": 0
        },
        {
          "name": "status",
          "location": "query",
          "type": "string",
          "required": false,
          "description": "Filter by account status.",
          "enum": ["active", "inactive", "suspended"],
          "default": "active"
        }
      ],
      "response": {
        "type": "object",
        "properties": {
          "total": {
            "type": "number",
            "description": "Total number of users matching the filter."
          },
          "users": {
            "type": "array",
            "description": "The list of user objects.",
            "items": { "$ref": "#/schemas/User" }
          }
        },
        "required": ["total", "users"]
      },
      "errors": ["unauthorized", "validation_error"],
      "examples": [
        {
          "title": "List active users, first page",
          "request": {
            "params": { "limit": 2, "offset": 0, "status": "active" }
          },
          "response": {
            "total": 42,
            "users": [
              {
                "id": "usr_001",
                "name": "Alice Smith",
                "email": "alice@example.com",
                "status": "active",
                "created_at": "2025-01-10T09:00:00Z"
              },
              {
                "id": "usr_002",
                "name": "Bob Jones",
                "email": "bob@example.com",
                "status": "active",
                "created_at": "2025-01-11T14:30:00Z"
              }
            ]
          }
        }
      ]
    },
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
          "description": "The unique identifier of the user.",
          "pattern": "^usr_[0-9]{3,}$"
        }
      ],
      "response": {
        "$ref": "#/schemas/User"
      },
      "errors": ["unauthorized", "not_found"],
      "examples": [
        {
          "title": "Fetch user usr_001",
          "request": {
            "params": { "user_id": "usr_001" }
          },
          "response": {
            "id": "usr_001",
            "name": "Alice Smith",
            "email": "alice@example.com",
            "status": "active",
            "created_at": "2025-01-10T09:00:00Z"
          }
        }
      ]
    },
    {
      "name": "create_user",
      "method": "POST",
      "path": "/users",
      "description": "Create a new user account with the provided details.",
      "auth_required": true,
      "request_content_type": "application/json",
      "response_content_type": "application/json",
      "request": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string",
            "description": "The full display name for the new user."
          },
          "email": {
            "type": "string",
            "description": "A valid, unique email address for the new user."
          },
          "role": {
            "type": "string",
            "description": "The role to assign to the new user.",
            "enum": ["admin", "editor", "viewer"],
            "default": "viewer"
          }
        },
        "required": ["name", "email"]
      },
      "response": {
        "$ref": "#/schemas/User"
      },
      "errors": ["unauthorized", "forbidden", "validation_error"],
      "examples": [
        {
          "title": "Create a new viewer",
          "request": {
            "body": {
              "name": "Carol White",
              "email": "carol@example.com",
              "role": "viewer"
            }
          },
          "response": {
            "id": "usr_003",
            "name": "Carol White",
            "email": "carol@example.com",
            "status": "active",
            "created_at": "2026-02-23T01:00:00Z"
          }
        }
      ]
    }
  ],
  "schemas": {
    "User": {
      "type": "object",
      "description": "Represents a user account.",
      "properties": {
        "id": {
          "type": "string",
          "description": "Unique user identifier assigned by the system."
        },
        "name": {
          "type": "string",
          "description": "Full display name."
        },
        "email": {
          "type": "string",
          "description": "Email address."
        },
        "status": {
          "type": "string",
          "description": "Current account status.",
          "enum": ["active", "inactive", "suspended"]
        },
        "created_at": {
          "type": "string",
          "description": "ISO 8601 timestamp of when the account was created."
        }
      },
      "required": ["id", "name", "email", "status", "created_at"]
    }
  },
  "errors": {
    "unauthorized": {
      "code": "unauthorized",
      "http_status": 401,
      "message": "Unauthorized",
      "description": "The request did not include valid authentication credentials. Ensure a valid bearer token is present in the Authorization header."
    },
    "forbidden": {
      "code": "forbidden",
      "http_status": 403,
      "message": "Forbidden",
      "description": "The authenticated user does not have permission to perform this operation. Do not retry without obtaining elevated permissions."
    },
    "not_found": {
      "code": "not_found",
      "http_status": 404,
      "message": "Not Found",
      "description": "The requested resource does not exist. Verify the identifier and retry."
    },
    "validation_error": {
      "code": "validation_error",
      "http_status": 422,
      "message": "Validation Error",
      "description": "One or more request parameters failed validation. The response body contains a list of field-level errors. Correct the identified fields before retrying."
    }
  }
}
```

## 2. Agent Interaction Flow Example

This section shows a practical sequence an AI agent can follow to safely interact with an API using AIIF.

### 2.0 Step 0 — Discover API and auth docs (`GET /ai-docs/summary`)

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
      "name": "get_user",
      "method": "GET",
      "path": "/users/{user_id}",
      "description": "Retrieve a single user by their unique identifier.",
      "auth_required": true
    }
  ]
}
```

### 2.1 Step 1 — Load auth guidance for protected APIs (`GET /ai-docs/auth`)

```json
{
  "type": "bearer",
  "description": "Protected endpoints require a bearer token.",
  "instructions": [
    "Acquire access token via POST /auth/token.",
    "Send Authorization: Bearer <token> on protected requests.",
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
}
```

### 2.2 Step 2 — Re-check endpoint catalog (`GET /ai-docs/summary`)

```json
{
  "api": "User Management API",
  "base_url": "https://api.example.com/v1",
  "agent_rules": [
    "Do not infer endpoints not listed in this document.",
    "If a 429 response has no Retry-After header, wait at least 1 second before retrying.",
    "Require explicit user confirmation before destructive operations such as DELETE or PUT."
  ],
  "endpoints": [
    {
      "name": "list_users",
      "method": "GET",
      "path": "/users",
      "description": "Returns a paginated list of users.",
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

### 2.3 Step 3 — Load one endpoint contract (`GET /ai-docs/get_user`)

```json
{
  "endpoint": {
    "name": "get_user",
    "method": "GET",
    "path": "/users/{user_id}",
    "description": "Retrieve a single user by their unique identifier.",
    "auth_required": true,
    "params": [
      {
        "name": "user_id",
        "location": "path",
        "type": "string",
        "required": true,
        "description": "The unique identifier of the user.",
        "pattern": "^usr_[0-9]{3,}$"
      }
    ],
    "response": {
      "$ref": "#/schemas/User"
    },
    "errors": ["unauthorized", "not_found"]
  },
  "schemas": {
    "User": {
      "type": "object",
      "properties": {
        "id": { "type": "string" },
        "name": { "type": "string" },
        "email": { "type": "string" },
        "status": { "type": "string" },
        "created_at": { "type": "string" }
      },
      "required": ["id", "name", "email", "status", "created_at"]
    }
  },
  "errors": {
    "unauthorized": {
      "code": "unauthorized",
      "http_status": 401,
      "message": "Unauthorized",
      "description": "Missing or invalid credentials."
    },
    "not_found": {
      "code": "not_found",
      "http_status": 404,
      "message": "Not Found",
      "description": "Requested user does not exist."
    }
  },
  "agent_rules": [
    "Do not infer endpoints not listed in this document.",
    "If a 429 response has no Retry-After header, wait at least 1 second before retrying."
  ]
}
```

### 2.4 Step 4 — Execute call and handle outcomes

Request:

```http
GET /v1/users/usr_001 HTTP/1.1
Host: api.example.com
Authorization: Bearer <token>
Accept: application/json
```

Success response (`200`):

```json
{
  "id": "usr_001",
  "name": "Alice Smith",
  "email": "alice@example.com",
  "status": "active",
  "created_at": "2025-01-10T09:00:00Z"
}
```

Error handling examples:

- If `404 not_found`, do not retry with the same identifier until input changes.
- If `429` with no `Retry-After`, wait at least 1 second before retrying.

### 2.5 Negative Path Handling Examples

These examples show how an agent should behave when requests fail.

#### A) Validation failure (`422 validation_error`)

Request:

```http
POST /v1/users HTTP/1.1
Host: api.example.com
Authorization: Bearer <token>
Content-Type: application/json

{"name":"", "email":"not-an-email"}
```

Response:

```json
{
  "code": "validation_error",
  "message": "Validation Error",
  "details": [
    { "field": "name", "issue": "must not be empty" },
    { "field": "email", "issue": "must be a valid email" }
  ]
}
```

Expected agent behavior:

- Do not retry until invalid fields are corrected.

#### B) Rate limit (`429 rate_limited`)

Response (without `Retry-After`):

```json
{
  "code": "rate_limited",
  "message": "Too Many Requests"
}
```

Expected agent behavior:

- Wait at least 1 second (or longer per `agent_rules`) before retrying.

#### C) Forbidden (`403 forbidden`)

Response:

```json
{
  "code": "forbidden",
  "message": "Forbidden"
}
```

Expected agent behavior:

- Do not retry with the same credentials; retry only after authorization changes.

#### D) Server error (`500 internal_error`)

Response:

```json
{
  "code": "internal_error",
  "message": "Internal Server Error"
}
```

Expected agent behavior:

- Retry with bounded exponential backoff, maximum three attempts.

#### E) Unauthorized (`401 unauthorized`)

Response:

```json
{
  "code": "unauthorized",
  "message": "Unauthorized"
}
```

Expected agent behavior:

- Refresh or re-obtain credentials before retrying.
