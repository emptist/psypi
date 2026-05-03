// src/common/gleam-bridge.ts
// Single bridge file - ALL Gleam modules exported here!

// Partner module (26 lines of beauty!)
export {
  create,
  heartbeat,
} from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core/partner.mjs";

// Review module (Gleam rewrite of InterReviewService!)
export {
  run_review,
} from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core/review.mjs";
