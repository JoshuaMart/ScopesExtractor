![Image](https://github.com/user-attachments/assets/8fa9dd2a-04c8-48d4-a0d7-6057c102436c)

A tool to automatically synchronize and track bug bounty program scopes from multiple platforms. Monitor new programs, scope changes, and receive Discord notifications for updates.

[![Ruby](https://img.shields.io/badge/Ruby-3.4.7-red.svg)](https://www.ruby-lang.org/en/)
[![Docker](https://img.shields.io/badge/Docker-Supported-blue.svg)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Maintainability](https://qlty.sh/gh/JoshuaMart/projects/ScopesExtractor/maintainability.svg)](https://qlty.sh/gh/JoshuaMart/projects/ScopesExtractor)

## Features

- 🔄 **Multi-Platform Support**: YesWeHack, HackerOne, Intigriti, Bugcrowd
- 📊 **Automatic Synchronization**: Continuously monitor programs and detect scope changes
- 🔔 **Discord Notifications**: Get notified about new programs, scope changes, and removals
- 🗄️ **SQLite Database**: Persistent storage with historical change tracking
- 🌐 **REST API**: Query scopes and changes programmatically
- 🎯 **Smart Scope Processing**: Automatic validation and normalization with platform-specific rules

## Installation

### Prerequisites

- Ruby >= 3.4.0
- SQLite3
- libcurl (for Typhoeus)

### Configuration

1. **Copy the environment template**:
   ```bash
   cp .env.example .env
   ```

2. **Configure platform credentials** in `.env` (email, password, API tokens, TOTP secrets)

3. **Configure application settings** in `config/settings.yml` (enable/disable platforms, Discord webhooks, etc.)

### Using Docker (Recommended)

```bash
# Build the image
docker build -t scopes_extractor .

# Run with mounted config and database
docker run -v $(pwd)/config/settings.yml:/app/config/settings.yml \
           -v $(pwd)/db:/app/db \
           -v $(pwd)/.env:/app/.env \
           scopes_extractor \
           bundle exec bin/scopes_extractor sync
```

### Local Installation

```bash
# Install dependencies
bundle install

# Run migrations
bundle exec bin/scopes_extractor migrate
```

## CLI Usage

### Commands

#### Sync Programs

```bash
# Sync all enabled platforms
bundle exec bin/scopes_extractor sync

# Sync specific platform
bundle exec bin/scopes_extractor sync hackerone

# Verbose output
bundle exec bin/scopes_extractor sync -v
bundle exec bin/scopes_extractor sync yeswehack --verbose
```

#### Start API Server

```bash
# Start API server
bundle exec bin/scopes_extractor serve

# Custom port and bind address
bundle exec bin/scopes_extractor serve -p 8080 -b 127.0.0.1

# Enable auto-sync in background
bundle exec bin/scopes_extractor serve --sync

# Verbose logging
bundle exec bin/scopes_extractor serve -v
```

#### Database Management

```bash
# Run migrations
bundle exec bin/scopes_extractor migrate

# Cleanup old history entries
bundle exec bin/scopes_extractor cleanup

# Reset database (WARNING: deletes all data)
bundle exec bin/scopes_extractor reset
bundle exec bin/scopes_extractor reset --force  # Skip confirmation
```

#### Other Commands

```bash
# Display version
bundle exec bin/scopes_extractor version

# Show help
bundle exec bin/scopes_extractor help
```

## Docker Usage

### Docker Compose

Create a `docker-compose.yml`:

```yaml
services:
  scopes_extractor:
    build: .
    container_name: scopes_extractor
    volumes:
      - ./config/settings.yml:/app/config/settings.yml
      - ./db:/app/db
      - ./.env:/app/.env
    ports:
      - "4567:4567"
    command: bundle exec bin/scopes_extractor serve --sync
    restart: unless-stopped
```

Run with:

```bash
docker-compose up -d
```

### Docker Run Examples

```bash
# Sync once
docker run -v $(pwd)/config/settings.yml:/app/config/settings.yml \
           -v $(pwd)/db:/app/db \
           -v $(pwd)/.env:/app/.env \
           --name scopes_extractor \
           scopes_extractor \
           bundle exec bin/scopes_extractor sync

# Start API server with auto-sync
docker run -d \
           -v $(pwd)/config/settings.yml:/app/config/settings.yml \
           -v $(pwd)/db:/app/db \
           -v $(pwd)/.env:/app/.env \
           -p 4567:4567 \
           --name scopes_extractor \
           scopes_extractor \
           bundle exec bin/scopes_extractor serve --sync

# View logs
docker logs -f scopes_extractor
```

## API Documentation

The REST API provides programmatic access to scopes and change history.

<details>
<summary><strong>GET /</strong> - List all scopes</summary>

### Query Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `platform` | string | Filter by platform name (e.g., `hackerone`, `bugcrowd`) |
| `type` | string | Filter by scope type (e.g., `web`, `mobile`, `api`) |
| `bounty` | boolean | Filter by bounty status (`true` or `false`) |
| `slug` | string | Filter by program slug |
| `values_only` | boolean | Return only scope values as array |

### Example Request

```bash
curl "http://localhost:4567/?platform=hackerone&type=web&bounty=true"
```

### Example Response

```json
{
  "scopes": [
    {
      "slug": "example-program",
      "platform": "hackerone",
      "program_name": "Example Program",
      "bounty": true,
      "value": "*.example.com",
      "type": "web",
      "is_in_scope": true
    },
    {
      "slug": "example-program",
      "platform": "hackerone",
      "program_name": "Example Program",
      "bounty": true,
      "value": "api.example.com",
      "type": "web",
      "is_in_scope": true
    }
  ],
  "count": 2
}
```

### Example Response (values_only=true)

```json
[
  "*.example.com",
  "api.example.com"
]
```

</details>

<details>
<summary><strong>GET /changes</strong> - Recent changes in history</summary>

### Query Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `hours` | integer | Number of hours to look back (default: 24) |
| `platform` | string | Filter by platform name |
| `type` | string | Filter by event type (`new_program`, `removed_program`, `new_scope`, `removed_scope`) |

### Example Request

```bash
curl "http://localhost:4567/changes?hours=48&platform=bugcrowd&type=new_scope"
```

### Example Response

```json
{
  "changes": [
    {
      "id": 123,
      "program_id": 45,
      "program_slug": "example-program",
      "platform_name": "bugcrowd",
      "event_type": "new_scope",
      "scope_value": "newapp.example.com",
      "scope_type": "web",
      "created_at": "2026-01-10T14:30:00Z"
    },
    {
      "id": 122,
      "program_id": 46,
      "program_slug": "another-program",
      "platform_name": "bugcrowd",
      "event_type": "new_scope",
      "scope_value": "*.another.com",
      "scope_type": "web",
      "created_at": "2026-01-10T12:15:00Z"
    }
  ],
  "count": 2
}
```

</details>

<details>
<summary><strong>GET /wildcards</strong> - List all wildcard scopes</summary>

### Query Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `platform` | string | Filter by platform name |
| `values_only` | boolean | Return only wildcard values as array |

### Example Request

```bash
curl "http://localhost:4567/wildcards?platform=hackerone"
```

### Example Response

```json
{
  "wildcards": [
    {
      "slug": "example-program",
      "platform": "hackerone",
      "program_name": "Example Program",
      "bounty": true,
      "value": "*.example.com",
      "type": "web",
      "is_in_scope": true
    },
    {
      "slug": "another-program",
      "platform": "hackerone",
      "program_name": "Another Program",
      "bounty": false,
      "value": "*.another.org",
      "type": "web",
      "is_in_scope": true
    }
  ],
  "count": 2
}
```

### Example Response (values_only=true)

```json
[
  "*.example.com",
  "*.another.org"
]
```

</details>

<details>
<summary><strong>GET /exclusions</strong> - List all excluded/ignored assets</summary>

### Example Request

```bash
curl "http://localhost:4567/exclusions"
```

### Example Response

```json
{
  "exclusions": [
    {
      "id": 1,
      "value": "admin.example.com",
      "reason": "Out of scope - admin panel",
      "created_at": "2026-01-09T10:00:00Z"
    },
    {
      "id": 2,
      "value": "internal.example.com",
      "reason": "Internal use only",
      "created_at": "2026-01-08T15:30:00Z"
    }
  ],
  "count": 2
}
```

</details>

## Discord Notifications

Configure Discord webhooks to receive real-time notifications:

### Notification Types

- **new_program**: New bug bounty program discovered
- **removed_program**: Program no longer available
- **new_scope**: New scope added to a program
- **removed_scope**: Scope removed from a program
- **ignored_asset**: Asset failed validation and was ignored

### Scope Type Filtering

Use `new_scope_types` to filter which scope types trigger notifications:

```yaml
discord:
  webhooks:
    main:
      new_scope_types: ["web"]  # Only notify for web scopes
      # Or leave empty/null to notify for all types
```

## Scope Processing

ScopesExtractor includes intelligent scope processing with automatic normalization and validation.

<details>
<summary><strong>Auto-Heuristic Type Detection</strong></summary>

Scopes are automatically categorized based on pattern matching, overriding platform-provided types when applicable:

| Pattern | Detected Type | Example |
|---------|--------------|---------|
| GitHub/GitLab URLs | `source_code` | `https://github.com/user/repo` |
| Atlassian Marketplace | `source_code` | `https://marketplace.atlassian.com/apps/123` |
| App Store URLs | `mobile` | `https://apps.apple.com/app/id123` |
| Play Store URLs | `mobile` | `https://play.google.com/store/apps/details?id=com.app` |
| Chrome Web Store | `executable` | `https://chrome.google.com/webstore/detail/ext` |
| CIDR notation | `cidr` | `192.168.1.0/24` |
| Wildcard domains | `web` | `*.example.com` |

</details>

<details>
<summary><strong>Platform-Specific Normalization</strong></summary>

Each platform has custom normalization rules to handle their scope formats:

**YesWeHack**
- Expands multi-TLD patterns: `example.{fr,com}` → `example.fr`, `example.com`
- Handles prefix patterns: `{www,api}.example.com` → `www.example.com`, `api.example.com`

**HackerOne**
- Replaces `.*` with `.com`: `example.*` → `example.com`
- Replaces `.(TLD)` with `.com`: `example.(TLD)` → `example.com`
- Splits comma-separated values: `domain1.com,domain2.com` → `domain1.com`, `domain2.com`

**Intigriti**
- Replaces `<tld>` with `.com`: `*.example.<tld>` → `*.example.com`
- Splits slash-separated values: `domain1.com / domain2.com` → `domain1.com`, `domain2.com`

**Bugcrowd**
- Extracts primary domain from dash-separated descriptions: `example.com - Production` → `example.com`

</details>

<details>
<summary><strong>Global Normalization</strong></summary>

Applied to all scopes regardless of platform:

- Converts leading dots to wildcards: `.example.com` → `*.example.com`
- Removes trailing slashes and wildcards: `example.com/*` → `example.com`
- Downcases all values: `Example.COM` → `example.com`
- Cleans up escaped characters and extra spaces

</details>

<details>
<summary><strong>Validation Rules</strong></summary>

Scopes are validated before being added to the database. Invalid scopes trigger `ignored_asset` notifications.

**Rejected patterns:**
- Values without dots (unless IP addresses)
- Multiple wildcards: `*.xyz.*.example.com` ❌
- Invalid wildcard placement: `example*.com` ❌
- Template placeholders: `{id}`, `<identifier>`, `[name]`
- Descriptions in parentheses: `example.com (production only)`
- Sentence punctuation: periods, commas, semicolons in unexpected positions
- Values with spaces (except in URLs with query parameters)
- Very short values (< 4 characters)
- Hash symbols in domain portion (allowed in URL fragments)

**Accepted patterns:**
- Standard domains: `example.com` ✅
- Subdomains: `api.example.com` ✅
- Wildcards: `*.example.com` ✅
- URLs with protocols: `https://example.com` ✅
- URLs with paths: `https://example.com/api` ✅
- IP addresses: `192.168.1.1` ✅
- CIDR ranges: `10.0.0.0/8` ✅

</details>

## Development

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with coverage
bundle exec rspec --format documentation

# Run specific test file
bundle exec rspec spec/scopes_extractor/models/scope_spec.rb
```

### Code Quality

```bash
# Run RuboCop
bundle exec rubocop
```

### Project Structure

```
scopes_refactor/
├── bin/
│   └── scopes_extractor          # CLI executable
├── lib/
│   └── scopes_extractor/
│       ├── api.rb                # REST API server
│       ├── auto_sync.rb          # Background sync scheduler
│       ├── cli.rb                # Thor CLI commands
│       ├── config.rb             # Configuration loader
│       ├── database.rb           # Database connection & migrations
│       ├── diff_engine.rb        # Program diff & change detection
│       ├── http.rb               # HTTP client with cookie support
│       ├── normalizer.rb         # Scope value normalization
│       ├── sync_manager.rb       # Platform synchronization orchestration
│       ├── validator.rb          # Scope validation logic
│       ├── models/               # Dry-Struct models
│       ├── notifiers/            # Discord notifications
│       └── platforms/            # Platform-specific implementations
│           ├── base_platform.rb
│           ├── yeswehack/
│           ├── hackerone/
│           ├── intigriti/
│           ├── bugcrowd/
│           └── immunefi/
├── spec/                         # RSpec tests
├── config/
│   └── settings.yml              # Main configuration
├── Dockerfile
└── Gemfile
```

## License

This project is licensed under the MIT License.
