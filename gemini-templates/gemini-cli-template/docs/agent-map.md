# Agent Capability Map
This document is automatically generated. Do not edit manually. It serves as the primary discovery source for the Gemini Router.

| Agent | Entry Point | Intent Triggers | Description |
| :--- | :--- | :--- | :--- |
| **AIResearcher** | [`ai-researcher.md`](file:///../.agents/ai-researcher.md) | ml-paper, arxiv, dataset-search, huggingface, model-card, academic-research | Specialized in ML paper retrieval and dataset querying. |
| **AndroidEngineer** | [`android-engineer.md`](file:///../.agents/android-engineer.md) | kotlin, android-sdk, mobile-app, ui-kit, mobile-architecture | Specialized in mobile application development and system architecture. |
| **architect** | [`architect.md`](file:///../.agents/architect.md) | new-feature, requirements, interview, ambiguity, specification, architecture-decision | Use this agent FIRST for any new feature or task. It gathers requirements and interviews the user to resolve ambiguities. |
| **BrowserAssistant** | [`browser-assistant.md`](file:///../.agents/browser-assistant.md) | web-scrape, browser-automation, ui-test, website-screenshot, live-web-data | Specialized in web scraping, testing, and automation using the Standalone Browser MCP. |
| **CatalogManager** | [`catalog-manager.md`](file:///../.agents/catalog-manager.md) | install-agent, mcp-server-install, capability-discovery, catalog-search, fix-missing-tool | A JIT agent to handle finding and installing items from the external catalog safely. |
| **DeepResearcher** | [`deep-researcher.md`](file:///../.agents/deep-researcher.md) | deep-dive, investigation, literature-review, comprehensive-search, market-analysis | Specialized in long-form, multi-step investigative research. |
| **GameDesigner** | [`game-designer.md`](file:///../.agents/game-designer.md) | gameplay, mechanics, balance, level-design, roguelike, rpg-systems | Specialized in game mechanics, balance, and interactive systems. |
| **implementer** | [`implementer.md`](file:///../.agents/implementer.md) | code-execution, file-edit, implementation, write-code, refactoring | Use this agent ONLY after the user has explicitly approved a plan from the planner. It writes code and executes shell commands. |
| **ObsidianArchitect** | [`obsidian-architect.md`](file:///../.agents/obsidian-architect.md) | obsidian-vault, plugin-config, vault-structure, templater, dataview-query | Specialized in Obsidian vault structure, templates, and plugin optimization. |
| **PKMCurator** | [`pkm-curator.md`](file:///../.agents/pkm-curator.md) | semantic-search, graph-analysis, note-connection, pkm-organization, moc-creation | Specialized in graph traversal and semantic note querying. |
| **planner** | [`planner.md`](file:///../.agents/planner.md) | implementation-plan, checklist, step-by-step, task-breakdown, project-planning | Analyzes requirements to draft a step-by-step implementation checklist. |
| **QAAutomation** | [`qa-automation.md`](file:///../.agents/qa-automation.md) | unit-test, pipeline, bug-fix-verification, qa-audit, test-coverage | Specialized in test suites, CI/CD pipelines, and bug verification. |
| **SecurityAuditor** | [`security-auditor.md`](file:///../.agents/security-auditor.md) | vulnerability, leak, secret-scan, CVE, hardening, security-audit, guardrails | Specialized in identifying security vulnerabilities and code leaks. |
| **UXRAnalyst** | [`uxr-analyst.md`](file:///../.agents/uxr-analyst.md) | persona, user-flow, usability-test, qualitative-research, user-insights, ux-design | Specialized in user research, persona creation, and usability analysis. |
| **WebDeveloper** | [`web-developer.md`](file:///../.agents/web-developer.md) | nextjs, react, vite, frontend, fullstack, css-styling, web-app | Specialized in fullstack web applications and frontend frameworks. |
| **WikiManager** | [`wiki-manager.md`](file:///../.agents/wiki-manager.md) | confluence, notion, wiki-update, documentation-sync, knowledge-base | Specialized in Confluence, Notion, or flat markdown wiki management. |
| **Worldbuilder** | [`worldbuilder.md`](file:///../.agents/worldbuilder.md) | lore, npc-design, magic-system, timeline, culture, setting, immersive | Specialized in state tracking for canonical narrative facts. |
