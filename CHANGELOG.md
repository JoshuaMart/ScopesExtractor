# Changelog

## Version 2.1.3 - Malformed Scope Handling

### ✨ Features

- Add `GET /malformed-scopes` to list invalid-format assets ordered by program.
- Expand explicit YesWeHack hostname alternatives in parentheses or brackets, including multi-part TLDs and URL paths.

### 🐛 Bug Fixes

- Restrict hostname expansion to safe host alternatives so query parameters and paths cannot produce unintended targets.
- Hide malformed assets belonging to programs that have been removed.
- Clear previously rejected assets after a successful sync when they are no longer malformed.
- Allow the `extra_data` migration to complete when the column exists but the migration version was not recorded.
- Isolate tests from the application database and preserve migration metadata during test cleanup.
- Update the CLI version and HTTP User-Agent to `2.1.3`.

---

## Version 2.1.2 - Scope State Synchronization

### 🐛 Bug Fixes

- Compare scopes by value, type, and in-scope status so changes to either property update the stored scope and the `/` API response.
- Record scope state and type transitions as `remove_scope` followed by `add_scope` events in history.
- Remove scopes by their database ID so entries sharing a value do not delete one another.
- Update the CLI `version` command and HTTP User-Agent to report the current release.

---

## Version 2.1.1 - YesWeHack Inactive Programs

### 🐛 Bug Fixes

- Exclude YesWeHack programs marked `archived` or `disabled` from synchronization, using both the program listing and detail response.
- Remove previously stored scopes for these programs on the next sync, so they no longer appear in `/`. The removal is recorded in history as a `remove_program` event.
- Update the CLI `version` command and HTTP User-Agent to report the current release.

---

## Version 2.1.0 - Generic HTTP Webhook Notifications

### ✨ Features

#### Generic HTTP Webhook Notifications

Notifications are no longer Discord-only: a generic HTTP webhook notifier can be enabled alongside (or instead of) Discord.

**Changes:**
- **New `Notifiers::Webhook`**: POSTs every event as JSON to a configurable endpoint
- **New `Notifiers::Multi`**: fans notifications out to all configured notifiers, a failing one never blocks the others
- **Custom headers**: optional headers (typically for authentication) with `${VAR}` environment variable interpolation, so secrets stay in `.env`
- **Same filtering as Discord**: `events` and `new_scope_types` filters, plus a dedicated `error` event

**Configuration** (`config/settings.yml`):

```yaml
webhook:
  enabled: true
  url: "https://example.com/hooks/scopes"
  headers:
    Authorization: "Bearer ${WEBHOOK_TOKEN}"
  events: ["new_program", "removed_program", "new_scope", "removed_scope", "ignored_asset", "error"]
  new_scope_types: ["web"]
```

**Payload:**

```json
{
  "event": "new_scope",
  "timestamp": "2025-07-30T10:17:00Z",
  "data": { "platform": "yeswehack", "program": "Example Program", "value": "*.example.com", "type": "web" }
}
```

---

## Version 2.0.1 - Bugcrowd Auth Fix

### 🐛 Bug Fixes

#### Migrated Bugcrowd Authentication to Okta-Based Flow

Bugcrowd has migrated its authentication system to Okta. The previous CSRF-based login flow no longer works.

**Changes:**
- **New Okta flow**: Authentication now goes through `login.hackers.bugcrowd.com` using Okta's IDX API
- **Multi-step authentication**: Implements the full Okta pipeline — `stateToken` extraction, introspect, identify, password challenge, and OTP challenge
- **Removed legacy code**: Dropped CSRF token extraction, `CGI`-based form encoding, manual redirect following, and the old `prepare_login_body` / `extract_csrf` / `authenticated_response?` helpers
- **Simplified session verification**: Dashboard check now uses a simple body content match

---

## Version 2.0.0 - Complete Refactor

### 🚨 BREAKING CHANGES

This is a complete rewrite of ScopesExtractor with significant architectural changes and breaking changes from version 1.x.

#### API Breaking Changes
- **Endpoint changes**: All API endpoints restructured
  - `/wildcards` now returns different JSON structure with full scope objects
  - `/changes` endpoint for history tracking
  - New `/exclusions` endpoint for ignored assets
- **Response format**: All endpoints now return JSON with `count` metadata
- **Query parameters**: Standardized filtering with `platform`, `type`, `bounty`, `slug` parameters

#### CLI Breaking Changes
- **Command structure**: New Thor-based CLI with different command syntax
  - `sync [PLATFORM]` - Sync programs (replaces old sync command)
  - `serve` - Start API server (new)
  - `migrate` - Run database migrations (new)
  - `cleanup` - Cleanup old history (new)
  - `reset` - Reset database (new)
- **Flags**: New standardized flags across commands
  - `--verbose` / `-v` - Enable verbose logging
  - `--sync` / `-s` - Enable auto-sync with API server
  - `--port` / `-p` - Custom API port
  - `--bind` / `-b` - Custom bind address

#### Platform Support
- ⚠️ **Immunefi**: Removed (pending reimplementation)

---

## Version 1.13.0 - Program Exclusions

