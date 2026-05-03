#!/usr/bin/env node
/**
 * Replace @@GIT_HASH@@ in built files with actual git hash
 */
import { execSync } from 'child_process';
import { readFileSync, writeFileSync, readdirSync, statSync } from 'fs';
import { join } from 'path';

function getGitHash() {
  try {
    return execSync('git rev-parse --short HEAD', { encoding: 'utf-8' }).trim();
  } catch {
    return 'unknown';
  }
}

function replaceInFile(filePath, hash) {
  try {
    const content = readFileSync(filePath, 'utf-8');
    const updated = content.replace(/@@GIT_HASH@@/g, hash);
    if (updated !== content) {
      writeFileSync(filePath, updated, 'utf-8');
      console.log(`  Updated hash in: ${filePath}`);
    }
  } catch (err) {
    console.warn(`  Warning: Could not process ${filePath}:`, err.message);
  }
}

function walkDir(dir) {
  const files = readdirSync(dir);
  for (const file of files) {
    const fullPath = join(dir, file);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      walkDir(fullPath);
    } else if (file.endsWith('.js') || file.endsWith('.cjs')) {
      replaceInFile(fullPath, getGitHash());
    }
  }
}

console.log('Replacing @@GIT_HASH@@ with actual git hash...');
walkDir('dist');
console.log(`Hash: ${getGitHash()}`);
