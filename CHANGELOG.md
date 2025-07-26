# Changelog

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
