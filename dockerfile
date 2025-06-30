FROM python:3.9-slim

ENV APP_HOME /app
WORKDIR $APP_HOME

# Install system dependencies
RUN apt-get clean && apt-get -y update && apt-get install -y \
    build-essential \
    libopenblas-dev \
    liblapack-dev \
    cmake \
    libopencv-dev \
    python3-opencv \
    pkg-config \
    libboost-python-dev \
    libboost-thread-dev \
    python3-dev \
    && apt-get clean

# Upgrade pip
RUN pip install --upgrade pip

# Install base Python dependencies
RUN pip install numpy==1.24.3

# Copy requirements (excluding face_recognition) and install
COPY requirements.txt .
RUN pip install flask==2.3.3 opencv-python==4.8.1.78 pymongo==4.5.0 Pillow==10.0.1 werkzeug==2.3.7 gunicorn==21.2.0

# Install face_recognition (includes dlib)
RUN pip install face_recognition==1.3.0

# Copy application code
COPY . .

# Create uploads directory
RUN mkdir -p uploads

CMD ["python3", "app.py"]
