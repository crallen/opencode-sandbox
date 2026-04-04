---
name: agent-authoring
description: Schemas, templates, conventions, and validation rules for creating OpenCode agents, skills, and slash commands.
---

# Agent Authoring Reference

This skill contains the exact schemas, conventions, and templates for authoring OpenCode agents, skills, and slash commands. Use it whenever creating or modifying these artifacts.

## File Locations and Naming

| Artifact | Location | Naming Rule | Identifier |
|---|---|---|---|
| Agent | `.opencode/agents/<name>.md` | kebab-case filename | Filename sans `.md` (becomes `@name`) |
| Skill | `.opencode/skills/<name>/SKILL.md` | kebab-case directory name | Directory name = `name` in frontmatter |
| Command | `.opencode/commands/<name>.md` | kebab-case filename | Filename sans `.md` (becomes `/name`) |

Identifiers must be consistent across all references:
- Commands reference agents by their filename identifier in the `agent:` frontmatter key.
- Agents reference skills by directory name in prose (e.g., "Use the skill tool to load `agent-authoring`").
- The global config (`opencode.json`) references the default agent by filename identifier.
- `AGENTS.md` uses `@name` syntax when referencing agents.

## Agent Definition Schema

### Frontmatter

```yaml
---
description: One-sentence summary of the agent's purpose and capabilities.
mode: primary | subagent
permission:
  edit: allow | deny
  bash:
    "*": allow | deny
    "<command-pattern>": allow
  webfetch: allow | ask | deny
color: "#hexcode"
---
```

| Key | Type | Required | Description |
|---|---|---|---|
| `description` | string | Yes | One-sentence summary. Displayed in agent listings and injected into the runtime. |
| `mode` | `"primary"` or `"subagent"` | Yes | `primary` = top-level orchestrator (only one). `subagent` = specialist invoked via `@mention` or Task tool. |
| `permission` | object | Yes | Defines the agent's access scope. See Permission Patterns below. |
| `color` | hex string | Subagents only | UI display color. Omit for `primary` agents. Must not duplicate an existing agent's color. |
| `temperature` | float (0.0-1.0) | No | Controls response randomness. Lower = more deterministic. Omit to use model defaults. |
| `top_p` | float (0.0-1.0) | No | Controls response diversity. Alternative to temperature. |
| `steps` | integer | No | Maximum agentic iterations before forced text-only response. Omit for unlimited. |
| `hidden` | boolean | No | Subagents only. Hides from `@` autocomplete menu. Agent can still be invoked via the Task tool. |

### Permission Patterns

#### Full access (for agents that need to build, test, or run arbitrary commands)

```yaml
permission:
  edit: allow
  bash:
    "*": allow
```

#### Read-only (for analysis agents that must not modify anything)

```yaml
permission:
  edit: deny
  bash:
    "*": deny
    "git diff*": allow
    "git log*": allow
    "git show*": allow
    "git blame*": allow
    "grep *": allow
    "rg *": allow
    "cat /workspace/*": allow
    "cat /reference/*": allow
    "wc /workspace/*": allow
    "wc /reference/*": allow
```

#### Edit + restricted bash (for agents that write files but have limited shell access)

```yaml
permission:
  edit: allow
  bash:
    "*": deny
    "git log*": allow
    "git diff*": allow
    "grep *": allow
    "rg *": allow
    "cat /workspace/*": allow
    "cat /reference/*": allow
    "ls *": allow
    "find /workspace*": allow
    "find /reference*": allow
    "wc /workspace/*": allow
    "wc /reference/*": allow
```

#### Bash pattern rules

- `"*": deny` sets the default to deny-all; specific patterns then allowlist commands.
- `"*": allow` permits all commands (use sparingly).
- Patterns use glob-style prefix matching: `"git diff*"` matches `git diff`, `git diff --staged`, etc.
- **Security**: Scope file-reading commands (`cat`, `find`, `tree`, `file`, `stat`) to `/workspace/*` and `/reference/*` to prevent reading sensitive files like SSH keys or `/proc/self/environ`.
- Per-agent permissions further restrict within the global config baseline. They cannot grant more than the global config allows.

#### Additional permission keys

Beyond `edit` and `bash`, these permission keys can be set at the agent level:

| Key | Granularity | Description |
|---|---|---|
| `webfetch` | URL pattern (`allow`, `ask`, `deny`) | Controls URL fetching. Set to `deny` for agents that shouldn't access the web. |
| `task` | Subagent name pattern | Controls which subagents an agent can invoke via the Task tool. Use glob patterns (e.g., `"orchestrator-*": allow`). |
| `skill` | Skill name pattern | Controls which skills an agent can load. Rarely needed — defaults to `allow`. |
| `question` | Non-granular | Controls whether the agent can ask the user interactive questions. |

Example — restricting task invocation:

```yaml
permission:
  task:
    "*": deny
    "code-reviewer": allow
    "tester": allow
```

### Body Structure

Follow this template for the markdown body (after the `---` closing the frontmatter):

```markdown
You are a senior [role title]. Your job is to [primary responsibility in one sentence].

## How You Work

1. **Step one** - Description of the first phase of the agent's workflow.
2. **Step two** - Load relevant skills: "Use the skill tool to load `skill-name` for [what it provides]."
3. **Step three** - The core work phase.
4. **Step four** - Verification, output, or handoff.

## [Domain-Specific Section]

Content covering the agent's domain expertise: categories, principles, techniques, etc.

## Output Format (optional — for analysis agents)

Structure your [report/review/analysis] as:

[Template with severity levels, sections, etc.]

## Guidelines

- Behavioral rule one.
- Behavioral rule two.
- Always read existing [artifacts] before creating new ones.
- You are running inside a Docker container. [Any relevant constraints.]
```

