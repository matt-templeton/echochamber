FROM python:3.11-slim as builder

# Install build dependencies with additional FFmpeg dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    build-essential \
    libavcodec-extra \
    libavformat-dev \
    libavutil-dev \
    libavfilter-dev \
    libswscale-dev \
    && rm -rf /var/lib/apt/lists/*

# Create and activate virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy and install requirements
WORKDIR /app
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt \
    && find /opt/venv -type d -name "__pycache__" -exec rm -r {} + \
    && find /opt/venv -type d -name "tests" -exec rm -r {} + \
    && find /opt/venv -type d -name "test" -exec rm -r {} + \
    && find /opt/venv -type f -name "*.pyc" -delete

# Start fresh with a clean image
FROM python:3.11-slim

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install runtime dependencies with additional FFmpeg dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libavcodec-extra \
    libavformat58 \
    libavutil56 \
    libavfilter7 \
    libswscale5 \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables to control ML backend and FFmpeg
ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
ENV BASIC_PITCH_MODEL_TYPE=tensorflow
ENV BASIC_PITCH_BACKEND=tensorflow
ENV BASIC_PITCH_SKIP_COREML=1
ENV PATH="/usr/bin:${PATH}"

# Set working directory and copy function code
WORKDIR /app
COPY . .

# Verify FFmpeg installation
RUN ffmpeg -version

# Set the Cloud Function entry point
CMD ["python", "-m", "firebase_functions"] 