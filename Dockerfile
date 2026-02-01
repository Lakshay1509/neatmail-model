# Use a slim python base image for efficiency
FROM python:3.11-slim

# Set environment variables
# PYTHONDONTWRITEBYTECODE: Prevents Python from writing pyc files to disc
# PYTHONUNBUFFERED: Prevents Python from buffering stdout and stderr
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies (if any are needed for specific wheels)
# clean up apt cache to keep image small
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first to leverage Docker cache
COPY requirements.txt .

# Install dependencies
# Note: Using --extra-index-url for pytorch cpu versions to ensure we find the +cpu wheels
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cpu

# Set Hugging Face cache directory explicitly
# ENV HF_HOME=/app/model_cache

# Bake the model into the image by downloading it during build
# RUN python -c "from transformers import pipeline; pipeline('zero-shot-classification', model='MoritzLaurer/mDeBERTa-v3-base-xnli-multilingual-nli-2mil7')"

# Copy the application code
COPY . .

# Create a non-root user and switch to it
# We combine chown to ensure the user owns the downloaded model cache
RUN adduser --disabled-password --gecos '' appuser && \
    chown -R appuser:appuser /app
USER appuser

# Expose the port the app runs on
EXPOSE 8000

# Run the application
# IMPORTANT: To access from Postman, run with: docker run -p 8000:8000 --env-file .env <image_name>
# Then use http://localhost:8000/classify (use 'localhost' instead of '0.0.0.0' in Postman)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
