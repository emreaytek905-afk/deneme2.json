# ComfyUI Face Swap Serverless - RunPod Deployment

AI-powered face swap workflow with 2-stage upscaling, deployed as a serverless API on RunPod.

## Overview

This project provides a complete ComfyUI face swap pipeline that:
- Accepts two images via API (face + body)
- Swaps the face from image 1 onto the body in image 2
- Performs 2-stage upscaling for high-quality output
- Returns the result as a base64-encoded image

**Deployment**: RunPod Serverless (pay-per-use, auto-scaling)

## Features

- **AI Face Swap**: Advanced face detection and seamless blending
- **2-Stage Upscaling**: First upscale preserves face identity, second upscale enhances quality
- **Serverless API**: HTTP endpoint for easy integration
- **Base64 I/O**: Send and receive images as base64 strings
- **Auto-scaling**: Scales to zero when idle, instant cold start
- **GPU Acceleration**: Runs on A100 or RTX 4090 for fast inference

## Quick Start

### Prerequisites

- Docker installed locally (for testing)
- RunPod account (for deployment)
- RunPod API key

### Local Testing

Build and run the container locally:

```bash
cd ~/deneme2.json
docker build -t comfyui-faceswap .
docker run --rm -it -p 8188:8188 --gpus all comfyui-faceswap
```

Expected output:
```
Starting ComfyUI RunPod Serverless Worker
Starting ComfyUI server...
ComfyUI started (PID: 123)
Starting handler...
Waiting for ComfyUI to start...
ComfyUI is ready!
Initializing RunPod serverless worker...
```

### Deployment to RunPod

#### Step 1: Build and Push Docker Image

```bash
# Login to Docker Hub
docker login

# Tag image
docker tag comfyui-faceswap your-username/comfyui-faceswap:v1

# Push to Docker Hub
docker push your-username/comfyui-faceswap:v1
```

#### Step 2: Create RunPod Serverless Endpoint

1. Go to [RunPod Serverless](https://www.runpod.io/serverless)
2. Click **"New Endpoint"**
3. Configure:
   - **Name**: `comfyui-faceswap`
   - **Image**: `your-username/comfyui-faceswap:v1`
   - **GPU**: A100 40GB (recommended) or RTX 4090
   - **Container Disk**: 20 GB
   - **Execution Timeout**: 600 seconds
   - **Idle Timeout**: 60 seconds
   - **Max Workers**: 3 (adjust based on budget)
4. Click **"Deploy"**

#### Step 3: Get Your Endpoint ID and API Key

- **Endpoint ID**: Found in endpoint URL (`https://api.runpod.io/v2/{ENDPOINT_ID}/run`)
- **API Key**: Settings → API Keys → Create new key

## API Usage

### Request Format

Send a POST request with base64-encoded images:

```json
{
  "input": {
    "workflow": { ... },
    "image1": "base64_encoded_face_image",
    "image2": "base64_encoded_body_image"
  }
}
```

### Python Example

```python
import requests
import base64
import json
import time

# Load workflow
with open("example-request.json", "r") as f:
    workflow = json.load(f)

# Encode images as base64
def encode_image(filepath):
    with open(filepath, "rb") as f:
        return base64.b64encode(f.read()).decode()

face_image = encode_image("face.jpg")
body_image = encode_image("body.jpg")

# Submit request to RunPod
ENDPOINT_ID = "your-endpoint-id"
API_KEY = "your-api-key"

response = requests.post(
    f"https://api.runpod.io/v2/{ENDPOINT_ID}/run",
    headers={
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    },
    json={
        "input": {
            "workflow": workflow,
            "image1": face_image,
            "image2": body_image
        }
    }
)

job_id = response.json()["id"]
print(f"Job submitted: {job_id}")

# Poll for completion
while True:
    status_response = requests.get(
        f"https://api.runpod.io/v2/{ENDPOINT_ID}/status/{job_id}",
        headers={"Authorization": f"Bearer {API_KEY}"}
    )

    status_data = status_response.json()
    status = status_data.get("status")

    print(f"Status: {status}")

    if status == "COMPLETED":
        # Extract output images
        output = status_data.get("output", {})
        images = output.get("images", [])

        for i, img_data in enumerate(images):
            filename = img_data.get("filename", f"output_{i}.png")
            base64_image = img_data.get("base64")

            # Decode and save
            image_bytes = base64.b64decode(base64_image)
            with open(f"result_{filename}", "wb") as f:
                f.write(image_bytes)

            print(f"Saved: result_{filename}")

        break

    elif status in ["FAILED", "CANCELLED"]:
        print(f"Job failed: {status_data}")
        break

    time.sleep(3)
```

### JavaScript Example

```javascript
const fs = require('fs');
const axios = require('axios');

const ENDPOINT_ID = 'your-endpoint-id';
const API_KEY = 'your-api-key';

// Load workflow
const workflow = JSON.parse(fs.readFileSync('example-request.json', 'utf8'));

// Encode images as base64
const faceImage = fs.readFileSync('face.jpg').toString('base64');
const bodyImage = fs.readFileSync('body.jpg').toString('base64');

// Submit request
async function runFaceSwap() {
  const response = await axios.post(
    `https://api.runpod.io/v2/${ENDPOINT_ID}/run`,
    {
      input: {
        workflow: workflow,
        image1: faceImage,
        image2: bodyImage
      }
    },
    {
      headers: {
        'Authorization': `Bearer ${API_KEY}`,
        'Content-Type': 'application/json'
      }
    }
  );

  const jobId = response.data.id;
  console.log(`Job submitted: ${jobId}`);

  // Poll for completion
  while (true) {
    const statusResponse = await axios.get(
      `https://api.runpod.io/v2/${ENDPOINT_ID}/status/${jobId}`,
      {
        headers: { 'Authorization': `Bearer ${API_KEY}` }
      }
    );

    const status = statusResponse.data.status;
    console.log(`Status: ${status}`);

    if (status === 'COMPLETED') {
      const output = statusResponse.data.output;
      const images = output.images || [];

      for (let i = 0; i < images.length; i++) {
        const imgData = images[i];
        const filename = imgData.filename || `output_${i}.png`;
        const base64Image = imgData.base64;

        // Decode and save
        const imageBuffer = Buffer.from(base64Image, 'base64');
        fs.writeFileSync(`result_${filename}`, imageBuffer);

        console.log(`Saved: result_${filename}`);
      }

      break;
    } else if (status === 'FAILED' || status === 'CANCELLED') {
      console.log('Job failed:', statusResponse.data);
      break;
    }

    await new Promise(resolve => setTimeout(resolve, 3000));
  }
}

