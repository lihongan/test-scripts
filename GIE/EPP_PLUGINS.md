# EPP (Endpoint Picker Proxy) Plugin System

## Overview

The EPP is a core component of the gateway-api-inference-extension project. It acts as an intelligent request router/scheduler for inference workloads, picking the best backend endpoint based on metrics like KV cache utilization, queue depth, and model affinity.

## EPP Source Code Layout

**Entry point:**
- `cmd/epp/main.go` — main binary entry point
- `cmd/epp/runner/` — runner, health checks, test runner

**Core packages under `pkg/epp/`:**

| Package | Purpose |
|---------|---------|
| `backend/metrics/` | Backend pod metrics collection and types |
| `config/` | EPP configuration and config loader |
| `controller/` | Kubernetes reconcilers (InferenceModel, InferencePool, Pod) |
| `datalayer/` | Data collection, endpoint pool, Kubernetes bindings |
| `datastore/` | In-memory data store for models and pods |
| `flowcontrol/` | Request flow control, queuing, eviction, scheduling |
| `metrics/` | EPP-level metrics (latency, tokens, queue size, etc.) |
| `util/` | Utilities for env, pod, and request handling |

## Plugin Categories & Interfaces

The EPP defines **6 plugin categories**, each with its own interface:

### 1. Scheduling Plugins

**Scorers** — score endpoints on a `[0,1]` scale, grouped by category:

| Plugin | Category | Purpose |
|--------|----------|---------|
| `prefix-cache-scorer` | Affinity | Scores by prefix cache hit ratio |
| `lora-affinity-scorer` | Affinity | Scores by LoRA model affinity |
| `kvcache-utilization-scorer` | Distribution | Scores by KV cache utilization |
| `queue-depth-scorer` | Distribution | Scores by queue depth |
| `running-requests-scorer` | Distribution | Scores by running request count |
| `token-load-scorer` | Distribution | Scores by token load |
| `latency-scorer` | Balance | Scores by predicted latency |

**Pickers** — select the final endpoint:

| Plugin | Purpose |
|--------|---------|
| `max-score-picker` | Picks highest-scoring endpoint |
| `random-picker` | Random selection |
| `weighted-random-picker` | Weighted random by score |

**Profile Handlers**: `single-profile-handler` — manages scheduler profiles.

### 2. Flow Control Plugins

| Plugin | Type | Purpose |
|--------|------|---------|
| `global-strict-fairness-policy` | Fairness | Global FIFO across all flows |
| `round-robin-fairness-policy` | Fairness | Round-robin among flows |
| `fcfs-ordering-policy` | Ordering | First Come First Served |
| `edf-ordering-policy` | Ordering | Earliest Deadline First |
| `slo-deadline-ordering-policy` | Ordering | SLO-aware deadline ordering |
| `concurrency-detector` | Saturation | Detects saturation by concurrency |
| `utilization-detector` | Saturation | Detects saturation by utilization |
| `static-usage-limit-policy` | Usage Limit | Static limit per priority level |

### 3. Request Control Plugins

| Plugin | Type | Purpose |
|--------|------|---------|
| `approximate-prefix-cache-producer` | DataProducer | Produces prefix cache match info |
| `inflightload-producer` | DataProducer | Produces in-flight load data |
| `predicted-latency-producer` | DataProducer | Produces latency predictions |
| `latency-slo-admitter` | Admitter | Rejects sheddable requests if SLO unmet |
| `request-attribute-reporter` | ResponseBody | Reports request attributes |

### 4. Data Layer Plugins

| Plugin | Purpose |
|--------|---------|
| `metrics-datasource` | Polls metrics from model servers |
| `notification-datasource` | Watches Kubernetes object events |
| `endpoint-notification-datasource` | Endpoint lifecycle events |
| `metrics-extractor` | Transforms raw metrics into endpoint attributes |

### 5. Request Handling (Parsers)

