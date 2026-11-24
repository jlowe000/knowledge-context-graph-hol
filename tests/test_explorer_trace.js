/* Exercise the maintained UI helpers with synthetic traces; no browser or database access. */
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');
const source = fs.readFileSync(path.join(__dirname, '../apex/explorer.js'), 'utf8');
function section(start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a);
  assert.ok(a >= 0 && b > a, 'Maintained helper boundaries must exist');
  return source.slice(a, b);
}
const helpers = vm.createContext({});
vm.runInContext(section(' function eventLabel(', ' function network('), helpers);
function trace(origin) {
  return { question: 'Synthetic question', revision_id: 'R1', mode: 'question',
    context: { question: 'Synthetic context' }, started_at: '10:00', model_started_at: '10:02', finished_at: '10:03',
    tool_calls: [{ tool: 'EVIDENCE', origin, status: 'SUCCEEDED', started_at: '10:01', finished_at: '10:02',
      output: { evidence: [{ id: 'P1' }], base_graph: 'BASE', overlay_graph: 'OVERLAY' } }] };
}
const hasEdge = (flow, from, to) => flow.edges.some(e => e[0] === from && e[1] === to);

test('application evidence precedes the model and is not reported as an agent tool', () => {
  const flow = helpers.traceProcess(trace('APPLICATION'), { turn_id: 2 });
  assert.ok(hasEdge(flow, 'graphs', 'event0'));
  assert.ok(hasEdge(flow, 'event0', 'team'));
  assert.ok(hasEdge(flow, 'team', 'answer'));
  assert.ok(!hasEdge(flow, 'team', 'event0'));
  assert.match(flow.counts, /1 application evidence step/);
  assert.doesNotMatch(flow.counts, /agent tool/);
  assert.equal(flow.events[1][0], 'Application evidence retrieval · succeeded');
  assert.equal(flow.events[2][0], 'Team request');
  assert.equal(flow.events[2][1], '10:02');
  assert.ok(flow.text.indexOf('Application evidence retrieval') < flow.text.indexOf('team request'));
});

test('agent-triggered retrieval follows the team request', () => {
  const flow = helpers.traceProcess(trace('AGENT'), { turn_id: 2 });
  assert.ok(hasEdge(flow, 'team', 'event0'));
  assert.ok(hasEdge(flow, 'event0', 'answer'));
  assert.ok(!hasEdge(flow, 'event0', 'team'));
  assert.match(flow.counts, /1 agent tool call/);
  assert.equal(flow.events[1][0], 'Team request');
  assert.equal(flow.events[2][0], 'EVIDENCE agent tool · succeeded');
});

test('older traces do not invent an origin or model request timestamp', () => {
  const old = trace(undefined); delete old.model_started_at;
  const flow = helpers.traceProcess(old, { turn_id: 2 });
  assert.match(flow.counts, /trigger not recorded/);
  assert.doesNotMatch(flow.counts, /agent tool call/);
  assert.match(flow.events[1][1], /not recorded/);
  assert.match(flow.nodes.find(n => n.key === 'event0').description, /did not record its trigger/);
});

test('an absent capture stays visibly incomplete', () => {
  const empty = trace(undefined); empty.tool_calls = [];
  const flow = helpers.traceProcess(empty, { turn_id: 2 });
  assert.match(flow.counts, /No evidence or tool event captured/);
  assert.ok(flow.nodes.some(n => n.key === 'none'));
  assert.doesNotMatch(flow.text, /Application evidence retrieval/);
});

async function failingCall(code, action = 'ask') {
  let requests = 0;
  const requestTokens = new Map();
  const context = vm.createContext({ busy: false, session: 'S1', requestTokens,
    requestToken: () => '0123456789abcdef0123456789abcdef', lock: () => {}, status: () => {}, personal: () => false,
    apex: { server: { process: async () => { requests++; return { ok: false, error: 'Synthetic failure', error_code: code }; } } } });
  vm.runInContext(section(' async function call(', ' function traceTab('), context);
  await context.call(action, 'Synthetic question', 'question', '');
  return { requests, retained: requestTokens.size };
}

test('definitive pre-model failure releases only its request token, without retry', async () => {
  assert.deepEqual(await failingCall(-20174), { requests: 1, retained: 0 });
});

test('other errors retain the token and never retry automatically', async () => {
  assert.deepEqual(await failingCall(-20401), { requests: 1, retained: 1 });
  assert.deepEqual(await failingCall(undefined), { requests: 1, retained: 1 });
  assert.deepEqual(await failingCall(-20174, 'observe'), { requests: 1, retained: 1 });
});

test('malformed model JSON warns, preserves raw text, and keeps captured evidence separate', () => {
  const rendering = vm.createContext({ el: (tag, text, cls) => ({ tag, text, cls, children: [], append(...nodes) { this.children.push(...nodes); } }) });
  vm.runInContext(section(' function json(', ' function publicUrl('), rendering);
  vm.runInContext(section(' function packetOf(', ' function eventLabel('), rendering);
  const malformed = '{"assessment":"first line\nsecond line","citations":["unverified-id"]}';
  const card = { children: [], append(...nodes) { this.children.push(...nodes); } };
  rendering.answerBody(card, malformed, true);
  assert.equal(card.children.length, 2);
  assert.match(card.children[0].text, /citation matching is unavailable/);
  assert.equal(card.children[1].text, malformed);
  const recorded = trace('APPLICATION'); recorded.citation_parse_status = 'UNAVAILABLE'; recorded.citations = [];
  recorded.tool_calls[0].output.graph_paths = [{ evidence_id: 'P1' }];
  const packet = rendering.packetOf(recorded);
  assert.equal(packet.evidence.length, 1);
  assert.equal(packet.evidence[0].id, 'P1');
  assert.equal(packet.graph_paths[0].evidence_id, 'P1');
  assert.ok(!packet.evidence.some(p => p.id === 'unverified-id'));
  const question = { children: [], append(...nodes) { this.children.push(...nodes); } };
  rendering.answerBody(question, 'An ordinary user question', false);
  assert.equal(question.children.length, 1, 'User prose must not receive a model formatting warning');
});