### 🆕 New Features

#### Program-Level Exclusions

Added the ability to exclude entire programs from synchronization on a per-platform basis.

**Configuration:**
Programs can now be excluded by adding their slug/handle/ID to `config/exclusions.yml`:

```yaml
scopes:
  - "*.abcdedf.net"

programs:
  bugcrowd:
    - "program-slug-1"
    - "program-slug-2"
  yeswehack:
    - "program-slug-1"
  hackerone:
    - "program-handle-1"
  intigriti:
    - "program-handle-1"
  immunefi:
    - "project-id-1"
```

**Use Cases:**
- Exclude programs you're not interested in monitoring
- Reduce noise from specific bug bounty programs

---

## Version 1.12.1 - Intigriti Scopes

### 🔄 Modifications

#### Update Intigriti Scopes Categories

Add `source_code` category to scopes

## Version 1.12.0 - Remove debug line

### 🔄 Modifications

#### Removal of scope skipping variable

Removed a variable that was used for debugging, which caused the `ripe.net` scope to be skipped.

## Version 1.11.0 - Fix Type Casting Bug

### 🐛 Bug Fixes

#### Fixed NoMethodError on Boolean Values

Resolved a type casting issue where calling `.downcase` on boolean values caused a `NoMethodError`.
The environment variables from `.env` are always strings (e.g., `"true"`, `"false"`) while the default values in `ENV.fetch` were booleans (e.g., `false`, `true`)

## Version 1.10.1 - YesWeHack Scopes

### 🔄 Modifications

#### Update YesWeHack Scopes Categories

Add `open-source` category to scopes

## Version 1.10.0 - YesWeHack Scopes

### 🔄 Modifications

#### Update YesWeHack Scopes Categories

Add `wildcard` category to scopes

## Version 1.9.0 - Improve Domain Normalization

### 🔄 Modifications

#### Updated Protocol Removal for Wildcard Domains

**Changes:**
- Protocol removal now happens **before** `global_end_strip` to ensure proper normalization

**Example:**
```ruby
# Before:
'https://*.domain.tld/' → 'https://*.domain.tld' (incorrect)

# After:
'https://*.domain.tld/' → '*.domain.tld' (correct)
'*.domain.tld/' → '*.domain.tld' (correct)
```

---

## Version 1.8.0 - Scope Category Detection & Parser Improvements

### 🆕 New Features

#### Centralized Scope Category Detection

Introduced a new `ScopeCategoryDetector` utility module to centralize and standardize category detection across all platforms.

**Features:**
- **Unified Logic**: Eliminates code duplication across platform-specific scope modules

### 🐛 Bug Fixes

#### Fixed Invalid Wildcard Pattern Validation

Resolved an issue where invalid wildcard patterns were incorrectly accepted during scope normalization.

**Example of invalid patterns now rejected:**
- `abcd-*.domain.tld` (wildcard in the middle of domain)
- `https://*abcd.domain.tld` (wildcard immediately after protocol)

**Valid patterns still accepted:**
- `*.example.com` (standard wildcard subdomain)
- `https://*.example.com` (wildcard subdomain with protocol)

## Version 1.7.0 - HackerOne Pagination Optimization

### 🔄 Modifications

#### Migrated to Structured Scopes Endpoint with Pagination

Improved HackerOne scope fetching by migrating from the legacy program endpoint to the dedicated structured scopes endpoint with full pagination support.

**Changes:**
- **Endpoint Migration**: Switched from `/v1/hackers/programs/{slug}` to `/v1/hackers/programs/{slug}/structured_scopes`

---

## Version 1.6.0 - Fix Program Status Change Detection

### 🐛 Bug Fixes

#### Resolved Bad Program Deletions

Fixed an issue where programs with status changes (e.g., `open` → `closed`) were not properly detected during synchronization.

---

## Version 1.5.0 - HTTP Client Retry

### 🔄 Modifications

#### Centralized HTTP Retry Mechanism

Refactored the HTTP retry logic from platform-specific implementations to a centralized system in `HttpClient`.

**Changes:**
- **Moved retry logic** from `Intigriti::Scopes.try_request_with_retries` to `HttpClient.request`
- **Enhanced retry conditions** to include status codes: 0 (connection errors), 400 (Bad Request), and 5xx (server errors)
- **Configurable parameters** via `max_retries` (default: 3) and `retry_delay` (default: 30s) options
- **Unified logging** format across all HTTP requests with retry attempt details

---

## Version 1.4.0 - Intigriti Retry Mechanism

### 🆕 New Features

#### Automatic Retry Mechanism for Intigriti Program Fetch

Added a retry system to improve resilience when fetching Intigriti program scopes.

**Behavior:**
- Automatically retries failed requests for **5xx server errors** up to 3 times (`RETRY_MAX`)
- Waits 30 seconds between each retry (`RETRY_DELAY`)
- Logs retry attempts to Discord with attempt count and delay
- Aborts retries on non-5xx errors or after reaching the retry limit

**Use Case:**
Helps mitigate temporary network or Intigriti API outages by automatically retrying before raising an alert, reducing false-positive failure notifications.

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