runFaceSwap().catch(console.error);
```

## Workflow Details

The face swap workflow consists of 20 nodes across 2 stages:

### Stage 1: Face Swap
1. **Load Images** (nodes 7, 8): Load face and body images
2. **Encode Face** (node 1): Extract face features using Qwen text encoder
3. **Encode Body** (node 2): Extract body features
4. **Initial Swap** (node 3): Perform face swap using Z-Image Turbo diffusion model
5. **Resize** (node 18): Resize to 2000px on longest edge for upscaling

### Stage 2: Quality Upscaling
1. **Encode Again** (nodes 9, 10): Re-encode swapped image
2. **Final Upscale** (node 11): High-quality upscaling with face preservation
3. **VAE Decode** (nodes 12, 19): Decode latent images to pixels
4. **Save** (node 20): Save final output

**Key Parameters**:
- **Positive Prompt**: "Beautiful woman with perfect face, high quality, photorealistic"
- **Negative Prompt**: "ugly, deformed, bad anatomy, blurry, low quality"
- **Sampler**: Euler (25 steps)
- **CFG**: 7.0
- **Final Resolution**: 2000px longest edge

## Troubleshooting

### Error: "Node type not found: ResizeImagesByLongerEdge"

**Cause**: Old workflow used incorrect node name.

**Fix**: This is already fixed in `example-request.json`. The correct node is `JWImageResizeByLongerSide` from the `comfyui-various` custom node.

### Error: "ComfyUI did not start within 120 seconds"

**Cause**: Cold start taking too long on slow GPU.

**Fix**: Increase `COMFYUI_STARTUP_TIMEOUT` in `handler.py` or use faster GPU (A100).

### Error: "No output images generated"

**Cause**: Workflow failed silently or output path incorrect.

**Fix**: Check ComfyUI logs:
```bash
docker exec -it <container_id> cat /tmp/comfyui.log
```

### Error: "Workflow execution failed or timed out"

**Cause**: Inference taking longer than 600 seconds.

**Fix**: Increase `WORKFLOW_TIMEOUT` in `handler.py` or optimize workflow (reduce steps, lower resolution).

### Container Exits Immediately

**Cause**: Missing `CMD` in Dockerfile.

**Fix**: Already fixed. Dockerfile now includes `CMD ["/start.sh"]` which keeps container running.

## Cost Estimates

RunPod Serverless pricing (as of 2024):

| GPU | Cold Start | Inference Time | Cost per Request |
|-----|------------|----------------|------------------|
| **A100 40GB** | ~30s | ~60-90s | $0.09 - $0.18 |
| **RTX 4090** | ~40s | ~90-120s | $0.06 - $0.12 |
| **RTX A6000** | ~45s | ~100-140s | $0.08 - $0.16 |

**Total Request Time**: Cold start + inference time (first request only)
**Subsequent Requests**: Only inference time if worker stays warm (<60s idle timeout)

**Example Monthly Costs**:
- 100 requests: $9 - $18
- 500 requests: $45 - $90
- 1,000 requests: $90 - $180

**Tip**: Keep workers warm during peak hours by setting idle timeout to 5-10 minutes.

## Advanced Configuration

### Modify Prompts

Edit `example-request.json` nodes 1 and 2:

```json
"1": {
  "inputs": {
    "text": "Your custom positive prompt here",
    ...
  }
}
```

### Change Output Size

Edit node 18 `size` parameter:

```json
"18": {
  "inputs": {
    "size": 3000,  // Larger output (slower, more expensive)
    ...
  }
}
```

### Adjust Quality vs Speed

Edit node 3 (KSampler) parameters:

```json
"3": {
  "inputs": {
    "steps": 15,  // Lower = faster but lower quality
    "cfg": 5.0,   // Lower = less strict adherence to prompts
    ...
  }
}
```

### Use Different Models

Replace model download URLs in `Dockerfile`:

```dockerfile
RUN comfy model download --url https://huggingface.co/your-model.safetensors \
    --relative-path models/checkpoints --filename your-model.safetensors
