# clean base image containing only comfyui, comfy-cli and comfyui-manager
FROM runpod/worker-comfyui:5.5.1-base

# install custom nodes into comfyui (first node with --mode remote to fetch updated cache)
# NOTE: All custom nodes in this workflow are listed under unknown_registry and none include an aux_id (GitHub repo) or registry id.
# Could not resolve unknown registry node: VAEDecode (no aux_id provided)
# Could not resolve unknown registry node: ResizeImagesByLongerEdge (no aux_id provided)
# Could not resolve unknown registry node: VAEEncode (no aux_id provided)
# Could not resolve unknown registry node: EmptyLatentImage (no aux_id provided)
# Could not resolve unknown registry node: CheckpointLoaderSimple (no aux_id provided)
# Could not resolve unknown registry node: KSampler (no aux_id provided)
# Could not resolve unknown registry node: LoadImage (no aux_id provided)
# Could not resolve unknown registry node: LoadImage (no aux_id provided)
# Could not resolve unknown registry node: TextEncodeQwenImageEditPlus (no aux_id provided)
# Could not resolve unknown registry node: TextEncodeQwenImageEditPlus (no aux_id provided)

# download models into comfyui
RUN comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors --relative-path models/diffusion_models --filename z_image_turbo_bf16.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors --relative-path models/text_encoders --filename qwen_3_4b.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors --relative-path models/vae --filename ae.safetensors
# The checkpoint was located in the Phr00t Hugging Face repository. The actual file in the repo is named Qwen-Rapid-AIO-NSFW-v21.safetensors;
# we download it and rename to the expected filename from the workflow.
RUN comfy model download --url https://huggingface.co/Phr00t/Qwen-Image-Edit-Rapid-AIO/resolve/main/v21/Qwen-Rapid-AIO-NSFW-v21.safetensors --relative-path models/checkpoints --filename Phr00t__Qwen-Image-Edit-Rapid-AIO__Qwen-Rapid-AIO-NSFW-v21.safetensors

# copy all input data (like images or videos) into comfyui (uncomment and adjust if needed)
# COPY input/ /comfyui/input/