| Plugin | Purpose |
|--------|---------|
| `openai-parser` | Parses OpenAI API format requests |
| `vllm-grpc-parser` | Parses vLLM gRPC format |
| `passthrough-parser` | No parsing (passthrough) |

### 6. Test Plugins

| Plugin | Purpose |
|--------|---------|
| `header-based-test-filter` | Filter for conformance tests |
| `destination-endpoint-served-verifier` | Verifies endpoint served request |

## Request Processing Pipeline

```
Parse Request → Get InferenceObjective → Candidate Endpoints
  → Flow Control Admission
  → DataProducers (parallel, 400ms timeout)
  → Admitters (e.g., latency SLO check)
  → Scheduler: Filter → Score → Pick
  → PreRequest hooks
  → Route to endpoint
  → ResponseHeader plugins (async)
  → ResponseBody plugins (async, ordered)
```

### Extension Points

- **PreRequest** — After scheduling, before request sent
- **ResponseHeader** — When response headers received
- **ResponseBody** (async) — Each response chunk (guaranteed order)
- **ResponseComplete** — Final response chunk (EndOfStream=true)

### Producer/Consumer Data Flow

Plugins declare data dependencies using `Produces()` and `Consumes()`:

| Data Key | Producer | Consumer |
|----------|----------|----------|
| `prefix-cache-match-info` | `approximate-prefix-cache-producer` | `prefix-cache-scorer` |
| `inflight-load` | `inflightload-producer` | — |
| `latency-prediction` | `predicted-latency-producer` | `latency-slo-admitter` |

Missing producers are auto-created from `DefaultProducerRegistry` and execution is topologically sorted.

## Plugin Implementation Files

All paths relative to project root.

### Scheduling Plugins

**Scorers** — `pkg/epp/framework/plugins/scheduling/scorer/`

| Plugin | File |
|--------|------|
| prefix-cache-scorer | `scorer/prefix/plugin.go` |
| lora-affinity-scorer | `scorer/loraaffinity/lora_affinity.go` |
| kvcache-utilization-scorer | `scorer/kvcacheutilization/kvcache_utilization.go` |
| queue-depth-scorer | `scorer/queuedepth/queue.go` |
| running-requests-scorer | `scorer/runningrequests/runningrequest.go` |
| token-load-scorer | `scorer/tokenload/token_load.go` |
| latency-scorer | `scorer/latency/plugin.go` |

**Pickers** — `pkg/epp/framework/plugins/scheduling/picker/`

| Plugin | File |
|--------|------|
| max-score-picker | `picker/maxscore/picker.go` |
| random-picker | `picker/random/picker.go` |
| weighted-random-picker | `picker/weightedrandom/picker.go` |

**Profile Handler** — `pkg/epp/framework/plugins/scheduling/profile/`

| Plugin | File |
|--------|------|
| single-profile-handler | `profile/single_profile_handler.go` |

### Flow Control Plugins

**Fairness** — `pkg/epp/framework/plugins/flowcontrol/fairness/`

| Plugin | File |
|--------|------|
| global-strict-fairness-policy | `fairness/globalstrict/global_strict.go` |
| round-robin-fairness-policy | `fairness/roundrobin/roundrobin.go` |

**Ordering** — `pkg/epp/framework/plugins/flowcontrol/ordering/`

| Plugin | File |
|--------|------|
| fcfs-ordering-policy | `ordering/fcfs/fcfs.go` |
| edf-ordering-policy | `ordering/edf/edf.go` |
| slo-deadline-ordering-policy | `ordering/slodeadline/slo_deadline.go` |

**Saturation Detectors** — `pkg/epp/framework/plugins/flowcontrol/saturationdetector/`

| Plugin | File |
|--------|------|
| concurrency-detector | `saturationdetector/concurrency/detector.go` |
| utilization-detector | `saturationdetector/utilization/detector.go` |

**Usage Limits** — `pkg/epp/framework/plugins/flowcontrol/usagelimits/`

| Plugin | File |
|--------|------|
| static-usage-limit-policy | `usagelimits/usagelimitpolicy.go` |

