/**
 * Session ID utilities - ONE SINGLE WAY per AGENTS.md
 * 
 * Two methods to get Pi session ID:
 * 1. process.env.AGENT_SESSION_ID (set by Pi TUI)
 * 2. Parse from current session JSONL file (fallback)
 */

import path from 'path';
import fs from 'fs';
import os from 'os';

/**
 * Get Pi Session ID - ONE SINGLE WAY
 * Tries two methods:
 * 1. process.env.AGENT_SESSION_ID (set by Pi TUI)
 * 2. Parse from most recent JSONL session file
 * 
 * @throws Error if session ID cannot be found
 */
export function getPiSessionID(): string {
  // Method 1: Check environment variable (set by Pi TUI)
  const envSessionID = process.env.AGENT_SESSION_ID;
  if (envSessionID) {
    return envSessionID;
  }
  
  // Method 2: Try to parse from current session JSONL file
  const sessionIdFromFile = getSessionIdFromJsonL();
  if (sessionIdFromFile) {
    console.warn(`[session] AGENT_SESSION_ID not set, using ID from JSONL file: ${sessionIdFromFile}`);
    return sessionIdFromFile;
  }
  
  throw new Error('AGENT_SESSION_ID not set. Pi TUI must be running.');
}

/**
 * Try to get session ID from current session JSONL file
 * Looks for most recent JSONL file in Pi's session directory
 */
function getSessionIdFromJsonL(): string | null {
  const cwd = process.cwd();
  const dirName = '--' + cwd.replace(/\//g, '-') + '--';
  const sessionDir = path.join(os.homedir(), '.pi', 'agent', 'sessions', dirName);
  
  if (!fs.existsSync(sessionDir)) {
    return null;
  }
  
  // Read directory and find most recent JSONL file
  const files = fs.readdirSync(sessionDir)
    .filter(f => f.endsWith('.jsonl'))
    .map(f => ({ 
      name: f, 
      mtime: fs.statSync(path.join(sessionDir, f)).mtime 
    }))
    .sort((a, b) => b.mtime.getTime() - a.mtime.getTime());
  
  if (files.length === 0) {
    return null;
  }
  
  // Parse session ID from filename: 2026-04-30T23-45-16-335Z_<sessionId>.jsonl
  const mostRecent = files[0];
  const match = mostRecent.name.match(/_([a-f0-9-]+)\.jsonl$/i);
  if (match) {
    return match[1];
  }
  
  return null;
}
