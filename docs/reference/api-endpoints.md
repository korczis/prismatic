# API Endpoints

Comprehensive reference for all HTTP API endpoints in the Prismatic application, including authentication, request/response formats, and usage examples.

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Reference](README.md) > API Endpoints

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to reference index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](glossary.md)** - Find terms and concepts

### Related Documentation

- [API Authentication](api-authentication.md) - Authentication and authorization details
- [Database Schema](database-schema.md) - Data models and relationships
- [Security Guidelines](../guides/security-guidelines.md) - API security best practices
- [Performance Optimization](../guides/performance-optimization.md) - API performance considerations
- [System Diagrams](../architecture/system-diagrams.md) - API architecture visualization
<!-- NAV_END -->

## Overview

This document provides a comprehensive reference for all HTTP API endpoints available in the Prismatic application. The API follows RESTful conventions and supports both JSON and HTML responses depending on the Accept header.

## API Standards

### Base URL
- **Production**: `https://api.prismatic.example.com`
- **Staging**: `https://staging-api.prismatic.example.com`
- **Development**: `http://localhost:4000`

### Common Headers
```http
Content-Type: application/json
Accept: application/json
Authorization: Bearer <jwt_token>
X-Requested-With: XMLHttpRequest
```

### Response Format
All API responses follow a consistent format:

#### Success Response
```json
{
  "data": {
    "id": "123",
    "type": "user",
    "attributes": {
      "name": "John Doe",
      "email": "john@example.com"
    }
  },
  "meta": {
    "request_id": "req_123456789",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

#### Error Response
```json
{
  "errors": [
    {
      "id": "validation_error",
      "status": "422",
      "code": "INVALID_EMAIL",
      "title": "Validation Error",
      "detail": "Email format is invalid",
      "source": {
        "pointer": "/data/attributes/email"
      }
    }
  ],
  "meta": {
    "request_id": "req_123456789",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

### Status Codes
- **200 OK** - Successful GET, PUT, PATCH requests
- **201 Created** - Successful POST requests
- **204 No Content** - Successful DELETE requests
- **400 Bad Request** - Invalid request format
- **401 Unauthorized** - Authentication required
- **403 Forbidden** - Access denied
- **404 Not Found** - Resource not found
- **422 Unprocessable Entity** - Validation errors
- **429 Too Many Requests** - Rate limit exceeded
- **500 Internal Server Error** - Server error

## Authentication Endpoints

### POST /api/auth/login
Authenticate user and receive JWT token.

**Request:**
```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "secure_password"
}
```

**Response:**
```json
{
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_in": 3600,
    "token_type": "Bearer"
  }
}
```

### POST /api/auth/refresh
Refresh access token using refresh token.

**Request:**
```http
POST /api/auth/refresh
Content-Type: application/json

{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### DELETE /api/auth/logout
Logout user and invalidate tokens.

**Request:**
```http
DELETE /api/auth/logout
Authorization: Bearer <access_token>
```

**Response:**
```http
HTTP/1.1 204 No Content
```

## User Management

### GET /api/users
List users with pagination and filtering.

**Parameters:**
- `page` (integer, optional) - Page number (default: 1)
- `limit` (integer, optional) - Items per page (default: 20, max: 100)
- `filter[status]` (string, optional) - Filter by user status
- `filter[role]` (string, optional) - Filter by user role
- `sort` (string, optional) - Sort field (default: created_at)

**Request:**
```http
GET /api/users?page=1&limit=10&filter[status]=active&sort=name
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "data": [
    {
      "id": "1",
      "type": "user",
      "attributes": {
        "name": "John Doe",
        "email": "john@example.com",
        "status": "active",
        "role": "user",
        "created_at": "2024-01-15T10:00:00Z",
        "updated_at": "2024-01-15T10:00:00Z"
      }
    }
  ],
  "meta": {
    "pagination": {
      "current_page": 1,
      "total_pages": 5,
      "total_count": 47,
      "per_page": 10
    }
  }
}
```

### GET /api/users/:id
Get specific user by ID.

**Request:**
```http
GET /api/users/123
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "data": {
    "id": "123",
    "type": "user",
    "attributes": {
      "name": "John Doe",
      "email": "john@example.com",
      "status": "active",
      "role": "user",
      "profile": {
        "bio": "Software developer",
        "location": "San Francisco, CA",
        "website": "https://johndoe.com"
      },
      "created_at": "2024-01-15T10:00:00Z",
      "updated_at": "2024-01-15T10:00:00Z"
    },
    "relationships": {
      "posts": {
        "data": [
          {"id": "1", "type": "post"},
          {"id": "2", "type": "post"}
        ]
      }
    }
  }
}
```

### POST /api/users
Create new user.

**Request:**
```http
POST /api/users
Content-Type: application/json
Authorization: Bearer <access_token>

