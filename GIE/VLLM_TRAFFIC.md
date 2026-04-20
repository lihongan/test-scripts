# EPP Traffic Flow and Protocol Configuration

## Accessing LLM Services on Kubernetes

### HTTPRoute Is Required

**HTTPRoute is the only supported route type** for exposing inference services. There is no support for:
- Direct Kubernetes Service access
- Ingress
- GRPCRoute

The system requires:
1. A **Gateway** that supports both Gateway API and **Envoy ext-proc filter** (Envoy Gateway, Istio, GKE Gateway, kgateway, etc.)
2. An **HTTPRoute** pointing to the InferencePool as backend
3. An **InferencePool** defining the model server pods
4. The **EPP** service referenced by the InferencePool's `endpointPickerRef`

### End-to-End Traffic Flow

```
Client (OpenAI-compatible HTTP)
  ↓
Gateway (Envoy / Istio / GKE Gateway / kgateway)
  ├── HTTPRoute routes to InferencePool backend
  ├── Calls ext-proc hook → EPP (port 9002, gRPC)
  ↓
EPP (Endpoint Picker)
  ├── Finds eligible pods via InferencePool selector
  ├── Applies scheduling (score, filter, pick)
  ├── Returns selected endpoint via header/metadata
  ↓
Gateway forwards to selected pod:port
  ├── HTTP/1.1 if appProtocol: "http"
  ├── HTTP/2 (gRPC) if appProtocol: "kubernetes.io/h2c"
  ↓
Model Server Pod (vLLM, SGLang, etc.)
  ↓
Response flows back through Gateway → Client
```

### HTTPRoute Example

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
spec:
  parentRefs:
    - kind: Gateway
      name: my-gateway
  rules:
    - backendRefs:
        - group: inference.networking.k8s.io
          kind: InferencePool
          name: my-pool
      matches:
        - path:
            type: PathPrefix
            value: /
```

### Protocol at Each Hop

| Hop | Protocol |
|-----|----------|
| Client → Gateway | HTTP/1.1 (OpenAI API: `/v1/chat/completions`, etc.) |
| Gateway → EPP | gRPC (Envoy ext-proc protocol) |
| Gateway → Model Server | `http` (HTTP/1.1) or `kubernetes.io/h2c` (gRPC) — set via InferencePool `appProtocol` |

### gRPC Backend Support

While **clients always go through HTTPRoute**, the backend (Gateway → Model Server) can use gRPC:
- Set `appProtocol: "kubernetes.io/h2c"` in InferencePool
- Use the `vllm-grpc-parser` plugin in EndpointPickerConfig
- This enables HTTP-in/gRPC-out transcoding

There is no GRPCRoute support — gRPC is only at the backend level. See the design doc at `docs/proposals/2162-grpc-support/README.md`.

### Supported Gateway Implementations

The architecture works with any gateway supporting Gateway API and Envoy ext-proc filter:
- Envoy Gateway
- Istio
- GKE Gateway
- kgateway
- Solo AI Gateway

---

## Protocol Configuration: HTTP vs gRPC

### The Protocol Is Not Auto-Detected — You Declare It

There are **two settings** you must align, both set at deploy time:

#### 1. InferencePool `appProtocol` — tells the Gateway how to talk to model servers

Defined in `api/v1/inferencepool_types.go`:

```yaml
# For HTTP model servers (default)
spec:
  appProtocol: "http"

# For gRPC model servers
spec:
  appProtocol: "kubernetes.io/h2c"
```

#### 2. EndpointPickerConfig `parser` — tells EPP how to parse request/response

| Parser | Protocol | Use When |
|--------|----------|----------|
| `openai-parser` | HTTP + gRPC (both) | Model server speaks OpenAI HTTP API |
| `vllmgrpc-parser` | gRPC only | Model server speaks vLLM gRPC protocol |
| `passthrough-parser` | any | No parsing needed |

### Via Helm Chart — Simplest Way

The Helm chart (`config/charts/inferencepool/values.yaml`) auto-wires both settings from a single value:

```yaml
# values.yaml
inferencePool:
  modelServerProtocol: grpc    # ← just set this to "http" or "grpc"
  modelServerType: vllm
