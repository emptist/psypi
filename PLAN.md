# Fix `before_agent_start` Hook to Record Event Trigger

## Goal
Ensure the `before_agent_start` hook records its execution in the `event_hooks` table before returning the system prompt. The current generated JavaScript returns the prompt **before** calling `event_hooks_record_trigger`, making the trigger