### Request Control Plugins

`pkg/epp/framework/plugins/requestcontrol/`

| Plugin | File |
|--------|------|
| approx-prefix-cache-producer | `dataproducer/approximateprefix/plugin.go` |
| inflight-load-producer | `dataproducer/inflightload/producer.go` |
| predicted-latency-producer | `dataproducer/predictedlatency/plugin.go` |
| latency-slo-admitter | `admitter/latencyslo/plugin.go` |
| request-attribute-reporter | `requestattributereporter/plugin.go` |

### Data Layer Plugins

`pkg/epp/framework/plugins/datalayer/`

| Plugin | File |
|--------|------|
| metrics-datasource | `source/metrics/datasource.go` |
| notification-datasource | `source/notifications/factory.go` |
| endpoint-notification-datasource | `source/notifications/endpoint_datasource.go` |
| metrics-extractor | `extractor/metrics/extractor.go` |

### Request Handling (Parsers)

`pkg/epp/framework/plugins/requesthandling/parsers/`

| Plugin | File |
|--------|------|
| openai-parser | `parsers/openai/openai.go` |
| vllm-grpc-parser | `parsers/vllmgrpc/vllmgrpc.go` |
| passthrough-parser | `parsers/passthrough/passthrough.go` |

### Test Plugins

| Plugin | File |
|--------|------|
| header-based-test-filter | `pkg/epp/framework/plugins/scheduling/test/filter/request_header_based_filter.go` |
| destination-endpoint-served-verifier | `pkg/epp/framework/plugins/requestcontrol/test/responsereceived/destination_endpoint_served_verifier.go` |

## Plugin Interfaces

Plugin interfaces are defined under `pkg/epp/framework/interface/` in the following subdirectories:

| Directory | Interfaces |
|-----------|------------|
| `plugin/` | `Plugin`, `ConsumerPlugin`, `ProducerPlugin`, registry, handle, state |
| `scheduling/` | `ProfileHandler`, `Filter`, `Scorer`, `Picker` |
| `flowcontrol/` | `FairnessPolicy`, `OrderingPolicy`, `SaturationDetector`, `UsageLimitPolicy` |
| `datalayer/` | `DataSource`, `PollingDataSource`, `Extractor`, `NotificationSource`, `EndpointSource` |
| `requestcontrol/` | `PreRequest`, `ResponseHeaderProcessor`, `ResponseBodyProcessor`, `DataProducer`, `Admitter` |
| `requesthandling/` | `Parser` |

## Plugin Registration

All in-tree plugins are registered in `cmd/epp/runner/runner.go` via the `registerInTreePlugins()` function. Plugins use a factory pattern — each registers a `FactoryFunc` into a global registry, and plugins are instantiated from configuration with automatic dependency resolution (producers/consumers are topologically sorted).

## Plugin Configuration

### InferencePool CR vs EndpointPickerConfig

Plugin configuration is **NOT** in the InferencePool CR. It uses a separate config object called **EndpointPickerConfig**.

**InferencePool** (`api/v1/inferencepool_types.go`) is a stable (`v1`) Kubernetes CRD with only 4 spec fields:

```yaml
apiVersion: inference.networking.x-k8s.io/v1
kind: InferencePool
spec:
  selector:          # Which pods are in the pool
  targetPorts:       # Ports to use
  appProtocol:       # http or h2c
  endpointPickerRef: # Reference to EPP service (name, kind, port, failureMode)
```

**EndpointPickerConfig** (`apix/config/v1alpha1/endpointpickerconfig_types.go`) is an experimental (`v1alpha1`) config object with 7 top-level sections:

