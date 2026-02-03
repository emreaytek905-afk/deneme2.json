#!/usr/bin/env python3
"""
RunPod Serverless Handler for ComfyUI Face Swap Workflow

This handler:
1. Accepts API requests with workflow + base64 images
2. Saves base64 images to /comfyui/input/
3. Executes the face swap workflow
4. Returns base64-encoded output images
"""

import os
import sys
import json
import time
import base64
import uuid
import requests
from typing import Dict, Any, Optional, List

import runpod

# Configuration
COMFYUI_URL = "http://127.0.0.1:8188"
COMFYUI_INPUT_DIR = "/comfyui/input"
COMFYUI_OUTPUT_DIR = "/comfyui/output"
WORKFLOW_TIMEOUT = 600  # 10 minutes
COMFYUI_STARTUP_TIMEOUT = 120  # 2 minutes


def wait_for_comfyui(timeout: int = COMFYUI_STARTUP_TIMEOUT) -> bool:
    """
    Wait for ComfyUI to be ready by polling the /system_stats endpoint.

    Args:
        timeout: Maximum time to wait in seconds

    Returns:
        True if ComfyUI is ready, False if timeout
    """
    print("Waiting for ComfyUI to start...")
    start_time = time.time()

    while time.time() - start_time < timeout:
        try:
            response = requests.get(f"{COMFYUI_URL}/system_stats", timeout=5)
            if response.status_code == 200:
                print("ComfyUI is ready!")
                return True
        except requests.exceptions.RequestException:
            pass

        time.sleep(2)

    print(f"ERROR: ComfyUI did not start within {timeout} seconds")
    return False


def save_base64_image(base64_data: str, filename: str) -> str:
    """
    Decode and save a base64 image to the ComfyUI input directory.

    Args:
        base64_data: Base64 encoded image string
        filename: Filename to save as

    Returns:
        Full path to saved file
    """
    # Remove data URI prefix if present
    if "," in base64_data:
        base64_data = base64_data.split(",", 1)[1]

    # Decode base64
    image_bytes = base64.b64decode(base64_data)

    # Save to input directory
    filepath = os.path.join(COMFYUI_INPUT_DIR, filename)
    os.makedirs(COMFYUI_INPUT_DIR, exist_ok=True)

    with open(filepath, "wb") as f:
        f.write(image_bytes)

    print(f"Saved image to {filepath} ({len(image_bytes)} bytes)")
    return filepath


def queue_workflow(workflow: Dict[str, Any]) -> Optional[str]:
    """
    Submit a workflow to ComfyUI for execution.

    Args:
        workflow: ComfyUI workflow JSON

    Returns:
        Prompt ID if successful, None otherwise
    """
    try:
        payload = {
            "prompt": workflow,
            "client_id": str(uuid.uuid4())
        }

        response = requests.post(
            f"{COMFYUI_URL}/prompt",
            json=payload,
            timeout=30
        )

        if response.status_code == 200:
            result = response.json()
            prompt_id = result.get("prompt_id")
            print(f"Workflow queued with prompt_id: {prompt_id}")
            return prompt_id
        else:
            print(f"ERROR: Failed to queue workflow: {response.status_code} {response.text}")
            return None

    except Exception as e:
        print(f"ERROR: Exception while queuing workflow: {e}")
        return None


def poll_workflow_status(prompt_id: str, timeout: int = WORKFLOW_TIMEOUT) -> bool:
    """
    Poll ComfyUI for workflow completion.

    Args:
        prompt_id: The prompt ID to monitor
        timeout: Maximum time to wait in seconds

    Returns:
        True if completed successfully, False if timeout or error
    """
    print(f"Polling workflow status for prompt_id: {prompt_id}")
    start_time = time.time()

    while time.time() - start_time < timeout:
        try:
            response = requests.get(f"{COMFYUI_URL}/history/{prompt_id}", timeout=10)

            if response.status_code == 200:
                history = response.json()

                if prompt_id in history:
                    prompt_history = history[prompt_id]

                    # Check if workflow completed
                    if "outputs" in prompt_history:
                        print("Workflow completed successfully!")
                        return True

                    # Check for errors
                    if "status" in prompt_history:
                        status = prompt_history["status"]
                        if status.get("completed", False):
                            print("Workflow completed!")
                            return True
                        if "error" in status:
                            print(f"ERROR: Workflow failed: {status['error']}")
                            return False

            time.sleep(3)

        except Exception as e:
            print(f"ERROR: Exception while polling status: {e}")
            time.sleep(3)

    print(f"ERROR: Workflow timeout after {timeout} seconds")
    return False


