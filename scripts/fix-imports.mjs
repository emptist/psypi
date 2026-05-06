// Fix .mjs imports in Gleam build output
// Gleam doesn't add .mjs extension to local imports, which breaks Node.js ESM

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const buildDir = path.join(__dirname, '..', 'gleam', 'psypi_core', 'build', 'dev', 'javascript', 'psypi_core');

let fixedCount = 0;

function fixFile(filePath) {
  let content = fs.readFileSync(filePath, 'utf-8');
  const original = content;

  // Fix imports like: from "./monitor_ai_js" -> from "./monitor_ai_js.mjs"
  // Only fix local imports (starting with ./ or ../) that don't already have .mjs
  content = content.replace(
    /from\s+["'](\.\.?\/[^"']*?)["']/g,
    (match, importPath) => {
      // Skip if already has .mjs extension
      if (importPath.endsWith('.mjs')) return match;
      // Skip node_modules imports
      if (!importPath.startsWith('.') && !importPath.startsWith('..')) return match;
      // Add .mjs extension
      return `from "${importPath}.mjs"`;
    }
  );

  if (content !== original) {
    fs.writeFileSync(filePath, content, 'utf-8');
    fixedCount++;
    console.log(`[fix-imports] Fixed: ${path.relative(buildDir, filePath)}`);
  }
}

function walkDir(dir) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const fullPath = path.join(dir, file);
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      walkDir(fullPath);
    } else if (file.endsWith('.mjs')) {
      fixFile(fullPath);
    }
  }
}

console.log('[fix-imports] Fixing .mjs imports...');
walkDir(buildDir);
console.log(`[fix-imports] Fixed ${fixedCount} files`);
