# local-ai-coding-lab

Private, reproducible and self-hosted local AI coding environment using Docker Compose, Ollama, Open WebUI and local coding LLMs.

> Run coding-focused AI locally with privacy, reproducibility and no cloud dependency.

---

## Overview

`local-ai-coding-lab` is a lightweight, reproducible and privacy-oriented local AI environment for software development.

The project provides a simple stack for running local coding LLMs using:

- Docker Compose
- Ollama
- Open WebUI
- local coding models (Qwen, DeepSeek, etc.)
- Aider running on the host (optional)

The main goal is to offer a secure and reproducible coding assistant environment without relying on cloud APIs or external inference providers.

---

## Goals

- Run coding-focused LLMs locally
- Preserve source-code privacy
- Avoid vendor lock-in
- Keep setup reproducible across machines
- Support WSL2/Linux workflows
- Maintain operational simplicity

---

## Architecture

```text
WSL2 / Linux Host
└── Docker Compose
    ├── Ollama
    │   └── Local LLMs
    └── Open WebUI
        └── Local Chat Interface

Host / WSL
└── Aider (optional)
     ↓ localhost
   Ollama API
```

---

## Features

- Local inference
- No cloud dependency
- Self-hosted coding models
- Dockerized setup
- Local-only binding (`127.0.0.1`)
- Persistent models and configuration
- Compatible with Aider
- Reproducible environment

---

## Tech Stack

| Component | Purpose |
|---|---|
| Ollama | Local LLM runtime |
| Open WebUI | Local chat interface |
| Docker Compose | Reproducible environment |
| Aider | AI coding assistant (host side) |
| Qwen / DeepSeek | Coding models |

---

## Why this project?

Most AI coding assistants depend on external APIs and remote inference.

That creates concerns regarding:

- source code privacy
- data leakage
- reproducibility
- cloud dependency
- cost predictability

This project aims to provide a pragmatic alternative:

> local-first AI for software development.

---

## Project Structure

```text
.
├── docker-compose.yml
├── .env.example
├── Makefile
├── README.md
├── scripts/
│   ├── pull-model.sh
│   ├── run-model.sh
│   ├── test-ollama.sh
│   └── test-open-webui.sh
└── docs/
```

---

## Requirements

Recommended:

- Linux or WSL2
- Docker
- Docker Compose
- 16 GB RAM minimum
- 32 GB RAM recommended for larger models

Optional:

- NVIDIA GPU

---

## Quick Start

Clone the repository:

```bash
git clone https://github.com/<your-user>/local-ai-coding-lab.git
cd local-ai-coding-lab
```

Copy environment variables:

```bash
cp .env.example .env
```

Start services:

```bash
docker compose up -d
```

Verify containers:

```bash
docker compose ps
```

---

## Pull a Model

Recommended starter model:

```text
qwen2.5-coder:7b
```

Download model:

```bash
make pull-model
```

Or manually:

```bash
docker exec -it ai-ollama ollama pull qwen2.5-coder:7b
```

---

## Test Ollama

Check if the API is running:

```bash
curl http://127.0.0.1:11434/api/tags
```

Expected result:

A JSON response listing installed models.

---

## Open WebUI

Access:

```text
http://127.0.0.1:3000
```

Open WebUI provides a ChatGPT-like local interface powered by Ollama.

---

## Using Aider (Optional)

Install on host:

```bash
pipx install aider-chat
```

Run inside a Git repository:

```bash
cd my-project

aider \
  --model ollama/qwen2.5-coder:7b
```

Aider will use the local Ollama instance.

No external API required.

---

## Privacy and Security

Design principles:

- local-first
- no cloud dependency
- localhost-only binding
- no exposed services
- no Docker privileged mode
- no mounted SSH keys
- no Docker socket exposure

By default:

- services bind to `127.0.0.1`
- models are stored locally
- no external inference provider is required

---

## Performance Recommendations

### Recommended

Keep repositories inside WSL filesystem:

Good:

```text
~/workspace/project
```

Avoid:

```text
/mnt/c/project
```

Reason:

NTFS mounts in WSL can significantly reduce filesystem performance.

### Model sizing

| Model | Recommended RAM |
|---|---:|
| 7B | 8–12 GB |
| 14B | 16–24 GB |
| 32B | 32+ GB |

Start small.

Recommended first model:

```text
qwen2.5-coder:7b
```

---

## NVIDIA GPU (Optional)

GPU acceleration can be enabled using:

- NVIDIA drivers
- NVIDIA Container Toolkit

Documentation and setup instructions may vary depending on OS and GPU model.

---

## Troubleshooting

### Open WebUI cannot connect to Ollama

Check containers:

```bash
docker compose ps
```

Check logs:

```bash
docker compose logs
```

---

### No models available

Verify installed models:

```bash
docker exec -it ai-ollama ollama list
```

---

### Slow performance

Possible causes:

- model too large
- insufficient RAM
- repository stored under `/mnt/c`
- CPU-only inference

---

## Roadmap

Planned ideas:

- optional GPU profile
- model presets
- automated health checks
- offline bootstrap scripts
- local embeddings support

---

## Philosophy

> Your code. Your models. Your machine.

---

## License

Choose your preferred license.

Suggested:

- MIT
- Apache-2.0