```

This triggers in `config/charts/inferencepool/templates/inferencepool.yaml`:

```yaml
# modelServerProtocol: "grpc" →
appProtocol: "kubernetes.io/h2c"

# modelServerProtocol: "http" →
appProtocol: "http"
```

And auto-selects the parser in `config/charts/epplib/templates/_config.yaml`:

```yaml
# vllm + grpc → vllmgrpc-parser
# otherwise   → openai-parser (or user-specified)
```

### How the Conversion Works

```
Client (always HTTP, OpenAI API)
  ↓
Gateway + ext-proc → EPP
  ↓
EPP parses request using the configured parser:
  - openai-parser:   understands JSON body (model, messages, etc.)
  - vllmgrpc-parser: understands gRPC frames / protobuf
  ↓
Gateway forwards to model server using appProtocol:
  - "http"              → HTTP/1.1 request
  - "kubernetes.io/h2c" → HTTP/2 cleartext (gRPC) request
```

---

## vLLM: Choosing HTTP or gRPC

When starting vLLM, you choose one entrypoint or the other:

**HTTP (OpenAI-compatible API)** — the default and most common:

```bash
python -m vllm.entrypoints.openai.api_server \
  --model <model-name> \
  --port 8000
```

**gRPC:**

```bash
python -m vllm.entrypoints.grpc_server \
  --model <model-name> \
  --port 8033
```

### Configuration Mapping

| vLLM entrypoint | Helm values | InferencePool appProtocol | EPP parser |
|---|---|---|---|
| `openai.api_server` | `modelServerProtocol: http` | `http` | `openai-parser` |
| `grpc_server` | `modelServerProtocol: grpc` | `kubernetes.io/h2c` | `vllmgrpc-parser` |

### Example Deployment Manifests

Both deployment styles are available in this repo:
- **HTTP**: `config/manifests/vllm/gpu-deployment.yaml` (default entrypoint)
- **gRPC**: `config/manifests/vllm/gpu-grpc-deployment.yaml` (explicitly uses `vllm.entrypoints.grpc_server`)

### When to Use Which

- **HTTP** — default, simpler to debug, compatible with standard OpenAI client libraries
- **gRPC** — better performance for high-throughput scenarios due to lower serialization overhead and HTTP/2 multiplexing

---

## Helm Charts

The project provides several Helm charts under `config/charts/` for deploying the EPP and related components.

### Available Charts

| Chart | Purpose | GitHub Link |
|-------|---------|-------------|
| **inferencepool** | Main chart — creates Deployment, Service, InferencePool CR, and ConfigMap | [config/charts/inferencepool](https://github.com/kubernetes-sigs/gateway-api-inference-extension/tree/main/config/charts/inferencepool) |
| **epplib** | Shared library chart — common templates (deployment, service, config) used by inferencepool and standalone | [config/charts/epplib](https://github.com/kubernetes-sigs/gateway-api-inference-extension/tree/main/config/charts/epplib) |
| **standalone** | Standalone EPP deployment (without InferencePool CR creation) | [config/charts/standalone](https://github.com/kubernetes-sigs/gateway-api-inference-extension/tree/main/config/charts/standalone) |
| **body-based-routing** | Body-based routing support | [config/charts/body-based-routing](https://github.com/kubernetes-sigs/gateway-api-inference-extension/tree/main/config/charts/body-based-routing) |

### What the `inferencepool` Chart Creates

A single `helm install` creates the full stack:
- **Deployment** — runs the EPP container
- **Service** — exposes EPP so the InferencePool's `endpointPickerRef` can reference it
- **InferencePool CR** — defines model server pods and links to the EPP service
- **ConfigMap** — holds the EndpointPickerConfig YAML

### Setting a Custom EPP Image

The EPP image is configured in the Helm values (`config/charts/inferencepool/values.yaml`):

```yaml
inferenceExtension:
  image:
    registry: us-central1-docker.pkg.dev/k8s-staging-images
    repository: gateway-api-inference-extension/epp
    tag: main
    pullPolicy: Always
