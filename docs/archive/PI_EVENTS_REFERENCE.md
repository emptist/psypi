# Pi Event Hooks Reference

Complete list of available `pi.on()` event hooks from extensions.md.

## Session Events
| Event | Description |
|-------|-------------|
| `session_start` | Session initialization |
| `session_shutdown` | Session cleanup |
| `session_before_switch` | Before switching context |
| `session_before_fork` | Before forking session |
| `session_before_compact` | Before compaction |
| `session_compact` | During compaction |
| `session_before_tree` | Before tree operations |
| `session_tree` | Tree operations |

## Agent Events
| Event | Description |
|-------|-------------|
| `before_agent_start` | Before agent starts |
| `agent_start` | Agent lifecycle start |
| `agent_end` | Agent lifecycle end |

## Turn/Message Events
| Event | Description |
|-------|-------------|
| `turn_start` | Turn begins |
| `turn_end` | Turn ends |
| `message_start` | Message starts |
| `message_update` | Message updates |
| `message_end` | Message ends |

## Tool Events
| Event | Description |
|-------|-------------|
| `tool_call` | Tool called (CAN BLOCK dangerous ops!) |
| `tool_result` | Tool result returned |
| `tool_execution_start` | Tool execution begins |
| `tool_execution_update` | Tool execution progress |
| `tool_execution_end` | Tool execution ends |

## Provider Events
| Event | Description |
|-------|-------------|
| `before_provider_request` | Before LLM request |
| `after_provider_response` | After LLM response |
| `model_select` | Model selection |

## Other Events
| Event | Description |
|-------|-------------|
| `thinking_level_select` | Thinking level selection |
| `resources_discover` | Resource discovery |
| `context` | Context updates |
| `user_bash` | User bash command |
| `input` | Input handling |

## Monitor Usage
- **Safety**: `tool_call` can block dangerous operations
- **Guidance**: `before_agent_start` for injecting Monitor advice
- **Capture**: `tool_result` for logging/callbacks
- **Session**: `session_start` for context setup