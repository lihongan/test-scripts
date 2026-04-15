# AI in Industrial Environments — A Comprehensive Guide

---

## 1. Can Industrial Systems Use Large Multimodal Models (LMMs)?

Both large and small models have their place — it depends on the use case.

### When to Use Large Models (LLMs/LMMs)

- **Complex visual inspection** — detecting subtle defects across many product types
- **Unstructured data analysis** — parsing maintenance logs, manuals, supplier documents
- **Planning & scheduling** — optimizing complex production workflows
- **Root cause analysis** — reasoning across multiple sensor signals
- **Natural language interfaces** — operators querying systems in plain language

These typically run **in the cloud or on edge servers**, not on the factory floor device itself.

### When to Use Small/Edge Models

- **Real-time control loops** — latency requirements under 10ms (robot arms, conveyors)
- **Simple classification** — pass/fail on a single known defect type
- **Sensor anomaly detection** — vibration, temperature thresholds
- **Predictable, narrow tasks** — counting objects, reading barcodes
- **Air-gapped environments** — no cloud connectivity allowed for security reasons

These run **on-device** (PLCs, embedded GPUs, FPGAs).

### The Common Pattern in Industry

Most modern factories use a **hybrid architecture**:

| Layer | Model Size | Example |
|-------|-----------|---------|
| Device/Edge | Tiny/Small | Real-time defect detection on camera |
| Plant Server | Medium | Aggregated quality analytics |
| Cloud | Large (LMM) | Process optimization, digital twin reasoning |

### Key Considerations for Factories

1. **Latency** — If you need sub-second responses on the production line, small models win
2. **Connectivity** — Many factories have unreliable or restricted network; edge models are more resilient
3. **Cost** — API calls to large models at high throughput (thousands of inspections/min) get expensive fast
4. **Accuracy** — For safety-critical tasks, a fine-tuned small model on your specific data often outperforms a general-purpose large model
5. **Data privacy** — Manufacturing data is often proprietary; on-prem small models avoid sending it externally

### Bottom Line

Don't choose one or the other — **use small models where speed and reliability matter, and large models where reasoning and flexibility matter**. The trend is toward distilling large model capabilities into smaller, specialized models that can run at the edge.

---

## 2. Training AI Models in Air-Gapped Environments

### The Core Challenge

You can't send data out or pull updates in. So training must be adapted to that constraint.

### Common Approaches

#### 2.1 Train Outside, Deploy Inside (Most Common)

This is the standard pattern for high-security environments:

```
[External Lab]              [Air-Gapped Site]

Collect similar data  --->  Transfer via approved media
Train model           --->  (USB, secure disk, diode)
Validate & harden     --->  Deploy frozen model
                             Inference only, no training
```

- Use **synthetic data** or **public datasets** that resemble the real environment
- Train and iterate freely in a lab
- Transfer only the final model binary through a **data diode** or approved physical media
- The model runs inference-only on site — no learning, no data leaving

#### 2.2 Train On-Site (Federated / Local Training)

When the real operational data is critical and can't be replicated:

- Set up a **local training cluster** inside the secure perimeter
- All data stays on-premises
- Engineers work on-site or through secure terminals
- Model updates go through internal review before deployment

**Used by:** Nuclear facilities, defense, some aerospace

#### 2.3 Hybrid with Data Diode

A one-way hardware device that allows data to flow **out** but never **in** (or vice versa):

```
[Secure Site] --data diode (one-way)--> [Training Lab]
                                              |
              <--approved media (manual)------+
                   (reviewed model binary)
```

- Operational data flows out for training
- Trained model is reviewed, signed, and physically carried back in
- Strict audit trail at every step

#### 2.4 Simulation-Based Training

For environments where real data is too rare or dangerous (rocket launches, reactor failures):

- Build a **digital twin** or physics simulator
- Generate millions of synthetic scenarios
- Train entirely on simulated data
- Validate with small amounts of real historical data

**Examples:**

- NASA uses simulated telemetry for anomaly detection
- Nuclear plants use reactor simulators for training predictive models

### Practical Workflow Summary

| Step | Where | How |
|------|-------|-----|
| Data collection | On-site | Sensors, logs, SCADA systems |
| Data sanitization | On-site | Remove classified/sensitive markers |
| Data transfer | Physical | Approved media, data diode, manual review |
| Model training | Off-site lab or on-site cluster | Standard ML pipeline |
| Model validation | Off-site + on-site | Test on real conditions |
| Model signing | Security team | Cryptographic signing, audit |
| Deployment | On-site | Approved physical media |
| Monitoring | On-site | Inference logs, drift detection |

### Key Principles