```yaml
apiVersion: inference.networking.x-k8s.io/v1alpha1
kind: EndpointPickerConfig

plugins:              # Plugin declarations (type, name, parameters)
schedulingProfiles:   # Profiles combining scorers/filters/pickers with weights
saturationDetector:   # Which saturation detector plugin
dataLayer:            # Data sources → extractors pipeline
parser:               # Request/response parser plugin
flowControl:          # Queuing, priorities, fairness, ordering
  maxBytes:
  maxRequests:
  defaultRequestTTL:
  defaultPriorityBand:
  priorityBands:      # Per-priority: maxBytes, maxRequests, fairnessPolicy, orderingPolicy
  usageLimitPolicyPluginRef:
featureGates:         # Experimental feature flags
```

| | InferencePool | EndpointPickerConfig |
|---|---|---|
| **API version** | `v1` (stable) | `v1alpha1` (experimental) |
| **What it is** | Kubernetes CRD (cluster resource) | Config file (mounted via ConfigMap) |
| **Concern** | **What** pods to route to | **How** to pick among them |
| **Complexity** | 4 fields | 7 sections, deeply nested |
| **Who manages** | Platform user | EPP operator/admin |
| **Delivery** | `kubectl apply` | `--config-file` flag or ConfigMap |

The InferencePool's `endpointPickerRef` points to the EPP service, and the EPP service reads its own EndpointPickerConfig separately. This separation keeps the user-facing CRD simple while allowing sophisticated scheduling tuning in the EPP config.

### EndpointPickerConfig Type Definitions

**PluginSpec** — declares a plugin instance:

```go
type PluginSpec struct {
    Name       string          // Optional identifier (defaults to Type)
    Type       string          // Required plugin type (e.g., "queue-scorer")
    Parameters json.RawMessage // Optional JSON config passed to factory
}
```

**SchedulingProfile** — combines plugins into a scheduling pipeline:

```go
type SchedulingProfile struct {
    Name    string             // Profile name
    Plugins []SchedulingPlugin // List of plugin references with weights
}

type SchedulingPlugin struct {
    PluginRef string   // Reference to a plugin by name
    Weight    *float64 // Optional scorer weight (default: 1.0)
}
```

**FlowControlConfig** — configures request queuing and prioritization:

```go
type FlowControlConfig struct {
    MaxBytes                  *resource.Quantity  // Global max bytes across all priorities
    MaxRequests               *resource.Quantity  // Global max concurrent requests
    DefaultRequestTTL         *metav1.Duration    // Fallback timeout for requests
    DefaultPriorityBand       *PriorityBandConfig // Template for unconfigured priorities
    PriorityBands             []PriorityBandConfig // Per-priority configurations
    UsageLimitPolicyPluginRef string              // Adaptive capacity plugin
}

type PriorityBandConfig struct {
    Priority          int                // Priority level (higher = more important)
    MaxBytes          *resource.Quantity // Max bytes for this band
    MaxRequests       *resource.Quantity // Max requests for this band
    FairnessPolicyRef string            // Default: "global-strict-fairness-policy"
    OrderingPolicyRef string            // Default: "fcfs-ordering-policy"
}
```

### How Config is Provided to EPP

**CLI flags** (defined in `pkg/epp/server/options.go`):
- `--config-file <path>` — path to YAML/JSON config file
- `--config-text <yaml/json>` — inline config string
- If neither is provided, built-in defaults are used

**In Kubernetes** — via a ConfigMap mounted into the EPP deployment. The Helm chart (`config/charts/epplib/templates/_config.yaml`) generates the ConfigMap, and the deployment passes `--config-file /config/default-plugins.yaml`.

### Default Config (when nothing is specified)

Defined in `pkg/epp/config/loader/defaults.go`:

| Component | Default |
|-----------|---------|
| Scorers | `queue-scorer` (weight 2.0), `kv-cache-utilization-scorer` (weight 2.0), `prefix-cache-scorer` (weight 3.0) |
| Picker | `max-score-picker` (auto-injected) |
| Profile Handler | `single-profile-handler` (auto-injected) |
| Parser | `openai-parser` |
| Saturation Detector | `utilization-detector` |
| Data Layer | `metrics-data-source` + `metrics-extractor` |

### Example Config Files

Found in `test/integration/epp/testdata/`:

