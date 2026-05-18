import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    try {\n",
    "      // Auto-Backup: only for 'edit' (write creates new files)\n",
    "      if (event.toolName === 'edit') {\n",
    "        const filePath = event.input?.path || event.input?.filePath;\n",
    "        if (filePath) {\n",
    "          try {\n",
    "            const fs = await import('fs');\n",
    "            const content = fs.readFileSync(filePath, 'utf-8');\n",
    "            const { save_version } = await import('./build/dev/javascript/psypi/code_version.mjs');\n",
    "            const result = await save_version(filePath, content, 'psypi', '', 'auto-backup');\n",
    "            const r = unwrapGleamResult(result);\n",
    "            if (r.ok) {\n",
    "              ctx.ui.setStatus('psypi-autobackup', 'Auto-backed up ' + filePath.split('/').pop());\n",
    "            } else {\n",
    "              ctx.ui.setStatus('psypi-autobackup', '[FAIL] save_version: ' + r.error);\n",
    "            }\n",
    "          } catch(e) {\n",
    "            ctx.ui.setStatus('psypi-autobackup', '[FAIL] ' + e.message);\n",
    "          }\n",
    "        }\n",
    "      }\n",
    "    } catch (err) {\n",
    "      ctx.ui.notify('tool_call hook error: ' + err.message, 'error');\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
