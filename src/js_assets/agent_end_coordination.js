// A-agentbot coordination: detect idle → check context → compose → wake up S-agentbot
ctx.ui.notify('[AUTONOMIC] agent_end fired', 'info');
try {
  let debounceMs;
  {
    const { get_debounce_ms } = await import('./build/dev/javascript/psypi/system_config.mjs');
    const result = await get_debounce_ms();
    const r = unwrapGleamResult(result);
    if (r.ok) {
      debounceMs = r.value;
    } else {
      ctx.ui.notify('[AUTONOMIC] get_debounce_ms failed: ' + r.error + ' — using 15000ms', 'warning');
      debounceMs = 15000;
    }
  }
  ctx.ui.notify('[AUTONOMIC] Starting debounce timer: ' + debounceMs + 'ms', 'info');
  setTimeout(async () => {
    try {
      ctx.ui.notify('[AUTONOMIC] Debounce fired, checking isIdle...', 'info');
      if (!ctx.isIdle()) {
        ctx.ui.notify('[AUTONOMIC] ctx.isIdle() = false, skipping A-agentbot wake-up', 'info');
        return;
      }
      if (ctx.hasPendingMessages()) {
        ctx.ui.notify('[AUTONOMIC] S-agentbot has pending messages, skipping wake-up', 'info');
        return;
      }
      const entries = ctx.sessionManager.getEntries();
      const recentAwakeup = entries.slice(-6).find(e =>
        e.message && e.message.customType === 'autonomic-wakeup'
      );
      if (recentAwakeup) {
        ctx.ui.notify('[AUTONOMIC] Recent autonomic-wakeup already in context, skipping repeat', 'info');
        return;
      }
      ctx.ui.notify('[AUTONOMIC] ctx.isIdle() = true, no recent wake-up, proceeding', 'info');
      let msg = '';
      try {
        ctx.ui.notify('[AUTONOMIC] Reading MONITOR-BRIEF.md...', 'info');
        const fs = await import('fs');
        const path = await import('path');
        const briefPath = path.join(ctx.cwd, 'docs', 'MONITOR-BRIEF.md');
        let brief = '';
        try { brief = fs.readFileSync(briefPath, 'utf-8'); } catch (_e) { ctx.ui.notify('[AUTONOMIC] No MONITOR-BRIEF.md found', 'info'); }
        const usage = ctx.getContextUsage();
        const tokenInfo = usage ? `Context: ${Math.round(usage.tokens / usage.contextWindow * 100)}% used.` : '';
        const recentEntries = entries.slice(-10);
        const recentSummary = recentEntries.map(e => {
          if (e.message) {
            const role = e.message.role || 'unknown';
            const text = (e.message.content || []).filter(c => c.type === 'text').map(c => c.text).join(' ').substring(0, 120);
            return role + ': ' + text;
          }
          return '';
        }).filter(Boolean).join('\n');
        const systemPrompt = `You are the Autonomic Agentbot (Monitor). The Somatic Agentbot has gone idle.\n\n${tokenInfo}\n\nMonitor Brief:\n${brief}\n\nRecent conversation context:\n${recentSummary}\n\nCompose a brief, natural wake-up message (1-2 sentences). Mention what needs attention based on the context. Do NOT repeat what was already said. The S-agentbot is smart — it will decide what to do. Prefix with [from A-agentbot:].`;
        ctx.ui.notify('[AUTONOMIC] Calling callMonitor...', 'info');
        const messages = [{ role: 'user', content: [{ type: 'text', text: 'Somatic agentbot is idle. Compose a wake-up message based on the recent context.' }], timestamp: Date.now() }];
        const composed = await callMonitor(ctx, messages, systemPrompt);
        ctx.ui.notify('[AUTONOMIC] callMonitor returned: ' + (composed ? composed.substring(0, 100) : 'null/empty'), 'info');
        if (composed && composed.trim()) { msg = composed; }
      } catch (e) {
        ctx.ui.notify('[AUTONOMIC] callMonitor failed: ' + e, 'error');
        msg = `Issue! LLM call failed: ${e.message || e}`;
      }
      if (!msg || !msg.trim()) { msg = `Issue found! callMonitor returned empty — LLM produced no output`; }
      ctx.ui.notify('[AUTONOMIC] Sending wake-up message to S-agentbot...', 'info');
      pi.sendMessage({
        customType: 'autonomic-wakeup',
        content: [{ type: 'text', text: msg }],
        display: 'persistent',
        details: { source: 'agent_end_coordination' }
      }, { triggerTurn: true });
      ctx.ui.notify('[AUTONOMIC] Wake-up message sent', 'info');
    } catch (e) {
      ctx.ui.notify('[AUTONOMIC] Inner error: ' + e, 'error');
    }
  }, debounceMs);
} catch (err) {
  ctx.ui.notify('[AUTONOMIC] Outer error: ' + err, 'error');
}
