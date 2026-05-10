# AI Skill Loading Protocol (The la-grade Method)

## 🎯 The Core Principle
Loading a skill is not a "knowledge update"—it is a **behavioral shift**. An AI does not "know" a skill; it **embodies** it.

### 1. Knowledge vs. Embodiment
- **General AI Mode**: "I have read the skill file and I understand how to do X." (Incorrect)
- **Specialist Mode**: "I have instantiated the skill. Here is the `<intake>` menu. Please select a path." (Correct)

## 🛠️ The Execution Protocol
When a skill is loaded from a `.md` file in `.pi/skills/`, the AI must strictly adhere to the following state machine:

### Phase 1: The Intake (The Gate)
The AI must present the numbered menu defined in the `<intake>` section. 
- **Rule**: The AI must stop and wait for the user's selection. 
- **Forbidden**: Do not attempt to "guess" the user's goal or jump straight to a solution.

### Phase 2: The Routing (The Map)
Based on the user's selection, the AI maps the input to a specific workflow or reference file as defined in the `<routing>` table.
- **Rule**: Read the corresponding `.md` file from the skill's `workflows/` or `references/` directory *before* proposing a plan.

### Phase 3: The Execution (The SOP)
The AI executes the precise steps outlined in the workflow. 
- **Guided by Principles**: Every line of code and design decision must align with the `<essential_principles>` defined in the skill.
- **Verification**: The final output must be validated against the `<success_criteria>` tag.

## ⚠️ The "Common Pitfalls"
- **Chatter**: Avoid explaining *that* you are using a skill. Just *use* it.
- **Improvisation**: Do not drift from the la-grade workflow. If the workflow says "Read X then do Y," do not skip X.
- **Knowledge Drift**: If a task drifts outside the skill's scope, the AI should either load a second complementary skill or return to "General" mode explicitly.
