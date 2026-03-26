#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import concurrent.futures
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

from openai import AzureOpenAI

DEFAULT_SIZE = "1024x1024"
DEFAULT_QUALITY = "high"
DEFAULT_OUTPUT_FORMAT = "png"
ALLOWED_SIZES = {"1024x1024", "1536x1024", "1024x1536", "auto"}
ALLOWED_QUALITIES = {"low", "medium", "high", "auto"}
ALLOWED_BACKGROUNDS = {"transparent", "opaque", "auto", None}


def die(message: str, code: int = 1) -> None:
    print(f"Error: {message}", file=sys.stderr)
    raise SystemExit(code)


def warn(message: str) -> None:
    print(f"Warning: {message}", file=sys.stderr)


def require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        die(f"Missing environment variable: {name}")
    return value


def validate_size(size: str) -> None:
    if size not in ALLOWED_SIZES:
        die("size must be one of 1024x1024, 1536x1024, 1024x1536, or auto")


def validate_quality(quality: str) -> None:
    if quality not in ALLOWED_QUALITIES:
        die("quality must be one of low, medium, high, or auto")


def validate_background(background: str | None) -> None:
    if background not in ALLOWED_BACKGROUNDS:
        die("background must be one of transparent, opaque, or auto")


def normalize_output_format(fmt: str | None) -> str:
    if not fmt:
        return DEFAULT_OUTPUT_FORMAT
    fmt = fmt.lower()
    if fmt == "jpg":
        fmt = "jpeg"
    if fmt not in {"png", "jpeg", "webp"}:
        die("output-format must be png, jpeg, jpg, or webp")
    return fmt


def ensure_transparency(background: str | None, output_format: str) -> None:
    if background == "transparent" and output_format not in {"png", "webp"}:
        die("transparent background requires png or webp")


def fields_from_args(args: argparse.Namespace) -> dict[str, str | None]:
    return {
        "use_case": getattr(args, "use_case", None),
        "scene": getattr(args, "scene", None),
        "subject": getattr(args, "subject", None),
        "style": getattr(args, "style", None),
        "composition": getattr(args, "composition", None),
        "lighting": getattr(args, "lighting", None),
        "palette": getattr(args, "palette", None),
        "materials": getattr(args, "materials", None),
        "text": getattr(args, "text", None),
        "constraints": getattr(args, "constraints", None),
        "negative": getattr(args, "negative", None),
    }


def augment_prompt(prompt: str, fields: dict[str, str | None], enabled: bool = True) -> str:
    if not enabled:
        return prompt.strip()
    sections: list[str] = []
    if fields.get("use_case"):
        sections.append(f"Use case: {fields['use_case']}")
    sections.append(f"Primary request: {prompt.strip()}")
    if fields.get("scene"):
        sections.append(f"Scene/background: {fields['scene']}")
    if fields.get("subject"):
        sections.append(f"Subject: {fields['subject']}")
    if fields.get("style"):
        sections.append(f"Style/medium: {fields['style']}")
    if fields.get("composition"):
        sections.append(f"Composition/framing: {fields['composition']}")
    if fields.get("lighting"):
        sections.append(f"Lighting/mood: {fields['lighting']}")
    if fields.get("palette"):
        sections.append(f"Color palette: {fields['palette']}")
    if fields.get("materials"):
        sections.append(f"Materials/textures: {fields['materials']}")
    if fields.get("text"):
        sections.append(f"Text (verbatim): \"{fields['text']}\"")
    if fields.get("constraints"):
        sections.append(f"Constraints: {fields['constraints']}")
    if fields.get("negative"):
        sections.append(f"Avoid: {fields['negative']}")
    return "\n".join(sections)


def build_client(args: argparse.Namespace) -> AzureOpenAI:
    endpoint = args.endpoint or require_env("AZURE_OPENAI_ENDPOINT")
    api_key = args.api_key or require_env("AZURE_OPENAI_API_KEY")
    api_version = args.api_version or require_env("AZURE_OPENAI_API_VERSION")
    return AzureOpenAI(azure_endpoint=endpoint, api_key=api_key, api_version=api_version)


