FROM python:3.13-slim

WORKDIR /app

# Instalar dependencias del sistema necesarias para compilación y cliente Postgres
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copiar e instalar dependencias de Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el código fuente de la aplicación
COPY . .

# Exponer el puerto de Uvicorn
EXPOSE 8000

# Comando por defecto para arrancar FastAPI en producción
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