{
  "data": {
    "type": "user",
    "attributes": {
      "name": "Jane Smith",
      "email": "jane@example.com",
      "password": "secure_password",
      "role": "user"
    }
  }
}
```

**Response:**
```json
{
  "data": {
    "id": "124",
    "type": "user",
    "attributes": {
      "name": "Jane Smith",
      "email": "jane@example.com",
      "status": "active",
      "role": "user",
      "created_at": "2024-01-15T11:00:00Z",
      "updated_at": "2024-01-15T11:00:00Z"
    }
  }
}
```

### PUT /api/users/:id
Update existing user.

**Request:**
```http
PUT /api/users/124
Content-Type: application/json
Authorization: Bearer <access_token>

{
  "data": {
    "type": "user",
    "attributes": {
      "name": "Jane Smith Updated",
      "profile": {
        "bio": "Senior software developer"
      }
    }
  }
}
```

### DELETE /api/users/:id
Delete user (soft delete).

**Request:**
```http
DELETE /api/users/124
Authorization: Bearer <access_token>
```

**Response:**
```http
HTTP/1.1 204 No Content
```

## Content Management

### GET /api/posts
List posts with filtering and pagination.

**Parameters:**
- `page` (integer, optional) - Page number
- `limit` (integer, optional) - Items per page
- `filter[status]` (string, optional) - Filter by post status
- `filter[author_id]` (string, optional) - Filter by author
- `filter[category]` (string, optional) - Filter by category
- `include` (string, optional) - Include related resources (author, comments)

**Request:**
```http
GET /api/posts?include=author,comments&filter[status]=published&page=1&limit=10
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "data": [
    {
      "id": "1",
      "type": "post",
      "attributes": {
        "title": "Getting Started with Elixir",
        "content": "Elixir is a dynamic, functional language...",
        "status": "published",
        "category": "tutorial",
        "tags": ["elixir", "programming", "functional"],
        "published_at": "2024-01-15T09:00:00Z",
        "created_at": "2024-01-14T15:00:00Z",
        "updated_at": "2024-01-15T09:00:00Z"
      },
      "relationships": {
        "author": {
          "data": {"id": "123", "type": "user"}
        },
        "comments": {
          "data": [
            {"id": "1", "type": "comment"},
            {"id": "2", "type": "comment"}
          ]
        }
      }
    }
  ],
  "included": [
    {
      "id": "123",
      "type": "user",
      "attributes": {
        "name": "John Doe",
        "email": "john@example.com"
      }
    },
    {
      "id": "1",
      "type": "comment",
      "attributes": {
        "content": "Great tutorial!",
        "created_at": "2024-01-15T10:00:00Z"
      }
    }
  ]
}
```

### GET /api/posts/:id
Get specific post by ID.

**Request:**
```http
GET /api/posts/1?include=author,comments
```

### POST /api/posts
Create new post.

**Request:**
```http
POST /api/posts
Content-Type: application/json
Authorization: Bearer <access_token>

{
  "data": {
    "type": "post",
    "attributes": {
      "title": "Advanced Elixir Patterns",
      "content": "In this post, we'll explore...",
      "status": "draft",
      "category": "advanced",
      "tags": ["elixir", "patterns", "advanced"]
    }
  }
}
```

### PUT /api/posts/:id
Update existing post.

### DELETE /api/posts/:id
Delete post.

## Comments

### GET /api/posts/:post_id/comments
List comments for a specific post.

**Request:**
```http
GET /api/posts/1/comments?include=author&sort=-created_at
```

### POST /api/posts/:post_id/comments
Create new comment on a post.

**Request:**
```http
POST /api/posts/1/comments
Content-Type: application/json
Authorization: Bearer <access_token>