```

Override at install time to use a custom image (e.g., for out-of-tree plugins):

```bash
helm install my-pool ./config/charts/inferencepool \
  --set inferenceExtension.image.registry=my-registry.com \
  --set inferenceExtension.image.repository=my-org/custom-epp \
  --set inferenceExtension.image.tag=v1.0.0 \
  --set inferencePool.modelServers.matchLabels.app=my-model-server
```

The InferencePool CR's `endpointPickerRef` only references the EPP **Service** by name and port — it has no knowledge of the container image. This means you can swap the EPP image freely via Helm without modifying the InferencePool CR.

### Example Helm Commands

Full chart documentation: [config/charts/inferencepool/README.md](https://github.com/kubernetes-sigs/gateway-api-inference-extension/tree/main/config/charts/inferencepool)

**Basic install from local chart:**

```bash
helm install vllm-qwen3-32b ./config/charts/inferencepool \
  --set inferencePool.modelServers.matchLabels.app=vllm-qwen3-32b
```

**Install from OCI registry (latest dev version):**

```bash
helm install vllm-qwen3-32b \
  --set inferencePool.modelServers.matchLabels.app=vllm-qwen3-32b \
  --set provider.name=gke \
  oci://us-central1-docker.pkg.dev/k8s-staging-images/gateway-api-inference-extension/charts/inferencepool \
  --version v0
```

**Install with custom EPP image (e.g., out-of-tree plugins):**

```bash
helm install vllm-qwen3-32b ./config/charts/inferencepool \
  --set inferencePool.modelServers.matchLabels.app=vllm-qwen3-32b \
  --set inferenceExtension.image.registry=my-registry.com \
  --set inferenceExtension.image.repository=my-org/custom-epp \
  --set inferenceExtension.image.tag=v1.0.0
```

**Install with custom plugin configuration:**

```bash
helm install vllm-qwen3-32b ./config/charts/inferencepool \
  --set inferencePool.modelServers.matchLabels.app=vllm-qwen3-32b \
  -f my-values.yaml
```

Where `my-values.yaml` contains:

```yaml
inferenceExtension:
  pluginsCustomConfig:
    custom-plugins.yaml: |
      apiVersion: inference.networking.x-k8s.io/v1alpha1
      kind: EndpointPickerConfig
      plugins:
      - type: custom-scorer
        parameters:
          custom-threshold: 64
      schedulingProfiles:
      - name: default
        plugins:
        - pluginRef: custom-scorer
```

**Install with custom CLI flags (e.g., log verbosity):**

```bash
helm install vllm-qwen3-32b \
  --set inferencePool.modelServers.matchLabels.app=vllm-qwen3-32b \
  --set inferenceExtension.flags.v=3 \
  oci://us-central1-docker.pkg.dev/k8s-staging-images/gateway-api-inference-extension/charts/inferencepool \
  --version v0
```

**Install for different model server types:**

```bash
# SGLang
helm install sglang-pool ./config/charts/inferencepool \
  --set inferencePool.modelServers.matchLabels.app=sglang-qwen3-32b \
  --set inferencePool.modelServerType=sglang

# Triton TensorRT-LLM
helm install triton-pool ./config/charts/inferencepool \
  --set inferencePool.modelServers.matchLabels.app=triton-qwen3-32b \
  --set inferencePool.modelServerType=triton-tensorrt-llm

# trtllm-serve
helm install trtllm-pool ./config/charts/inferencepool \
  --set inferencePool.modelServers.matchLabels.app=trtllm-serve-qwen3-32b \
  --set inferencePool.modelServerType=trtllm-serve
```

**Install with gRPC backend:**

```bash
helm install vllm-qwen3-32b ./config/charts/inferencepool \
  --set inferencePool.modelServers.matchLabels.app=vllm-qwen3-32b \
  --set inferencePool.modelServerProtocol=grpc
```

**Install with High Availability (multiple replicas):**

```bash
helm install vllm-qwen3-32b ./config/charts/inferencepool \
  --set inferencePool.modelServers.matchLabels.app=vllm-qwen3-32b \
  --set inferenceExtension.replicas=3
```

**Uninstall:**

```bash
helm uninstall vllm-qwen3-32b
```
