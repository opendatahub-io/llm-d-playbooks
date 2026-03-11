# Benchmarking Granite 3.3 8B Instruct

## Deploy and Benchmark vLLM

```bash
oc apply -k vllm/granite

oc wait --for=condition=ready pod -l serving.kserve.io/inferenceservice=granite-vllm \
  -n demo-llm --timeout=600s

oc apply -k guidellm/overlays/vllm-granite

oc logs -f job/vllm-granite-guidellm-benchmark -n demo-llm-benchmarks
```

## Deploy and Benchmark LLM-D

```bash
oc delete -k vllm/granite

oc apply -k llm-d/granite

oc wait --for=condition=ready pod -l app.kubernetes.io/name=granite \
  -n demo-llm --timeout=600s

oc apply -k guidellm/overlays/llm-d-granite

oc logs -f job/llm-d-granite-guidellm-benchmark -n demo-llm-benchmarks
```

## Clean Up

```bash
oc delete -k llm-d/granite
oc delete job vllm-granite-guidellm-benchmark llm-d-granite-guidellm-benchmark -n demo-llm-benchmarks
```

python kv-cache-prompt-generator.py \
  --kv-cache-size 158592 \
  --num-replicas 4 \
  --prompt-size 8000 \
  --num-pairs 8 \
  --output prompts.csv
