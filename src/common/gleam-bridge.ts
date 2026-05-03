// src/common/gleam-bridge.ts
// Simple bridge - only imports Gleam modules, not FFI

export {
  create,
  heartbeat,
} from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core/partner.mjs";
