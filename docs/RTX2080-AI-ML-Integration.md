# RTX2080 AI/ML Integration Guide

## Overview

This guide provides comprehensive instructions for integrating the NVIDIA GeForce RTX 2080 GPU into the homelab infrastructure for AI/ML workloads and development environments.

## RTX2080 Specifications

### Hardware Capabilities
- **GPU Architecture**: Turing
- **CUDA Cores**: 2944
- **RT Cores**: 46 (real-time ray tracing)
- **Tensor Cores**: 368 (AI acceleration)
- **Memory**: 8GB GDDR6
- **Memory Bandwidth**: 448 GB/s
- **Base Clock**: 1515 MHz
- **Boost Clock**: 1710 MHz
- **TDP**: 215W

### AI/ML Performance Characteristics
- **Deep Learning**: Excellent for training medium to large models (up to 8GB)
- **Inference**: High-performance inference for production workloads
- **Computer Vision**: Optimized for image processing and computer vision tasks
- **NLP**: Suitable for transformer models and natural language processing
- **Mixed Precision**: Support for FP16 training with Tensor Cores

## Integration Architecture

### Container Strategy
The RTX2080 GPU is integrated into the homelab using **Container 100 (AI-Dev)** with GPU passthrough:

```bash
# Container specifications
Container ID: 100
Container Name: AI-Dev
OS: Ubuntu 22.04
Resources: 8 CPU cores, 32GB RAM
GPU: RTX2080 passthrough
Status: Ready for activation

# Management commands
./homelab-unified.sh start 100 lxc    # Start AI development container
./homelab-unified.sh gpu status       # Check GPU availability
./homelab-unified.sh gpu resources    # View GPU specifications
```

### Software Stack
1. **NVIDIA Drivers**: Latest stable drivers for RTX2080
2. **CUDA Toolkit**: CUDA 11.8+ for optimal compatibility
3. **cuDNN**: Deep learning primitives library
4. **Docker**: NVIDIA Container Runtime for containerized workloads
5. **Development Environment**: Jupyter Lab with GPU acceleration

## Setup Instructions

### Phase 1: GPU Passthrough Configuration

#### 1.1 Proxmox GPU Passthrough Setup
```bash
# Enable IOMMU in Proxmox
echo "intel_iommu=on" >> /etc/default/grub  # For Intel CPUs
# OR
echo "amd_iommu=on" >> /etc/default/grub    # For AMD CPUs

# Update GRUB and reboot
update-grub
reboot

# Verify IOMMU groups
find /sys/kernel/iommu_groups/ -name "devices" -exec cat {} \;

# Configure GPU for passthrough
echo "vfio-pci" >> /etc/modules
echo "options vfio-pci ids=10de:1e82" >> /etc/modprobe.d/vfio.conf  # RTX2080 device ID

# Blacklist GPU drivers on host
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf

# Update initramfs and reboot
update-initramfs -u
reboot
```

#### 1.2 Container GPU Configuration
```bash
# Add GPU to Container 100 configuration
nano /etc/pve/lxc/100.conf

# Add GPU device mapping
lxc.cgroup2.devices.allow: c 195:* rwm  # NVIDIA device
lxc.cgroup2.devices.allow: c 507:* rwm  # NVIDIA UVM
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
```

### Phase 2: Container Environment Setup

#### 2.1 NVIDIA Driver Installation
```bash
# Inside Container 100
apt update && apt upgrade -y

# Install NVIDIA drivers
apt install -y nvidia-driver-535
apt install -y nvidia-utils-535

# Verify GPU detection
nvidia-smi
```

#### 2.2 CUDA Toolkit Installation
```bash
# Download and install CUDA Toolkit
wget https://developer.download.nvidia.com/compute/cuda/12.0.0/local_installers/cuda_12.0.0_525.60.13_linux.run
chmod +x cuda_12.0.0_525.60.13_linux.run
./cuda_12.0.0_525.60.13_linux.run

# Add CUDA to PATH
echo 'export PATH=/usr/local/cuda-12.0/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.0/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

# Verify CUDA installation
nvcc --version
```

#### 2.3 Docker with NVIDIA Runtime
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install NVIDIA Container Runtime
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list

apt update
apt install -y nvidia-container-runtime

# Configure Docker daemon
cat > /etc/docker/daemon.json << EOF
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
EOF

# Restart Docker
systemctl restart docker

# Test GPU access in Docker
docker run --rm nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi
```

### Phase 3: AI/ML Development Environment

#### 3.1 Jupyter Lab with GPU Support
```bash
# Create AI development environment
docker run -d \
  --name jupyter-gpu \
  --restart unless-stopped \
  -p 8888:8888 \
  -v /data/jupyter:/home/jovyan/work \
  --gpus all \
  jupyter/tensorflow-notebook:latest

# Access Jupyter Lab
# URL: http://192.168.2.xxx:8888 (Container 100 IP)
```

#### 3.2 TensorFlow GPU Setup
```bash
# Create TensorFlow GPU environment
docker run -it --rm \
  --gpus all \
  -v /data/models:/workspace \
  tensorflow/tensorflow:latest-gpu-jupyter

# Test TensorFlow GPU
python3 -c "
import tensorflow as tf
print('TensorFlow version:', tf.__version__)
print('GPU available:', tf.config.list_physical_devices('GPU'))
print('CUDA version:', tf.sysconfig.get_build_info()['cuda_version'])
"
```

#### 3.3 PyTorch GPU Setup
```bash
# Create PyTorch GPU environment
docker run -it --rm \
  --gpus all \
  -v /data/models:/workspace \
  pytorch/pytorch:latest

