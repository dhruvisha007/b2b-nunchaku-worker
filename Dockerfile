# B2B catalogue — Nunchaku INT4 serverless worker
# Adds the Nunchaku backend + the ComfyUI-nunchaku node to RunPod's official
# ComfyUI serverless worker, to run the INT4 (SVDQuant) + Lightning Qwen-Image-Edit
# model. Models live on the network volume (downloaded once); this image only adds code.
#
# CRITICAL (confirmed from the base image's own Dockerfile + a runtime log):
# worker-comfyui 5.10.0 has TWO venvs. comfy-cli installs ComfyUI into its workspace
# venv /comfyui/.venv, but start.sh LAUNCHES ComfyUI with **/opt/venv**'s python
# (torch 2.11.0, cu128, py3.12 live there, and /opt/venv/bin is on PATH). So nunchaku
# MUST be installed into /opt/venv — installing into /comfyui/.venv makes the build-time
# `import nunchaku` pass but ComfyUI fail at runtime with "No module named 'nunchaku'".
FROM runpod/worker-comfyui:5.10.0-base

# 1) the ComfyUI-nunchaku custom node (provides NunchakuQwenImageDiTLoader)
RUN git clone --depth 1 https://github.com/nunchaku-tech/ComfyUI-nunchaku.git \
      /comfyui/custom_nodes/ComfyUI-nunchaku

# 2) the Nunchaku backend wheel, matched to the image (cu12.8 / torch2.11 / cp312),
#    installed INTO THE RUNTIME VENV /opt/venv (NOT /comfyui/.venv).
RUN uv pip install --python /opt/venv/bin/python --no-cache \
      "https://github.com/nunchaku-tech/nunchaku/releases/download/v1.3.0dev20260213/nunchaku-1.3.0.dev20260213+cu12.8torch2.11-cp312-cp312-linux_x86_64.whl"

# 3) the node's python deps, also into /opt/venv
RUN uv pip install --python /opt/venv/bin/python --no-cache \
      -r /comfyui/custom_nodes/ComfyUI-nunchaku/requirements.txt

# 4) sanity: nunchaku imports in the RUNTIME venv (fails the build early if it does not)
RUN /opt/venv/bin/python -c "import nunchaku; print('nunchaku', getattr(nunchaku,'__version__','?'))"

# 5) expose the Nunchaku INT4 model to ComfyUI's "diffusion_models" category.
#    The base image's extra_model_paths.yaml maps unet/clip/vae but has NO
#    diffusion_models key, yet NunchakuQwenImageDiTLoader reads
#    get_filename_list("diffusion_models") + get_full_path_or_raise("diffusion_models", ...).
#    APPEND the key (do NOT overwrite the file) so the volume's
#    /runpod-volume/models/diffusion_models/ is searched. base_path stays /runpod-volume.
RUN printf '\n  diffusion_models: models/diffusion_models/\n' >> /comfyui/extra_model_paths.yaml \
 && echo '=== extra_model_paths.yaml after append ===' \
 && cat /comfyui/extra_model_paths.yaml
