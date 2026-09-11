# API Mapping — {FEAT-ID}: {Feature Name}

> Generated: {date} | Session: {SESSION_ID}

## Endpoint Matrix

| Route | Method | Handler | Command/Query | Validator | Permission | Response Type |
|-------|--------|---------|---------------|-----------|------------|---------------|
| `/api/v1/{route}` | GET | `GetXxxQueryHandler` | `GetXxxQuery` | - | `{module}.{res}.view` | `XxxDto[]` |
| `/api/v1/{route}` | POST | `CreateXxxCommandHandler` | `CreateXxxCommand` | `CreateXxxCommandValidator` | `{module}.{res}.create` | `XxxDto` |
| `/api/v1/{route}/{id}` | PUT | `UpdateXxxCommandHandler` | `UpdateXxxCommand` | `UpdateXxxCommandValidator` | `{module}.{res}.edit` | `XxxDto` |
| `/api/v1/{route}/{id}` | DELETE | `DeleteXxxCommandHandler` | `DeleteXxxCommand` | - | `{module}.{res}.delete` | `bool` |

## File Locations

| Artifact | Path |
|----------|------|
| Endpoint class | `apps/backend/Eureka.Api/Endpoints/{ModuleEndpoints.cs}` |
| Commands folder | `apps/backend/Eureka.Modules.{Module}/Application/Commands/` |
| Queries folder | `apps/backend/Eureka.Modules.{Module}/Application/Queries/` |

## Request/Response Shapes

### POST /api/v1/{route} — Create

**Request:**
```json
{
  "fieldA": "string (required, max 255)",
  "fieldB": "number (required)",
  "fieldC": "string (optional)"
}
```

**Response (201):**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "fieldA": "string",
    "fieldB": 0,
    "createdAt": "ISO8601"
  },
  "meta": null
}
```

**Error (400):**
```json
{
  "success": false,
  "errors": [
    { "field": "fieldA", "message": "FieldA là bắt buộc" }
  ]
}
```

## Validation Rules (từ Validator class)

| Field | Rule | Error Message |
|-------|------|---------------|
| {field} | NotEmpty | "{Field} không được để trống" |
| {field} | MaximumLength(255) | "{Field} không quá 255 ký tự" |

## Dependencies (gitnexus impact)

| Endpoint | Depends On | Impact |
|----------|-----------|--------|
| POST /api/v1/{route} | {Module2}.{Service} | Trigger domain event |