1. **Data never leaves casually** — every transfer is logged, reviewed, and approved
2. **Models are treated like firmware** — signed, versioned, tested before deployment
3. **Prefer small, interpretable models** — easier to audit and certify (regulators want to understand what the model does)
4. **Retrain infrequently** — deploy stable models, not continuously learning ones
5. **Fail-safe design** — if the model fails or gives uncertain output, fall back to manual/rule-based control

### Why Continuous Learning Is Usually Avoided

In these environments, a model that updates itself is a **liability**:

- Regulators require **deterministic, auditable** behavior
- A self-updating model could drift into unsafe predictions
- Certification (e.g., nuclear NRC, aerospace DO-178C) requires **fixed, tested software**

So the model is frozen at deployment and only updated through a formal release cycle — just like any other safety-critical software.

---

## 3. Popular Tools for Model Training in Air-Gapped Environments

### 3.1 ML Frameworks (Core Training)

| Framework | Best For | Air-Gap Friendly? |
|-----------|----------|-------------------|
| **PyTorch** | Research, custom models, flexibility | Yes — fully offline once installed |
| **TensorFlow** | Production pipelines, TFLite for edge | Yes — but heavier dependency tree |
| **scikit-learn** | Classical ML (anomaly detection, regression) | Very easy — minimal dependencies |
| **ONNX Runtime** | Cross-platform inference | Yes — great for deploying frozen models |
| **XGBoost / LightGBM** | Tabular sensor data, time series | Excellent — lightweight, few dependencies |

For industrial use cases (sensor data, time series, anomaly detection), **scikit-learn** and **XGBoost** are often enough. You don't always need deep learning.

### 3.2 MLOps / Pipeline Tools (Managing the Workflow)

| Tool | Purpose | Air-Gap Notes |
|------|---------|---------------|
| **MLflow** | Experiment tracking, model registry, deployment | Runs fully on-prem, no cloud needed |
| **DVC (Data Version Control)** | Version datasets and models alongside code | Git-based, works offline |
| **Kubeflow** | ML pipelines on Kubernetes | Self-hosted, good for on-prem clusters |
| **Apache Airflow** | Workflow orchestration | Fully self-hosted |
| **Weights & Biases (W&B)** | Experiment tracking | Has a **self-hosted server** option |

**MLflow + DVC** is probably the most popular lightweight combo for air-gapped setups.

### 3.3 Data Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **Apache Kafka** | Streaming sensor data ingestion | Runs on-prem |
| **TimescaleDB / InfluxDB** | Time-series databases for sensor data | Purpose-built for industrial IoT |
| **Apache Spark** | Large-scale data processing | On-prem cluster |
| **Pandas** | Data manipulation | Runs anywhere Python runs |
| **Label Studio** | Data labeling (images, text, etc.) | Self-hosted, open source |

### 3.4 Edge Deployment / Inference

| Tool | Purpose | Hardware |
|------|---------|----------|
| **ONNX Runtime** | Cross-platform inference | CPU, GPU, ARM |
| **TensorRT** | Optimized inference on NVIDIA GPUs | NVIDIA Jetson, T4, A100 |
| **OpenVINO** | Optimized inference on Intel hardware | Intel CPUs, VPUs, FPGAs |
| **TFLite / TFLite Micro** | Tiny models on microcontrollers | ARM Cortex-M, ESP32 |
| **NVIDIA Triton** | Model serving at scale | GPU servers |
| **Apache TVM** | Compiler for any hardware target | Broad hardware support |

**The typical industrial stack:**

- NVIDIA Jetson for vision tasks (defect detection, safety monitoring)
- Intel OpenVINO for CPU-based inference on existing industrial PCs
- TFLite Micro for ultra-constrained embedded devices

### 3.5 Simulation / Synthetic Data

| Tool | Purpose | Notes |
|------|---------|-------|
| **NVIDIA Omniverse / Isaac Sim** | Robotics and factory simulation | Generates synthetic training data |
| **Gazebo** | Robot simulation | Open source, widely used |
| **MATLAB/Simulink** | Control system simulation | Standard in power/aerospace |
| **Modelica / OpenModelica** | Physics-based system modeling | Open source |
| **Unity / Unreal Engine** | Synthetic image generation | Used for vision model training |

### 3.6 Security & Compliance Tools

| Tool | Purpose |
|------|---------|
| **Cosign (Sigstore)** | Cryptographically sign model artifacts |
| **Notary / TUF** | Secure software/model update framework |
| **HashiCorp Vault** | Secrets management on-prem |
| **Anchore / Trivy** | Scan container images for vulnerabilities before deployment |

### Typical Air-Gapped Training Stack

