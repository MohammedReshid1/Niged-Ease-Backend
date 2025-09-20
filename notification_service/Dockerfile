FROM python:3.11-slim

# Set work directory
WORKDIR /app

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Skip system dependencies installation for now to speed up build

# Install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip
RUN pip install -r requirements.txt

# Copy project
COPY . .

# Create a non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Run the application
EXPOSE 8001
CMD ["gunicorn", "notification_service.wsgi:application", "--bind", "0.0.0.0:8001", "--workers", "2", "--threads", "2"]