def get_output_images(prompt_id: str) -> List[Dict[str, str]]:
    """
    Retrieve and encode output images from a completed workflow.

    Args:
        prompt_id: The prompt ID to get outputs for

    Returns:
        List of dicts with 'filename' and 'base64' keys
    """
    try:
        response = requests.get(f"{COMFYUI_URL}/history/{prompt_id}", timeout=10)

        if response.status_code != 200:
            print(f"ERROR: Failed to get history: {response.status_code}")
            return []

        history = response.json()

        if prompt_id not in history:
            print(f"ERROR: Prompt ID {prompt_id} not found in history")
            return []

        outputs = history[prompt_id].get("outputs", {})
        images = []

        # Extract image filenames from outputs
        for node_id, node_output in outputs.items():
            if "images" in node_output:
                for img_info in node_output["images"]:
                    filename = img_info.get("filename")
                    subfolder = img_info.get("subfolder", "")

                    if filename:
                        # Construct full path
                        if subfolder:
                            filepath = os.path.join(COMFYUI_OUTPUT_DIR, subfolder, filename)
                        else:
                            filepath = os.path.join(COMFYUI_OUTPUT_DIR, filename)

                        # Read and encode image
                        if os.path.exists(filepath):
                            with open(filepath, "rb") as f:
                                image_bytes = f.read()
                                base64_image = base64.b64encode(image_bytes).decode()

                                images.append({
                                    "filename": filename,
                                    "base64": base64_image
                                })

                                print(f"Encoded output image: {filename} ({len(image_bytes)} bytes)")
                        else:
                            print(f"WARNING: Output image not found: {filepath}")

        return images

    except Exception as e:
        print(f"ERROR: Exception while getting output images: {e}")
        return []


def handler(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Main RunPod handler function.

    Expected input format:
    {
        "input": {
            "workflow": { ... ComfyUI workflow JSON ... },
            "image1": "base64_encoded_face_image",
            "image2": "base64_encoded_body_image"
        }
    }

    Returns:
    {
        "images": [
            {"filename": "output.png", "base64": "..."}
        ]
    }
    """
    try:
        # Extract inputs
        job_input = event.get("input", {})

        workflow = job_input.get("workflow")
        image1_b64 = job_input.get("image1")
        image2_b64 = job_input.get("image2")

        # Validate inputs
        if not workflow:
            return {"error": "Missing 'workflow' in input"}
        if not image1_b64:
            return {"error": "Missing 'image1' (face image) in input"}
        if not image2_b64:
            return {"error": "Missing 'image2' (body image) in input"}

        # Generate unique filenames for this request
        request_id = str(uuid.uuid4())[:8]
        face_filename = f"face_{request_id}.png"
        body_filename = f"body_{request_id}.png"

        # Save base64 images to input directory
        print("Saving input images...")
        save_base64_image(image1_b64, face_filename)
        save_base64_image(image2_b64, body_filename)

        # Update workflow to reference the saved images
        # Node 7: Face image (LoadImage)
        # Node 8: Body image (LoadImage)
        if "7" in workflow and "inputs" in workflow["7"]:
            workflow["7"]["inputs"]["image"] = face_filename
            print(f"Updated node 7 to use {face_filename}")

        if "8" in workflow and "inputs" in workflow["8"]:
            workflow["8"]["inputs"]["image"] = body_filename
            print(f"Updated node 8 to use {body_filename}")

        # Queue the workflow
        prompt_id = queue_workflow(workflow)
        if not prompt_id:
            return {"error": "Failed to queue workflow"}

        # Poll for completion
        success = poll_workflow_status(prompt_id)
        if not success:
            return {"error": "Workflow execution failed or timed out"}

        # Get output images
        output_images = get_output_images(prompt_id)
        if not output_images:
            return {"error": "No output images generated"}

        return {"images": output_images}

    except Exception as e:
        print(f"ERROR: Handler exception: {e}")
        import traceback
        traceback.print_exc()
        return {"error": f"Handler exception: {str(e)}"}


if __name__ == "__main__":
    print("Starting ComfyUI RunPod Serverless Worker")

    # Wait for ComfyUI to be ready
    if not wait_for_comfyui():
        print("FATAL: ComfyUI did not start")
        sys.exit(1)

    # Start RunPod serverless worker
    print("Initializing RunPod serverless worker...")
    runpod.serverless.start({"handler": handler})
