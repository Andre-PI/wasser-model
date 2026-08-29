FROM python:3.13-slim-bookworm
WORKDIR /app

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg libgl1 libglib2.0-0 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.11.21 /uv /uvx /bin/

COPY pyproject.toml uv.lock ./

ENV UV_LINK_MODE=copy
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev

COPY . .

ENV PATH="/app/.venv/bin:$PATH"

# Os pesos .pt nao estao versionados (.gitignore) nem entram na imagem
# (.dockerignore). Monte-os em runtime, ex.:
#   docker run -p 8501:8501 \
#     -v "$PWD/yolo26x.pt:/app/yolo26x.pt" \
#     -v "$PWD/yolo26x-cls.pt:/app/yolo26x-cls.pt" wasser-model
EXPOSE 8501
CMD ["streamlit", "run", "app.py", \
     "--server.address=0.0.0.0", \
     "--server.port=8501", \
     "--server.headless=true"]
