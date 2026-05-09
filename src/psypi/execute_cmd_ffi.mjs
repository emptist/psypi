export function execute(cmd, timeout) {
  const { execSync } = require('child_process');
  try {
    const output = execSync(cmd, { 
      encoding: 'utf-8', 
      timeout: timeout,
      stdio: ['pipe', 'pipe', 'pipe']
    });
    return { 
      ok: true, 
      value: { 
        stdout: output || '', 
        stderr: '', 
        status: 0 
      } 
    };
  } catch(e) {
    return { 
      ok: false, 
      value: { ExecutionError: e.message || 'Command failed' } 
    };
  }
}