def deployment_name(args: argparse.Namespace, job: dict[str, Any] | None = None) -> str:
    if job and str(job.get("deployment", "")).strip():
        return str(job["deployment"]).strip()
    if args.deployment:
        return args.deployment
    return require_env("AZURE_OPENAI_IMAGE_DEPLOYMENT")


def build_output_paths(out: str, output_format: str, count: int, out_dir: str | None) -> list[Path]:
    ext = "." + output_format
    if out_dir:
        base_dir = Path(out_dir)
        base_dir.mkdir(parents=True, exist_ok=True)
        return [base_dir / f"image_{i}{ext}" for i in range(1, count + 1)]
    out_path = Path(out)
    if out_path.suffix == "":
        out_path = out_path.with_suffix(ext)
    if count == 1:
        return [out_path]
    return [out_path.with_name(f"{out_path.stem}-{i}{out_path.suffix}") for i in range(1, count + 1)]


def decode_and_write(images: list[str], outputs: list[Path], force: bool) -> None:
    for idx, b64_data in enumerate(images):
        out = outputs[idx]
        if out.exists() and not force:
            die(f"Output already exists: {out} (use --force to overwrite)")
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(base64.b64decode(b64_data))
        print(f"Wrote {out}")


def read_prompt(prompt: str | None, prompt_file: str | None) -> str:
    if prompt and prompt_file:
        die("Use --prompt or --prompt-file, not both")
    if prompt_file:
        path = Path(prompt_file)
        if not path.exists():
            die(f"Prompt file not found: {path}")
        return path.read_text(encoding="utf-8").strip()
    if prompt:
        return prompt.strip()
    die("Missing prompt")
    return ""


def print_payload(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, indent=2, ensure_ascii=False, sort_keys=True))


def generate_one(client: AzureOpenAI, payload: dict[str, Any]) -> list[str]:
    response = client.images.generate(**payload)
    data = getattr(response, "data", None) or []
    images: list[str] = []
    for item in data:
        b64_json = getattr(item, "b64_json", None) or (item.get("b64_json") if isinstance(item, dict) else None)
        if not b64_json:
            die("Azure response did not contain b64_json image data")
        images.append(b64_json)
    if not images:
        die("Azure returned no images")
    return images


