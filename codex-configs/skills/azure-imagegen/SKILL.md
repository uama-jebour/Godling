---
name: azure-imagegen
description: Generate game/UI bitmap assets with Azure OpenAI image models when the user has Azure credentials instead of a standard OpenAI API key. Use for portraits, textures, backgrounds, card surfaces, and batch asset generation. Do not use for vector icons, deterministic SVG assets, or non-Azure image workflows.
---

# Azure Imagegen

## Overview

Use this skill when the user wants image generation through Azure OpenAI instead of the standard OpenAI Images API.

This skill is for bitmap asset production such as:
- character portraits
- combat backgrounds
- UI textures
- card surfaces
- mockups

This skill is not for:
- SVG or icon systems
- code-native UI layout
- non-Azure OpenAI workflows

## Workflow

1. Confirm the request is a new image-generation task, not a vector-editing task.
2. Prefer project-bound outputs under the current workspace.
3. Check Azure environment variables before generating:
   - `AZURE_OPENAI_API_KEY`
   - `AZURE_OPENAI_ENDPOINT`
   - `AZURE_OPENAI_API_VERSION`
   - `AZURE_OPENAI_IMAGE_DEPLOYMENT`
4. Build a structured prompt with:
   - use case
   - subject
   - style
   - composition
   - lighting
   - palette
   - materials
   - constraints
5. Use `scripts/azure_image_gen.py`.
6. For many assets, use `generate-batch` with JSONL input under `tmp/imagegen/`.
7. Save finals under `output/imagegen/` unless the user requests another destination.
8. Report the final output paths and the exact deployment used.

## Commands

Single image:

```bash
python3 ~/.codex/skills/azure-imagegen/scripts/azure_image_gen.py generate \
  --prompt "Pilgrim hero bust portrait for a dark ritual fantasy RPG UI" \
  --background transparent \
  --size 1024x1536 \
  --out output/imagegen/hero-pilgrim-a01.png
```

Batch:

```bash
python3 ~/.codex/skills/azure-imagegen/scripts/azure_image_gen.py generate-batch \
  --input tmp/imagegen/jobs.jsonl \
  --out-dir output/imagegen/batch
```

Dry-run:

```bash
python3 ~/.codex/skills/azure-imagegen/scripts/azure_image_gen.py generate \
  --prompt "Test" \
  --out output/imagegen/test.png \
  --dry-run
```

## Output policy

- Use non-destructive filenames by default.
- Do not overwrite existing outputs unless `--force` is provided.
- Keep project-bound outputs inside the workspace.
- Use `png` for transparent-background UI assets.

## When To Read References

- Read `references/azure-openai-setup.md` when you need environment-variable setup, deployment naming guidance, or Azure-specific constraints.

