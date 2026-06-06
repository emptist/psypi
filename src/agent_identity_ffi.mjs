// agent_identity_ffi.mjs — JavaScript FFI for agent_identity.gleam
//
// Contains ctx accessor functions that do NOT depend on @earendil-works/pi-ai.
// This file is imported by agent_identity.mjs which is imported by
// extension_generator.mjs (via ppi.mjs), so it MUST NOT depend on
// Pi runtime packages that are only available inside the Pi process.

// ctx accessor functions — extract properties from Pi ctx object.
// These only read properties from ctx, no Pi runtime package needed.
export function ctx_is_idle(ctx) {
  return ctx.isIdle();
}

export function ctx_get_source(ctx) {
  return ctx.model?.provider || '';
}

export function ctx_get_model_id(ctx) {
  return ctx.model?.id || '';
}

export function ctx_get_thinking_level(ctx) {
  return ctx.model?.thinkingLevel || '';
}
