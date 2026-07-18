# ModelAdapter — Provider Interface Contract

## Purpose

Every AI model provider integrated into the SAW harness must satisfy this interface.
If a provider cannot meet a REQUIRED field, it cannot be used for that agent role.

## REQUIRED Interface

```
invoke(prompt, context, tools, max_tokens) → response
  prompt:     string (the agent's instruction)
  context:    string[] (file contents, task, code)
  tools:      string[] (list of tool names available)
  max_tokens: int (from task.budget_tokens)
  response:   string (model output)

count_tokens(text) → int
  text:    string
  returns: estimated token count (for budget enforcement)

get_capabilities() → CapabilitySet
  returns: see CapabilitySet below
```

## CapabilitySet (required fields)

```yaml
context_window_tokens:    int    # minimum 32k required for most agents
supports_tool_use:        bool   # required for Verifier, SAST Integrator
supports_code_generation: bool   # required for Verifier (PoC writing)
reasoning_depth:          low | medium | high | maximum
supports_structured_output: bool # required for Threat Modeler, Judge
```

## Minimum Capability Requirements by Agent Role

| Agent | Min context_window | reasoning_depth | tool_use | code_gen |
|-------|-------------------|----------------|---------|---------|
| Threat Modeler | 32k | maximum | false | false |
| Deep Reasoner | 32k | maximum | false | false |
| Verifier | 64k | high | true | true |
| Decomposer | 128k | high | false | false |
| Judge | 32k | high | false | false |
| Flow Mapper | 64k | medium | false | false |
| Skeptic | 32k | high | false | false |
| Economic Analyst | 32k | medium | true | false |
| Orchestrator | 32k | medium | false | false |
| SAST Integrator | 32k | low | true | false |
| Context Builder | 64k | low | true | false |
| Report Compiler | 32k | low | false | false |
| Harness Critic | 32k | medium | false | false |
| Deduplicator | 64k | low | false | false |
| Evolution Manager | 32k | medium | false | false |
| Hypothesis Generator | 32k | high | false | false |

## OPTIONAL Interface (improves performance if available)

```
stream(prompt, context, tools) → token_stream
  Use for long reasoning tasks (Deep Reasoner, Decomposer)
  Allows early termination if drift detected

get_cost_per_1k_tokens() → {input: float, output: float}
  Used by cost-tracking skill for per-task cost logging
```

## Provider Validation Check

Before running an audit with a new provider, verify:

```bash
# Check context window
echo "Provider context window: {N} tokens"
echo "Minimum required: 32,000 tokens"

# Check tool use support
echo "Tool use supported: {yes/no}"
echo "Required for: Verifier, SAST Integrator, Context Builder, Economic Analyst"

# Check structured output
echo "Structured output: {yes/no}"
echo "Required for: Threat Modeler (19-field tasks), Judge (gate decisions)"
```

## Known Provider Capabilities

| Provider | Model | Context | Tool Use | Code Gen | Reasoning Depth |
|---------|-------|---------|---------|---------|----------------|
| Anthropic | claude-opus-4 | 200k | ✓ | ✓ | maximum |
| Anthropic | claude-sonnet-4 | 200k | ✓ | ✓ | high |
| Anthropic | claude-haiku-3 | 200k | ✓ | ✓ | medium |
| OpenAI | o3 | 200k | ✓ | ✓ | maximum |
| OpenAI | gpt-4.1 | 128k | ✓ | ✓ | high |
| OpenAI | gpt-4.1-mini | 128k | ✓ | ✓ | medium |
| Google | gemini-2.5-pro | 1M | ✓ | ✓ | maximum |
| Google | gemini-2.5-flash | 1M | ✓ | ✓ | high |
