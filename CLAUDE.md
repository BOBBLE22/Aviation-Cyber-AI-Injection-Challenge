# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A prompt-injection CTF. A Flask app serves a chat UI where players try to extract a hidden `AstroSec{...}` flag from each of several themed LLM personas (levels 1–5 plus a "Fun" level). Each level is a hardened system prompt with an intentionally-planted bypass path.

## Commands

```bash
# Install
pip install -r requirements.txt

# Run (dev)
python Flash.py              # serves on http://localhost:5000

# Run (prod-ish, gunicorn is in requirements)
gunicorn -b 0.0.0.0:5000 Flash:app
```

There are no tests, linters, or build step. Verify changes by running the app and driving the chat UI.

## Architecture

Everything lives in **`Flash.py`** (~280 lines) plus one Jinja template and static images.

- **`LEVELS` dict** — the entire challenge content. Each entry: a primary `provider`/`model`, an ordered `fallbacks` list, the `system` prompt (persona + the planted vulnerability), and the `flag`. Adding or editing a level = editing this dict only.
- **Multi-provider abstraction** — five backends (`gemini`, `groq`, `mistral`, `openrouter`, `nvidia`), each wrapped by a `call_<provider>(model, system, message)` function returning plain reply text. `PROVIDERS` maps name → function. OpenRouter and Nvidia both reuse the OpenAI SDK with a custom `base_url`.
- **Fallback chain** — `/chat/<level_id>` tries the primary config, then each fallback in order, catching any exception and moving on. This exists because free-tier API keys hit rate limits (429); the front-of-house behavior is a level staying reachable even when one provider is throttled. `429`/quota/rate errors after exhausting all providers return a themed "relay congested" message.
- **Statelessness** — `/chat` reads only the current `message`; **no conversation history is sent to the model**. Each turn is independent. The frontend (`templates/index.html`) keeps per-level history for *display only*. Note level 5's "loyalty gate" prompt assumes multi-turn buildup that the backend does not actually provide — keep this in mind when editing that level.

## Keys / config

Provider keys come from a git-ignored `.env` via `python-dotenv`: `GROQ_API_KEY`, `MISTRAL_API_KEY`, `OPENROUTER_API_KEY`, `NVIDIA_API_KEY`, and Gemini's key (read by the `google-genai` client from its default env var). A missing key surfaces at call time and just triggers the fallback chain.

## Adding a level

1. Add an entry to `LEVELS` (pick a primary provider + fallbacks that use models you have keys for).
2. Add its 3 images under `static/<Level Name>/` and wire them into the image map in `templates/index.html`.
3. Add the level to the `<select id="level-select">` dropdown in the template.
