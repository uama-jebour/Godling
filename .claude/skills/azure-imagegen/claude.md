# Azure Image Generation Skill

## 何时使用

当用户需要通过 Azure OpenAI 生成或编辑图像资源时使用本 skill。

支持的工作流：
- 文生图 (`generate`)
- 图文生图 (`edit`)
- 批量生成 (`generate-batch`)

## 环境变量要求

必须设置以下环境变量：
- `AZURE_OPENAI_API_KEY`
- `AZURE_OPENAI_ENDPOINT`
- `AZURE_OPENAI_API_VERSION`
- `AZURE_OPENAI_IMAGE_DEPLOYMENT`

## 使用方式

### 1. 单张生成

```bash
python3 codex-configs/skills/azure-imagegen/scripts/azure_image_gen.py generate \
  --prompt "Dark fantasy pilgrim hero, full-body standing" \
  --use-case stylized-concept \
  --asset-type "battle unit illustration" \
  --background transparent \
  --size 1024x1536 \
  --out output/imagegen/hero-pilgrim.png
```

### 2. 编辑图像

```bash
python3 codex-configs/skills/azure-imagegen/scripts/azure_image_gen.py edit \
  --image input/base.png \
  --prompt "Remove only background, keep subject unchanged" \
  --use-case background-extraction \
  --input-fidelity high \
  --background transparent \
  --out output/imagegen/base-cutout.png
```

### 3. 批量生成

```bash
python3 codex-configs/skills/azure-imagegen/scripts/azure_image_gen.py generate-batch \
  --input codex-configs/skills/azure-imagegen/examples/godling_batch1.jsonl \
  --out-dir output/imagegen/batch
```

### 4. Dry-run 验证

```bash
python3 codex-configs/skills/azure-imagegen/scripts/azure_image_gen.py generate \
  --prompt "test" \
  --out output/imagegen/test.png \
  --dry-run
```

## Prompt 构建规范

必须遵循 OpenAI 图像生成指南的结构：

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

### Use-case 分类 slug（生成）
- `photorealistic-natural`
- `product-mockup`
- `ui-mockup`
- `infographic-diagram`
- `logo-brand`
- `illustration-story`
- `stylized-concept`
- `historical-scene`

### Use-case 分类 slug（编辑）
- `text-localization`
- `identity-preserve`
- `precise-object-edit`
- `lighting-weather`
- `background-extraction`
- `style-transfer`
- `compositing`
- `sketch-to-render`

## 输出规范

- 输出目录优先使用 `output/imagegen/`
- 除非使用 `--force`，否则不覆盖已有文件
- 透明背景资源使用 `png` 或 `webp` 格式
- 报告最终输出路径和使用的部署

## 批量生成 JSONL 格式

```jsonl
{"prompt": "描述文本", "use_case": "stylized-concept", "size": "1024x1536", "out": "custom-name.png"}
{"prompt": "另一个描述", "use_case": "ui-mockup", "background": "transparent"}
```

## 注意事项

- 长迭代工作时，每次迭代只做一个针对性修改
- 图像内文字必须使用 `--text` 参数提供精确文本
- 严格保留编辑时，结合 `--use-case identity-preserve` 和明确的约束条件
