---
name: azure-imagegen
description: Generate or edit raster game/UI assets with Azure OpenAI image models, aligned with OpenAI curated imagegen skill and gpt-image-1.5 prompting guide.
---

# Azure Imagegen

## Overview

Use this skill when the user wants image generation/editing through **Azure OpenAI**.

Supported workflows:
- text → image (`generate`)
- text + image(s) → image (`edit`)
- batch text → image (`generate-batch`)

Not for:
- SVG/icon vector systems
- code-native layout work
- non-Azure API flows

## Required environment variables

- `AZURE_OPENAI_API_KEY`
- `AZURE_OPENAI_ENDPOINT`
- `AZURE_OPENAI_API_VERSION`
- `AZURE_OPENAI_IMAGE_DEPLOYMENT`

## Prompt policy (strict)

Prompt scaffolding follows OpenAI guide order:

```text
Use case: <taxonomy slug>
Asset type: <where the asset will be used>
Primary request: <main request>
Input images: <Image 1 role; Image 2 role> (optional)
Scene/backdrop: <environment>
Subject: <main subject>
Style/medium: <style>
Composition/framing: <framing>
Lighting/mood: <lighting>
Color palette: <palette>
Materials/textures: <materials>
Text (verbatim): "<exact text>"
Constraints: <must keep / must avoid>
Avoid: <negative constraints>
```

### Use-case taxonomy slugs (exact)

Generate:
- `photorealistic-natural`
- `product-mockup`
- `ui-mockup`
- `infographic-diagram`
- `logo-brand`
- `illustration-story`
- `stylized-concept`
- `historical-scene`

Edit:
- `text-localization`
- `identity-preserve`
- `precise-object-edit`
- `lighting-weather`
- `background-extraction`
- `style-transfer`
- `compositing`
- `sketch-to-render`

## Commands

### 1) Generate

```bash
python3 ~/.codex/skills/azure-imagegen/scripts/azure_image_gen.py generate \
  --prompt "Dark fantasy pilgrim hero, full-body standing" \
  --use-case stylized-concept \
  --asset-type "battle unit illustration" \
  --background transparent \
  --size 1024x1536 \
  --out output/imagegen/hero-pilgrim.png
```

### 2) Edit

```bash
python3 ~/.codex/skills/azure-imagegen/scripts/azure_image_gen.py edit \
  --image input/base.png \
  --prompt "Remove only background, keep subject unchanged" \
  --use-case background-extraction \
  --input-fidelity high \
  --background transparent \
  --out output/imagegen/base-cutout.png
```

For multi-image edit, repeat `--image`.

### 3) Batch

```bash
python3 ~/.codex/skills/azure-imagegen/scripts/azure_image_gen.py generate-batch \
  --input tmp/imagegen/jobs.jsonl \
  --out-dir output/imagegen/batch
```

### 4) Dry-run

```bash
python3 ~/.codex/skills/azure-imagegen/scripts/azure_image_gen.py generate \
  --prompt "test" \
  --out output/imagegen/test.png \
  --dry-run
```

## Output policy

- Keep outputs project-bound (`output/imagegen/` preferred).
- No overwrite unless `--force`.
- For transparent assets, use `--background transparent` and `png`/`webp`.
- Report final output paths and deployment used.

## Notes

- For long iterative work, prefer one targeted change per iteration.
- For in-image text, always use `--text` with exact verbatim copy.
- For strict preservation edits, combine `--use-case identity-preserve` + explicit constraints.
