# Changelog

## Version 1.3.0 - Enhanced Notification Control

### 🆕 New Features

#### Granular Control for Intigriti 403 Error Notifications

Introducing fine-grained control over Discord notifications for Intigriti program fetch errors, specifically targeting 403 status codes.

**New Configuration Variable:**
- `NOTIFY_INTIGRITI_403_ERRORS` - Controls Discord notifications for Intigriti 403 errors (default: `true`)

**Behavior:**
- **When `true` (default):** All Intigriti fetch errors (403, 404, 500, etc.) trigger Discord notifications
- **When `false`:** Only 403 errors are silenced, other error codes still trigger notifications

**Use Case:**
Intigriti returns 403 errors for programs that haven't been manually accepted on their website. This option allows you to reduce notification noise from these expected 403 errors while maintaining visibility on actual technical issues.

---

## Version 1.2.0 - Wildcards Endpoint

### 🆕 New Features

#### Dedicated Wildcards API Endpoint

Introducing the new `/wildcards` endpoint to easily extract and filter wildcard domains (`*.example.com`) from all bug bounty programs.

**Endpoint:** `GET /wildcards`

**Features:**
- Extract all wildcard domains from in-scope web targets
- Filter by platform (`?platform=YesWeHack`)
- Filter by program (`?program=ProgramName`)
- Combine filters for precise results

**Response Format:**
```json
[
  {
    "domain": "*.example.com",
    "platform": "YesWeHack",
    "program": "Acme Corp",
    "slug": "acme-corp",
    "private": false
  },
  {
    "domain": "*.api.company.io",
    "platform": "Hackerone",
    "program": "Company Security",
    "slug": "company-security",
    "private": true
  }
]
```

**API Examples:**
```bash
# Get all wildcard domains
curl -H "X-API-Key: your_key" http://localhost:4567/wildcards

# Get wildcards from specific platform
curl -H "X-API-Key: your_key" "http://localhost:4567/wildcards?platform=YesWeHack"

# Get wildcards from specific program
curl -H "X-API-Key: your_key" "http://localhost:4567/wildcards?program=Acme%20Corp"

# Combined filtering
curl -H "X-API-Key: your_key" "http://localhost:4567/wildcards?platform=Hackerone&program=Company"
```

---

## Version 1.1.0 - Enhanced History Tracking

### 🆕 New Features

#### Complete Scope Preservation for Removed Programs

When a bug bounty program is removed from any platform, ScopesExtractor now preserves the complete scope information that was present at the time of removal.

**Before:**
```json
{
  "timestamp": "2025-07-02T09:42:48Z",
  "platform": "Immunefi",
  "program": "Example Program",
  "change_type": "remove_program",
  "scope_type": null,
  "category": null,
  "value": "Example Program"
}
```

**After:**
```json
{
  "timestamp": "2025-07-02T09:42:48Z",
  "platform": "Immunefi",
  "program": "Example Program",
  "change_type": "remove_program",
  "scope_type": null,
  "category": null,
  "value": "Example Program",
  "scopes": {
    "in": {
      "web": ["*.domain.tld", "www.example.tld"],
    },
    "out": {}
  }
}
```