# Test PyTorch GPU
python3 -c "
import torch
print('PyTorch version:', torch.__version__)
print('CUDA available:', torch.cuda.is_available())
print('CUDA version:', torch.version.cuda)
print('GPU device:', torch.cuda.get_device_name(0))
"
```

## AI/ML Use Cases

### 1. Deep Learning Training
- **Image Classification**: ResNet, EfficientNet, Vision Transformers
- **Object Detection**: YOLO, R-CNN, RetinaNet
- **Semantic Segmentation**: U-Net, DeepLab, Mask R-CNN
- **Generative Models**: GANs, VAEs, Diffusion Models

### 2. Natural Language Processing
- **Text Classification**: BERT, RoBERTa, DistilBERT
- **Language Generation**: GPT-2 (small models), T5
- **Machine Translation**: Transformer models
- **Sentiment Analysis**: Fine-tuned BERT variants

### 3. Computer Vision Applications
- **Real-time Object Detection**: YOLO deployment
- **Image Enhancement**: Super-resolution models
- **Style Transfer**: Neural style transfer
- **Face Recognition**: FaceNet, ArcFace

### 4. Time Series and Forecasting
- **LSTM Networks**: Time series prediction
- **Transformer Models**: Temporal pattern recognition
- **Anomaly Detection**: Autoencoder-based detection

## Performance Optimization

### Memory Management
```python
# TensorFlow memory growth
import tensorflow as tf

gpus = tf.config.experimental.list_physical_devices('GPU')
if gpus:
    tf.config.experimental.set_memory_growth(gpus[0], True)

# PyTorch memory management
import torch
torch.cuda.empty_cache()  # Clear GPU memory
```

### Mixed Precision Training
```python
# TensorFlow mixed precision
from tensorflow.keras.mixed_precision import Policy
policy = Policy('mixed_float16')
tf.keras.mixed_precision.set_global_policy(policy)

# PyTorch automatic mixed precision
from torch.cuda.amp import autocast, GradScaler
scaler = GradScaler()

with autocast():
    outputs = model(inputs)
    loss = criterion(outputs, targets)

scaler.scale(loss).backward()
```

## Monitoring and Management

### GPU Monitoring Commands
```bash
# Real-time GPU monitoring
./homelab-unified.sh gpu monitor

# GPU utilization dashboard
./homelab-unified.sh hardware dashboard

# Temperature monitoring
./homelab-unified.sh hardware temps

# Container resource usage
./homelab-unified.sh start 100 lxc
docker stats jupyter-gpu
```

### Performance Metrics
- **GPU Utilization**: Target 80-95% during training
- **Memory Usage**: Monitor VRAM usage (max 8GB)
- **Temperature**: Keep below 80°C for sustained performance
- **Power Draw**: Monitor TDP compliance (max 215W)

## Troubleshooting

### Common Issues

#### GPU Not Detected
```bash
# Check GPU visibility
nvidia-smi
lspci | grep -i nvidia

# Verify driver installation
nvidia-detector
ubuntu-drivers devices
```

#### CUDA Compatibility Issues
```bash
# Check CUDA version compatibility
nvcc --version
nvidia-smi | grep "CUDA Version"

# TensorFlow CUDA compatibility
python3 -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
```

#### Docker GPU Access Issues
```bash
# Test NVIDIA Docker runtime
docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi

# Check NVIDIA Container Runtime
nvidia-container-cli info
```

### Performance Issues
- **Thermal Throttling**: Monitor temperatures, improve cooling
- **Memory Limits**: Reduce batch sizes, use gradient checkpointing
- **Driver Issues**: Update to latest stable NVIDIA drivers
- **Power Limits**: Ensure adequate PSU capacity (750W+ recommended)

## Best Practices

### Development Workflow
1. **Data Preparation**: Use CPU for data preprocessing when possible
2. **Model Development**: Start with small models, scale up gradually
3. **Training Strategy**: Use mixed precision, gradient accumulation
4. **Validation**: Regular checkpointing and validation monitoring
5. **Deployment**: Optimize models for inference (TensorRT, ONNX)

### Resource Management
- **Container Isolation**: Separate environments for different projects
- **Memory Monitoring**: Regular cleanup and memory profiling
- **Temperature Management**: Monitor thermal performance
- **Power Efficiency**: Use dynamic power management

### Security Considerations
- **Container Security**: Regular updates and vulnerability scanning
- **Access Control**: Limit GPU access to authorized users
- **Data Protection**: Encrypt sensitive training data
- **Network Security**: Secure Jupyter Lab access with authentication

## Integration with Homelab Infrastructure

### GitOps Workflow
```bash
# Model versioning with Git
git lfs track "*.h5" "*.pb" "*.onnx"
git add .gitattributes
git commit -m "Add model versioning"

# ArgoCD deployment for ML services
kubectl apply -f k3s/ai-ml/jupyter-deployment.yml
```

### Monitoring Integration
- **Grafana Dashboards**: GPU metrics visualization
- **Prometheus Alerts**: Temperature and utilization alerts
- **Log Aggregation**: Centralized logging for training jobs

### Backup Strategy
- **Model Checkpoints**: Automated backup of trained models
- **Data Backup**: Regular backup of training datasets
- **Environment Backup**: Container image snapshots

This RTX2080 integration provides a robust foundation for AI/ML development and experimentation within the homelab infrastructure, offering enterprise-grade capabilities for deep learning research and development.