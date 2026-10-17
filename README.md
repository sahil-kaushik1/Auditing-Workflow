 # SAFe Agentic Workflow 
### AI Agent Harness for Multi-Agent Team Workflows
  
**A Production-Tested Three-Layer Architecture for Coordinated AI Teams** 
     
<p align="center"> 
  <img src="https://img.shields.io/badge/version-v2.10.0-blue?style=flat-square" alt="Version">   
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/template-ready-brightgreen?style=flat-square" alt="Template Ready">  
  <img src="https://img.shields.io/badge/tests-382%2F382-brightgreen?style=flat-square" alt="Tests"> 
  <a href="https://deepwiki.com/bybren-llc/safe-agentic-workflow"> 
    <img src="https://img.shields.io/badge/DeepWiki-bybren--llc%2Fsafe--agentic--workflow-blue?style=flat-   square&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IndoaXRlIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCI+PHBhdGggZD0iTTQgMTloMTYiLz48cGF0aCBkPSJNNCAxNWg4Ii8+PHBhdGggZD0iTTQgMTFoMTIiLz48cGF0aCBkPSJNNCA3aDE2Ii8+PC9zdmc+" alt="DeepWiki">   
  </a>    
</p>   
<p align="center"> 
  <a href=".claude/agents/">
    <img src="https://img.shields.io/badge/agents-11%20SAFe%20roles-red?style=flat-square" alt="Agents">
  </a>
  <a href=".claude/skills/">
    <img src="https://img.shields.io/badge/skills-18%20model--invoked-purple?style=flat-square" alt="Skills">
  </a>
  <a href=".claude/commands/">
    <img src="https://img.shields.io/badge/commands-24%20workflows-orange?style=flat-square" alt="Commands">
  </a>
  <a href=".cursor/rules/">
    <img src="https://img.shields.io/badge/cursor%20rules-16-00D084?style=flat-square" alt="Cursor Rules">
  </a>
</p>


---

## What This Is

A **production-tested AI agent harness** for teams that want structured AI workflows.
 
**Multi-provider support**: Works with **Claude Code** (Anthropic), **Gemini CLI** (Google), **Codex CLI** (OpenAI), and **Cursor IDE** (Anysphere).

**Built on SAFe methodology** (Scaled Agile Framework), adapted for AI agent teams.
Works for any team with repeatable processes: Software, Marketing, Research, Legal, Operations.

Includes:

- **18 Model-Invoked Skills** - Domain expertise that loads automatically (Skills 2.0 frontmatter)
- **24 Slash Commands** - Workflow automation for common tasks
- **11 SAFe Agent Profiles** - Specialized roles with clear boundaries
- **Three-Layer Architecture** - Hooks → Commands → Skills
- **Agent Teams** - Multi-agent orchestration with SAFe quality gates (experimental)
- **Dark Factory** - Persistent autonomous agent teams via tmux on remote servers ([guide](dark-factory/README.md))

