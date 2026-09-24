<p align="center">
  <img src="https://github.com/user-attachments/assets/8fa9dd2a-04c8-48d4-a0d7-6057c102436c" alt="ScopesExtractor">
</p>

<p align="center">
  Synchronize and track bug bounty program scopes across YesWeHack, HackerOne, Intigriti and Bugcrowd.
</p>

<p align="center">
  <a href="https://www.ruby-lang.org/en/"><img src="https://img.shields.io/badge/Ruby-3.4.11-red.svg" alt="Ruby"></a>
  <a href="https://www.docker.com/"><img src="https://img.shields.io/badge/Docker-Supported-blue.svg" alt="Docker"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License"></a>
  <a href="https://qlty.sh/gh/JoshuaMart/projects/ScopesExtractor"><img src="https://qlty.sh/gh/JoshuaMart/projects/ScopesExtractor/maintainability.svg" alt="Maintainability"></a>
  <a href="https://qlty.sh/gh/JoshuaMart/projects/ScopesExtractor"><img src="https://qlty.sh/gh/JoshuaMart/projects/ScopesExtractor/coverage.svg" alt="Code Coverage"></a>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> •
  <a href="#configuration">Configuration</a> •
  <a href="#cli">CLI</a> •
  <a href="#rest-api">REST API</a> •
  <a href="#notifications">Notifications</a> •
  <a href="#scope-processing">Scope Processing</a>
</p>

---

ScopesExtractor fetches the programs you have access to on each platform, normalizes and validates their scopes, and stores them in a local SQLite database. Every sync is diffed against the previous state, so new programs, removed programs and scope changes are recorded in a history and can be pushed to Discord or any HTTP endpoint. A REST API exposes the data to your recon tooling.

## Features

- **Four platforms**: YesWeHack, HackerOne, Intigriti and Bugcrowd, each enabled independently
- **Change tracking**: new and removed programs and scopes, with a configurable history retention
- **Notifications**: Discord webhooks and a generic JSON webhook, filterable by event and scope type
- **REST API**: scopes, wildcards, recent changes, exclusions and malformed scopes
- **Scope normalization**: platform-specific cleanup, type detection and validation before storage
- **Background sync**: run the API server with a built-in sync scheduler

## Quick Start

The recommended way to run ScopesExtractor is Docker Compose. Database migrations run automatically on first start.

```bash
git clone https://github.com/JoshuaMart/ScopesExtractor.git
cd ScopesExtractor

cp .env.example .env    # then fill in your platform credentials and API key
```

Review `config/settings.yml` to enable the platforms and notifications you need, then create a `docker-compose.yml`:

```yaml
services:
  scopes_extractor:
    build: .
    container_name: scopes_extractor
    command: bundle exec bin/scopes_extractor serve --sync
    ports:
      - "4567:4567"
    volumes:
      - ./config/settings.yml:/app/config/settings.yml:ro
      - ./.env:/app/.env:ro
      - scopes_db:/app/db
    restart: unless-stopped

volumes:
  scopes_db:
```

```bash
docker compose up -d
docker logs -f scopes_extractor
```

The API is now available on `http://localhost:4567` and a sync runs every 3 hours by default.

<details>
<summary><strong>Using <code>docker run</code> instead</strong></summary>

```bash
docker build -t scopes_extractor .
docker volume create scopes_db

# One-off sync
docker run --rm \
  -v "$(pwd)/config/settings.yml:/app/config/settings.yml:ro" \
  -v "$(pwd)/.env:/app/.env:ro" \
  -v scopes_db:/app/db \
  scopes_extractor \
  bundle exec bin/scopes_extractor sync

# API server with background sync
docker run -d --name scopes_extractor \
  -v "$(pwd)/config/settings.yml:/app/config/settings.yml:ro" \
  -v "$(pwd)/.env:/app/.env:ro" \
  -v scopes_db:/app/db \
  -p 4567:4567 \
  scopes_extractor \
  bundle exec bin/scopes_extractor serve --sync
```

</details>

<details>
<summary><strong>Running without Docker</strong></summary>

Requirements: Ruby 3.4+, SQLite3 and libcurl.

