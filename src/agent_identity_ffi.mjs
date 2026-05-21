// agent_identity_ffi.mjs — JavaScript FFI for agent_identity.gleam

import { existsSync } from 'node:fs';
import { join } from 'node:path';

export function check_git_exists(cwd) {
  return existsSync(join(cwd, '.git'));
}
