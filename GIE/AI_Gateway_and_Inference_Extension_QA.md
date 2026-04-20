# AI Gateway and Inference Extension Q&A

A comprehensive Q&A covering Gateway API Inference Extension, AI Gateway concepts, WasmPlugin, and the broader ecosystem.

---

## Table of Contents

- [1. CRDs Defined in the Inference Extension Repo](#1-crds-defined-in-the-inference-extension-repo)
- [2. Does the Inference Extension Support WasmPlugin?](#2-does-the-inference-extension-support-wasmplugin)
- [3. Where Is the WasmPlugin CRD Defined?](#3-where-is-the-wasmplugin-crd-defined)
- [4. Where Is the Proxy-Wasm ABI Standard Defined?](#4-where-is-the-proxy-wasm-abi-standard-defined)
- [5. Data Plane WASM and ext_proc Support Matrix](#5-data-plane-wasm-and-ext_proc-support-matrix)
- [6. Kong and the Inference Extension](#6-kong-and-the-inference-extension)
- [7. Kong AI Gateway Architecture](#7-kong-ai-gateway-architecture)
- [8. Inference Gateway vs AI Gateway](#8-inference-gateway-vs-ai-gateway)
- [9. Higress: AI Gateway or Inference Gateway?](#9-higress-ai-gateway-or-inference-gateway)
- [10. Building an AI Gateway with Istio + WasmPlugins](#10-building-an-ai-gateway-with-istio--wasmplugins)
- [11. Other Projects Combining AI Gateway + Inference Extension](#11-other-projects-combining-ai-gateway--inference-extension)

---

## 1. CRDs Defined in the Inference Extension Repo

The gateway-api-inference-extension repo does **not** define an `InferenceRoute` CRD. The CRDs it defines are:

### Core API (`api/v1`)

| CRD | File |
|-----|------|
| **InferencePool** | `api/v1/inferencepool_types.go` |

### Extended API (`apix/`)

| CRD | File |
|-----|------|
| **InferenceObjective** | `apix/v1alpha2/inferenceobjective_types.go` |
| **InferenceModelRewrite** | `apix/v1alpha2/inferencemodelrewrite_types.go` |
| **InferencePoolImport** | `apix/v1alpha1/inferencepoolimport_types.go` |

### Config API (`apix/config/`)

| CRD | File |
|-----|------|
| **EndpointPickerConfig** | `apix/config/v1alpha1/endpointpickerconfig_types.go` |

---

## 2. Does the Inference Extension Support WasmPlugin?

The inference extension does **not** directly support Istio's `WasmPlugin` CRD, but it does discuss WASM as a **portable implementation strategy** for data plane integration.

### How the Architecture Works

The inference extension uses **Envoy's `ext_proc` (External Processing)** protocol as the communication layer between the data plane (proxy) and the Endpoint Picker (EPP). The EPP is a gRPC server — not a WASM module.

### Where WASM Fits In

From the implementer's guide (`site-src/guides/implementers.md`), WASM is mentioned as a portable option for proxies that don't natively support ext_proc:

> A portable WASM module implementing ext_proc can be developed, leveraging the [Proxy-Wasm ABI](https://github.com/proxy-wasm/spec) that is now supported by hosts such as Envoy, NGINX, Apache Traffic Server and others.

The idea is that a WASM module could act as a **shim** — implementing the ext_proc client inside the proxy so it can talk to the EPP. This is analogous to Kuadrant's [WASM Shim](https://github.com/Kuadrant/wasm-shim).

### Summary

| Aspect | Status |
|--------|--------|
| Native `WasmPlugin` CRD support | No |
| Core protocol | Envoy `ext_proc` (gRPC) |
| WASM as a portable shim for ext_proc | Discussed as a future option, not implemented |
| Plugin framework (Go-native) | Yes — filters, scorers, pickers in `pkg/epp/framework/plugins/` |

If using **Istio** as the inference extension provider, you can use `WasmPlugin` CRD alongside it. The `WasmPlugin` and the inference extension's EPP operate at **different layers of the Envoy filter chain** — they don't conflict. The `WasmPlugin` runs as an HTTP filter in Envoy, while the EPP communicates via the `ext_proc` filter. You control ordering via Istio's `WasmPlugin` `phase` and `priority` fields.

---

## 3. Where Is the WasmPlugin CRD Defined?

The `WasmPlugin` CRD is defined in the **Istio API** repository:

- **Repository**: [github.com/istio/api](https://github.com/istio/api)
- **Type definition**: `extensions/v1alpha1/wasm.proto` (protobuf source)
- **Go types**: Generated into `extensions/v1alpha1/wasm.gen.go`
- **API Group**: `extensions.istio.io/v1alpha1`

### Related Repos

| Repo | Role |
|------|------|
| `istio/api` | Protobuf definitions and generated Go types for `WasmPlugin` |
| `istio/istio` | Controller that reconciles `WasmPlugin` CRDs and configures Envoy |
| `istio/client-go` | Generated Go client for interacting with `WasmPlugin` resources |

### Example

```yaml
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: my-plugin
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  url: oci://ghcr.io/my-org/my-wasm-plugin:v1
  phase: AUTHZ
  priority: 10
```

The `WasmPlugin` CRD is **Istio-specific**. Other data planes that support WASM use different configuration mechanisms (see next section).

---

## 4. Where Is the Proxy-Wasm ABI Standard Defined?

The Proxy-Wasm ABI standard is defined in:

- **Repository**: [github.com/proxy-wasm/spec](https://github.com/proxy-wasm/spec)

### Related Repos in the proxy-wasm Organization

| Repo | Purpose |
|------|---------|
| `proxy-wasm/spec` | The ABI specification itself |
| `proxy-wasm/proxy-wasm-rust-sdk` | Rust SDK for writing WASM plugins |
| `proxy-wasm/proxy-wasm-go-sdk` | Go SDK for writing WASM plugins |
| `proxy-wasm/proxy-wasm-cpp-sdk` | C++ SDK for writing WASM plugins |
| `proxy-wasm/proxy-wasm-assemblyscript-sdk` | AssemblyScript SDK |
| `proxy-wasm/proxy-wasm-cpp-host` | C++ host implementation (used by Envoy) |

### What the Spec Defines

- **Host functions** — callbacks the proxy provides to the WASM module (e.g., get/set headers, metadata, log, HTTP calls)
- **Module functions** — entry points the proxy calls into the WASM module (e.g., `proxy_on_request_headers`, `proxy_on_response_body`)
- **Memory management** — how data is exchanged across the WASM boundary
- **Context lifecycle** — how plugin instances, streams, and connections are managed

---

## 5. Data Plane WASM and ext_proc Support Matrix

| Proxy | Proxy-Wasm | ext_proc | WASM Config Mechanism | Inference Extension Compatible |
|-------|-----------|----------|----------------------|-------------------------------|
| Envoy | Yes | Yes (native) | `envoy.filters.http.wasm` | Yes |
| Istio (Envoy) | Yes | Yes | `WasmPlugin` CRD | Yes |
| Envoy Gateway | Yes | Yes | `EnvoyExtensionPolicy` CRD | Yes |
| agentgateway | Yes | Yes | Configuration file | Yes |
| NGINX | Yes | No | `proxy_wasm` directive | Needs shim |
| Apache Traffic Server | Yes | No | Proxy-Wasm plugin | Needs shim |
| **Kong Gateway** | **No** | **No** | N/A (Lua plugins) | **Needs significant work** |
| **HAProxy** | **No** | **No** | N/A (SPOE/Lua) | **Needs significant work** |

### HAProxy

HAProxy does not support the Proxy-Wasm ABI. It has its own extensibility mechanisms:

| Mechanism | Description |
|-----------|-------------|
| SPOE / SPOA | Stream Processing Offload Engine — external agent protocol |
| Lua scripting | Inline scripting for request/response manipulation |
| FCGI | FastCGI for offloading to external processes |

### Kong Gateway

Kong Gateway is built on **NGINX + OpenResty (Lua)**, not Envoy. It does not implement ext_proc or Proxy-Wasm. Its extensibility is through Lua plugins and Go/Python/JS plugin SDKs.

---

## 6. Kong and the Inference Extension

Kong is **not listed** as an implementation of the inference extension. Per the project's `site-src/implementations/gateways.md`, the current implementations (planned or in progress) are:

1. **Alibaba Cloud ACK** — managed Kubernetes with ACK Gateway (Higress-based)
2. **Envoy AI Gateway** — built on Envoy + Envoy Gateway
3. **Google Kubernetes Engine (GKE)** — GKE Gateway controller
4. **Istio** — service mesh / gateway
5. **Agentgateway** — Rust-based, standalone or Kubernetes
6. **Kubvernor** — experimental Rust API Gateway (Envoy-based)
7. **NGINX Gateway Fabric** — NGINX as data plane

Kong would need significant work to integrate with the inference extension — either implementing an ext_proc client as a custom plugin or adopting the Proxy-Wasm shim approach.

---

## 7. Kong AI Gateway Architecture

Kong implements its AI Gateway through **native Lua plugins** on top of NGINX/OpenResty — a completely different architecture than the inference extension.

### AI Plugins

| Plugin | Purpose |
|--------|---------|
| **ai-proxy** | Translates requests to/from multiple LLM providers via a unified API |
| **ai-proxy-advanced** | Multi-model load balancing (round-robin, lowest-latency, semantic routing) |
| **ai-prompt-template** | Centralized prompt template management |
| **ai-prompt-decorator** | Inject system prompts or context into requests |
| **ai-prompt-guard** | Allow/deny lists for prompt governance |
| **ai-rate-limiting-advanced** | Rate limiting by token count or cost |

### Architecture

```
Client → Kong Gateway (NGINX/OpenResty)
              │
              ├── ai-prompt-guard (validate prompt)
              ├── ai-prompt-decorator (inject system prompt)
              ├── ai-proxy (translate to provider format)
              │       │
              │       ├── OpenAI
              │       ├── Azure AI
              │       ├── Anthropic
              │       ├── Cohere
              │       └── ...other providers
              │
              └── response transformation (back to unified format)
```

### Key Difference from the Inference Extension

| Aspect | Kong AI Gateway | Gateway API Inference Extension |
|--------|----------------|--------------------------------|
| **Focus** | LLM provider proxy & governance | Intelligent endpoint selection within a model serving cluster |
| **Architecture** | Lua plugins on NGINX/OpenResty | ext_proc protocol (gRPC) to EPP |
| **Routing intelligence** | Provider-level: which LLM backend | Pod-level: which specific model server pod |
| **CRDs** | None — configured via Admin API or decK | `InferencePool`, `InferenceModel`, etc. |

They solve **different problems**:

- **Kong**: "Route this request to OpenAI vs Azure vs Anthropic" (provider-level routing + governance)
- **Inference Extension**: "Route this request to the best GPU pod running vLLM in my cluster" (pod-level, inference-aware routing)

---

## 8. Inference Gateway vs AI Gateway

A gateway supporting the inference extension is better described as an **"Inference Gateway"** — not an "AI Gateway."

### What "AI Gateway" Typically Means

| Capability | AI Gateway | Inference Extension |
|-----------|-----------|---------------------|
| Multi-provider routing (OpenAI, Azure, Anthropic) | Yes | No |
| Prompt governance / guardrails | Yes | No |
| PII redaction | Yes | No |
| Token-based rate limiting | Yes | No |
| LLM observability (token counts, cost) | Yes | Partial (metrics) |
| Credential management for LLM providers | Yes | No |
| Model-aware routing (by model name) | Sometimes | Yes |
| Pod-level intelligent routing (KV-cache, LoRA, queue depth) | No | Yes |
| Request/response streaming for inference | Sometimes | Yes |
| Load shedding based on model server state | No | Yes |

### The Distinction

```
App → [AI Gateway] → External LLM Providers (OpenAI, Anthropic...)

App → [Gateway + Inference Extension] → Your own GPU pods (vLLM, TGI...)
```

- **AI Gateway** (Kong, Portkey, LiteLLM, etc.) → sits between your app and **external LLM providers**
- **Inference Gateway** (this project) → sits between your gateway and your own **model server pods**

A **complete AI Gateway** might combine both: inference extension for smart pod-level routing internally, plus AI gateway capabilities (prompt guardrails, multi-provider fallback, observability) at the edge.

---

## 9. Higress: AI Gateway or Inference Gateway?

Higress is **both** — a full AI Gateway that also supports the Inference Extension.

### Coverage

| Capability | AI Gateway | Inference Gateway | Higress |
|-----------|-----------|-------------------|---------|
| Multi-provider LLM routing (100+ providers) | Yes | — | Yes |
| Unified protocol conversion (OpenAI-compatible) | Yes | — | Yes |
| Prompt governance / guardrails | Yes | — | Yes |
| Token-based rate limiting & cost tracking | Yes | — | Yes |
| MCP protocol support (AI agent tool calling) | Yes | — | Yes |
| RAG integration | Yes | — | Yes |
| Model-aware routing by model name | — | Yes | Yes |
| Pod-level intelligent routing (KV-cache, LoRA, queue depth) | — | Yes | Yes |
| ext_proc / EPP integration | — | Yes | Yes |
| InferencePool CRD support | — | Yes | **Yes (v2.2.0+)** |

### How Higress Supports the Inference Extension

Since Higress is built on **Envoy + Istio**, it natively supports ext_proc:

```
Client → Higress (Envoy data plane)
              │
              ├── AI Gateway plugins (WASM): provider routing, prompt governance, etc.
              │
              ├── ext_proc → EPP (Endpoint Picker)
              │                  ├── KV-cache utilization
              │                  ├── LoRA affinity
              │                  └── Queue depth
              │
              └── Route to optimal model server pod in InferencePool
```

Among the listed implementations in the repo's `site-src/implementations/gateways.md`, Higress falls under the **Alibaba Cloud ACK** entry — ACK Gateway with Inference Extension is built on Higress.

### Sources

- [Higress AI Gateway](https://higress.ai/en/)
- [Higress supports Gateway API Inference Extension](https://www.alibabacloud.com/blog/higress-has-supported-the-new-gateway-api-and-its-ai-inference-extension_602891)
- [Higress joins CNCF](https://www.cncf.io/blog/2026/03/25/higress-joins-cncf-delivering-an-enterprise-grade-ai-gateway-and-a-seamless-path-from-nginx-ingress/)
- [Higress GitHub](https://github.com/alibaba/higress)

---

## 10. Building an AI Gateway with Istio + WasmPlugins

With **Istio/Envoy + Inference Extension + your own WasmPlugins**, you can build a full AI Gateway.

### What Each Layer Gives You

| Layer | Provides |
|-------|----------|
| **Istio + Gateway API** | Traffic management, mTLS, observability |
| **Inference Extension (EPP)** | Intelligent pod-level routing (KV-cache, LoRA, queue depth) |
| **Your WasmPlugins** | The AI Gateway features you build yourself |

### What You Could Implement in WasmPlugins

- **LLM provider routing** — route to different backends based on model name
- **Prompt governance** — inspect/block/modify prompts before forwarding
- **PII redaction** — strip sensitive data from requests/responses
- **Token-based rate limiting** — parse streaming responses, count tokens, enforce limits
- **Request/response transformation** — normalize between OpenAI/Anthropic/etc. formats
- **Cost tracking** — log token usage per consumer
- **Guardrails** — content safety checks
- **RAG injection** — augment prompts with context from external sources

### Architecture

```
Client → Istio Gateway (Envoy)
              │
              ├── WasmPlugin: auth / rate limiting
              ├── WasmPlugin: prompt governance / PII redaction
              ├── WasmPlugin: provider format translation
              │
              ├── ext_proc → EPP (inference-aware endpoint selection)
              │
              ├── WasmPlugin: response transformation / token counting
              │
              └── Optimal model server pod in InferencePool
```

### Trade-offs

| Approach | Pros | Cons |
|----------|------|------|
| **DIY (Istio + WasmPlugins)** | Full control, no vendor lock-in, exactly what you need | You build and maintain everything yourself |
| **Higress** | AI features built-in (100+ providers, MCP, RAG), WASM-extensible | Alibaba ecosystem, less mainstream than Istio |
| **Kong** | Mature AI plugins, large ecosystem | No inference extension support, NGINX-based |

The approach is **incremental** — start with the inference extension for smart routing, add WasmPlugins as needed, and you have a customized AI Gateway tailored to your exact requirements.

---

## 11. Other Projects Combining AI Gateway + Inference Extension

Several projects take a similar approach to Higress — combining AI Gateway features with Inference Extension support on top of Envoy.

### Comparison

| Project | AI Gateway Features | Inference Extension | Architecture |
|---------|-------------------|---------------------|-------------|
| **Higress** | 100+ LLM providers, MCP, RAG, prompt governance | Yes (v2.2.0+) | Envoy + Istio + WASM |
| **Envoy AI Gateway** | Model-based routing, token rate limiting, multi-provider, observability | Yes (v0.3+) | Envoy Gateway + ext_proc |
| **kgateway** | Multi-provider (OpenAI, Anthropic, Gemini, Mistral), prompt guarding | Yes (v2.1+) | Envoy / agentgateway + ext_proc |
| **AIBrix** | LLM-aware routing, LoRA management, distributed KV-cache, autoscaler | Collaborating with GIE project | Envoy Gateway + ext_proc |

### Envoy AI Gateway

Built directly on Envoy Gateway, supports two modes:
- `HTTPRoute + InferencePool` — simple inference routing
- `AIGatewayRoute + InferencePool` — advanced AI features (model routing, token rate limiting, observability)

### kgateway

Formerly Gloo, now a CNCF project:
- First to integrate [agentgateway](https://agentgateway.dev/) as its AI data plane (v2.1+)
- Fully conformant with Gateway API v1.3.0 and Inference Extension v1.0.0
- Partnered with vLLM/llm-d for disaggregated serving
- Multi-provider support: OpenAI, Anthropic, Google Gemini, Mistral, Ollama
- Features: prompt guarding, LoRA adapter support, criticality-based prioritization, load shedding

### AIBrix

By ByteDance/vLLM project, more focused on the inference platform side:
- Distributed KV-cache runtime (50% throughput increase, 70% latency reduction)
- Heterogeneous GPU inference
- Unified AI Runtime sidecar
- LLM-tailored autoscaler
- Working with the GIE community toward future adoption

### The Common Pattern

All follow the same architecture:

```
Client → [Envoy-based Gateway]
              │
              ├── AI Gateway layer (provider routing, guardrails, rate limiting)
              │     (via WASM plugins, native filters, or custom extensions)
              │
              ├── ext_proc → EPP (inference-aware endpoint selection)
              │
              └── Optimal model server pod in InferencePool
```

### How to Choose

| If you need... | Consider |
|---------------|----------|
| Broadest LLM provider support + MCP | Higress |
| Pure Envoy Gateway ecosystem | Envoy AI Gateway |
| Agentgateway + service mesh + CNCF backing | kgateway |
| Deep vLLM integration + distributed KV-cache | AIBrix |
| Full control, build your own | Istio + your WasmPlugins |

### Sources

- [Envoy AI Gateway InferencePool Support](https://aigateway.envoyproxy.io/docs/capabilities/inference/inferencepool-support/)
- [kgateway Inference Extension](https://kgateway.dev/docs/integrations/inference-extension/)
- [kgateway v2.1 Release](https://www.cncf.io/blog/2025/11/18/kgateway-v2-1-is-released/)
- [AIBrix GitHub](https://github.com/vllm-project/aibrix)
- [AIBrix Architecture Paper](https://arxiv.org/html/2504.03648v1)
- [llm-d KV Cache Routing](https://developers.redhat.com/articles/2025/10/07/master-kv-cache-aware-routing-llm-d-efficient-ai-inference)

---

## Conclusion

The **Envoy + ext_proc + Gateway API Inference Extension** stack is becoming the standard approach for building AI/Inference Gateways on Kubernetes. The key distinction is:

- **Inference Gateway** = intelligent pod-level routing for self-hosted model servers
- **AI Gateway** = LLM provider abstraction, prompt governance, observability
- **Complete solution** = both combined (Higress, Envoy AI Gateway, kgateway, or DIY with Istio + WasmPlugins)
