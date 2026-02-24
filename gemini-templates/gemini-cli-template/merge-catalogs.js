const fs = require('fs');

const claudeCatalogPath = '../../claude-templates/external-catalog.json';
const geminiCatalogPath = 'external-catalog.json';

const claudeCatalog = JSON.parse(fs.readFileSync(claudeCatalogPath, 'utf8'));
const geminiCatalog = JSON.parse(fs.readFileSync(geminiCatalogPath, 'utf8'));

// We want to keep Gemini's base agents:
const geminiAgents = geminiCatalog.components.agents;
// And keep Gemini's MCP servers:
const geminiMCPs = geminiCatalog.components['mcp-servers'] || [];

// Add all Claude agents that don't overlap with Gemini's
for (const cAgent of claudeCatalog.components.agents || []) {
  if (!geminiAgents.find(a => a.name === cAgent.name)) {
    geminiAgents.push(cAgent);
  }
}

geminiCatalog.components.skills = claudeCatalog.components.skills || [];
geminiCatalog.components.plugins = claudeCatalog.components.plugins || [];

// Write back
fs.writeFileSync(geminiCatalogPath, JSON.stringify(geminiCatalog, null, 2));

console.log('Successfully merged claude-templates catalog into gemini-cli-template catalog.');
