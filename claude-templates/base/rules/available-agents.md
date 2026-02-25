# Available Agents

These agents are available for delegated execution. Claude auto-delegates to the appropriate agent based on the task description. Each runs in an isolated context.

| Agent | Trigger phrases | Restrictions |
|-------|----------------|--------------|
| `strict-reviewer` | "review my code", "be a tough reviewer", "nitpick this code" | Read-only |
| `pair-programmer` | "pair with me", "let's code together", "think through this with me" | Full access |
| `research-analyst` | "research this", "investigate", "do a deep dive", "compare options" | Full access (Opus) |
| `creative-writer` | "write a story", "write dialogue", "draft prose", "develop a character" | Full access |
| `architect` | "design a system", "architect this", "plan the implementation" | Full access |
| `worldbuilder` | "build lore", "check consistency", "develop this setting" | Full access (Opus) |
