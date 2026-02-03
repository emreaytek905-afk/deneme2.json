# Temiz base imaj: ComfyUI + comfy-cli + manager içerir
FROM runpod/worker-comfyui:5.5.1-base

# Çalışma dizini custom_nodes altına geç
WORKDIR /comfyui/custom_nodes

# Qwen Edit Utils (TextEncodeQwenImageEditPlus için – zorunlu)
RUN git clone https://github.com/lrzjason/Comfyui-QwenEditUtils.git && \
    cd Comfyui-QwenEditUtils && \
    if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi && \
    cd .. && \
    rm -rf .git

# Resize alternatifi: jamesWalker55/comfyui-various (JWImageResizeByLongerSide node'u var)
# Bu repo'da requirements.txt YOK, pip satırını kaldırıyoruz
RUN git clone https://github.com/jamesWalker55/comfyui-various.git && \
    rm -rf comfyui-various/.git  # Cache temizle

# Opsiyonel ekstra resize node'ları (eğer JW yetmezse, requirements.txt varsa pip yap)
# RUN git clone https://github.com/Zar4X/ComfyUI-Image-Resizing.git && \
#     cd ComfyUI-Image-Resizing && \
#     if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi && \
#     cd .. && rm -rf .git

# Modelleri indir (workflow'una göre aynı)
RUN comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors \
    --relative-path models/diffusion_models --filename z_image_turbo_bf16.safetensors

RUN comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors \
    --relative-path models/text_encoders --filename qwen_3_4b.safetensors

RUN comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors \
    --relative-path models/vae --filename ae.safetensors

RUN comfy model download --url https://huggingface.co/Phr00t/Qwen-Image-Edit-Rapid-AIO/resolve/main/v21/Qwen-Rapid-AIO-NSFW-v21.safetensors \
    --relative-path models/checkpoints --filename Phr00t__Qwen-Image-Edit-Rapid-AIO__Qwen-Rapid-AIO-NSFW-v21.safetensors

# Build log
RUN echo "Custom nodes and models installed" > /comfyui/startup.log