> **Origin**: 5 months production use, 169 issues, 2,193 commits. Implements patterns from
> [6 Anthropic engineering papers](#implementing-anthropics-research) and [SAFe methodology](https://scaledagileframework.com/).

---

## Quick Start (30 seconds)

### Claude Code (Anthropic)

```bash
# Copy harness to your project
cp -r .claude/ /your-project/.claude/

# Customize placeholders
edit .claude/SETUP.md  # Replace {{TICKET_PREFIX}}, {{PROJECT_NAME}}

# Start working
/start-work TICKET-123
```

### Gemini CLI (Google)

```bash
# Copy harness to your project
cp -r .gemini/ /your-project/.gemini/

# Install Gemini CLI (if needed)
npm install -g @google/gemini-cli

# Authenticate
export GEMINI_API_KEY="your-api-key"

# Start working
/workflow:start-work TICKET-123
```

### Codex CLI (OpenAI)

```bash
# Copy harness to your project
cp -r .codex/ /your-project/.codex/
cp -r .agents/ /your-project/.agents/

# Install Codex CLI (if needed)
npm install -g @openai/codex

# Authenticate
export OPENAI_API_KEY="your-api-key"

# Start working (natural language, no slash commands)
codex
```

### Cursor IDE (Anysphere)

```bash
# Copy rules to your project
cp -r .cursor/ /your-project/.cursor/

# Open in Cursor
cursor /your-project

# Rules activate automatically based on file context
# Use @rule-name to invoke agent roles manually
```

**That's it.** Your AI assistant now has your team's workflow patterns built in.

---

## Keeping Your Harness Updated

Already using the harness and a new version is out? You have two paths:

**Automated** (multi-domain, manifest-based):
```bash
# Initialize sync metadata (first time only)
./scripts/sync-claude-harness.sh init
./scripts/sync-claude-harness.sh manifest init --yes

# Preview and apply (syncs all domains in your manifest's sync_scope)
./scripts/sync-claude-harness.sh sync --version v2.10.0 --dry-run
./scripts/sync-claude-harness.sh sync --version v2.10.0

# Sync specific domains only
./scripts/sync-claude-harness.sh sync --version v2.10.0 --scope .claude,.gemini
```

**Manual** (full release, all providers):
```bash
git remote add harness https://github.com/bybren-llc/safe-agentic-workflow.git
git fetch harness main --tags
git diff v2.9.0..v2.10.0 --stat              # See what changed
git checkout harness/main -- .codex/agents/   # Cherry-pick what you need
bash scripts/setup-template.sh                # Re-apply your placeholders
```

> The sync script protects your customizations via a manifest (required since v2.10.0).
> It won't overwrite files you've marked as protected. See the
> [Harness Sync Guide](docs/HARNESS_SYNC_GUIDE.md) for the full reference and
> [Upgrade Guide](docs/releases/v2.10.0-UPGRADE.md) for rollback options.

---

## The Three-Layer Architecture

```text
┌──────────────────────────────────────────────────────────────────────┐
│                      Claude Code Harness                              │
├──────────────────────────────────────────────────────────────────────┤
│  LAYER 1: HOOKS     │ Automatic guardrails (format checks, blockers) │
│  LAYER 2: COMMANDS  │ User-invoked workflows (/start-work, /pre-pr)  │
│  LAYER 3: SKILLS    │ Model-invoked expertise (pattern discovery)    │
└──────────────────────────────────────────────────────────────────────┘
```

> **Philosophy**: Process as _service_, not _control_.
> Everything exists to reduce cognitive load on already-solved problems.

---

## Choose Your Path

<details>

### Getting Started

1. Run `bash scripts/setup-template.sh` to customize placeholders
2. Read the [Getting Started Guide](docs/guides/GETTING-STARTED.md) for the full walkthrough
3. Run `/start-work` on your first ticket

**Adopting into an existing repo?** See the [Workspace Adoption Guide](docs/guides/WORKSPACE-ADOPTION-GUIDE.md).
**Upgrading from a previous version?** See [Keeping the Harness Updated](docs/guides/WORKSPACE-ADOPTION-GUIDE.md#keeping-the-harness-updated).
**Syncing your fork with upstream?** See the [Harness Sync Guide](docs/HARNESS_SYNC_GUIDE.md).

### Key Commands

| Command           | Purpose                           |
| ----------------- | --------------------------------- |
| `/start-work`     | Begin ticket with proper workflow |
| `/pre-pr`         | Validate before pull request      |
| `/end-work`       | Complete session cleanly          |
| `/check-workflow` | Quick status check                |

### Full Command Reference

**Workflow** (8): `/start-work`, `/pre-pr`, `/release`, `/end-work`, `/check-workflow`, `/update-docs`, `/retro`, `/sync-linear`

**Local Operations** (3): `/local-sync`, `/local-deploy`, `/quick-fix`

**Remote Operations** (5): `/remote-status`, `/remote-deploy`, `/remote-health`, `/remote-logs`, `/remote-rollback`

[Complete Setup Guide](.claude/SETUP.md)

</details>

<details>
<summary><strong>For Researchers</strong> - I want to understand the methodology</summary>

### Research Foundation

This harness implements patterns from 6 Anthropic engineering papers (see [below](#implementing-anthropics-research)).

See `docs/whitepapers/` for methodology deep-dives and comparative analysis.

</details>

<details>
<summary><strong>For Leaders</strong> - I want to understand adoption</summary>

### Adoption Requirements

- At least one supported AI tool: Claude Code, Gemini CLI, Codex CLI, or Cursor IDE
- Git repository
- Team buy-in for structured workflows

### Why Teams Choose SAW

- **Structured autonomy**: AI agents work within clear boundaries and quality gates
- **Evidence-based delivery**: Every deliverable requires verifiable evidence, not "trust me"
- **Multi-provider flexibility**: Same workflow across Claude Code, Gemini CLI, Codex CLI, and Cursor IDE

### Known Limitations

- Claude Code has the deepest integration; Gemini CLI, Codex CLI, and Cursor IDE support is newer
- Non-SWE domain adaptations (marketing, research) are documented but not yet validated in production

</details>

---

## Gemini CLI Integration

<details>
<summary><strong>Why Gemini CLI?</strong> - Unique capabilities and when to use it</summary>

### Gemini CLI Unique Features

Gemini CLI offers capabilities that complement Claude Code:

| Feature | Gemini CLI | Claude Code |
|---------|------------|-------------|
| **Shell Injection** | `!{command}` - Execute shell, inject output into prompt | Via Bash tool only |
| **File Injection** | `@{file}` - Inject file contents into prompts | Via Read tool only |
| **Built-in Sandbox** | Google Cloud sandboxing | MCP sandboxing |
| **Model Options** | Gemini 3 Flash, Gemini 3.1 Pro Preview | Claude Opus, Sonnet, Haiku |
| **Command Format** | TOML | YAML + Markdown |
| **Namespaced Commands** | `/workflow:start-work` | `/start-work` |
| **Hooks** | `settings.json` hooks section | `hooks-config.json` |
| **MCP Servers** | `settings.json` mcpServers | `settings.local.json` |
| **Hook Migration** | `gemini hooks migrate --from-claude` | N/A |
| **Plan Mode** | `/plan` command, plan-then-execute | N/A |
| **Policy Engine** | YAML policies, seatbelt profiles | N/A |
| **Browser Agent** | Built-in experimental agent | MCP (claude-in-chrome) |
| **Extensions** | Bundled skill/MCP/command packages | N/A |
| **Checkpointing** | `/restore` session recovery | N/A |
| **Audio/Video** | Native multimodal (Gemini 3+) | N/A |

### When to Use Gemini CLI

**Choose Gemini CLI when you need:**
- Shell command output directly in prompts (`!{git log --oneline -5}`)
- File contents injected into context (`@{package.json}`)
- Plan mode for complex multi-step tasks (`/plan`)
- Audio/video transcription and analysis (Gemini 3+ multimodal)
- Policy engine for fine-grained tool control
- Google Cloud integration and Gemini model family access

**Choose Claude Code when you need:**
- Agent subprocesses with tool restrictions
- Claude model family access
- Production-tested workflow (5+ months validated)

### Gemini CLI Quick Reference

```bash
# Installation
npm install -g @google/gemini-cli

# Authentication (choose one)
export GEMINI_API_KEY="your-api-key"
# or
gcloud auth application-default login

# Start Gemini CLI
gemini

# List available commands
/help

# List available skills
/skills
```

### Command Syntax Differences

| Action | Claude Code | Gemini CLI |
|--------|-------------|------------|
| Start work | `/start-work {{TICKET_PREFIX}}-123` | `/workflow:start-work {{TICKET_PREFIX}}-123` |
| Pre-PR check | `/pre-pr` | `/workflow:pre-pr` |
| Local sync | `/local-sync` | `/local:sync` |
| Remote deploy | `/remote-deploy` | `/remote:deploy` |
| Search patterns | `/search-pattern "pattern"` | `/search-pattern "pattern"` |

### Gemini CLI Documentation

- **Official Docs**: [geminicli.com](https://geminicli.com)
- **Installation**: [geminicli.com/docs/get-started/installation/](https://geminicli.com/docs/get-started/installation/)
- **Authentication**: [geminicli.com/docs/get-started/authentication/](https://geminicli.com/docs/get-started/authentication/)
- **Custom Commands**: [geminicli.com/docs/cli/custom-commands/](https://geminicli.com/docs/cli/custom-commands/)
- **Skills**: [geminicli.com/docs/cli/skills/](https://geminicli.com/docs/cli/skills/)

</details>

---

## Implementing Anthropic's Research

This harness directly implements patterns from Anthropic's engineering papers:

| Paper                                                                                                       | What We Implement          |
| ----------------------------------------------------------------------------------------------------------- | -------------------------- |
| [Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents)                | 11-agent team structure    |
| [Effective Harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)    | Three-layer architecture   |
| [Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) | 18 model-invoked skills    |
| [Skills Announcement](https://www.anthropic.com/news/skills)                                                | Skills 2.0 frontmatter, trigger patterns |
| [Code Execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp)                    | Tool restrictions per role |

> "The best harness is one you forget exists." — [Agent Perspective](docs/whitepapers/CLAUDE-CODE-HARNESS-AGENT-PERSPECTIVE.md)

---

## SAFe Foundation

<details>
<summary><strong>For Agile Practitioners</strong> - Deep dive into SAFe integration</summary>

This harness maps SAFe roles to AI agents:

| SAFe Role                | Agent            | Responsibility                    |
| ------------------------ | ---------------- | --------------------------------- |
| Business Systems Analyst | BSA              | Requirements, acceptance criteria |
| System Architect         | System Architect | Architecture decisions, ADRs      |
| Product Owner            | POPM (human)     | Final approval on deliverables    |
| Scrum Master             | TDM              | Coordination, blocker escalation  |
| Release Train Engineer   | RTE              | CI/CD, release coordination       |

### SAFe Concepts Implemented

- **Epic → Feature → Story → Enabler** hierarchy in specs
- **Sprint cycles** with velocity tracking
- **Evidence-based delivery** with Linear integration
- **Specs-driven workflow** - BSA plans, developers execute


</details>

---

## The 11-Agent Team

| Agent             | Role                    | When to Use               |
| ----------------- | ----------------------- | ------------------------- |
| BSA               | Requirements & specs    | Starting any feature      |
| System Architect  | Architecture review     | Significant changes       |
| FE Developer      | Frontend implementation | UI components             |
| BE Developer      | Backend implementation  | API routes, server logic  |
| Data Engineer     | Database & migrations   | Schema changes            |
| QAS               | Quality assurance       | Test validation           |
| Security Engineer | Security validation     | RLS, vulnerability checks |
| Tech Writer       | Documentation           | Guides, technical content |
| DPE               | Data provisioning       | Test data, seeds          |
| RTE               | Release coordination    | CI/CD, deployments        |
| TDM               | Coordination            | Blockers, escalation      |

See [AGENTS.md](AGENTS.md) for complete reference with invocation examples.

---

## Domain Adaptation Guide

The harness patterns work beyond software engineering:

### Marketing Team Example

| SWE Concept     | Marketing Adaptation  |
| --------------- | --------------------- |
| BSA (specs)     | Campaign Brief Writer |
| Code Review     | Asset Review          |
| `/pre-pr`       | `/pre-launch`         |
| Pattern Library | Brand Guidelines      |

### Research Team Example

| SWE Concept   | Research Adaptation  |
| ------------- | -------------------- |
| User Stories  | Research Questions   |
| Test Cases    | Validation Criteria  |
| CI/CD         | Peer Review Pipeline |
| Documentation | Literature Notes     |

---

## What Makes This Different

### Round Table Philosophy

Human and AI input have equal weight. No hierarchy, just expertise.

### Stop-the-Line Authority

Any agent can halt work for architectural or security concerns.

### Pattern Discovery Protocol

"Search First, Reuse Always, Create Only When Necessary"

### Evidence-Based Delivery

All work requires verifiable evidence. No "trust me, it works."

---

## vNext Workflow Contract (v1.4)

> **Note from the Author**: It became apparent early on that some of the autonomy and alignment we'd lost in our original harness was not going to work. This re-introduces strong solo and larger orchestration hats with selection criteria. Gates for QAS cover all scenarios.

### Complete Agent Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                        SAFe AGENTIC WORKFLOW - vNext                                     │
└─────────────────────────────────────────────────────────────────────────────────────────┘

                                    ┌──────────────┐
                                    │  USER/POPM   │
                                    │  Creates     │
                                    │  Linear      │
                                    │  Ticket      │
                                    └──────┬───────┘
                                           │
                                           ▼
                              ┌────────────────────────┐
                              │         BSA            │
                              │  • Defines AC/DoD      │
                              │  • Pattern discovery   │
                              │  • Creates spec        │
                              └────────────┬───────────┘
                                           │
                        ┌──────────────────┴──────────────────┐
                        │       STOP-THE-LINE GATE            │
                        │  AC/DoD exists? YES → Proceed       │
                        │                 NO  → STOP          │
                        └──────────────────┬──────────────────┘
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    ▼                      ▼                      ▼
          ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
          │  BE-DEVELOPER   │    │  FE-DEVELOPER   │    │  DATA-ENGINEER  │
          │  Exit: "Ready   │    │  Exit: "Ready   │    │  Exit: "Ready   │
          │   for QAS"      │    │   for QAS"      │    │   for QAS"      │
          └────────┬────────┘    └────────┬────────┘    └────────┬────────┘
                   └──────────────────────┼──────────────────────┘
                                          ▼
                        ┌─────────────────────────────────┐
                        │        QAS (GATE OWNER)         │
                        │  • Iteration authority          │
                        │  • Bounce back repeatedly       │
                        │  • Final evidence to Linear     │
                        │  Exit: "Approved for RTE"       │
                        └────────────┬────────────────────┘
                                     ▼
                        ┌─────────────────────────────────┐
                        │        RTE (PR SHEPHERD)        │
                        │  • PR creation (from spec)      │
                        │  • CI/CD monitoring             │
                        │  • NO code, NO merge            │
                        │  Exit: "Ready for HITL Review"  │
                        └────────────┬────────────────────┘
                                     ▼
                    ┌─────────────────────────────────────────────┐
                    │           3-STAGE PR REVIEW                 │
                    │  Stage 1: System Architect (pattern)        │
                    │  Stage 2: ARCHitect-in-CLI (architecture)   │
                    │  Stage 3: HITL ({{AUTHOR_NAME}}) → MERGE