```
┌─────────────────────────────────────────────────┐
│              SECURE TRAINING ZONE                │
│                                                  │
│  Data Ingestion:   Kafka → TimescaleDB           │
│  Labeling:         Label Studio                  │
│  Training:         PyTorch / scikit-learn         │
│  Experiment Track: MLflow                        │
│  Data Versioning:  DVC + Git (internal)          │
│  Pipeline:         Kubeflow or Airflow           │
│  Model Registry:   MLflow Model Registry         │
│                                                  │
│  Model Signing:    Cosign                        │
│  Model Export:     ONNX format                   │
│                                                  │
├──────────── approved transfer ───────────────────┤
│                                                  │
│              DEPLOYMENT ZONE                     │
│                                                  │
│  Inference:  ONNX Runtime / OpenVINO / TensorRT  │
│  Hardware:   Jetson / Industrial PC / FPGA        │
│  Monitoring: Prometheus + Grafana                │
│                                                  │
└─────────────────────────────────────────────────┘
```

### How to Set Up Dependencies Offline

**Python packages:**

```bash
# On an internet-connected machine
pip download torch scikit-learn mlflow -d ./packages/

# Transfer ./packages/ to air-gapped machine via approved media

# On air-gapped machine
pip install --no-index --find-links=./packages/ torch scikit-learn mlflow
```

**Container images:**

```bash
# On connected machine
docker save myimage:latest -o myimage.tar

# Transfer tar file

# On air-gapped machine
docker load -i myimage.tar
```

**OS packages:**

- Use tools like `reposync` (RHEL/CentOS) or `apt-mirror` (Debian/Ubuntu) to mirror entire repos to portable drives

### Recommendations by Industry

| Industry | Typical Stack |
|----------|--------------|
| **Power/Energy** | MATLAB/Simulink + scikit-learn + OpenVINO on industrial PCs |
| **Aerospace/Defense** | PyTorch + MLflow + TensorRT on NVIDIA hardware |
| **Nuclear** | scikit-learn/XGBoost + heavy validation + minimal dependencies |
| **Manufacturing** | PyTorch (vision) + OpenVINO/TensorRT + Kubeflow |
| **Oil & Gas** | Time-series models + Spark + edge inference |

The general rule: **the more safety-critical the environment, the simpler and more auditable the tooling should be.**

---

## 4. Commercial Large Model Training vs. Industrial Air-Gapped Training

### What's Similar

Both use the same core frameworks at the bottom:

| Layer | Commercial LLM | Industrial/Air-Gapped |
|-------|----------------|----------------------|
| Framework | PyTorch (dominant) | PyTorch, scikit-learn, TensorFlow |
| Data format | Parquet, JSON, Arrow | Same + time-series DBs |
| Experiment tracking | Internal tools (similar to MLflow) | MLflow, W&B |
| Containers | Docker / Kubernetes | Same |
| Model format | Custom → ONNX/safetensors for serving | ONNX, TensorRT |

**PyTorch is the industry standard for both.** Claude, Qwen, Kimi, GPT — all trained primarily with PyTorch.

### What's Fundamentally Different

#### Scale of Compute

| | Commercial LLM (Claude, GPT, Qwen) | Industrial Model |
|--|-------------------------------------|------------------|
| GPUs | **Tens of thousands** (H100, A100) | 1–8 GPUs or just CPUs |
| Training time | **Weeks to months** | Hours to days |
| Cost | **$10M–$100M+** per training run | $100–$10K |
| Cluster size | Thousands of nodes | Single machine or small cluster |
| Parameters | **Billions to trillions** | Thousands to millions |

#### Distributed Training Tools

Commercial LLMs need specialized tools to train across thousands of GPUs. Industrial models rarely need these:

| Tool | What It Does | Used By |
|------|-------------|---------|
| **DeepSpeed** (Microsoft) | ZeRO optimizer, model parallelism | Open source LLMs, Qwen |
| **Megatron-LM** (NVIDIA) | Tensor/pipeline parallelism for giant models | Many commercial LLMs |
| **FSDP** (PyTorch native) | Fully Sharded Data Parallel | Meta's Llama |
| **JAX + TPU** (Google) | Google's framework for TPU clusters | Gemini |
| **Ray Train** | Distributed training orchestration | Various |
| **Colossal-AI** | Efficient large-model training | Some Chinese LLMs |
| **Internal proprietary tools** | Custom schedulers, fault tolerance | Anthropic, OpenAI |

#### Data Pipeline

| Aspect | Commercial LLM | Industrial |
|--------|----------------|------------|
| Data size | **Petabytes** of text, code, images | Gigabytes of sensor/image data |
| Sources | Web crawls, books, code repos, partnerships | Sensors, SCADA, cameras, logs |
| Cleaning | Massive dedup, filtering, toxicity removal | Domain-specific cleaning |
| Labeling | RLHF with thousands of human annotators | Small team or automated labels |
| Tools | Custom data pipelines, **Spark**, **datatrove** | Pandas, Spark, Label Studio |

