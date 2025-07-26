# Changelog - Enhanced Program Removal Tracking

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
