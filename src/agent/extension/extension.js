// extension.js - Pi TUI Extension for psypi
// MANUAL creation (NOT from .ts) - Pi requires .js/.ts!
// Imports Gleam-compiled .mjs modules!

import { psypi_my_id } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/agent_identity.mjs";
import { psypi_task_add, psypi_tasks, psypi_task_complete } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/task.mjs";
import { psypi_issue_add, psypi_issue_list, psypi_issue_resolve } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/issue.mjs";
import { psypi_skill_build, psypi_skill_list, psypi_skill_show, psypi_skill_search } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/skill.mjs";
import { psypi_monitor_health, psypi_monitor_housekeeping, psypi_monitor_prepare_context } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/monitor_ai.mjs";
import { psypi_learn, psypi_areflect } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/learning.mjs";
import { psypi_broadcast_send, psypi_broadcast_list } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/broadcast.mjs";
import { psypi_inter_review_request, psypi_inter_reviews, psypi_inter_review_show } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/inter_review.mjs";

export function tools() {
  return [
    // Agent Identity tools
    {
      name: "psypi-my-id",
      description: "Get current agent ID (e.g., S-psypi-psypi)",
      parameters: {},
      handler: psypi_my_id,
    },
    // Task tools
    {
      name: "psypi-task-add",
      description: "Add a new task to the database",
      parameters: {
        title: { type: "string" },
        description: { type: "string", optional: true },
        priority: { type: "number", optional: true },
      },
      handler: psypi_task_add,
    },
    // ... (other tools) - simplified for now
  ];
}

// Register tools when loaded by Pi
export function register() {
  const toolsList = tools();
  // Pi will call this function and register the tools
  return toolsList;
}
