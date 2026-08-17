const fs = require('fs');
const path = require('path');

const SUPABASE = { id: 'fQVqgkOGVZ6Zw47v', name: 'content_factory' };
const GEMINI = { id: 'sanjgJOPV62e0Vul', name: 'n8n' };
const GMAIL = { id: 'aw0729XCociMNVtw', name: 'Gmail account' };

// credential names that should be blanked (removed) entirely -> user wires manually
const BLANK_NAMES = new Set([
  'Hey gen', 'hey gen -sugg',
  'insta - sugg', 'fb -sugg', 'linkeidn - sugg', 'YouTube account -sugg',
  'fb-asses token', 'linkeidn', 'fb asses token new',
  'Slack account', // no exact-type match on target instance, left blank on purpose
]);

const dir = path.join(__dirname, 'workflows');
const outDir = path.join(__dirname, 'workflows_remapped');
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir);

const files = fs.readdirSync(dir).filter(f => f.endsWith('.json'));
const report = [];

for (const f of files) {
  const raw = fs.readFileSync(path.join(dir, f), 'utf8');
  const wf = JSON.parse(raw);

  const blanked = [];
  const remapped = [];

  const nodes = wf.nodes || [];
  for (const node of nodes) {
    if (!node.credentials) continue;
    for (const [credType, val] of Object.entries(node.credentials)) {
      if (credType === 'supabaseApi') {
        node.credentials[credType] = { id: SUPABASE.id, name: SUPABASE.name };
        remapped.push(`${node.name}: supabaseApi -> ${SUPABASE.name}`);
      } else if (credType === 'googlePalmApi') {
        node.credentials[credType] = { id: GEMINI.id, name: GEMINI.name };
        remapped.push(`${node.name}: googlePalmApi -> ${GEMINI.name}`);
      } else if (credType === 'gmailOAuth2' && val.name === 'Gmail account') {
        node.credentials[credType] = { id: GMAIL.id, name: GMAIL.name };
        remapped.push(`${node.name}: gmailOAuth2 -> ${GMAIL.name}`);
      } else if (BLANK_NAMES.has(val.name)) {
        delete node.credentials[credType];
        blanked.push(`${node.name}: ${credType} (${val.name}) left blank`);
      }
    }
    if (Object.keys(node.credentials).length === 0) delete node.credentials;
  }

  // strip fields the create API rejects / that are stale from source instance
  const clean = {
    name: wf.name,
    nodes: wf.nodes,
    connections: wf.connections,
    settings: wf.settings || {},
  };
  if (wf.staticData) clean.staticData = wf.staticData;

  fs.writeFileSync(path.join(outDir, f), JSON.stringify(clean, null, 2));
  report.push({ file: f, name: wf.name, remapped, blanked });
}

fs.writeFileSync(path.join(__dirname, 'scratch_import_report.json'), JSON.stringify(report, null, 2));
console.log('done', files.length, 'files');
