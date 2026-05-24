# Root Cause Analysis: "JSON error injected into SSE stream"

**Date:** 2026-05-24
**Status:** Root cause identified, fix pending
**Severity:** High — blocks psypi/pi operation

## Error

```
Error: JSON error injected into SSE stream
```

Appears consistently in the pi TUI after any user prompt or agent_end event.

## Root Cause

**This is an OpenRouter 502 `provider_unavailable` error.**

OpenRouter returns a 502 error with this JSON body injected into the SSE stream:

```json
{
  "code": 502,
  "message": "JSON error injected into SSE stream",
  "metadata": {
    "error_type": "provider_unavailable"
  }
}
```

This is a **transient server-side error from OpenRouter** — not a bug in psypi or pi-coding-agent.

### Evidence

1. The exact error message `"JSON error injected into SSE stream"` does NOT appear anywhere in:
   - psypi source code (`src/`)
   - pi-coding-agent (`@earendil-works/pi-coding-agent`)
   - pi-ai SDK (`@earendil-works/pi-ai`)
   - OpenAI SDK (`openai`)
   - Anthropic SDK (`@anthropic-ai/sdk`)

2. The error matches a **known OpenRouter 502 error pattern** documented in [opencode issue #22448](https://github.com/anomalyco/opencode/issues/22448), which shows the identical error:
   ```json
   {
     "code": 502,
     "message": "JSON error injected into SSE stream",
     "metadata": { "error_type": "provider_unavailable" }
   }
   ```

3. The error appears consistently after prompts because every prompt triggers an LLM API call through OpenRouter, which is returning 502 errors.

## How the Error Flows

1. User sends a prompt → pi calls LLM via OpenRouter
2. OpenRouter returns HTTP 200 but injects a 502 error JSON into the SSE stream
3. The OpenAI SDK's SSE parser encounters this non-standard JSON in the stream
4. pi-ai's `openai-completions.js` catches the error and sets:
   ```js
   output.stopReason = "error"
   output.errorMessage = error.message  // "JSON error injected into SSE stream"
   ```
5. pi surfaces this error in the TUI

## Why It's Happening Now

This is likely caused by:
- OpenRouter experiencing provider availability issues (upstream model provider down or overloaded)
- The specific model being used may have a flaky upstream provider
- This is NOT caused by any psypi code change (verified via `git diff`)

## Affected Code Paths

### Primary: pi's main LLM call
- Every user prompt triggers this if OpenRouter is returning 502s
- The error stops the entire agent turn

### Secondary: psypi's `call_monitor` in `pi_extension_ffi.mjs`
- The autonomic agent_end hook calls `completeSimple()` which also goes through OpenRouter
- If the main prompt works but `call_monitor` hits the 502, the autonomic wake-up fails
- `call_monitor` already has retry logic (retries with `reasoning: 'none'`), but it doesn't specifically handle 502 `provider_unavailable` errors

## Potential Fixes

### Option A: Wait for OpenRouter to recover (temporary)
If this is a transient outage, it will resolve on its own.

### Option B: Add retry logic for 502 provider_unavailable errors
In `pi_extension_ffi.mjs` `call_monitor()`, add specific handling for this error:
- Detect the `"JSON error injected into SSE stream"` or `provider_unavailable` pattern
- Retry with exponential backoff (2-3 attempts)
- Fall back to a different model/provider if available

### Option C: Switch to a different provider/model
If the current model's upstream provider is consistently failing, switch to a more stable one.

### Option D: Report upstream to pi-coding-agent
The pi-ai SDK should handle OpenRouter 502s as retryable errors (similar to the opencode fix in issue #22448).

## References

- [opencode #22448: 502 provider_unavailable errors from OpenRouter](https://github.com/anomalyco/opencode/issues/22448) — exact same error, proposed retry fix
- [pi_extension_ffi.mjs](../src/pi_extension_ffi.mjs) — `call_monitor()` function with existing retry logic
- [openai-completions.js](file:///opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai/dist/providers/openai-completions.js) — pi-ai error handling at lines 322-327