```

Then update `example-request.json` node 4 to reference new model.

## Files Overview

| File | Purpose |
|------|---------|
| **Dockerfile** | Container image with ComfyUI + models + custom nodes |
| **handler.py** | RunPod serverless handler (accepts API requests) |
| **start.sh** | Startup script (launches ComfyUI + handler) |
| **example-request.json** | Face swap workflow definition |
| **README.md** | This file |

## Models Included

Pre-downloaded during Docker build:

1. **z_image_turbo_bf16.safetensors** (4.5 GB) - Fast diffusion model
2. **qwen_3_4b.safetensors** (7.2 GB) - Text encoder for prompts
3. **ae.safetensors** (321 MB) - VAE for image encoding/decoding
4. **Qwen-Rapid-AIO-NSFW-v21.safetensors** (8.1 GB) - Main checkpoint

**Total Size**: ~20 GB (requires 20 GB container disk on RunPod)

## Custom Nodes Installed

1. **comfyui_controlnet_aux** (Fannovel16)
2. **comfyui-various** (jamesWalker55) - provides `JWImageResizeByLongerSide`
3. **Comfyui-QwenEditUtils** (lrzjason) - provides `TextEncodeQwenImageEditPlus`

## System Requirements

### Local Testing
- Docker with GPU support (NVIDIA Docker)
- 24GB+ VRAM (RTX 3090, A5000, or better)
- 32GB+ system RAM
- 50GB+ free disk space

### RunPod Deployment
- **Minimum GPU**: RTX A6000 (48GB VRAM)
- **Recommended GPU**: A100 40GB (faster, cheaper per request)
- **Container Disk**: 20 GB
- **Execution Timeout**: 600 seconds

## Performance Tips

1. **Keep Workers Warm**: Set idle timeout to 5-10 minutes during peak hours
2. **Batch Requests**: Send multiple requests to same worker for efficiency
3. **Optimize Images**: Resize input images to ~1024px before sending (faster upload)
4. **Use A100**: Best price/performance ratio for this workflow
5. **Monitor Costs**: Enable RunPod budget alerts

## Security Notes

- API keys should be stored as environment variables, never hardcoded
- Input images are temporarily stored in `/comfyui/input/` and deleted after processing
- Output images are encoded as base64 and returned immediately (not stored)
- No data persists between requests (stateless serverless)

## Support

For issues specific to:
- **RunPod**: [RunPod Discord](https://discord.gg/runpod)
- **ComfyUI**: [ComfyUI GitHub](https://github.com/comfyanonymous/ComfyUI)
- **This Project**: Open an issue in your repository

## License

This project uses:
- ComfyUI (GPL-3.0)
- Custom nodes (various licenses - see respective repos)
- Models (check model card licenses on HuggingFace)

## Acknowledgments

- **ComfyUI** by comfyanonymous
- **RunPod** for serverless infrastructure
- **Qwen Team** for text encoding models
- **Custom Node Authors** for community contributions

---

**Built with**: ComfyUI + RunPod Serverless
**Last Updated**: 2026-02-04
