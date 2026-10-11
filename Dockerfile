# B2B catalogue — Nunchaku INT4 serverless worker
# Builds on RunPod's official ComfyUI serverless worker and adds the Nunchaku
# backend + the ComfyUI-nunchaku node, so we can run the INT4 (SVDQuant) +
# Lightning-4step Qwen-Image-Edit model. Models themselves live on the network
# volume (downloaded once) — this image only adds the code.
#
# Base: ComfyUI at /comfyui, custom_nodes at /comfyui/custom_nodes,
#       Python 3.12, CUDA 12.8, PyTorch (cu128). Handler + network-volume
#       support come from the base image.
FROM runpod/worker-comfyui:5.10.0-base

# 1) ComfyUI-nunchaku custom node (provides the Nunchaku loader nodes)
RUN git clone --depth 1 https://github.com/nunchaku-tech/ComfyUI-nunchaku.git \
      /comfyui/custom_nodes/ComfyUI-nunchaku \
 && (pip install --no-cache-dir -r /comfyui/custom_nodes/ComfyUI-nunchaku/requirements.txt || true)

# 2) Nunchaku backend wheel — matched to the image's torch / Python 3.12 / cu128.
#    Auto-detects the torch major.minor so it survives a base-image torch bump,
#    and tries a few recent nunchaku releases. The final import check fails the
#    build early if nothing matched (so we catch it in the build log, not at run time).
RUN set -eux; \
    TV="$(python -c 'import torch;print(".".join(torch.__version__.split("+")[0].split(".")[:2]))')"; \
    echo "Detected torch ${TV} / python cp312 / linux_x86_64"; \
    ok=0; \
    for VER in 1.0.1 1.0.0 0.3.2 0.3.1; do \
      URL="https://github.com/nunchaku-tech/nunchaku/releases/download/v${VER}/nunchaku-${VER}+torch${TV}-cp312-cp312-linux_x86_64.whl"; \
      echo "trying nunchaku ${VER}: ${URL}"; \
      if pip install --no-cache-dir "${URL}"; then ok=1; echo "installed nunchaku ${VER}"; break; fi; \
    done; \
    if [ "${ok}" != "1" ]; then echo "NO matching wheel for torch ${TV}; falling back to pip"; pip install --no-cache-dir nunchaku || true; fi; \
    python -c "import nunchaku; print('nunchaku import OK')"

# 3) Make the Nunchaku diffusion model (on the volume) visible to ComfyUI.
#    The base worker auto-links unet/clip/vae/loras from /runpod-volume/models,
#    but NOT diffusion_models — the Nunchaku Qwen loader reads diffusion_models,
#    so add it here.
RUN printf 'nunchaku_volume:\n  base_path: /runpod-volume/models/\n  diffusion_models: diffusion_models/\n' \
      > /comfyui/extra_model_paths.yaml
