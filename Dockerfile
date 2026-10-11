# B2B catalogue — Nunchaku INT4 serverless worker
# Adds the Nunchaku backend + the ComfyUI-nunchaku node to RunPod's official
# ComfyUI serverless worker, to run the INT4 (SVDQuant) + Lightning Qwen-Image-Edit
# model. Models live on the network volume (downloaded once); this image only adds code.
#
# IMPORTANT: worker-comfyui 5.10.0 runs ComfyUI inside its own uv venv at
# /comfyui/.venv with torch 2.11.0 (cu128), ComfyUI at /comfyui, custom_nodes at
# /comfyui/custom_nodes. So Nunchaku MUST be installed into that venv, and the
# base image's /comfyui/extra_model_paths.yaml must be left intact.
FROM runpod/worker-comfyui:5.10.0-base

# 1) the ComfyUI-nunchaku custom node (provides NunchakuQwenImageDiTLoader)
RUN git clone --depth 1 https://github.com/nunchaku-tech/ComfyUI-nunchaku.git \
      /comfyui/custom_nodes/ComfyUI-nunchaku

# 2) the Nunchaku backend wheel, matched to the image (cu12.8 / torch2.11 / cp312),
#    installed INTO THE COMFYUI VENV (not system python).
RUN uv pip install --python /comfyui/.venv/bin/python --no-cache \
      "https://github.com/nunchaku-tech/nunchaku/releases/download/v1.3.0dev20260213/nunchaku-1.3.0.dev20260213+cu12.8torch2.11-cp312-cp312-linux_x86_64.whl"

# 3) the node's python deps, also into the venv
RUN uv pip install --python /comfyui/.venv/bin/python --no-cache \
      -r /comfyui/custom_nodes/ComfyUI-nunchaku/requirements.txt

# 4) sanity: nunchaku imports in the venv (fails the build early if it does not)
RUN /comfyui/.venv/bin/python -c "import nunchaku; print('nunchaku', getattr(nunchaku,'__version__','?'))"
