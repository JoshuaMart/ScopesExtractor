![Image](https://github.com/user-attachments/assets/8fa9dd2a-04c8-48d4-a0d7-6057c102436c)

A tool for monitoring bug bounty programs across multiple platforms to track scope changes.

[![Ruby](https://img.shields.io/badge/Ruby-3.4.2-red.svg)](https://www.ruby-lang.org/en/)
[![Docker](https://img.shields.io/badge/Docker-Supported-blue.svg)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![codeclimate](https://api.codeclimate.com/v1/badges/713b3c783fe46abaca0e/maintainability)](https://codeclimate.com/github/JoshuaMart/ScopesExtractor/maintainability/)

## 📖 Overview

Scopes Extractor is a Ruby application that monitors bug bounty programs. It tracks changes to program scopes (additions and removals) and sends notifications through Discord webhooks. The tool can be run in classic mode or API mode for querying the latest data.

## ✨ Features

- 🔍 Monitors multiple bug bounty platforms (YesWeHack, Immunefi, Hackerone & Bugcrowd)
- 🔄 Detects changes in program scopes
- 📏 Normalizes scope formats for better consistency (e.g., domain.(tld|xyz) becomes domain.tld and domain.xyz)
- 🚨 Sends notifications to Discord webhooks
- 🔌 Offers an API mode for querying data
- 🔄 Supports automatic synchronization with configurable intervals
- 🔐 Authentication with platforms including OTP support
- 💾 Persistent storage of program data in JSON format
- 📊 Historical tracking of changes with retention policy

## 🛠️ Installation

### Prerequisites

- Docker (recommended) or Ruby 3.4.2

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/JoshuaMart/ScopesExtractor
   cd ScopesExtractor
   ```

2. Create the environment file:
   ```bash
   cp .env.example .env
   ```

3. Configure your `.env` file with:
   - YesWeHack, Intigriti, Hackerone and Bugcrowd credentials (if applicable)
   - Discord webhook URLs
   - API settings
   - Synchronization options
   - History retention policy

4. Build the Docker image:
   ```bash
   docker build . -t scopes
   ```

## 🚀 Usage

### Classic Mode

Run the application in classic mode (no API):

```bash
docker run --mount type=bind,source="$(pwd)/libs/db/db.json",target=/app/libs/db/db.json --mount type=bind,source="$(pwd)/libs/db/history.json",target=/app/libs/db/history.json scopes
```

### API Mode

Run the application in API mode to expose HTTP endpoints for querying the data:

```bash
docker run -p 4567:4567 --mount type=bind,source="$(pwd)/libs/db/db.json",target=/app/libs/db/db.json --mount type=bind,source="$(pwd)/libs/db/history.json",target=/app/libs/db/history.json scopes
```

When in API mode, you can query the data by sending a request to the endpoint with your configured API key:

```bash
# Get current program data
curl -H "X-API-Key: your_api_key_here" http://localhost:4567

# Get recent changes (last 48 hours by default)
curl -H "X-API-Key: your_api_key_here" http://localhost:4567/changes

# Get changes from the last 24 hours
curl -H "X-API-Key: your_api_key_here" "http://localhost:4567/changes?hours=24"

# Filter changes by platform
curl -H "X-API-Key: your_api_key_here" "http://localhost:4567/changes?platform=YesWeHack"

# Filter by change type (add_program, remove_program, add_scope, remove_scope)
curl -H "X-API-Key: your_api_key_here" "http://localhost:4567/changes?type=add_scope"

# Filter by program name
curl -H "X-API-Key: your_api_key_here" "http://localhost:4567/changes?program=ProgramName"

# Combine filters
curl -H "X-API-Key: your_api_key_here" "http://localhost:4567/changes?hours=72&platform=Hackerone&type=add_scope"
```

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `API_MODE` | Enable/disable API mode | `false` |
| `API_KEY` | API key for authentication | `""` |
| `AUTO_SYNC` | Enable/disable automatic synchronization | `false` |
| `SYNC_DELAY` | Delay between synchronizations (in seconds) | `10800` |
| `HISTORY_RETENTION_DAYS` | Number of days to retain change history | `30` |
| `YWH_SYNC` | Enable YesWeHack synchronization | `false` |
| `YWH_EMAIL` | YesWeHack email | `""` |
| `YWH_PWD` | YesWeHack password | `""` |
| `YWH_OTP` | YesWeHack OTP secret | `""` |
| `INTIGRITI_SYNC` | Enable Intigriti synchronization | `false` |
| `INTIGRITI_TOKEN` | Intigriti API Token | `""` |
| `H1_SYNC` | Enable Hackerone synchronization | `false` |
| `H1_USERNAME` | Hackerone username | `""` |
| `H1_TOKEN` | Hackerone API Token | `""` |
| `BC_SYNC` | Enable Bugcrowd synchronization | `false` |
| `BC_EMAIL` | Bugcrowd email | `""` |
| `BC_PWD` | Bugcrowd password | `""` |
| `BC_OTP` | Bugcrowd OTP secret | `""` |
| `IMMUNEFI_SYNC` | Enable Immunefi synchronization | `false` |
| `DISCORD_WEBHOOK` | Discord webhook URL for program notifications | `""` |
| `DISCORD_LOGS_WEBHOOK` | Discord webhook URL for log notifications | `""` |

### 📊 Exclusions

You can configure pattern exclusions in `config/exclusions.yml` to filter out specific scopes.

## ✋ FAQ

<details>
  <summary>Intigriti - Failed to fetch program ... 403</summary>

  Programs must be manually accepted on the Intigriti website in order to be able to consult them.
</details>

<details>
  <summary>Error : Invalid OTP code</summary>

  The most likely reason is that your server's time is not correct, so the generated OTP code is not correct either.
</details>

<details>
  <summary>Change History Informations</summary>

  ScopesExtractor now tracks all changes (program and scope additions/removals) with timestamps. This history is automatically managed with a configurable retention policy to avoid excessive growth. By default, changes are kept for 30 days.

  You can query recent changes through the API (only) to see what has changed in the last few hours or days, which is useful for keeping track of bug bounty program changes even if you missed the Discord notifications.

  The changes reflect what is detected by ScopesExtractor (addition/removal of scopes and programs) and not the modifications indicated directly on the program page of each platform.
</details>

## 📜 License

This project is open-source and available under the MIT License.
