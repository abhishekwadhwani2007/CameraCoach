# PoseCoach Overlay API — production image for Render (or any Docker host)

FROM python:3.10-slim AS builder

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt


FROM python:3.10-slim AS runner

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000 \
    PATH="/opt/venv/bin:$PATH" \
    HOME="/home/user"

# OpenCV, MediaPipe, and TensorFlow all need these system libs at runtime.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Most cloud container runtimes (including Render) expect a non-root user.
RUN useradd -m -u 1000 user

WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY --chown=user:user . /app/

# Create the corrections directory before dropping root so the app can write to it.
RUN mkdir -p /app/data/corrections && \
    chown -R user:user /app

USER user

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -f http://localhost:${PORT:-8000}/health || exit 1

# Shell form so ${PORT} is evaluated at container startup, not build time.
CMD ["sh", "-c", "uvicorn server:app --host 0.0.0.0 --port ${PORT:-8000}"]
