import assert from "node:assert/strict";
import { test } from "node:test";
import { installPatch } from "./patch.ts";

// Mirrors pi 1.5.0 AgentSession._refreshFinalizedContext: each refresh re-projects entries,
// building new objects for custom/compaction entries that reuse the entry's content/summary.
function fakeSession(entries: { id: string; build: () => any }[]) {
  class Session {
    agent = { state: { messages: [] as any[] } };
    _entryIdsByMessage = new WeakMap<object, string>();
    _refreshFinalizedContext() {
      this.agent.state.messages = entries.map((entry) => {
        const message = entry.build();
        this._entryIdsByMessage.set(message, entry.id);
        return message;
      });
    }
  }
  installPatch(Session.prototype);
  return new Session();
}

const userMessage = { role: "user", content: [{ type: "text", text: "hi" }] };
const customContent = [{ type: "text", text: "note" }];

test("keeps message identity across a refresh that re-projects unchanged entries", () => {
  const entries = [
    { id: "u", build: () => userMessage },
    { id: "c", build: () => ({ role: "custom", content: customContent }) },
    { id: "s", build: () => ({ role: "compactionSummary", summary: "sum" }) },
  ];
  const session = fakeSession(entries);
  session._refreshFinalizedContext();
  const before = session.agent.state.messages;
  const captured = [...before];

  entries.push({ id: "n", build: () => ({ role: "custom", content: "new" }) });
  session._refreshFinalizedContext();
  const after = session.agent.state.messages;

  assert.equal(after.length, 4);
  captured.forEach((message, index) => assert.equal(after[index], message));
  assert.equal(session._entryIdsByMessage.get(after[1]), "c");
});

test("keeps the refreshed object when the payload changed", () => {
  let summary = "old";
  const session = fakeSession([{ id: "s", build: () => ({ role: "compactionSummary", summary }) }]);
  session._refreshFinalizedContext();
  const before = session.agent.state.messages[0];
  summary = "new";
  session._refreshFinalizedContext();
  assert.notEqual(session.agent.state.messages[0], before);
  assert.equal(session.agent.state.messages[0].summary, "new");
});

test("falls back to stock behavior and reports once when the session shape changed", () => {
  const reports: string[] = [];
  let calls = 0;
  class Session {
    agent = { state: {} as any }; // messages renamed upstream
    _refreshFinalizedContext() {
      calls++;
      this.agent.state.renamed = [{ role: "user", content: "x" }];
      return "result";
    }
  }
  installPatch(Session.prototype, (message) => reports.push(message));
  const session = new Session();
  assert.equal(session._refreshFinalizedContext(), "result");
  assert.equal(session._refreshFinalizedContext(), "result");
  assert.equal(calls, 2);
  assert.equal(reports.length, 1);
  assert.match(reports[0], /disabled.*not an array/);
});

test("installs once and reports a missing private API", () => {
  const proto: any = { _refreshFinalizedContext() {} };
  assert.equal(installPatch(proto), true);
  const wrapped = proto._refreshFinalizedContext;
  assert.equal(installPatch(proto), true);
  assert.equal(proto._refreshFinalizedContext, wrapped);
  assert.equal(installPatch({}), false);
});
