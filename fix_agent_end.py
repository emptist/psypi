#!/usr/bin/env python3
with open('src/generator/agent_end_coordination.gleam', 'r') as f:
    content = f.read()

old = '''    "              // LLM compose failed — use fallback\\n",
    "            }\\n",'''

new = '''    "              // LLM compose failed — tell S-agentbot what went wrong\\n",
    "              msg = `[from A-agentbot:] Wake up. (callMonitor failed: ${e})`;\\n",
    "            }\\n",'''

content = content.replace(old, new)

with open('src/generator/agent_end_coordination.gleam', 'w') as f:
    f.write(content)
print('Done')