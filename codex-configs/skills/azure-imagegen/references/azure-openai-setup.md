# Azure OpenAI Image Generation Setup

## Required environment variables

- `AZURE_OPENAI_API_KEY`
- `AZURE_OPENAI_ENDPOINT`
- `AZURE_OPENAI_API_VERSION`
- `AZURE_OPENAI_IMAGE_DEPLOYMENT`

## Example shell setup

```bash
export AZURE_OPENAI_API_KEY="..."
export AZURE_OPENAI_ENDPOINT="https://YOUR_RESOURCE_NAME.openai.azure.com"
export AZURE_OPENAI_API_VERSION="2025-04-01-preview"
export AZURE_OPENAI_IMAGE_DEPLOYMENT="gpt-image-1"
```

## Notes

- The deployment value is the Azure deployment name, not necessarily the raw model family label.
- For transparent-background UI assets, prefer `png` output.
- For batch jobs, store input JSONL files under `tmp/imagegen/` and outputs under `output/imagegen/`.
- If a request fails with 404, first verify the deployment name and endpoint.
- If a request fails with 401, verify the API key and resource.
