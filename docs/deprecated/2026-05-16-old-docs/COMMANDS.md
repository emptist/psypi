# Psypi Command Reference - Complete Command List

> **All commands available in psypi (unified replacement for nezha and nupi)**
> 
> **Note**: `nezha` and `nupi` will be deleted once psypi is mature. Psypi is the complete, unified system.

## Legend
- ✅ **Working** (tested, functional)
- 🚧 **In Progress** (being implemented)

---

## All Commands (25+ Total)

### Core Task & Issue Management
| Command | Status | Description |
|---------|--------|-------------|
| `psypi task-add <title> [desc]` | ✅ Working | Add a task |
| `psypi tasks [--status]` | ✅ Working | List tasks |
| `psypi task-complete <id>` | ✅ Working | Mark a task as completed |
| `psypi issue-add <title> [--severity]` | ✅ Working | Add an issue |
| `psypi issue-list [--status]` | ✅ Working | List issues |
| `psypi issue-resolve <id> [notes]` | ✅ Working | Mark an issue as resolved |

### Meeting Management
| Command | Status | Description |
|---------|--------|-------------|
| `psypi meeting list [--limit] [--status]` | ✅ Working | List meetings |
| `psypi meeting show <id>` | ✅ Working | Show meeting details |
| `psypi meeting opinion <id> <perspective>` | ✅ Working | Add opinion to meeting |
| `psypi meeting complete <id> [consensus]` | ✅ Working | Complete a meeting |
| `psypi meeting cleanup [--days]` | ✅ Working | Cleanup old meetings |
| `psypi meeting archive [--days]` | ✅ Working | Archive old meetings |
| `psypi meeting search <term>` | ✅ Working | Search meetings |

### AI & Autonomous Work
| Command | Status | Description |
|---------|--------|-------------|
| `psypi think <question>` | ✅ Working | Delegate to external thinker |
| `psypi autonomous [context]` | ✅ Working | Autonomous work guidance |
| `psypi inner set-model [provider] [model]` | ✅ Working | Set inner AI model |
| `psypi inner model` | ✅ Working | Show inner AI agent ID |
| `psypi inner review` | ✅ Working | Invoke Inner AI review |

### Skills & Learning
| Command | Status | Description |
|---------|--------|-------------|
| `psypi skill-list` | ✅ Working | List approved skills |
| `psypi skill-show <name>` | ✅ Working | Show skill details |
| `psypi skill-build <name> <purpose>` | ✅ Working | Build new skill |
| `psypi skill-search <query>` | ✅ Working | Search skills |
| `psypi learn <insight>` | ✅ Working | Save learning to memory |
| `psypi areflect <text>` | ✅ Working | All-in-one [LEARN][ISSUE][TASK] |

### Session & Context
| Command | Status | Description |
|---------|--------|-------------|
| `psypi session-start` | ✅ Working | Start agent session |
| `psypi session-end` | ✅ Working | End agent session |
| `psypi context` | ✅ Working | Show current context |
| `psypi status` | ✅ Working | Show psypi status |

### Communication & Collaboration
| Command | Status | Description |
|---------|--------|-------------|
| `psypi announce <msg> [--priority]` | ✅ Working | Send announcement |
| `psypi broadcast <msg> [--priority]` | ✅ Working | Alias for announce |
| `psypi inter-review-request <taskId>` | ✅ Working | Request inter-review |
| `psypi inter-review-show <reviewId>` | ✅ Working | Show inter-review details |
| `psypi inter-reviews [status]` | ✅ Working | List inter-reviews |

### Documentation & Project
| Command | Status | Description |
|---------|--------|-------------|
| `psypi doc-save <name> <content>` | ✅ Working | Save project document |
| `psypi doc-list [project]` | ✅ Working | List project documents |
| `psypi project` | ✅ Working | Show project info |
| `psypi visits [limit]` | ✅ Working | Show recent visits |
| `psypi stats` | ✅ Working | Show ecosystem stats |

### Tools & Git
| Command | Status | Description |
|---------|--------|-------------|
| `psypi tools [tool-name]` | ✅ Working | List tools from DB |
| `psypi tools learn` | ✅ Working | Priority learnings |
| `psypi validate-commit <message>` | ✅ Working | Validate commit format |
| `psypi commit <message>` | ✅ Working | Git commit with quality control |
| `psypi provider-set-key <provider>` | ✅ Working | Set API key (encrypted) |

---

## Summary Statistics

| Status | Count | Percentage |
|--------|-------|------------|
| ✅ Working | 25+ | 100% |
| **Total Commands** | **25+** | **100%** |

---

## Command Name Convention

Psypi uses hyphenated command names (CLI convention):

| Old Style (nezha/nupi) | Psypi Style |
|------------------------|-------------|
| `skill list` | `psypi skill-list` |
| `skill show <name>` | `psypi skill-show <name>` |
| `skill build <name> <purpose>` | `psypi skill-build <name> <purpose>` |
| `nupi-think <question>` | `psypi think <question>` |
| `nupi-autonomous [context]` | `psypi autonomous [context]` |
| `nupi-meeting-*` | `psypi meeting <subcommand>` |

---

**Last Updated**: 2026-05-01  
**Status**: ✅ ALL COMMANDS IMPLEMENTED AND WORKING  
**Note**: `nezha` and `nupi` are being deprecated in favor of `psypi`
