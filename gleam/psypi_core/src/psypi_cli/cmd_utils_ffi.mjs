export function execute(cmd) {
  const { execSync } = require('child_process');
  try {
    const output = execSync(cmd, { encoding: 'utf-8', timeout: 30000 });
    return { ok: true, value: output };
  } catch(e) {
    return { ok: false, value: { ExecutionError: e.message } };
  }
}

export function exists(cmd) {
  const { execSync } = require('child_process');
  try {
    execSync('which ' + cmd, { stdio: 'ignore' });
    return true;
  } catch(e) {
    return false;
  }
}