**Minimal Config** (`default-config.yaml`):

```yaml
apiVersion: inference.networking.x-k8s.io/v1alpha1
kind: EndpointPickerConfig
plugins:
  - type: queue-scorer
  - type: kv-cache-utilization-scorer
  - type: prefix-cache-scorer
  - type: openai-parser
schedulingProfiles:
  - name: default
    plugins:
      - pluginRef: queue-scorer
      - pluginRef: kv-cache-utilization-scorer
      - pluginRef: prefix-cache-scorer
parser:
  pluginRef: openai-parser
featureGates:
  - enableLegacyMetrics
```

**With Data Layer** (`datalayer-config.yaml`):

```yaml
apiVersion: inference.networking.x-k8s.io/v1alpha1
kind: EndpointPickerConfig
plugins: [...]
schedulingProfiles: [...]
dataLayer:
  sources:
  - pluginRef: metrics-data-source
    extractors:
    - pluginRef: core-metrics-extractor
```

### Config Loading Flow

```
--config-file or --config-text or defaults
  → Parse YAML/JSON into EndpointPickerConfig
  → Apply static defaults (name = type if not set)
  → Register all in-tree plugins in registry (registerInTreePlugins)
  → Instantiate plugins via factory functions with parameters
  → Auto-inject missing critical components (picker, parser, etc.)
  → Validate structure
  → Build scheduler, data layer, flow control configs
  → EPP runtime ready
```

## In-Tree vs Out-of-Tree Plugin Model

The EPP plugin framework supports both **in-tree** and **out-of-tree** plugins, following the same pattern as kube-scheduler.

### In-Tree Plugins

In-tree plugins are community-standard, vendor-neutral plugins maintained directly in this repository (`kubernetes-sigs/gateway-api-inference-extension`). They are registered in `cmd/epp/runner/runner.go` via the `registerInTreePlugins()` function and are available to all users by default.

**When to contribute in-tree:**
- The plugin is broadly useful across vendors and platforms
- It implements a general-purpose scheduling, scoring, or flow control strategy
- It does not depend on vendor-specific hardware, metrics, or APIs

### Out-of-Tree Plugins

Out-of-tree plugins are developed and maintained in **separate repositories**. They are intended for vendor-specific or proprietary functionality tied to particular hardware, model servers, or infrastructure.

**When to use out-of-tree:**
- The plugin depends on vendor-specific metrics or APIs (e.g., custom accelerator telemetry)
- The plugin contains proprietary logic
- The plugin targets a specific model serving platform not covered by the standard protocol

**Important caveat:** The project notes that plugins relying on custom data collection "accept that the Model Server Protocol no longer provides guarantees on portability of a model server out of the box."

### Plugin Registry Mechanism

Plugins are registered to a global registry via factory functions defined in `pkg/epp/framework/interface/plugin/registry.go`:

```go
// Register a plugin factory function by type name.
func Register(pluginType string, factory FactoryFunc)

// Register a plugin as the default producer for a given data key.
// Out-of-tree projects can call this to make their producers eligible
// for auto-configuration alongside in-tree producers.
func RegisterAsDefaultProducer(pluginType string, factory FactoryFunc, key string)
```

Once registered, a plugin can be referenced by its type name in the `EndpointPickerConfig` YAML — the framework does not distinguish between in-tree and out-of-tree plugins at configuration time.

## Developing Out-of-Tree Plugins

### Step 1: Implement the Plugin Interface

Create a Go module that imports the framework interfaces and implements the desired plugin type:

