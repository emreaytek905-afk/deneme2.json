# Temiz base imaj: ComfyUI + comfy-cli + manager içerir
FROM runpod/worker-comfyui:5.5.1-base

# Çalışma dizini custom_nodes altına geç
WORKDIR /comfyui/custom_nodes

# ResizeImagesByLongerEdge node'unu sağlayan popüler bir repo (örnek)
RUN git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git && \
    cd comfyui_controlnet_aux && \
    pip install --no-cache-dir -r requirements.txt && \
    cd ..
RUN git clone https://github.com/jamesWalker55/comfyui-various.git && \
    cd comfyui-various && \
    pip install --no-cache-dir -r requirements.txt && \
    cd ..
# Veya daha spesifik resize node repo'su varsa onu clone et
# RUN git clone https://github.com/XXX/resize-by-longer-edge.git ...

# Qwen Edit Utils custom node'unu kur (TextEncodeQwenImageEditPlus buradan geliyor)
RUN git clone https://github.com/lrzjason/Comfyui-QwenEditUtils.git && \
    cd Comfyui-QwenEditUtils && \
    if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi && \
    cd .. && \
    # Opsiyonel: Repo'yu temizle, cache temizle
    rm -rf .git

# Eğer successor repo'yu (daha yeni versiyon) tercih edersen, yukarıdakini bununla değiştir:
# RUN git clone https://github.com/lrzjason/ComfyUI-EditUtils.git && \
#     cd ComfyUI-EditUtils && \
#     if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi

# Modelleri indir (workflow'una göre yol ve isimler aynı)
RUN comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors \
    --relative-path models/diffusion_models --filename z_image_turbo_bf16.safetensors

RUN comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors \
    --relative-path models/text_encoders --filename qwen_3_4b.safetensors

RUN comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors \
    --relative-path models/vae --filename ae.safetensors

# Checkpoint (Phr00t repo'sundan, workflow'un beklediği isimle rename)
RUN comfy model download --url https://huggingface.co/Phr00t/Qwen-Image-Edit-Rapid-AIO/resolve/main/v21/Qwen-Rapid-AIO-NSFW-v21.safetensors \
    --relative-path models/checkpoints --filename Phr00t__Qwen-Image-Edit-Rapid-AIO__Qwen-Rapid-AIO-NSFW-v21.safetensors

# Opsiyonel: Eğer input resim/video gibi dosyalar varsa kopyala (image-to-image için)
# Önce local'de input/ klasörü oluşturup Dockerfile aynı dizinde olsun
# COPY input/ /comfyui/input/

# ComfyUI'yi başlatmadan önce custom node'ların yüklendiğinden emin ol (RunPod otomatik yapar ama güvenli)
RUN echo "Custom nodes installed" > /comfyui/startup.log

# Copy handler and startup script
WORKDIR /
COPY handler.py /handler.py
COPY start.sh /start.sh

# Install RunPod SDK
RUN pip install --no-cache-dir runpod requests

# Make startup script executable
RUN chmod +x /start.sh

# Set startup command
CMD ["/start.sh"]
