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

4. Build the Docker image:
   ```bash
   docker build . -t scopes
   ```

## 🚀 Usage

### Classic Mode

Run the application in classic mode (no API):

```bash
docker run --mount type=bind,source="$(pwd)/libs/db/db.json",target=/app/libs/db/db.json scopes
```

### API Mode

Run the application in API mode to expose an HTTP endpoint for querying the data:

```bash
docker run -p 4567:4567 --mount type=bind,source="$(pwd)/libs/db/db.json",target=/app/libs/db/db.json scopes
```

When in API mode, you can query the data by sending a request to the endpoint with your configured API key:

```bash
curl -H "X-API-Key: your_api_key_here" http://localhost:4567
```

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `API_MODE` | Enable/disable API mode | `false` |
| `API_KEY` | API key for authentication | `""` |
| `AUTO_SYNC` | Enable/disable automatic synchronization | `false` |
| `SYNC_DELAY` | Delay between synchronizations (in seconds) | `10800` |
| `YWH_EMAIL` | YesWeHack email | `""` |
| `YWH_PWD` | YesWeHack password | `""` |
| `YWH_OTP` | YesWeHack OTP secret | `""` |
| `INTIGRITI_TOKEN` | Intigriti API Token | `""` |
| `H1_USERNAME` | Hackerone username | `""` |
| `H1_TOKEN` | Hackerone API Token | `""` |
| `BC_EMAIL` | Bugcrowd email | `""` |
| `BC_PWD` | Bugcrowd password | `""` |
| `DISCORD_WEBHOOK` | Discord webhook URL for program notifications | `""` |
| `DISCORD_LOGS_WEBHOOK` | Discord webhook URL for log notifications | `""` |

### Exclusions

You can configure pattern exclusions in `config/exclusions.yml` to filter out specific scopes.

## 📝 TODO

- [ ] Improve Bugcrowd normalization
- [ ] Improve YesWeHack normalization

## 📜 License

This project is open-source and available under the MIT License.