{
  "data": {
    "type": "comment",
    "attributes": {
      "content": "This is a helpful tutorial!"
    }
  }
}
```

### PUT /api/comments/:id
Update existing comment.

### DELETE /api/comments/:id
Delete comment.

## File Management

### POST /api/uploads
Upload file.

**Request:**
```http
POST /api/uploads
Content-Type: multipart/form-data
Authorization: Bearer <access_token>

file=@/path/to/file.jpg
```

**Response:**
```json
{
  "data": {
    "id": "upload_123",
    "type": "upload",
    "attributes": {
      "filename": "file.jpg",
      "content_type": "image/jpeg",
      "size": 102400,
      "url": "https://cdn.example.com/uploads/file_123.jpg",
      "created_at": "2024-01-15T12:00:00Z"
    }
  }
}
```

### GET /api/uploads/:id
Get upload metadata.

### DELETE /api/uploads/:id
Delete uploaded file.

## Search

### GET /api/search
Search across multiple content types.

**Parameters:**
- `q` (string, required) - Search query
- `type` (string, optional) - Content type filter (posts, users, comments)
- `page` (integer, optional) - Page number
- `limit` (integer, optional) - Results per page

**Request:**
```http
GET /api/search?q=elixir&type=posts&page=1&limit=10
```

**Response:**
```json
{
  "data": [
    {
      "id": "1",
      "type": "post",
      "attributes": {
        "title": "Getting Started with Elixir",
        "snippet": "Elixir is a dynamic, functional language designed for building...",
        "score": 0.95,
        "matched_fields": ["title", "content"]
      }
    }
  ],
  "meta": {
    "search": {
      "query": "elixir",
      "total_results": 15,
      "search_time": "0.045s"
    }
  }
}
```

## Analytics

### GET /api/analytics/dashboard
Get dashboard analytics data.

**Request:**
```http
GET /api/analytics/dashboard?period=30days
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "data": {
    "type": "analytics",
    "attributes": {
      "period": "30days",
      "users": {
        "total": 1250,
        "active": 890,
        "new": 45
      },
      "posts": {
        "total": 234,
        "published": 198,
        "drafts": 36
      },
      "engagement": {
        "page_views": 15420,
        "unique_visitors": 3240,
        "avg_session_duration": "4m 32s"
      }
    }
  }
}
```

### GET /api/analytics/posts/:id/stats
Get analytics for specific post.

## Webhooks

### GET /api/webhooks
List configured webhooks.

### POST /api/webhooks
Create new webhook.

**Request:**
```http
POST /api/webhooks
Content-Type: application/json
Authorization: Bearer <access_token>

{
  "data": {
    "type": "webhook",
    "attributes": {
      "url": "https://example.com/webhook",
      "events": ["post.created", "post.published", "user.registered"],
      "secret": "webhook_secret_key",
      "active": true
    }
  }
}
```

### PUT /api/webhooks/:id
Update webhook configuration.

### DELETE /api/webhooks/:id
Delete webhook.

## Rate Limiting

### Rate Limit Headers
All API responses include rate limiting headers:

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642234800
X-RateLimit-Window: 3600
```

### Rate Limits by Endpoint Type
- **Authentication**: 10 requests per minute
- **Read Operations**: 1000 requests per hour
- **Write Operations**: 100 requests per hour
- **Upload Operations**: 20 requests per hour
- **Search**: 500 requests per hour

### Rate Limit Exceeded Response
```json
{
  "errors": [
    {
      "status": "429",
      "code": "RATE_LIMIT_EXCEEDED",
      "title": "Rate Limit Exceeded",
      "detail": "Too many requests. Try again in 60 seconds.",
      "meta": {
        "retry_after": 60
      }
    }
  ]
}
```

## Pagination

### Cursor-based Pagination
For large datasets, use cursor-based pagination:

**Request:**
```http
GET /api/posts?limit=20&cursor=eyJjcmVhdGVkX2F0IjoiMjAyNC0wMS0xNVQxMDowMDowMFoiLCJpZCI6IjEyMyJ9
```

**Response:**
```json
{
  "data": [...],
  "meta": {
    "pagination": {
      "has_next": true,
      "has_previous": false,
      "next_cursor": "eyJjcmVhdGVkX2F0IjoiMjAyNC0wMS0xNFQwOTowMDowMFoiLCJpZCI6IjE0NCJ9",
      "previous_cursor": null
    }
  }
}
```

### Offset-based Pagination
For smaller datasets:

**Request:**
```http
GET /api/users?page=2&limit=20
```

**Response:**
```json
{
  "meta": {
    "pagination": {
      "current_page": 2,
      "total_pages": 5,
      "total_count": 87,
      "per_page": 20,
      "has_next": true,
      "has_previous": true
    }
  }
}
```

## Error Handling

### Validation Errors
```json
{
  "errors": [
    {
      "status": "422",
      "code": "VALIDATION_ERROR",
      "title": "Validation Failed",
      "detail": "Email is required",
      "source": {
        "pointer": "/data/attributes/email"
      }
    }
  ]
}
```

### Not Found Errors
```json
{
  "errors": [
    {
      "status": "404",
      "code": "RESOURCE_NOT_FOUND",
      "title": "Resource Not Found",
      "detail": "The requested user could not be found"
    }
  ]
}
```

### Authorization Errors
```json
{
  "errors": [
    {
      "status": "403",
      "code": "INSUFFICIENT_PERMISSIONS",
      "title": "Access Denied",
      "detail": "You don't have permission to perform this action"
    }
  ]
}
```

## API Versioning

### Version Header
Specify API version using header:
```http
Accept: application/vnd.prismatic.v1+json
```

### URL Versioning (Legacy)
Legacy endpoints support URL versioning:
```http
GET /api/v1/users
```

### Version Support
- **v1** - Current stable version
- **v2** - Beta version (limited endpoints)
- **Legacy versions** - Deprecated, remove after 6 months

## Testing API Endpoints

### cURL Examples
```bash
# Login
curl -X POST https://api.prismatic.example.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password"}'

# Get users with authentication
curl -X GET https://api.prismatic.example.com/api/users \
  -H "Authorization: Bearer <access_token>" \
  -H "Accept: application/json"

# Create post
curl -X POST https://api.prismatic.example.com/api/posts \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"data": {"type": "post", "attributes": {"title": "Test Post", "content": "Test content"}}}'
```

### Postman Collection
A Postman collection is available for testing all API endpoints:
- **Download**: [Prismatic API Collection](../shared/postman/prismatic-api.json)
- **Environment**: Configure base URL and authentication tokens
- **Examples**: Pre-configured requests with sample data

## SDK and Client Libraries

### Official SDKs
- **JavaScript/TypeScript**: [`@prismatic/js-sdk`](https://www.npmjs.com/package/@prismatic/js-sdk)
- **Python**: [`prismatic-python`](https://pypi.org/project/prismatic-python/)
- **Ruby**: [`prismatic-ruby`](https://rubygems.org/gems/prismatic-ruby)

### Community SDKs
- **PHP**: [`prismatic/php-client`](https://packagist.org/packages/prismatic/php-client)
- **Go**: [`github.com/prismatic/go-client`](https://github.com/prismatic/go-client)

## Related Documentation

- [API Authentication](api-authentication.md) - Detailed authentication and authorization guide
- [Database Schema](database-schema.md) - Understanding data models and relationships
- [Security Guidelines](../guides/security-guidelines.md) - API security best practices and implementation
- [Performance Optimization](../guides/performance-optimization.md) - API performance tuning and optimization
- [System Diagrams](../architecture/system-diagrams.md) - Visual representation of API architecture
- [Developer Experience](../guides/developer-experience.md) - API development workflow and tools

---

**This API reference is automatically updated as endpoints are added or modified. For the most current information, refer to the interactive API documentation at `/api/docs`.**