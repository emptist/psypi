# Pi Agent Implementation Plan for psypi

**Date**: 2026-05-04  
**Status**: Research & Planning  
**Author**: AI Assistant  
**Reference**: pi-mono project (`../refers/pi-mono`)

## Executive Summary

This document outlines the research findings from analyzing the pi-mono project's agent architecture and provides a detailed implementation plan for bringing Pi Agent capabilities to the psypi project (written in Gleam).

The goal is to implement a stateful, tool-executing agent with event streaming capabilities, similar to pi-mono's `@mariozechner/pi-agent-core`, but designed for Gleam's functional paradigm and psypi's specific needs.

---

## Table of Contents

1. [Research Findings](#research-findings)
2. [Architecture Analysis](#architecture-analysis)
3. [Implementation Plan](#implementation-plan)
4. [Technical Decisions](#technical-decisions)
5. [Risks and Challenges](#risks-and-challenges)
6. [Timeline](#timeline)

---

## Research Findings

### 1. pi-mono Architecture Overview

The pi-mono project implements a sophisticated three-layer architecture:

```
┌─────────────────────────────────────────┐
│  packages/ai - LLM Abstraction Layer    │
│  - Unified LLM API interface            │
│  - Multi-provider support               │
│  - Streaming response handling          │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  packages/agent - Agent Core Layer      │
│  - Agent class (state management)       │
│  - Agent Loop (event loop)              │
│  - Tool execution engine                │
│  - Message conversion (convertToLlm)    │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  packages/coding-agent - Application    │
│  - Concrete tools (bash, edit, etc.)    │
│  - Session management                   │
│  - CLI/TUI interface                    │
└─────────────────────────────────────────┘
```

### 2. Core Concepts

#### 2.1 AgentMessage vs LLM Message

**Key Insight**: pi-mono distinguishes between internal message representation and LLM-compatible messages.

```typescript
// AgentMessage - Flexible internal representation
type AgentMessage = 
  | UserMessage 
  | AssistantMessage 
  | ToolResultMessage 
  | CustomMessage;  // App-specific types

// LLM Message - Only what LLMs understand
type Message = 
  | UserMessage 
  | AssistantMessage 
  | ToolResultMessage;

// Conversion function
convertToLlm(messages: AgentMessage[]): Message[]
```

**Why This Matters**: This separation allows:
- UI-only messages (notifications, status updates)
- Custom message types for app-specific features
- Context window management before LLM calls
- Message transformation and filtering

#### 2.2 Event Flow

pi-mono uses a well-defined event sequence for agent lifecycle:

```
prompt("Hello")
├─ agent_start
├─ turn_start
├─ message_start   { message: userMessage }
├─ message_end     { message: userMessage }
├─ message_start   { message: assistantMessage }
├─ message_update  { message: partial... }      // Streaming chunks
├─ message_update  { message: partial... }
├─ message_end     { message: assistantMessage }
├─ tool_execution_start  { toolCallId, toolName, args }
├─ tool_execution_update { partialResult }      // If tool streams
├─ tool_execution_end    { toolCallId, result }
├─ message_start/end  { toolResultMessage }
├─ turn_end        { message, toolResults: [...] }
│
├─ turn_start                                    // Next turn
├─ message_start/end  { assistantMessage }       // LLM responds to tool result
├─ turn_end
└─ agent_end      { messages: [...] }
```

**Key Observations**:
- Events are emitted in a predictable sequence
- Tool execution is interleaved with message events
- Multiple turns can occur in a single prompt() call
- `agent_end` is always the final event

#### 2.3 Tool System

pi-mono's tool system is based on JSON Schema validation and type-safe execution:

```typescript
// Tool definition
interface AgentTool<TSchema> {
  name: string;
  description: string;
  parameters: TSchema;  // TypeBox schema
  execute: (
    args: Static<TSchema>, 
    signal?: AbortSignal
  ) => Promise<ToolResult>;
}

// Tool creation pattern
function createBashTool(cwd: string, options?: BashToolOptions): AgentTool {
  return {
    name: "bash",
    description: "Execute bash commands",
    parameters: Type.Object({
      command: Type.String({ description: "Bash command to execute" }),
      timeout: Type.Optional(Type.Number({ description: "Timeout in seconds" })),
    }),
    execute: async (args, signal) => {
      // Execute command
      return { 
        content: [
          { type: "text", text: output }
        ],
        isError: false 
      };
    }
  };
}
```

**Key Features**:
- Schema-based parameter validation
- Abort signal support for cancellation
- Structured tool results (text + images)
- Error handling via `isError` flag

#### 2.4 State Management

```typescript
interface AgentState {
  systemPrompt: string;
  model: Model;
  messages: AgentMessage[];
  tools: AgentTool[];
  isStreaming: boolean;
  streamingMessage?: AgentMessage;
  pendingToolCalls: Set<string>;
  errorMessage?: string;
}
```

**Key Design Decisions**:
- Mutable state wrapped in Agent class
- Defensive copying on state assignment
- Streaming state tracked separately
- Pending tool calls tracked by ID

#### 2.5 Message Queuing

pi-mono implements two message queue types:

```typescript
// Steering - Inject after current turn finishes
steer(message: AgentMessage): void;

// Follow-up - Run only after agent would otherwise stop
followUp(message: AgentMessage): void;
```

**Queue Modes**:
- `"all"` - Drain entire queue at once
- `"one-at-a-time"` - Process one message per drain

**Use Cases**:
- **Steering**: Inject context, redirect agent mid-task
- **Follow-up**: Chain tasks, auto-continue after completion

#### 2.6 Lifecycle Hooks

```typescript
// Before tool execution
beforeToolCall?: (
  context: BeforeToolCallContext,
  signal?: AbortSignal
) => Promise<BeforeToolCallResult | undefined>;

// After tool execution
afterToolCall?: (
  context: AfterToolCallContext,
  signal?: AbortSignal
) => Promise<AfterToolCallResult | undefined>;

// After each turn
shouldStopAfterTurn?: (
  context: ShouldStopAfterTurnContext
) => boolean | Promise<boolean>;
```

**Capabilities**:
- Block tool execution with custom error
- Modify tool results after execution
- Early termination based on custom logic
- Inject additional context or constraints

### 3. Tool Implementation Patterns

#### 3.1 Tool Definition Structure

```typescript
// tools/index.ts
export function createCodingToolDefinitions(cwd: string, options?: ToolsOptions): ToolDef[] {
  return [
    createReadToolDefinition(cwd, options?.read),
    createBashToolDefinition(cwd, options?.bash),
    createEditToolDefinition(cwd, options?.edit),
    createWriteToolDefinition(cwd, options?.write),
  ];
}

export function createReadOnlyToolDefinitions(cwd: string, options?: ToolsOptions): ToolDef[] {
  return [
    createReadToolDefinition(cwd, options?.read),
    createGrepToolDefinition(cwd, options?.grep),
    createFindToolDefinition(cwd, options?.find),
    createLsToolDefinition(cwd, options?.ls),
  ];
}
```

#### 3.2 Bash Tool Implementation

Key features of the bash tool:
- **Streaming output**: Real-time stdout/stderr streaming
- **Timeout support**: Optional timeout with process tree kill
- **Detached process tracking**: Track and cleanup detached processes
- **Temp file logging**: Full output capture to temp files
- **Truncation**: Configurable output truncation

```typescript
// Key implementation details
interface BashOperations {
  exec: (
    command: string,
    cwd: string,
    options: {
      onData: (data: Buffer) => void;
      signal?: AbortSignal;
      timeout?: number;
      env?: NodeJS.ProcessEnv;
    },
  ) => Promise<{ exitCode: number | null }>;
}
```

#### 3.3 File Operation Tools

- **Read tool**: Read files with truncation, encoding detection
- **Write tool**: Create/overwrite files with validation
- **Edit tool**: Search-replace with diff preview
- **Grep tool**: Search file contents with regex
- **Find tool**: Find files by name/pattern
- **Ls tool**: List directory contents

### 4. Comparison with psypi

| Feature | pi-mono | psypi (Current) | Gap |
|---------|---------|-----------------|-----|
| Language | TypeScript | Gleam | Different paradigm |
| Runtime | Node.js | Node.js (via Gleam JS) | ✅ Compatible |
| LLM Abstraction | Complete `@mariozechner/pi-ai` | None | ❌ Missing |
| Agent Core | Complete `@mariozechner/pi-agent-core` | None | ❌ Missing |
| Tool System | Complete tool set | None | ❌ Missing |
| State Management | Agent class | None | ❌ Missing |
| Event System | Event emitter pattern | None | ❌ Missing |
| Database | Not used in agent core | PostgreSQL (node_pg) | ✅ Advantage |

**psypi Advantages**:
- Already has database layer (tasks, issues, meetings, etc.)
- Gleam's type safety and pattern matching
- Functional paradigm benefits (immutability, pure functions)

**psypi Gaps**:
- No LLM integration
- No agent loop implementation
- No tool execution framework
- No event streaming

---

## Implementation Plan

### Phase 1: Foundation (Week 1-2)

#### 1.1 Core Type Definitions

**File**: `src/psypi_core/agent/types.gleam`

```gleam
pub type AgentMessage {
  UserMessage(content: String, timestamp: String)
  AssistantMessage(
    content: String, 
    tool_calls: List(ToolCall),
    stop_reason: StopReason
  )
  ToolResultMessage(
    tool_call_id: String, 
    content: List(ContentBlock),
    is_error: Bool
  )
}

pub type ContentBlock {
  TextContent(text: String)
  ImageContent(data: String, media_type: String)
}

pub type ToolCall {
  ToolCall(
    id: String,
    name: String,
    arguments: dynamic.Dynamic
  )
}

pub type StopReason {
  EndTurn
  ToolUse
  StopSequence
  Error
}

pub type AgentState {
  AgentState(
    system_prompt: String,
    messages: List(AgentMessage),
    tools: List(Tool),
    is_streaming: Bool,
    pending_tool_calls: Set(String),
  )
}
```

**Tasks**:
- [ ] Define `AgentMessage` type
- [ ] Define `ContentBlock` type
- [ ] Define `ToolCall` type
- [ ] Define `StopReason` type
- [ ] Define `AgentState` type
- [ ] Define `AgentEvent` type
- [ ] Add JSON encoding/decoding

#### 1.2 Event System

**File**: `src/psypi_core/agent/events.gleam`

```gleam
pub type AgentEvent {
  AgentStart
  AgentEnd(messages: List(AgentMessage))
  TurnStart
  TurnEnd(message: AssistantMessage, tool_results: List(ToolResultMessage))
  MessageStart(message: AgentMessage)
  MessageUpdate(message: AgentMessage)
  MessageEnd(message: AgentMessage)
  ToolExecutionStart(
    tool_call_id: String,
    tool_name: String,
    args: dynamic.Dynamic
  )
  ToolExecutionUpdate(partial_result: dynamic.Dynamic)
  ToolExecutionEnd(
    tool_call_id: String,
    result: ToolResult
  )
  Error(error: AgentError)
}

pub type AgentError {
  ConnectionError(String)
  LLMError(String)
  ToolError(String)
  ValidationError(String)
}
```

**Tasks**:
- [ ] Define all event types
- [ ] Implement event emitter pattern
- [ ] Add event subscription mechanism
- [ ] Implement event logging

#### 1.3 Tool Definition Framework

**File**: `src/psypi_core/agent/tool.gleam`

```gleam
pub type Tool {
  Tool(
    name: String,
    description: String,
    parameters: json_schema.Schema,
    execute: fn(dynamic.Dynamic, option.Option(AbortSignal)) -> 
      promise.Promise(Result(ToolResult, ToolError))
  )
}

pub type ToolResult {
  ToolResult(
    content: List(ContentBlock),
    is_error: Bool,
    details: option.Option(dynamic.Dynamic)
  )
}

pub type AbortSignal {
  AbortSignal(signal: dynamic.Dynamic)
}

pub fn create_tool(
  name: String,
  description: String,
  parameters: json_schema.Schema,
  execute: fn(dynamic.Dynamic, option.Option(AbortSignal)) -> 
    promise.Promise(Result(ToolResult, ToolError))
) -> Tool {
  Tool(name, description, parameters, execute)
}
```

**Tasks**:
- [ ] Define `Tool` type
- [ ] Define `ToolResult` type
- [ ] Implement `create_tool` helper
- [ ] Add JSON Schema validation
- [ ] Implement abort signal handling

### Phase 2: LLM Integration (Week 3-4)

#### 2.1 LLM Provider Abstraction

**File**: `src/psypi_core/llm/provider.gleam`

```gleam
pub type LLMProvider {
  OpenAI
  Anthropic
  Local(url: String)
}

pub type LLMConfig {
  LLMConfig(
    provider: LLMProvider,
    model: String,
    api_key: option.Option(String),
    base_url: option.Option(String),
    temperature: option.Option(Float),
    max_tokens: option.Option(Int),
  )
}

pub type Message {
  UserMessage(content: List(ContentBlock))
  AssistantMessage(content: List(ContentBlock), tool_calls: List(ToolCall))
  ToolResultMessage(tool_call_id: String, content: List(ContentBlock))
  SystemMessage(content: String)
}

pub fn stream_completion(
  config: LLMConfig,
  messages: List(Message),
  tools: List(Tool),
  signal: option.Option(AbortSignal),
) -> promise.Promise(Result(Stream, LLMError)) {
  // Implementation
}
```

**Tasks**:
- [ ] Define `LLMProvider` type
- [ ] Define `LLMConfig` type
- [ ] Define LLM `Message` type (separate from AgentMessage)
- [ ] Implement OpenAI provider
- [ ] Implement Anthropic provider
- [ ] Add streaming support
- [ ] Add error handling
- [ ] Add retry logic

#### 2.2 Message Conversion

**File**: `src/psypi_core/agent/message_converter.gleam`

```gleam
pub fn convert_to_llm(
  messages: List(AgentMessage)
) -> List(Message) {
  messages
  |> list.filter_map(fn(msg) {
    case msg {
      UserMessage(content, _) -> 
        Ok(UserMessage([TextContent(content)]))
      AssistantMessage(content, tool_calls, _) ->
        Ok(AssistantMessage([TextContent(content)], tool_calls))
      ToolResultMessage(id, content, _) ->
        Ok(ToolResultMessage(id, content))
    }
  })
}

pub fn transform_context(
  messages: List(AgentMessage),
  max_tokens: Int,
) -> List(AgentMessage) {
  // Implement context window management
  // - Prune old messages
  // - Keep system prompt
  // - Keep recent messages
}
```

**Tasks**:
- [ ] Implement `convert_to_llm`
- [ ] Implement `transform_context`
- [ ] Add context window management
- [ ] Add message truncation
- [ ] Add token counting

### Phase 3: Agent Core (Week 5-6)

#### 3.1 Agent Loop

**File**: `src/psypi_core/agent/agent_loop.gleam`

```gleam
pub fn run_agent_loop(
  state: AgentState,
  config: AgentLoopConfig,
  signal: option.Option(AbortSignal),
) -> promise.Promise(Result(AgentState, AgentError)) {
  // Main agent loop:
  // 1. Emit agent_start
  // 2. Convert messages to LLM format
  // 3. Stream LLM response
  // 4. Execute tools if needed
  // 5. Continue until stop
  // 6. Emit agent_end
}

pub fn execute_tool(
  tool: Tool,
  args: dynamic.Dynamic,
  signal: option.Option(AbortSignal),
) -> promise.Promise(Result(ToolResult, ToolError)) {
  // Tool execution with:
  // - Schema validation
  // - Timeout handling
  // - Error handling
  // - Abort signal support
}
```

**Tasks**:
- [ ] Implement main agent loop
- [ ] Implement tool execution
- [ ] Add event emission
- [ ] Add error recovery
- [ ] Add abort signal handling

#### 3.2 Agent Class

**File**: `src/psypi_core/agent/agent.gleam`

```gleam
pub type Agent {
  Agent(
    state: AgentState,
    config: AgentConfig,
    listeners: List(AgentEventListener),
    steering_queue: MessageQueue,
    follow_up_queue: MessageQueue,
  )
}

pub fn new(config: AgentConfig) -> Agent {
  Agent(
    state: initial_state(),
    config: config,
    listeners: [],
    steering_queue: MessageQueue("one-at-a-time"),
    follow_up_queue: MessageQueue("one-at-a-time"),
  )
}

pub fn prompt(
  agent: Agent,
  message: String,
) -> promise.Promise(Result(Agent, AgentError)) {
  // 1. Add user message
  // 2. Run agent loop
  // 3. Process queues
  // 4. Return updated agent
}

pub fn subscribe(
  agent: Agent,
  listener: AgentEventListener,
) -> Agent {
  Agent(..agent, listeners: [listener, ..agent.listeners])
}
```

**Tasks**:
- [ ] Implement `Agent` type
- [ ] Implement `new` constructor
- [ ] Implement `prompt` method
- [ ] Implement `subscribe` method
- [ ] Implement message queues
- [ ] Add state management

### Phase 4: Tool Implementation (Week 7-8)

#### 4.1 Bash Tool

**File**: `src/psypi_core/tools/bash.gleam`

```gleam
pub fn create_bash_tool(cwd: String) -> Tool {
  create_tool(
    "bash",
    "Execute bash commands",
    bash_schema(),
    fn(args, signal) {
      let command = decode.get_string(args, "command")
      let timeout = decode.get_optional_int(args, "timeout")
      
      execute_bash_command(cwd, command, timeout, signal)
    }
  )
}

fn execute_bash_command(
  cwd: String,
  command: String,
  timeout: option.Option(Int),
  signal: option.Option(AbortSignal),
) -> promise.Promise(Result(ToolResult, ToolError)) {
  // Use node child_process via FFI
  // Stream output
  // Handle timeout
  // Handle abort
}
```

**Tasks**:
- [ ] Implement bash schema
- [ ] Implement command execution via FFI
- [ ] Add output streaming
- [ ] Add timeout handling
- [ ] Add abort signal support
- [ ] Add output truncation

#### 4.2 File Tools

**Files**: 
- `src/psypi_core/tools/read.gleam`
- `src/psypi_core/tools/write.gleam`
- `src/psypi_core/tools/edit.gleam`

**Tasks**:
- [ ] Implement read tool
- [ ] Implement write tool
- [ ] Implement edit tool
- [ ] Add encoding detection
- [ ] Add file validation
- [ ] Add truncation

#### 4.3 Search Tools

**Files**:
- `src/psypi_core/tools/grep.gleam`
- `src/psypi_core/tools/find.gleam`
- `src/psypi_core/tools/ls.gleam`

**Tasks**:
- [ ] Implement grep tool
- [ ] Implement find tool
- [ ] Implement ls tool
- [ ] Add regex support
- [ ] Add glob pattern support

### Phase 5: Integration & Testing (Week 9-10)

#### 5.1 CLI Integration

**File**: `src/psypi_cli/main.gleam`

```gleam
pub fn run_agent_command(args: List(String)) {
  let agent = agent.new(config)
  let agent = agent.subscribe(agent, event_handler)
  
  case agent.prompt(agent, prompt_text) {
    Ok(agent) -> // Handle success
    Error(error) -> // Handle error
  }
}
```

**Tasks**:
- [ ] Add agent command to CLI
- [ ] Implement event display
- [ ] Add interactive mode
- [ ] Add configuration loading

#### 5.2 Database Integration

**File**: `src/psypi_core/agent/session.gleam`

```gleam
pub fn save_session(
  agent: Agent,
  session_id: String,
) -> promise.Promise(Result(Nil, SessionError)) {
  // Save agent state to database
  db.with_connection(fn(conn) {
    // Save messages
    // Save tool calls
    // Save state
  }, db_error_to_session_error)
}

pub fn load_session(
  session_id: String,
) -> promise.Promise(Result(Agent, SessionError)) {
  // Load agent state from database
}
```

**Tasks**:
- [ ] Design session schema
- [ ] Implement session save
- [ ] Implement session load
- [ ] Add session listing
- [ ] Add session deletion

#### 5.3 Testing

**Files**:
- `test/psypi_core/agent_test.gleam`
- `test/psypi_core/llm_test.gleam`
- `test/psypi_core/tools_test.gleam`

**Tasks**:
- [ ] Unit tests for agent types
- [ ] Unit tests for message conversion
- [ ] Integration tests for agent loop
- [ ] Mock LLM provider for testing
- [ ] Tool execution tests
- [ ] Event emission tests

---

## Technical Decisions

### 1. Why Gleam Instead of TypeScript?

**Pros**:
- ✅ Type safety with pattern matching
- ✅ Functional paradigm (immutability, pure functions)
- ✅ No runtime errors from type mismatches
- ✅ Better error handling with Result type
- ✅ Easier to reason about async code with Promise

**Cons**:
- ❌ Smaller ecosystem than TypeScript
- ❌ Need FFI for Node.js APIs
- ❌ Less tooling support

**Decision**: Use Gleam for core agent logic, TypeScript FFI for Node.js integration.

### 2. How to Handle LLM API Calls?

**Option A**: Direct HTTP calls via `gleam_http`  
**Option B**: FFI to Node.js `fetch` or `axios`  
**Option C**: FFI to existing TypeScript LLM SDKs

**Decision**: **Option B** - FFI to Node.js `fetch`
- Simpler than maintaining TypeScript SDK bindings
- More control over request/response handling
- Easier to add custom headers, retry logic

### 3. How to Implement Event Streaming?

**Option A**: Callback-based event emitter  
**Option B**: Channel-based message passing  
**Option C**: Stream-based with `gleam/iterator`

**Decision**: **Option A** - Callback-based event emitter
- Matches pi-mono's pattern
- Easier to integrate with CLI/TUI
- More flexible for different use cases

### 4. How to Handle Tool Execution?

**Option A**: Synchronous execution only  
**Option B**: Asynchronous with Promise  
**Option C**: Asynchronous with streaming results

**Decision**: **Option C** - Asynchronous with streaming
- Supports long-running tools (e.g., bash commands)
- Better user experience (real-time feedback)
- Matches pi-mono's pattern

### 5. How to Manage State?

**Option A**: Mutable state with refs  
**Option B**: Immutable state with state monad  
**Option C**: Immutable state with explicit passing

**Decision**: **Option C** - Immutable state with explicit passing
- More idiomatic Gleam
- Easier to test and reason about
- No hidden side effects

---

## Risks and Challenges

### Technical Risks

1. **FFI Complexity**
   - **Risk**: Complex Node.js APIs may be difficult to bind
   - **Mitigation**: Start with minimal FFI, expand as needed
   - **Impact**: Medium

2. **Streaming Implementation**
   - **Risk**: Streaming in Gleam may be challenging
   - **Mitigation**: Use Promise-based streaming pattern
   - **Impact**: High

3. **Error Handling**
   - **Risk**: Error propagation across FFI boundaries
   - **Mitigation**: Comprehensive error types, careful FFI design
   - **Impact**: Medium

4. **Performance**
   - **Risk**: Gleam-to-JS compilation overhead
   - **Mitigation**: Profile early, optimize hot paths
   - **Impact**: Low

### Integration Risks

1. **LLM API Changes**
   - **Risk**: LLM providers may change their APIs
   - **Mitigation**: Abstract provider interface, version pinning
   - **Impact**: High

2. **Tool Execution Safety**
   - **Risk**: Malicious tool execution (bash commands)
   - **Mitigation**: Sandboxing, permission system, validation
   - **Impact**: Critical

3. **State Consistency**
   - **Risk**: Database state vs. in-memory state drift
   - **Mitigation**: Single source of truth (database), optimistic updates
   - **Impact**: Medium

### Adoption Risks

1. **Learning Curve**
   - **Risk**: Users unfamiliar with Gleam
   - **Mitigation**: Good documentation, examples, TypeScript interop
   - **Impact**: Medium

2. **Ecosystem Maturity**
   - **Risk**: Gleam ecosystem may lack needed libraries
   - **Mitigation**: FFI to Node.js ecosystem, contribute back
   - **Impact**: Medium

---

## Timeline

### Week 1-2: Foundation
- [ ] Core type definitions
- [ ] Event system
- [ ] Tool framework
- [ ] Basic tests

### Week 3-4: LLM Integration
- [ ] Provider abstraction
- [ ] OpenAI provider
- [ ] Anthropic provider
- [ ] Message conversion
- [ ] Streaming support

### Week 5-6: Agent Core
- [ ] Agent loop
- [ ] Agent class
- [ ] State management
- [ ] Message queues
- [ ] Lifecycle hooks

### Week 7-8: Tools
- [ ] Bash tool
- [ ] File tools (read, write, edit)
- [ ] Search tools (grep, find, ls)
- [ ] Tool tests

### Week 9-10: Integration
- [ ] CLI integration
- [ ] Database integration
- [ ] Session management
- [ ] End-to-end tests
- [ ] Documentation

### Week 11-12: Polish & Release
- [ ] Performance optimization
- [ ] Error handling improvements
- [ ] Documentation
- [ ] Examples
- [ ] Release preparation

---

## Success Criteria

### Phase 1 Success
- ✅ All core types defined and tested
- ✅ Event system working
- ✅ Tool framework functional

### Phase 2 Success
- ✅ Can call OpenAI API
- ✅ Can call Anthropic API
- ✅ Streaming responses working
- ✅ Message conversion working

### Phase 3 Success
- ✅ Agent can run basic prompts
- ✅ Agent can execute tools
- ✅ Agent can handle multi-turn conversations
- ✅ Event emission working

### Phase 4 Success
- ✅ Bash tool working
- ✅ File tools working
- ✅ Search tools working
- ✅ All tools tested

### Phase 5 Success
- ✅ CLI integration working
- ✅ Database integration working
- ✅ End-to-end tests passing
- ✅ Documentation complete

---

## Pragmatic Approach: Dual-Track Monitor Agent Strategy

### Strategy Overview

After careful consideration, we've decided to take a more pragmatic approach to implementing Pi Agent in psypi. Instead of a full-scale implementation that might not deliver immediate value, we'll focus on a **dual-track strategy** with a specific use case: **Monitor Agent for Code Review**.

**Key Insight**: The current "fake monitor" (过客) works for basic code review, but lacks true "God's view" perspective. Rather than building a comprehensive agent system, we'll start with a focused experiment: can a Monitor Agent do better code reviews than the current system?

### Why This Approach?

1. **Low Risk, High Reward**
   - If Monitor Agent fails, we still have the working fake monitor
   - If it succeeds, we have a foundation for expansion
   - No need for 10-12 week investment upfront

2. **Immediate Value**
   - Code review is a concrete, measurable task
   - Easy to compare performance (fake monitor vs agent)
   - Quick feedback loop for iteration

3. **Self-Evolution Path**
   - Agent starts with code review
   - Gradually takes on more responsibilities
   - Eventually participates in its own design
   - Creates a sustainable improvement cycle

4. **No Urgency Pressure**
   - Current system works well enough
   - Can implement slowly and carefully
   - Focus on quality over speed

---

## Monitor Agent Implementation Plan

### Phase 1: Monitor Agent Prototype (Week 1-2)

**Goal**: Validate that agent can perform code review effectively

**Implementation**:

```gleam
// src/psypi_core/monitor/agent.gleam

pub type MonitorAgent {
  MonitorAgent(
    llm_config: LLMConfig,
    tools: List(Tool),
    review_history: List(ReviewResult),
  )
}

pub fn review_commit(
  agent: MonitorAgent,
  commit_diff: GitDiff,
) -> promise.Promise(Result(ReviewResult, AgentError)) {
  // 1. Read changed files
  // 2. Analyze code quality
  // 3. Check for issues
  // 4. Generate review comments
}
```

**Tool Set**:
- `read_file` - Read changed files
- `grep_code` - Search related code
- `check_patterns` - Check code patterns
- `query_db` - Query historical review records
- `analyze_complexity` - Analyze code complexity
- `check_dependencies` - Check dependency changes

**System Prompt**:
```
你是一个代码评审专家，负责审查代码提交。

你的职责：
1. 发现潜在的 bug 和安全问题
2. 检查代码质量和可维护性
3. 提出改进建议
4. 确保符合项目规范

评审原则：
- 准确性优于速度
- 建议具体可行
- 考虑上下文
- 学习历史经验

可用工具：
- read_file: 读取文件内容
- grep_code: 搜索相关代码
- query_history: 查询历史评审
- check_patterns: 检查代码模式

请基于 git diff 进行评审，给出具体的评审意见。
```

**Tasks**:
- [ ] Create MonitorAgent type
- [ ] Implement basic LLM integration
- [ ] Create minimal tool set (read, grep, query)
- [ ] Implement review_commit function
- [ ] Add basic error handling

---

### Phase 2: Dual-Track Parallel Testing (Week 3-4)

**Goal**: Compare fake monitor vs agent performance

**Implementation**:

```gleam
// src/psypi_core/monitor/supervisor.gleam

pub type MonitorMode {
  FakeOnly          // Only use fake monitor
  AgentOnly         // Only use agent
  DualTrack         // Run both in parallel
  GradualHandover   // Gradually switch to agent
}

pub fn run_review(
  mode: MonitorMode,
  commit: GitCommit,
) -> promise.Promise(Result(ReviewReport, MonitorError)) {
  case mode {
    FakeOnly -> fake_monitor.review(commit)
    AgentOnly -> agent_monitor.review(commit)
    DualTrack -> {
      let fake_result = fake_monitor.review(commit)
      let agent_result = agent_monitor.review(commit)
      combine_and_compare(fake_result, agent_result)
    }
    GradualHandover -> {
      let score = get_agent_performance_score()
      case score > 0.8 {
        True -> agent_monitor.review(commit)
        False -> fake_monitor.review(commit)
      }
    }
  }
}
```

**Comparison Metrics**:

```bash
# Example output
=== Fake Monitor Review ===
- Issues found: 3
- Suggestions: 2
- Review time: 2s
- Accuracy: Unknown

=== Agent Review ===
- Issues found: 5
- Suggestions: 4
- Review time: 15s
- Accuracy: To be validated

=== Comparison Analysis ===
- Agent found 2 additional issues
- Agent suggestions more specific and actionable
- Agent review time longer but acceptable
- Need to validate accuracy over time
```

**Evaluation Criteria**:

1. **Accuracy** - Real issues found / Total issues reported
   - Target: > 80%
   
2. **Recall** - Real issues found / Actual issues existing
   - Target: > 70%
   
3. **Actionability** - Suggestions adopted / Total suggestions
   - Target: > 50%
   
4. **Efficiency** - Review time vs value delivered
   - Target: Acceptable trade-off

**Tasks**:
- [ ] Implement dual-track mode
- [ ] Create comparison report generator
- [ ] Set up metrics collection
- [ ] Run parallel reviews for 2 weeks
- [ ] Analyze performance data

---

### Phase 3: Gradual Handover (Week 5-6)

**Goal**: If agent performs well, start taking over work

**Implementation**:

```bash
# Gradual transition plan
Week 5: Agent reviews 30% of commits
Week 6: Agent reviews 60% of commits
Week 7: Agent reviews 100% of commits
Week 8: Fake monitor becomes backup
```

**Performance Thresholds**:

```gleam
pub fn should_use_agent(history: List(ReviewResult)) -> Bool {
  let accuracy = calculate_accuracy(history)
  let recall = calculate_recall(history)
  let user_satisfaction = get_user_satisfaction(history)
  
  accuracy > 0.8 && recall > 0.7 && user_satisfaction > 0.75
}
```

**Monitoring Dashboard**:

```
Monitor Agent Performance Dashboard
====================================
Total Reviews: 45
Success Rate: 87%
User Satisfaction: 4.2/5.0

Issue Detection:
- Bugs found: 23 (21 confirmed)
- Security issues: 5 (5 confirmed)
- Code smells: 34 (28 confirmed)

Suggestion Quality:
- Total suggestions: 67
- Adopted: 41 (61%)
- Rejected: 12 (18%)
- Pending: 14 (21%)

Performance:
- Average review time: 12s
- False positive rate: 13%
- Missed issues: 3
```

**Tasks**:
- [ ] Implement performance tracking
- [ ] Create handover logic
- [ ] Set up monitoring dashboard
- [ ] Collect user feedback
- [ ] Adjust thresholds based on data

---

### Phase 4: Expand Responsibilities (Week 7+)

**Goal**: Give agent more work beyond code review

**New Capabilities**:

```gleam
pub type MonitorTask {
  ReviewCommit(commit: GitCommit)
  AnalyzeCodebase(scope: AnalysisScope)
  PredictIssues(timeframe: TimeFrame)
  SuggestRefactoring(area: CodeArea)
  MonitorPerformance(metrics: List(Metric))
  GenerateReport(report_type: ReportType)
  CoordinateWithOtherAgents(agents: List(AgentId))
}
```

**Task Assignment**:

```bash
# Agent autonomously selects tasks
psypi monitor assign --auto

Agent: "I noticed increased commit frequency recently. I will:
1. Increase review thoroughness
2. Analyze code quality trends
3. Predict potential problem areas
4. Prepare weekly summary report
Proceed?"
```

**Proactive Monitoring**:

```
Agent: "Based on the last 2 weeks of commits, I've identified:
- 3 areas with increasing complexity
- 2 potential performance bottlenecks
- 1 security concern in authentication flow

Should I create detailed reports for each?
Or should I create tasks for the team to address them?"
```

**Tasks**:
- [ ] Implement task prioritization
- [ ] Add codebase analysis capability
- [ ] Add prediction models
- [ ] Create reporting tools
- [ ] Implement proactive monitoring

---

### Phase 5: Self-Design and Evolution (Week 9+)

**Goal**: Agent participates in its own design and improvement

**Implementation**:

```bash
# Agent participates in design discussions
psypi monitor design-discuss

Agent: "Based on 4 weeks of operation, I suggest:
1. Add performance profiling tool
2. Improve pattern detection accuracy
3. Add automated test suggestions

These improvements require:
- New tool: read_perf_log
- Database update: review_patterns table
- Integration: test_coverage tool

Estimated impact:
- 15% improvement in issue detection
- 20% reduction in false positives
- Better user experience

Should I proceed with implementation plan?"
```

**Self-Improvement Cycle**:

```
Execute Tasks → Collect Feedback → Analyze Performance →
Identify Gaps → Propose Improvements → Implement Changes →
Validate Impact → Repeat
```

**Meta-Learning**:

```gleam
pub fn analyze_own_performance(
  agent: MonitorAgent,
  timeframe: TimeFrame,
) -> promise.Promise(Result(ImprovementPlan, AgentError)) {
  // 1. Analyze review accuracy trends
  // 2. Identify common failure patterns
  // 3. Review user feedback
  // 4. Compare with baseline
  // 5. Generate improvement suggestions
  // 6. Estimate impact of changes
}
```

**Tasks**:
- [ ] Implement self-analysis tools
- [ ] Create improvement proposal system
- [ ] Add A/B testing capability
- [ ] Implement gradual rollout
- [ ] Create feedback loops

---

## Dual-Track Strategy Benefits

### 1. Risk Mitigation

**Before**: All-or-nothing approach
- If agent fails, no fallback
- High pressure to succeed
- Risk of wasted effort

**After**: Dual-track approach
- Fake monitor as safety net
- Low pressure experimentation
- Fail gracefully

### 2. Evidence-Based Decision Making

**Before**: Speculative implementation
- Hope that agent will be useful
- Unclear success criteria
- Subjective evaluation

**After**: Data-driven validation
- Concrete performance metrics
- Clear comparison baseline
- Objective decision criteria

### 3. Gradual Value Delivery

**Before**: Long wait for value
- 10-12 weeks before any benefit
- High opportunity cost
- Delayed feedback

**After**: Incremental value
- Week 2: Basic review capability
- Week 4: Performance comparison
- Week 6: Real productivity gains
- Continuous improvement

### 4. Sustainable Evolution

**Before**: One-time implementation
- Fixed feature set
- Manual maintenance
- Stagnation risk

**After**: Self-improving system
- Agent learns from experience
- Proposes own improvements
- Continuous evolution

---

## Technical Architecture for Monitor Agent

### Minimal Agent Framework

Instead of building a full agent framework, we'll create a minimal, focused implementation:

```gleam
// src/psypi_core/monitor/minimal_agent.gleam

pub type MinimalAgent {
  MinimalAgent(
    llm_config: LLMConfig,
    tools: List(Tool),
    context: AgentContext,
  )
}

pub type AgentContext {
  AgentContext(
    current_task: Option(MonitorTask),
    history: List(TaskResult),
    learned_patterns: List(Pattern),
  )
}

pub fn execute_task(
  agent: MinimalAgent,
  task: MonitorTask,
) -> promise.Promise(Result(TaskResult, AgentError)) {
  // Simplified agent loop:
  // 1. Understand task
  // 2. Plan execution
  // 3. Execute with tools
  // 4. Validate results
  // 5. Learn from outcome
}
```

### Tool Integration

```gleam
// src/psypi_core/monitor/tools.gleam

pub fn create_monitor_tools() -> List(Tool) {
  [
    // File operations
    create_read_file_tool(),
    create_grep_code_tool(),
    
    // Code analysis
    create_check_patterns_tool(),
    create_analyze_complexity_tool(),
    
    // Database access
    create_query_history_tool(),
    create_save_review_tool(),
    
    // Git operations
    create_read_diff_tool(),
    create_get_commit_info_tool(),
  ]
}

// Example tool implementation
fn create_read_file_tool() -> Tool {
  Tool(
    name: "read_file",
    description: "Read file contents with line range support",
    parameters: file_read_schema(),
    execute: fn(args, signal) {
      let path = decode.get_string(args, "path")
      let start_line = decode.get_optional_int(args, "start_line")
      let end_line = decode.get_optional_int(args, "end_line")
      
      read_file_range(path, start_line, end_line, signal)
    }
  )
}
```

### LLM Integration (Minimal)

```gleam
// src/psypi_core/monitor/llm_client.gleam

pub fn call_llm(
  config: LLMConfig,
  messages: List(Message),
  tools: List(Tool),
) -> promise.Promise(Result(LLMResponse, LLMError)) {
  // Minimal implementation:
  // - Support OpenAI and Anthropic
  // - Basic streaming
  // - Tool calling support
  // - Error handling
  
  case config.provider {
    OpenAI -> call_openai(config, messages, tools)
    Anthropic -> call_anthropic(config, messages, tools)
  }
}
```

---

## Success Metrics for Monitor Agent

### Phase 1 Success (Prototype)
- ✅ Agent can perform basic code review
- ✅ Can read files and understand diffs
- ✅ Can identify obvious issues
- ✅ No critical false positives

### Phase 2 Success (Dual-Track)
- ✅ Performance metrics collection working
- ✅ Comparison reports generated
- ✅ Accuracy ≥ 75%
- ✅ Recall ≥ 65%

### Phase 3 Success (Handover)
- ✅ Agent handles 100% of reviews
- ✅ User satisfaction > fake monitor
- ✅ Issue miss rate < 5%
- ✅ False positive rate < 15%

### Phase 4 Success (Expansion)
- ✅ Can perform proactive analysis
- ✅ Can predict potential issues
- ✅ Can generate useful reports
- ✅ Team relies on agent insights

### Phase 5 Success (Self-Evolution)
- ✅ Agent identifies own weaknesses
- ✅ Proposes actionable improvements
- ✅ Improvements show measurable impact
- ✅ Continuous improvement cycle established

---

## Comparison: Full Agent vs Monitor Agent Approach

| Aspect | Full Agent (Original Plan) | Monitor Agent (Pragmatic) |
|--------|---------------------------|---------------------------|
| **Scope** | Comprehensive agent system | Focused code review agent |
| **Time to Value** | 10-12 weeks | 2-4 weeks |
| **Risk** | High (all-or-nothing) | Low (dual-track) |
| **Investment** | Large upfront | Incremental |
| **Fallback** | None | Fake monitor backup |
| **Validation** | Speculative | Evidence-based |
| **Evolution** | Manual updates | Self-improving |
| **Immediate Need** | Unclear | Clear (better reviews) |

---

## Revised Timeline

### Week 1-2: Monitor Agent Prototype
- [ ] Minimal agent framework
- [ ] Basic LLM integration
- [ ] Essential tools (read, grep, query)
- [ ] Code review capability

### Week 3-4: Dual-Track Testing
- [ ] Parallel execution mode
- [ ] Performance metrics
- [ ] Comparison reports
- [ ] User feedback collection

### Week 5-6: Gradual Handover
- [ ] Performance-based switching
- [ ] Monitoring dashboard
- [ ] Threshold tuning
- [ ] Full handover

### Week 7-8: Capability Expansion
- [ ] Additional analysis tools
- [ ] Proactive monitoring
- [ ] Report generation
- [ ] Task prioritization

### Week 9+: Self-Evolution
- [ ] Self-analysis tools
- [ ] Improvement proposals
- [ ] A/B testing
- [ ] Continuous optimization

---

## Next Steps

1. **Start with Monitor Agent prototype** - Focus on code review use case
2. **Implement dual-track mode** - Compare with existing system
3. **Collect performance data** - Make evidence-based decisions
4. **Gradually expand** - Based on proven value
5. **Enable self-evolution** - Let agent improve itself

**Note**: This pragmatic approach allows us to deliver value quickly while maintaining the option to expand into a full agent system later if needed. The key is to start small, prove value, and evolve organically.

---

## References

- [pi-mono repository](../refers/pi-mono)
- [pi-mono AGENTS.md](../refers/pi-mono/AGENTS.md)
- [Gleam documentation](https://gleam.run/documentation/)
- [node-postgres documentation](https://node-postgres.com/)
- [OpenAI API documentation](https://platform.openai.com/docs)
- [Anthropic API documentation](https://docs.anthropic.com/)

---

## Changelog

### 2026-05-04 (Update 2)
- Added pragmatic dual-track Monitor Agent strategy
- Revised implementation plan with focus on code review use case
- Added 5-phase approach: Prototype → Dual-Track → Handover → Expansion → Self-Evolution
- Included detailed comparison metrics and success criteria
- Updated timeline to reflect incremental approach

### 2026-05-04 (Update 1)
- Initial research and planning document
- Architecture analysis complete
- Implementation plan outlined
- Technical decisions documented