```go
package myvendor

import (
    "context"
    "encoding/json"

    fwkplugin "sigs.k8s.io/gateway-api-inference-extension/pkg/epp/framework/interface/plugin"
    framework "sigs.k8s.io/gateway-api-inference-extension/pkg/epp/framework/interface/scheduling"
)

const MyVendorScorerType = "my-vendor-scorer"

type MyVendorScorer struct {
    typedName fwkplugin.TypedName
}

// Factory function — called by the framework when instantiating the plugin from config.
func NewScorerFactory(name string, params json.RawMessage, handle fwkplugin.Handle) (fwkplugin.Plugin, error) {
    return &MyVendorScorer{
        typedName: fwkplugin.TypedName{Type: MyVendorScorerType, Name: name},
    }, nil
}

func (s *MyVendorScorer) TypedName() fwkplugin.TypedName { return s.typedName }

func (s *MyVendorScorer) Category() framework.ScorerCategory {
    return framework.ScorerCategoryDistribution
}

func (s *MyVendorScorer) Score(ctx context.Context, cycleState *framework.CycleState,
    request *framework.InferenceRequest, pods []framework.Endpoint) map[framework.Endpoint]float64 {
    // Vendor-specific scoring logic here
    scores := make(map[framework.Endpoint]float64)
    for _, pod := range pods {
        scores[pod] = 0.5 // placeholder
    }
    return scores
}
```

### Step 2: Build a Custom EPP Binary

Write your own `main.go` that wraps the upstream runner and registers your plugin:

```go
package main

import (
    "os"

    ctrl "sigs.k8s.io/controller-runtime"

    "sigs.k8s.io/gateway-api-inference-extension/cmd/epp/runner"
    fwkplugin "sigs.k8s.io/gateway-api-inference-extension/pkg/epp/framework/interface/plugin"

    // Import your out-of-tree plugin
    myvendor "github.com/my-org/my-epp-plugin"
)

func main() {
    // Register your out-of-tree plugin BEFORE calling Run().
    fwkplugin.Register(myvendor.MyVendorScorerType, myvendor.NewScorerFactory)

    if err := runner.NewRunner().Run(ctrl.SetupSignalHandler()); err != nil {
        os.Exit(1)
    }
}
```

**All in-tree plugins remain available.** The `runner.NewRunner()` call triggers `registerInTreePlugins()` internally, which registers all ~40 built-in plugins. Your out-of-tree plugin is simply added alongside them in the same global registry.

### Step 3: Build and Containerize

Since Go plugins are linked at compile time (no dynamic/runtime loading), you must build your own EPP binary and container image:

```dockerfile
FROM golang:1.24 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o epp ./cmd/epp/

FROM gcr.io/distroless/static
COPY --from=builder /app/epp /epp
ENTRYPOINT ["/epp"]
```

### Step 4: Configure the Plugin in EndpointPickerConfig

Reference your out-of-tree plugin by its registered type name — exactly the same way as in-tree plugins:

```yaml
apiVersion: inference.networking.x-k8s.io/v1alpha1
kind: EndpointPickerConfig
plugins:
  # In-tree plugins (still available)
  - type: queue-scorer
  - type: kv-cache-utilization-scorer
  - type: openai-parser
  # Out-of-tree plugin
  - type: my-vendor-scorer
    parameters:
      customParam: "value"
schedulingProfiles:
  - name: default
    plugins:
      - pluginRef: queue-scorer
        weight: 2
      - pluginRef: kv-cache-utilization-scorer
        weight: 2
      - pluginRef: my-vendor-scorer
        weight: 3
parser:
  pluginRef: openai-parser
```

### Step 5: Deploy

Deploy your custom EPP image instead of the default one. The InferencePool's `endpointPickerRef` points to your EPP service, and the EndpointPickerConfig is provided via ConfigMap or `--config-file` flag as usual.

## Design Documentation

For architectural rationale and detailed design, see the following proposals:

| Proposal | Path | Status |
|----------|------|--------|
| EPP Architecture | `docs/proposals/0683-epp-architecture-proposal/README.md` | Implemented |
| Scheduler Architecture | `docs/proposals/0845-scheduler-architecture-proposal/README.md` | Implemented |
| Data Layer Architecture | `docs/proposals/1023-data-layer-architecture/README.md` | Implemented |
| Pluggable BBR Framework | `docs/proposals/1964-pluggable-bbr-framework/README.md` | Provisional |