```bash
bundle install
bundle exec bin/scopes_extractor migrate
bundle exec bin/scopes_extractor serve --sync
```

</details>

## Configuration

Configuration is split between two files: secrets live in `.env`, everything else in `config/settings.yml`.

### Environment variables

| Variable | Description |
|----------|-------------|
| `YWH_EMAIL`, `YWH_PWD`, `YWH_OTP` | YesWeHack credentials and TOTP secret |
| `H1_USERNAME`, `H1_TOKEN` | HackerOne username and API token |
| `INTIGRITI_TOKEN` | Intigriti API bearer token |
| `BUGCROWD_EMAIL`, `BUGCROWD_PASSWORD`, `BUGCROWD_OTP` | Bugcrowd credentials and TOTP secret |
| `API_KEY` | Key expected in the `X-API-KEY` header of API requests |

Only the credentials of enabled platforms are required. Any other variable can be referenced from `settings.yml` with the `${VAR}` syntax (see [HTTP webhook](#http-webhook)).

### Settings

| Key | Default | Description |
|-----|---------|-------------|
| `app.log_level` | `INFO` | `DEBUG`, `INFO`, `WARN` or `ERROR` |
| `app.database_path` | `db/scopes.db` | SQLite database location |
| `http.proxy` | `null` | Optional proxy for outgoing requests |
| `http.timeout` | `30` | Request timeout in seconds |
| `api.port` / `api.bind` | `4567` / `0.0.0.0` | API listen address |
| `api.require_auth` | `true` | Require the `X-API-KEY` header |
| `api.allowed_hosts` | `[]` | Allowed `Host` headers, empty allows all |
| `platforms.<name>.enabled` | `true` | Enable or disable a platform |
| `platforms.<name>.skip_vdp` | varies | Ignore programs without bounty |
| `platform_exclusions.<name>` | `[]` | Program slugs to ignore |
| `sync.delay` | `10800` | Interval between background syncs, in seconds |
| `history_retention_days` | `30` | History entries older than this are purged |
| `validation.allow_private_suffixes` | `false` | Accept domains under [private public suffixes](https://github.com/weppos/publicsuffix-ruby/blob/main/data/list.txt) |

Notification settings are described in [Notifications](#notifications).

## CLI

```bash
bundle exec bin/scopes_extractor <command> [options]
```

| Command | Description |
|---------|-------------|
| `sync [PLATFORM]` | Synchronize all enabled platforms, or a single one |
| `serve` | Start the REST API server |
| `migrate` | Run database migrations |
| `cleanup` | Purge history entries older than `history_retention_days` |
| `reset` | Delete all data from the database |
| `version` | Print the version |
| `help [COMMAND]` | Show help |

| Option | Applies to | Description |
|--------|------------|-------------|
| `-v`, `--verbose` | `sync`, `serve` | Enable debug logging |
| `-p`, `--port` | `serve` | Override `api.port` |
| `-b`, `--bind` | `serve` | Override `api.bind` |
| `-s`, `--sync` | `serve` | Run syncs in the background every `sync.delay` seconds |
| `-f`, `--force` | `reset` | Skip the confirmation prompt |

Examples:

```bash
bundle exec bin/scopes_extractor sync hackerone -v
bundle exec bin/scopes_extractor serve -p 8080 -b 127.0.0.1 --sync
```

## REST API

All endpoints return JSON. When `api.require_auth` is enabled, requests must include the `X-API-KEY` header matching the `API_KEY` environment variable.

```bash
curl -H "X-API-KEY: $API_KEY" "http://localhost:4567/?platform=hackerone&type=web&bounty=true"
```

| Endpoint | Description |
|----------|-------------|
| [`GET /`](#get-) | In-scope assets, with filters |
| [`GET /wildcards`](#get-wildcards) | Wildcard scopes only |
| [`GET /changes`](#get-changes) | Recent entries from the change history |
| [`GET /exclusions`](#get-exclusions) | Assets ignored during validation |
| [`GET /malformed-scopes`](#get-malformed-scopes) | Assets rejected for an invalid format |

### `GET /`

| Parameter | Type | Description |
|-----------|------|-------------|
| `platform` | string | Platform name, e.g. `hackerone` |
| `type` | string | Scope type, e.g. `web`, `mobile`, `api` |
| `bounty` | boolean | Only programs with (`true`) or without (`false`) bounty |
| `slug` | string | Program slug |
| `values_only` | boolean | Return a flat array of scope values |

<details>
<summary>Example response</summary>

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
    }
  ],
  "count": 1
}
```

With `values_only=true`:

```json
["*.example.com", "api.example.com"]
```

</details>

### `GET /wildcards`

| Parameter | Type | Description |
|-----------|------|-------------|
| `platform` | string | Platform name |
| `values_only` | boolean | Return a flat array of wildcard values |

The response has the same shape as `GET /`, under a `wildcards` key.

### `GET /changes`

| Parameter | Type | Description |
|-----------|------|-------------|
| `hours` | integer | Look-back window in hours (default: `24`) |
| `platform` | string | Platform name |
| `type` | string | Event type: `add_program`, `remove_program`, `add_scope` or `remove_scope` |

<details>
<summary>Example response</summary>

```json
{
  "changes": [
    {
      "id": 123,
      "program_id": 45,
      "program_slug": "example-program",
      "platform_name": "bugcrowd",
      "event_type": "add_scope",
      "scope_value": "newapp.example.com",
      "scope_type": "web",
      "created_at": "2026-01-10T14:30:00Z"
    }
  ],
  "count": 1
}
```

</details>

### `GET /exclusions`

Returns every asset ignored during validation, most recent first.

<details>
<summary>Example response</summary>

```json
{
  "exclusions": [
    {
      "id": 1,
      "platform": "hackerone",
      "program_slug": "example-program",
      "value": "example.com (production only)",
      "reason": "Invalid format for web scope",
      "created_at": "2026-01-09T10:00:00Z"
    }
  ],
  "count": 1
}
```

</details>

### `GET /malformed-scopes`

Returns assets rejected with an `Invalid format` reason, limited to programs that still exist and sorted by program slug, platform, then value. The response has the same fields as `GET /exclusions`, under a `malformed_scopes` key.

Once a scope passes validation on a later sync, it is removed from this list.

## Notifications

Two notifiers are available and can be enabled together: Discord webhooks and a generic HTTP webhook.

| Event | Triggered when |
|-------|----------------|
| `new_program` | A program is discovered |
| `removed_program` | A program is no longer available |
| `new_scope` | A scope is added to a program |
| `removed_scope` | A scope is removed from a program |
| `ignored_asset` | An asset fails validation |
| `error` | A synchronization fails (HTTP webhook only; Discord uses the dedicated `errors` webhook) |

Both notifiers accept `new_scope_types` to restrict `new_scope` notifications to certain scope types, e.g. `["web"]`. Leave it empty or `null` to receive all types.

### Discord

```yaml
discord:
  enabled: true
  webhooks:
    main:
      url: "https://discord.com/api/webhooks/.../xxx"
      events: ["new_program", "removed_program", "new_scope", "removed_scope", "ignored_asset"]
      new_scope_types: ["web"]
    errors:
      url: "https://discord.com/api/webhooks/.../yyy"
```

### HTTP webhook

Each event is sent as a JSON `POST` request:

```yaml
webhook:
  enabled: true
  url: "https://example.com/hooks/scopes"
  headers:
    Authorization: "Bearer ${WEBHOOK_TOKEN}"
  events: ["new_program", "removed_program", "new_scope", "removed_scope", "ignored_asset", "error"]
  new_scope_types: ["web"]
```

`${VAR}` placeholders in the URL and header values are replaced with the matching environment variable, so tokens can stay in `.env`.

All payloads share the same envelope:

```json
{
  "event": "new_scope",
  "timestamp": "2025-07-30T10:17:00Z",
  "data": {
    "platform": "yeswehack",
    "program": "Example Program",
    "value": "*.example.com",
    "type": "web"
  }
}
```

| Event | `data` fields |
|-------|---------------|
| `new_program` | `platform`, `program`, `slug`, `scopes_count`, `scopes` (count per type) |
| `removed_program` | `platform`, `program`, `slug` |
| `new_scope` | `platform`, `program`, `value`, `type` |
| `removed_scope` | `platform`, `program`, `value` |
| `ignored_asset` | `platform`, `program`, `value`, `reason` |
| `error` | `title`, `message` |

## Scope Processing

Scopes go through three steps before being stored: platform-specific normalization, global normalization, then type detection and validation. Assets that fail validation are recorded as exclusions and trigger an `ignored_asset` notification.

<details>
<summary><strong>Platform-specific normalization</strong></summary>

**YesWeHack**
- Expands hostname alternatives in parentheses or brackets: `(www|api).example.com` → `www.example.com`, `api.example.com`
- Preserves URL paths: `https://api-(eu|sg).example.com/connect` → `https://api-eu.example.com/connect`, `https://api-sg.example.com/connect`
- Removes soft hyphens and handles multi-part TLDs: `example.(com|co.uk)`
- Only expands the listed entries when a list contains `…`

**HackerOne**
- `example.*` → `example.com`
- `example.(TLD)` → `example.com`
- `domain1.com,domain2.com` → `domain1.com`, `domain2.com`

**Intigriti**
- `*.example.<tld>` → `*.example.com`
- `domain1.com / domain2.com` → `domain1.com`, `domain2.com`

**Bugcrowd**
- `example.com - Production` → `example.com`

</details>

<details>
<summary><strong>Global normalization</strong></summary>

- Leading dots become wildcards: `.example.com` → `*.example.com`
- Trailing slashes and wildcards are removed: `example.com/*` → `example.com`
- Values are lowercased: `Example.COM` → `example.com`
- Escaped characters and extra spaces are cleaned up

</details>

<details>
<summary><strong>Type detection</strong></summary>

The platform-provided type is overridden when the value matches a known pattern:

| Pattern | Type | Example |
|---------|------|---------|
| GitHub / GitLab URL | `source_code` | `https://github.com/user/repo` |
| Atlassian Marketplace | `source_code` | `https://marketplace.atlassian.com/apps/123` |
| App Store / Play Store URL | `mobile` | `https://apps.apple.com/app/id123` |
| Chrome Web Store | `executable` | `https://chrome.google.com/webstore/detail/ext` |
| CIDR notation | `cidr` | `192.168.1.0/24` |
| Wildcard domain | `web` | `*.example.com` |

</details>

<details>
<summary><strong>Validation rules</strong></summary>

Accepted: domains, subdomains, wildcards (`*.example.com`), URLs with or without paths, IP addresses and CIDR ranges.

Rejected:
- Values without a dot, unless they are IP addresses
- Multiple wildcards (`*.xyz.*.example.com`) or misplaced wildcards (`example*.com`)
- Template placeholders: `{id}`, `<identifier>`, `[name]`
- Descriptions in parentheses: `example.com (production only)`
- Unexpected punctuation (periods, commas, semicolons)
- Spaces, except in URL query parameters
- Values shorter than 4 characters
- `#` in the domain part (allowed in URL fragments)

</details>

## Development

```bash
bundle install
bundle exec rspec      # test suite
bundle exec rubocop    # linting
```

<details>
<summary><strong>Project structure</strong></summary>

```
ScopesExtractor/
├── bin/scopes_extractor        # CLI entry point
├── config/settings.yml         # Application settings
├── db/migrations/              # Sequel migrations
├── lib/scopes_extractor/
│   ├── api.rb                  # REST API (Sinatra)
│   ├── auto_sync.rb            # Background sync scheduler
│   ├── cli.rb                  # CLI commands (Thor)
│   ├── config.rb               # Configuration loader
│   ├── database.rb             # Connection and migrations
│   ├── diff_engine.rb          # Change detection
│   ├── http.rb                 # HTTP client
│   ├── normalizer.rb           # Scope normalization
│   ├── sync_manager.rb         # Sync orchestration
│   ├── validator.rb            # Scope validation
│   ├── models/                 # Data models
│   ├── notifiers/              # Discord and HTTP webhook
│   └── platforms/              # One directory per platform
└── spec/                       # RSpec tests
```

</details>

## License

Released under the [MIT License](LICENSE). Upgrading from 1.x? See the [CHANGELOG](CHANGELOG.md) for breaking changes.