#### Training Techniques

Commercial LLMs use a multi-stage process that industrial models don't need:

```
Commercial LLM Training Pipeline:
┌─────────────────────────────────────────────────┐
│ Stage 1: Pre-training                           │
│   Trillions of tokens, thousands of GPUs        │
│   Self-supervised (next token prediction)        │
│   Weeks to months                               │
├─────────────────────────────────────────────────┤
│ Stage 2: Supervised Fine-Tuning (SFT)           │
│   High-quality instruction/response pairs       │
│   Hundreds of GPUs, days                        │
├─────────────────────────────────────────────────┤
│ Stage 3: RLHF / RLAIF / DPO                    │
│   Human preference data                         │
│   Alignment, safety, helpfulness tuning         │
│   Complex reward model training                 │
├─────────────────────────────────────────────────┤
│ Stage 4: Evaluation & Red-teaming               │
│   Safety testing, capability benchmarks         │
│   Internal + external testing                   │
└─────────────────────────────────────────────────┘

Industrial Model Training Pipeline:
┌─────────────────────────────────────────────────┐
│ Step 1: Collect sensor/image data               │
│ Step 2: Clean and label                         │
│ Step 3: Train (single machine, hours)           │
│ Step 4: Validate                                │
│ Step 5: Deploy                                  │
└─────────────────────────────────────────────────┘
```

#### Infrastructure

| Aspect | Commercial LLM | Industrial |
|--------|----------------|------------|
| Hardware | NVIDIA H100/B200 clusters, Google TPUs | Jetson, industrial PCs, FPGAs |
| Networking | **InfiniBand / RoCE** (400Gbps+) between GPUs | Standard Ethernet |
| Storage | **Distributed file systems** (Lustre, GPFS) | Local SSD / NAS |
| Cloud | Custom data centers or AWS/GCP/Azure | On-prem, air-gapped |
| Power | **Megawatts** per training run | Kilowatts |
| Cooling | Liquid cooling, custom facilities | Standard HVAC |

### How Each Company Differs

| Company | Key Infrastructure Choices |
|---------|---------------------------|
| **Anthropic (Claude)** | PyTorch, AWS/GCP, proprietary RLHF pipeline, Constitutional AI |
| **OpenAI (GPT)** | PyTorch, Azure (exclusive), custom distributed training |
| **Google (Gemini)** | **JAX + TPUs** (not PyTorch), custom Pathways system |
| **Meta (Llama)** | PyTorch + FSDP, own data centers, open-weights release |
| **Alibaba (Qwen)** | PyTorch + Megatron, Alibaba Cloud, PAI platform |
| **Moonshot (Kimi)** | PyTorch, mix of cloud providers |
| **DeepSeek** | PyTorch, custom MoE training, cost-optimized techniques |

Google is the notable outlier — they use **JAX instead of PyTorch** and **TPUs instead of NVIDIA GPUs**. Almost everyone else is on the PyTorch + NVIDIA stack.

### Could an Industrial Company Train a Large Model?

Technically yes, but **they almost never should**:

| Approach | Practicality | When It Makes Sense |
|----------|-------------|---------------------|
| Train from scratch | Almost never worth it | Never for most companies |
| Fine-tune an open model (Llama, Qwen) | Feasible | When you need domain-specific language understanding |
| Use a small task-specific model | Best option | 95% of industrial use cases |
| Use a cloud LLM via API | Easy but not air-gapped | When connectivity and data policy allow |

The realistic path for an industrial company wanting LLM capability:

```
Take open model (Llama, Qwen)
    → Fine-tune on your domain data (manuals, logs, procedures)
    → Quantize to smaller size (GGUF, GPTQ, AWQ)
    → Deploy on-prem with llama.cpp, vLLM, or TGI
    → Run on a single server with 1-4 GPUs
```

This gives you an LLM that understands your domain, runs fully offline, and costs a fraction of training from scratch.

### Final Comparison Summary

| | Commercial LLM | Industrial AI |
|--|----------------|---------------|
| **Goal** | General intelligence | Solve one specific problem |
| **Scale** | Planetary | Local |
| **Cost** | $10M–$100M+ | $100–$10K |
| **Core tools** | PyTorch + DeepSpeed/Megatron + massive clusters | PyTorch/scikit-learn + single machine |
| **Data** | Petabytes, internet-scale | Gigabytes, domain-specific |
| **Deployment** | Cloud API | Edge device, on-prem |
| **Update cycle** | Months | Months to years |
| **Key constraint** | Compute and data | Security, safety, auditability |

They share DNA (PyTorch, Python, similar concepts) but operate at completely different scales and with different priorities. It's like comparing a commercial airline to a crop duster — both are airplanes, both use engines and wings, but the engineering challenges are worlds apart.