Key conventions:
- **Opening line**: Always starts with "You are a senior [role]." followed by "Your job is to [verb]."
- **How You Work**: Numbered steps. Reference the skill tool here for loading procedural knowledge.
- **Domain sections**: One or more sections with the agent's area-specific knowledge.
- **Output Format**: Only for analysis/reporting agents (code-reviewer, security-analyst). Includes severity levels and structured templates.
- **Guidelines**: Always the last section. Bullet list of behavioral rules and guardrails.

## Skill Definition Schema

### Frontmatter

```yaml
---
name: skill-name
description: One-sentence description of the skill's content.
---
```

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Must exactly match the directory name under `.opencode/skills/`. |
| `description` | string | Yes | One-sentence summary. Displayed in the skill tool's available skills listing. |

### Body Structure

Skills are **reference documents**, not personas. They contain structured knowledge that agents load on demand.

```markdown
# Skill Title

Brief introduction (1-2 sentences) explaining what this skill covers and when to load it.

## Section One

Reference content: tables, rules, patterns, examples.

### Subsection

More detailed content. Use:
- **Tables** for quick-reference data (commit types, severity levels, coverage targets)
- **Code blocks** with language tags for examples
- **Checklists** (`- [ ]`) for audit/review workflows
- **Numbered steps** for ordered processes

## Section Two

Additional reference content.

## Anti-Patterns (optional)

What NOT to do. Common mistakes to avoid.
```

Key conventions:
- **No persona statements**. Skills never say "you are..." — they are pure reference material.
- **Dense and scannable**. Use headings, tables, code blocks, and bullet points liberally.
- **Actionable examples**. Include real code examples, command snippets, and templates.
- **Self-contained**. A skill should provide everything an agent needs without requiring additional context lookups.
- Skills typically range from 90-250 lines.

## Command Definition Schema

### Frontmatter

```yaml
---
description: Short description of what the command does.
agent: agent-identifier
subtask: true
---
```

| Key | Type | Required | Description |
|---|---|---|---|
| `description` | string | Yes | Short description displayed in help/command listings. |
| `agent` | string | Yes | The agent identifier (filename without `.md`) to route this command to. |
| `subtask` | boolean | Yes | Always `true`. Indicates the command runs as a delegated subtask. |

### Body Structure

```markdown
Instructional text telling the agent what to do (1-3 sentences).

Optional dynamic content:
!`shell command here`

Optional conditional/fallback logic in prose:
If [condition], do X. If [other condition], do Y.

$ARGUMENTS
```

Key conventions:
- **Dynamic content**: Use `` !`command` `` syntax to inject shell command output into the prompt at invocation time. The `!` backtick block evaluates the command and replaces itself with the output.
- **`$ARGUMENTS`**: Always present, always at the end. Replaced with whatever the user types after the slash command (e.g., `/debug the login page crashes` replaces `$ARGUMENTS` with "the login page crashes").
- **Keep it short**. Commands are prompts, not documentation. 5-15 lines total.
- **Multiple commands can route to the same agent** (e.g., `/commit` and `/release` both route to `git-manager`).

## Color Palette

The existing palette follows the One Dark theme. Colors are semantically chosen.

| Color | Hex | Currently used by | Semantic meaning |
|---|---|---|---|
| Red/coral | `#e06c75` | code-reviewer | Critical analysis |
| Dark red/brick | `#be5046` | security-analyst | Security/danger |
| Green | `#98c379` | tester | Pass/fail, testing |
| Yellow/amber | `#e5c07b` | debugger | Warnings, investigation |
| Blue | `#61afef` | documenter | Informational |
| Purple | `#c678dd` | devops | Infrastructure |
| Orange/tan | `#d19a66` | git-manager | Version control |
| Cyan/teal | `#56b6c2` | frontend | UI/interface |
| Silver/gray | `#abb2bf` | agent-builder | Meta/tooling |

When choosing a color for a new agent, pick one that:
1. Is not already used by another agent.
2. Has semantic relevance to the agent's domain if possible.
3. Maintains sufficient visual contrast with existing colors.

## Validation Checklist

After creating or modifying an agent, skill, or command, verify:

- [ ] **Filename matches identifier**: Agent filename = `@mention` name. Skill directory = `name` in frontmatter. Command filename = `/command` name.
- [ ] **Cross-references are correct**: Commands reference valid agent identifiers. Agents reference valid skill names. AGENTS.md lists the new artifact.
- [ ] **No color collisions**: New agent's `color` is not used by any existing agent.
- [ ] **Permission model is appropriate**: Read-only agents deny edit and restrict bash. Analysis agents don't need write access. File-reading commands are scoped to safe paths.
- [ ] **Frontmatter is complete**: All required keys are present with valid values.
- [ ] **Body follows conventions**: Opening persona line (agents), no persona (skills), `$ARGUMENTS` at end (commands).
- [ ] **AGENTS.md is updated**: New agents appear in the subagent table, new skills in the skills table, new commands in the commands table.
- [ ] **README.md is updated**: Same tables are updated for user-facing documentation.

## Updating Global Documentation

When adding a new artifact, update these files:

### `.opencode/config/AGENTS.md`

- Add agents to the "Specialist Subagents" table.
- Add skills to the "Available Skills" table with description and primary agent users.
- Add commands to the "Slash Commands" table with description and agent.

### `README.md`

- Add agents to the "Agents" table under "What's Inside".
- Add skills to the "Skills" table.
- Add commands to the "Slash Commands" table.