def slugify(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    value = re.sub(r"-{2,}", "-", value).strip("-")
    return value[:60] if value else "job"


def read_jobs_jsonl(path: str) -> list[dict[str, Any]]:
    file_path = Path(path)
    if not file_path.exists():
        die(f"Input file not found: {file_path}")
    jobs: list[dict[str, Any]] = []
    for line_no, raw in enumerate(file_path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        try:
            job = json.loads(line)
        except json.JSONDecodeError as exc:
            die(f"Invalid JSON on line {line_no}: {exc}")
        if not str(job.get("prompt", "")).strip():
            die(f"Missing prompt on line {line_no}")
        jobs.append(job)
    if not jobs:
        die("No jobs found in input file")
    return jobs


def job_output_paths(out_dir: Path, output_format: str, idx: int, prompt: str, explicit_out: str | None) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    ext = "." + output_format
    if explicit_out:
        path = out_dir / Path(explicit_out).name
        if path.suffix == "":
            path = path.with_suffix(ext)
        return [path]
    return [out_dir / f"{idx:03d}-{slugify(prompt)}{ext}"]


def cmd_generate(args: argparse.Namespace) -> int:
    prompt = read_prompt(args.prompt, args.prompt_file)
    validate_size(args.size)
    validate_quality(args.quality)
    validate_background(args.background)
    output_format = normalize_output_format(args.output_format)
    ensure_transparency(args.background, output_format)
    deployment = deployment_name(args)
    final_prompt = augment_prompt(prompt, fields_from_args(args), enabled=not args.no_augment)
    payload = {
        "model": deployment,
        "prompt": final_prompt,
        "size": args.size,
        "quality": args.quality,
        "n": args.n,
        "output_format": output_format,
    }
    if args.background is not None:
        payload["background"] = args.background
    outputs = build_output_paths(args.out, output_format, args.n, args.out_dir)
    if args.dry_run:
        print_payload({"deployment": deployment, "outputs": [str(p) for p in outputs], **payload})
        return 0
    client = build_client(args)
    images = generate_one(client, payload)
    decode_and_write(images, outputs, args.force)
    return 0


def run_batch_job(base_args: argparse.Namespace, job: dict[str, Any], idx: int, out_dir: Path, dry_run: bool) -> dict[str, Any]:
    size = str(job.get("size", base_args.size))
    quality = str(job.get("quality", base_args.quality))
    background = job.get("background", base_args.background)
    output_format = normalize_output_format(job.get("output_format", base_args.output_format))
    validate_size(size)
    validate_quality(quality)
    validate_background(background)
    ensure_transparency(background, output_format)
    prompt = str(job.get("prompt", "")).strip()
    fields = {
        "use_case": job.get("use_case", base_args.use_case),
        "scene": job.get("scene", base_args.scene),
        "subject": job.get("subject", base_args.subject),
        "style": job.get("style", base_args.style),
        "composition": job.get("composition", base_args.composition),
        "lighting": job.get("lighting", base_args.lighting),
        "palette": job.get("palette", base_args.palette),
        "materials": job.get("materials", base_args.materials),
        "text": job.get("text", base_args.text),
        "constraints": job.get("constraints", base_args.constraints),
        "negative": job.get("negative", base_args.negative),
    }
    final_prompt = augment_prompt(prompt, fields, enabled=not base_args.no_augment)
    deployment = deployment_name(base_args, job)
    payload = {
        "model": deployment,
        "prompt": final_prompt,
        "size": size,
        "quality": quality,
        "n": int(job.get("n", 1)),
        "output_format": output_format,
    }
    if background is not None:
        payload["background"] = background
    outputs = job_output_paths(out_dir, output_format, idx, prompt, job.get("out"))
    if dry_run:
        return {"job": idx, "deployment": deployment, "outputs": [str(p) for p in outputs], **payload}
    client = build_client(base_args)
    images = generate_one(client, payload)
    decode_and_write(images, outputs, base_args.force)
    return {"job": idx, "outputs": [str(p) for p in outputs]}


def cmd_generate_batch(args: argparse.Namespace) -> int:
    jobs = read_jobs_jsonl(args.input)
    out_dir = Path(args.out_dir)
    if args.dry_run:
        for idx, job in enumerate(jobs, start=1):
            print_payload(run_batch_job(args, job, idx, out_dir, True))
        return 0
    max_workers = max(1, int(args.concurrency))
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(run_batch_job, args, job, idx, out_dir, False): idx for idx, job in enumerate(jobs, start=1)}
        for future in concurrent.futures.as_completed(futures):
            idx = futures[future]
            try:
                result = future.result()
                print(f"[job {idx}/{len(jobs)}] completed {result['outputs']}")
            except Exception as exc:
                die(f"batch job {idx} failed: {exc}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Azure OpenAI image generation helper")
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--deployment")
    common.add_argument("--endpoint")
    common.add_argument("--api-key")
    common.add_argument("--api-version")
    common.add_argument("--size", default=DEFAULT_SIZE)
    common.add_argument("--quality", default=DEFAULT_QUALITY)
    common.add_argument("--background")
    common.add_argument("--output-format", default=DEFAULT_OUTPUT_FORMAT)
    common.add_argument("--use-case")
    common.add_argument("--scene")
    common.add_argument("--subject")
    common.add_argument("--style")
    common.add_argument("--composition")
    common.add_argument("--lighting")
    common.add_argument("--palette")
    common.add_argument("--materials")
    common.add_argument("--text")
    common.add_argument("--constraints")
    common.add_argument("--negative")
    common.add_argument("--no-augment", action="store_true")
    common.add_argument("--force", action="store_true")
    common.add_argument("--dry-run", action="store_true")

    sub = parser.add_subparsers(dest="command", required=True)

    gen = sub.add_parser("generate", parents=[common])
    gen.add_argument("--prompt")
    gen.add_argument("--prompt-file")
    gen.add_argument("--out", default="output/imagegen/output.png")
    gen.add_argument("--out-dir")
    gen.add_argument("--n", type=int, default=1)
    gen.set_defaults(func=cmd_generate)

    batch = sub.add_parser("generate-batch", parents=[common])
    batch.add_argument("--input", required=True)
    batch.add_argument("--out-dir", required=True)
    batch.add_argument("--concurrency", type=int, default=3)
    batch.set_defaults(func=cmd_generate_batch)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
