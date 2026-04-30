# Settings AI — CLI providers

TicketBrainy can use either an API key provider or a CLI provider configured on
the server. CLI providers must be installed and authenticated on the production
host before they can be selected in **Settings -> AI**.

## Claude Code CLI

Install and authenticate on the host:

```bash
npm install -g @anthropic-ai/claude-code
claude auth login
claude auth status
```

Default host paths used by the production compose file:

```env
CLAUDE_CLI_PATH=claude
HOST_CLAUDE_CREDS_FILE=/root/.claude/.credentials.json
HOST_CLAUDE_CONFIG_FILE=/root/.claude.json
```

After authentication, open **Settings -> AI -> AI provider** and select
**Claude Code CLI**.

## Codex CLI

Install and authenticate on the host:

```bash
npm install -g @openai/codex
codex login
codex login status
```

Default host path:

```env
CODEX_CLI_PATH=codex
HOST_CODEX_DIR=/root/.codex
```

After authentication, open **Settings -> AI -> AI provider** and select
**Codex CLI**.

## Verify inside containers

Run checks with the application user, not root:

```bash
docker compose exec -T -u 1001 web claude auth status
docker compose exec -T -u 1001 ai-service claude auth status
docker compose exec -T -u 1001 web codex login status
docker compose exec -T -u 1001 ai-service codex login status
```

If a CLI was authenticated after the containers were started, recreate only the
affected services:

```bash
docker compose up -d --no-deps web ai-service
```
