#!/usr/bin/env python3
"""Offline, exact-Pi PTY restart integration. Retains every artifact on success/failure.

Usage: scripts/test-pi-restart.py --ic-source /nix/store/...-pi-infinite-context \
    --actor-source /nix/store/...-pi-actor-subagents [--pi /path/to/pi]
Only temporary settings/extensions/sessions are modified; no real direnv is run.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time
import traceback

REPO = Path(__file__).resolve().parent.parent
CHECKPOINT = "pi-restart-in-dir/checkpoint"
MARKER = "pi-restart-in-dir:"
TIMEOUT = 25

# Discovered normally, not -e/--no-extensions: the launcher intentionally refuses
# explicit resource flags for replacement launches. The provider never opens a socket.
FIXTURE = r'''
import {appendFileSync, readFileSync, writeFileSync, existsSync, unlinkSync, rmSync} from 'node:fs';
import {join} from 'node:path';
import {inspect as inspectValue, isDeepStrictEqual} from 'node:util';
import {createAssistantMessageEventStream} from '@earendil-works/pi-ai';
const log = (kind, data={}) => appendFileSync(process.env.TEST_LOG!, JSON.stringify({kind,pid:process.pid,...data})+'\n');
const launch = () => {try{return JSON.parse(readFileSync(join(process.env.PI_RESTARTABLE_CONTROL_DIR!, 'launch.json'),'utf8'));}catch{return null;}};
const rows = file => file && existsSync(file) ? readFileSync(file,'utf8').trim().split('\n').map(x=>JSON.parse(x)) : [];
const usage = {input:1,output:1,cacheRead:0,cacheWrite:0,totalTokens:2,cost:{input:0,output:0,cacheRead:0,cacheWrite:0,total:0}};
export default function(pi) {
  let issued = false;
  pi.events.on('pi-restart-in-dir:ic-health-request',data=>log('health-request',{data}));
  pi.events.on('pi-restart-in-dir:ic-health-response',data=>log('health-response',{data}));
  pi.registerProvider('proof', {
    api:'proof-api',baseUrl:'http://127.0.0.1:1/never',apiKey:'offline-fixture',
    models:['old','new'].map(id=>({id,name:id,reasoning:true,input:['text'],cost:{input:0,output:0,cacheRead:0,cacheWrite:0},contextWindow:200000,maxTokens:1000})),
    streamSimple(model,context,options) {
      const authority=launch();
      log('provider',{model:model.id,thinking:options?.reasoning,messages:context.messages,launch:authority});
      const lastUser=context.messages.filter(m=>m.role==='user').at(-1);
      const text=typeof lastUser?.content==='string'?lastUser.content:JSON.stringify(lastUser?.content);
      const tool=!issued && !authority?.incoming && text?.includes('restart tool');
      if(tool) issued=true;
      const message={role:'assistant',content:tool?[{type:'toolCall',id:'offline-restart-call',name:'restart-in-dir',arguments:{directory:process.env.TEST_TARGET}}]:[{type:'text',text:'offline fixture reply'}],api:'proof-api',provider:'proof',model:model.id,usage,stopReason:tool?'toolUse':'stop',timestamp:Date.now()};
      const stream=createAssistantMessageEventStream();
      queueMicrotask(()=>{stream.push({type:'done',reason:message.stopReason,message});stream.end(message);});
      return stream;
    }
  });
  const state = ctx => {
    const id=ctx.sessionManager.getSessionId();
    const bridge=globalThis[Symbol.for('futile.pi.subagents.restart-in-dir.v1')];
    const engine=globalThis.__subagentsEngine_v28;
    const flagIndex=process.argv.indexOf('--pi-restart-in-dir-handoff');
    // getFlag is extension-owner-scoped; do not spoof/register the guard's flag here.
    const handoffArg=flagIndex<0?null:process.argv[flagIndex+1];
    return {model:ctx.model?.id,thinking:pi.getThinkingLevel(),name:pi.getSessionName(),cwd:ctx.cwd,sessionId:id,file:ctx.sessionManager.getSessionFile(),leaf:ctx.sessionManager.getLeafId(),branch:ctx.sessionManager.getBranch(),launch:launch(),handoffArg,actor:bridge?.inspect(id),
      // Evidence only: bridge readiness remains the production public contract.
      swarm:engine?.list().filter(a=>a.name!=='main').map(a=>({name:a.name,paused:engine.pausedAgents().includes(a.name),pausedMidTurn:a.pausedMidTurn}))};
  };
  pi.on('session_start',(_e,ctx)=>{
    if(process.env.TEST_SCENARIO==='same-dir-metadata' && launch()?.incoming)
      pi.appendEntry('restart-test/startup-metadata',{legitimate:true});
    log('startup',state(ctx));
  });
  pi.on('agent_settled',(_e,ctx)=>{
    const s=state(ctx);
    const live=s.branch.findLast(e=>e.message?.role==='toolResult');
    if(live){
      const saved=rows(s.file).find(e=>e.id===live.id);
      log('durability-diagnostic',{equal:isDeepStrictEqual(live,saved),live:inspectValue(live,{depth:8}),saved:inspectValue(saved,{depth:8})});
    }
    log('settled',s);
  });
  pi.on('session_shutdown',(_e,ctx)=>{
    const s=state(ctx), authority=launch();
    let request=null;
    try{request=JSON.parse(readFileSync(join(process.env.PI_RESTARTABLE_CONTROL_DIR!,'request.json'),'utf8'));}catch{}
    const durable=rows(s.file);
    log('shutdown',{...s,request,durable});
    if(!request || authority?.incoming) return;
    if(process.env.TEST_SCENARIO==='broken-ic') {
      for(const r of durable) if(r.customType==='infinite-context') r.data={version:1,roots:[]};
      writeFileSync(s.file,durable.map(r=>JSON.stringify(r)+'\n').join(''));
      log('fault-injected',{fault:'broken-ic'});
    }
    if(process.env.TEST_SCENARIO==='no-health') {
      unlinkSync(process.env.TEST_IC_EXTENSION!);log('fault-injected',{fault:'no-health'});
    }
    if(process.env.TEST_SCENARIO==='missing-owner') {
      rmSync(process.env.TEST_RESTART_EXTENSION!,{recursive:true});log('fault-injected',{fault:'missing-owner'});
    }
  });
  pi.registerCommand('restart-test-inspect',{handler:async(_args,ctx)=>log('inspect',state(ctx))});
  pi.registerCommand('restart-test-reload',{handler:async(_args,ctx)=>{
    log('reload-requested',state(ctx));
    await ctx.reload(); // Public command API; the old ctx must not be used afterward.
  }});
  pi.registerCommand('restart-test-change',{handler:async(_args,ctx)=>{
    await pi.setModel(ctx.modelRegistry.find('proof','new')); pi.setThinkingLevel('high'); pi.setSessionName('latest fixture name');log('changed',state(ctx));
  }});
  pi.registerCommand('restart-test-tree',{handler:async(args,ctx)=>{await ctx.navigateTree(args);log('navigated',state(ctx));}});
  pi.registerCommand('restart-test-fold',{handler:async(_args,ctx)=>{
    const ids=ctx.sessionManager.getBranch().filter(e=>(e.type==='message'&&e.message.role!=='system')||e.type==='custom_message').map(e=>e.id);
    const data={version:2,roots:[{kind:'fold',id:'outer-fixture',summary:'outer offline summary',children:[{kind:'fold',id:'inner-fixture',summary:'inner offline summary',children:ids.map(id=>({kind:'message',id}))}]}]};
    pi.appendEntry('infinite-context',data);log('fold',{data,leaf:ctx.sessionManager.getLeafId(),ids});
  }});
}
'''

FAST_FIXTURE = r'''
const key=Symbol.for('futile.pi.codex-fast.registry.v1');
export default function(pi) {
  const owner=Symbol('offline-fast-fixture');
  const registry=globalThis[key]??={version:1,controllers:new Map()};
  pi.on('session_start',(_event,ctx)=>{
    let desired=false;
    registry.controllers.set(ctx.sessionManager.getSessionId(),{owner,controller:{
      getState:()=>({desired,effective:false}),setDesired:enabled=>{desired=enabled;return {desired,effective:false};}}});
  });
  pi.on('session_shutdown',(_event,ctx)=>{
    const id=ctx.sessionManager.getSessionId();
    if(registry.controllers.get(id)?.owner===owner) registry.controllers.delete(id);
  });
}
'''


DIRENV_FIXTURE = r'''
import hashlib, json, os, pathlib, sys
cwd = pathlib.Path.cwd()
rc = next((p / '.envrc' for p in [cwd, *cwd.parents] if (p / '.envrc').is_file()), None)
authorization = pathlib.Path(os.environ['TEST_AUTHORIZATION'])
fingerprint = hashlib.sha256(rc.read_bytes()).hexdigest() if rc else None
allowed = rc is not None and authorization.exists() and authorization.read_text() == str(rc) + '\n' + fingerprint
with open(os.environ['TEST_DIRENV_LOG'], 'a') as stream:
    stream.write(json.dumps({'action': sys.argv[1], 'argv': sys.argv[1:], 'cwd': str(cwd),
                            'rc': str(rc) if rc else None, 'config': os.environ.get('DIRENV_CONFIG')}) + '\n')
if sys.argv[1] == 'status':
    print(json.dumps({'state': {'foundRC': {'path': str(rc), 'allowed': 0 if allowed else 1} if rc else None}}))
elif sys.argv[1] == 'allow':
    assert rc and pathlib.Path(sys.argv[2]) == rc.parent, 'approve only the discovered rc parent'
    authorization.write_text(str(rc) + '\n' + fingerprint)
elif sys.argv[1] == 'exec':
    if rc and not allowed:
        print('direnv fixture: rc blocked', file=sys.stderr); sys.exit(23)
    if str(cwd) == os.environ['TEST_SOURCE']:
        # Preflight must use the supervisor baseline, not these source-project overrides.
        os.environ['PATH'] = '/unusable-source-path'
        os.environ['DIRENV_CONFIG'] = 'source-project-override'
    os.execv(sys.argv[3], sys.argv[3:])
else:
    raise AssertionError('unexpected direnv command')
'''


def read_jsonl(path):
    if not Path(path).exists():
        return []
    # Readers may race a final append. A partial last line is retried, not accepted.
    data = Path(path).read_text()
    if data and not data.endswith("\n"):
        data = data.rsplit("\n", 1)[0] + "\n" if "\n" in data else ""
    return [json.loads(line) for line in data.splitlines() if line]


def require(condition, message):
    if not condition:
        raise AssertionError(message)


class Terminal:
    def __init__(self, command, cwd, env, artifacts):
        self.artifacts = artifacts
        self.log = Path(env["TEST_LOG"])
        self.master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 140, 0, 0))
        self.output = bytearray()
        self.process = subprocess.Popen(command, cwd=cwd, env=env, stdin=slave,
                                        stdout=slave, stderr=slave, start_new_session=True)
        os.close(slave)
        (artifacts / "command.json").write_text(json.dumps(command))

    def drain(self, seconds=0.05):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            if select.select([self.master], [], [], max(0, end-time.monotonic()))[0]:
                try:
                    chunk = os.read(self.master, 65536)
                except OSError:
                    break
                if not chunk:
                    break
                self.output.extend(chunk)

    def wait(self, predicate, description, timeout=TIMEOUT):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            self.drain()
            rows = read_jsonl(self.log)
            if predicate(rows):
                return rows
            if self.process.poll() is not None:
                raise AssertionError(f"exited {self.process.returncode} waiting for {description}; {self.artifacts}")
        raise AssertionError(f"timeout waiting for {description}; {self.artifacts}")

    def observe(self, seconds=0.8):
        self.drain(seconds)
        return read_jsonl(self.log)

    def send(self, text):
        # Waits above track hooks; a short drain allows TUI to return to its editor.
        self.drain(0.1)
        os.write(self.master, text.encode() + b"\r")

    def command(self, text, kind):
        before = sum(r["kind"] == kind for r in read_jsonl(self.log))
        self.send(text)
        rows = self.wait(lambda rs: sum(r["kind"] == kind for r in rs) > before, text)
        return [r for r in rows if r["kind"] == kind][-1]

    def close(self):
        if self.process.poll() is None:
            # Signal whole isolated process group; no live terminal/session is involved.
            os.killpg(self.process.pid, signal.SIGTERM)
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(self.process.pid, signal.SIGKILL)
            self.process.wait(timeout=5)
        self.drain(0.1)
        (self.artifacts / "terminal.txt").write_bytes(self.output)
        (self.artifacts / "exit-status.txt").write_text(str(self.process.returncode) + "\n")
        os.close(self.master)


def extension_path(source, name):
    source = Path(source).resolve()
    for candidate in (source / "extensions" / name, source / name, source):
        if (candidate / "index.ts").is_file():
            return candidate
    raise ValueError(f"Cannot find {name}/index.ts in {source}")


class Suite:
    def __init__(self, args):
        self.args = args
        self.root = Path(tempfile.mkdtemp(prefix="pi-restart-integration-"))
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.bin / "pi").symlink_to(Path(args.pi).resolve())
        # PATH cannot find real direnv; preserve only Python for the launcher's shebang.
        (self.bin / "python3").symlink_to(Path(sys.executable).resolve())
        self.ic = extension_path(args.ic_source, "infinite-context")
        self.actor = extension_path(args.actor_source, "actor-subagents")
        self.results = []
        (self.root / "manifest.json").write_text(json.dumps({
            "piVersion":"1.0.0", "pi":str(Path(args.pi).resolve()),
            "launcher":str(Path(args.launcher).resolve()), "ic":str(self.ic), "actor":str(self.actor),
            "startedUTC":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),
            "offline":True, "retained":True,
        },indent=2)+"\n")
        print(f"Artifacts retained: {self.root}", flush=True)

    def prepare(self, name, scenario="normal", ic=True, owner=True):
        case = self.root / name
        case.mkdir()
        agent = case / "agent"
        extensions = agent / "extensions"
        extensions.mkdir(parents=True)
        source, target = case / "source", case / "target"
        source.mkdir()
        target.mkdir()
        if ic:
            (extensions / "infinite-context").symlink_to(self.ic, target_is_directory=True)
        (extensions / "actor-subagents").symlink_to(self.actor, target_is_directory=True)
        if owner:
            shutil.copytree(REPO / "dotfiles/pi/extensions/pi-restart-in-dir", extensions / "pi-restart-in-dir")
        (extensions / "zz-restart-fixture.ts").write_text(FIXTURE)
        fast = case / "fast-fixture.ts"
        fast.write_text(FAST_FIXTURE)
        actor_settings = agent / "actor-subagents"
        actor_settings.mkdir()
        (actor_settings / "settings.json").write_text(json.dumps({"childExtensions":[str(fast)]}))
        settings = {"defaultProvider":"proof", "defaultModel":"old", "defaultThinkingLevel":"low",
                    "packages":[], "extensions":[], "compaction":{"enabled":False},
                    "cacheWarm":{"enabled":False}, "infiniteContext":{"enableNudges":False}}
        (agent / "settings.json").write_text(json.dumps(settings))
        models = {"providers":{"proof":{"api":"proof-api", "baseUrl":"http://127.0.0.1:1/never",
                  "apiKey":"offline-fixture", "models":[{"id":m,"name":m,"reasoning":True,
                  "contextWindow":200000,"maxTokens":1000} for m in ("old", "new")]}}}
        (agent / "models.json").write_text(json.dumps(models))
        (extensions / "infinite-context.json").write_text(json.dumps({"enableNudges":False}))
        # Deliberately do not inherit credentials, Pi extensions, HOME or user config.
        env = {"PATH":str(self.bin), "HOME":str(case), "XDG_CONFIG_HOME":str(case / "config"),
               "PI_CODING_AGENT_DIR":str(agent), "PI_TELEMETRY":"0", "PI_SKIP_VERSION_CHECK":"1",
               "PI_OFFLINE":"1", "TERM":"xterm-256color", "LANG":"C.UTF-8",
               "TEST_LOG":str(case / "events.jsonl"), "TEST_TARGET":str(target), "TEST_SCENARIO":scenario,
               "TEST_IC_EXTENSION":str(extensions / "infinite-context"),
               "TEST_RESTART_EXTENSION":str(extensions / "pi-restart-in-dir")}
        return case, source, target, env

    def start(self, case, cwd, env, args=(), direct=False):
        executable = self.args.pi if direct else self.args.launcher
        t = Terminal([str(executable), "--offline", *args], cwd, env, case)
        return t

    @staticmethod
    def kinds(rows, kind):
        return [r for r in rows if r["kind"] == kind]

    def startup(self, terminal, count=1):
        rows = terminal.wait(lambda rs: len(self.kinds(rs,"startup")) >= count, f"startup {count}")
        return self.kinds(rows, "startup")[count-1]

    def prompt(self, terminal, text):
        return terminal.command(text, "settled")

    def seed(self, terminal):
        self.startup(terminal)
        self.prompt(terminal, "seed offline turn")
        return terminal.command("/restart-test-fold", "fold")

    def assert_checkpoint(self, rows, tool):
        shutdowns = [r for r in self.kinds(rows,"shutdown") if r.get("request")]
        require(len(shutdowns)==1, "exactly one durable source shutdown/request required")
        s = shutdowns[0]
        request = s["request"]
        durable = s["durable"]
        require(durable[-1]["customType"]==CHECKPOINT, "checkpoint must be physically final before exit")
        require(durable[-1]["id"]==request["checkpointId"], "request must reference final durable checkpoint")
        expected = {key:request[key] for key in ("version","childId","sourceCwd","target","invocation","continue")}
        require(durable[-1]["data"]==expected, "checkpoint/request data differ")
        require(request["continue"] is tool, "wrong continuation mode")
        if tool:
            results = [r for r in durable if r.get("message",{}).get("role")=="toolResult"
                       and r["message"].get("toolName")=="restart-in-dir"]
            require(len(results)==1, "restart tool result must be saved exactly once before exit")
        return s

    def command_cross(self):
        case, source, target, env = self.prepare("command-cross")
        t = self.start(case, source, env, ["--model","proof/old","--thinking","low","--name","initial fixture name"])
        try:
            fold = self.seed(t)
            first = self.kinds(read_jsonl(t.log),"startup")[0]
            t.send(f"/restart-in-dir {target}")
            second = self.startup(t,2)
            rows = t.observe()
            require(len(self.kinds(rows,"provider"))==1, "command restart must await user control")
            require(second["sessionId"]!=first["sessionId"] and second["cwd"]==str(target), "cross-dir fork identity/cwd")
            inspect = t.command("/restart-test-inspect","inspect")
            require(inspect.get("swarm")==[], "cross-dir fork must have empty swarm")
            require(inspect.get("actor",{}).get("ready"), "actor readiness missing")
            shutdown = self.assert_checkpoint(read_jsonl(t.log),False)
            copied = read_jsonl(second["file"])
            require(copied[1:len(shutdown["durable"])]==shutdown["durable"][1:], "fork must preserve saved IDs/entries")
            snapshots = [r for r in copied if r.get("customType")=="infinite-context"]
            require(snapshots[-1]["data"]==fold["data"], "recursive fold IDs/children must survive fork")
            self.prompt(t,"manual user continuation")
            calls = self.kinds(read_jsonl(t.log),"provider")
            require(len(calls)==2, "manual continuation must make one request")
            require("outer offline summary" in json.dumps(calls[-1]["messages"]), "IC restored outer fold overlay missing")
            require("seed offline turn" not in json.dumps(calls[-1]["messages"]), "folded originals leaked into provider context")
        finally:
            t.close()

    def same_directory(self, tool=False):
        case, source, _target, env = self.prepare("same-directory-tool" if tool else "same-directory-paused", "same-dir-metadata")
        env["TEST_TARGET"]=str(source)
        t = self.start(case,source,env,["--model","proof/old","--thinking","low","--name","same fixture name"])
        try:
            self.seed(t)
            initial=self.kinds(read_jsonl(t.log),"startup")[0]
            session_file=Path(initial["file"])
            swarm_dir=session_file.parent / "subagents" / initial["sessionId"]
            swarm_dir.mkdir(parents=True)
            child=swarm_dir / "fixture-child.jsonl"
            child_rows=read_jsonl(session_file)
            child_rows[0]={**child_rows[0],"id":"offline-child-session"}
            child.write_text("".join(json.dumps(row)+"\n" for row in child_rows))
            roster=[{"name":"fixture-child","spawnedBy":"main","depth":1,"model":"proof/old",
                     "thinkingLevel":"low","systemPrompt":"offline paused fixture","sessionFile":str(child)}]
            (swarm_dir / "roster.json").write_text(json.dumps(roster))
            t.send("restart tool" if tool else f"/restart-in-dir {source}")
            replacement=self.startup(t,2)
            if tool:
                t.wait(lambda rs: any(r["kind"]=="settled" and r.get("launch",{}).get("incoming") for r in rs), "same-dir automatic continuation settled")
            require(replacement["sessionId"]==initial["sessionId"], "same-dir must retain native session ID")
            require(replacement["file"]==initial["file"] and replacement["cwd"]==str(source), "same-dir exact native --session source")
            inspect=t.command("/restart-test-inspect","inspect")
            require(inspect["model"]=="old" and inspect["thinking"]=="low" and inspect["name"]=="same fixture name", "same-dir native settings restoration")
            require(inspect.get("swarm")==[{"name":"fixture-child","paused":True,"pausedMidTurn":False}], "saved swarm must really restore paused, not disappear")
            require(inspect.get("actor",{}).get("ready"), "paused restored swarm should be actor-ready")
            calls=self.kinds(t.observe(),"provider")
            require(len(calls)==(3 if tool else 1), "same-dir command/paused child or automatic continuation count")
            target_calls=[r for r in calls if r.get("launch",{}).get("incoming")]
            require(len(target_calls)==(1 if tool else 0), "same-dir marker must survive legitimate startup metadata")
            require(any(r.get("customType")=="restart-test/startup-metadata" for r in read_jsonl(inspect["file"])), "same-dir fixture must append real startup metadata")
            self.assert_checkpoint(read_jsonl(t.log),tool)
        finally:
            t.close()

    def historical(self):
        case, source, target, env = self.prepare("historical-native")
        t = self.start(case,source,env,["--model","proof/old","--thinking","low","--name","initial fixture name"])
        try:
            fold = self.seed(t)
            t.command("/restart-test-change","changed")
            self.prompt(t,"new model branch turn")
            live = t.command("/restart-test-tree " + fold["leaf"],"navigated")
            require(live["model"]=="new" and live["thinking"]=="high", "fixture must retain different live model/thinking")
            t.send(f"/restart-in-dir {target}")
            second = self.startup(t,2)
            require(second["model"]=="old" and second["thinking"]=="low", "must restore recorded branch, not initial overrides/live model")
            require(second["name"]=="latest fixture name", "native latest session name restoration")
            shutdown = self.assert_checkpoint(read_jsonl(t.log),False)
            require(shutdown["request"]["expected"]=={"model":{"provider":"proof","modelId":"old"},"thinkingLevel":"low"}, "expected settings must follow native selected branch")
            require(len(self.kinds(t.observe(),"provider"))==2, "historical command restart must not auto-request")
        finally:
            t.close()

    def tool(self, name="tool-cross", fault="normal", reload=False):
        case, source, target, env = self.prepare(name, fault)
        t = self.start(case,source,env,["--model","proof/old","--thinking","low"])
        try:
            self.seed(t)
            t.send("restart tool")
            second = self.startup(t,2)
            if fault=="normal":
                rows = t.wait(lambda rs: len(self.kinds(rs,"provider"))>=3, "one automatic replacement request")
            else:
                rows = t.observe(1.2)
            shutdown = self.assert_checkpoint(rows,True)
            calls = self.kinds(rows,"provider")
            target_calls = [r for r in calls if r.get("launch",{}).get("incoming")]
            require(len(target_calls)==(1 if fault=="normal" else 0), f"{fault}: wrong automatic continuation count")
            source_calls = [r for r in calls if not r.get("launch",{}).get("incoming")]
            require(len(source_calls)==2, "source must stop before post-tool provider request")
            require(second["cwd"]==str(target), "tool target cwd")
            health_requests=self.kinds(rows,"health-request")
            health_responses=self.kinds(rows,"health-response")
            require(len(health_requests)==1, "marker must actually query IC health")
            request=health_requests[0]["data"]
            require(request["sessionId"]==second["sessionId"], "health query targets wrong session")
            if fault=="no-health":
                require(not health_responses, "missing IC fixture unexpectedly supplied health")
            else:
                require(len(health_responses)==1, "IC must return exactly one correlated health response")
                response=health_responses[0]["data"]
                require(all(response[k]==request[k] for k in ("requestId","sessionId","leafId")), "IC health correlation mismatch")
                require(response["version"]==2 and response["ok"] is (fault=="normal"), "wrong IC validation outcome")
                if fault=="broken-ic":
                    require(response.get("error"), "broken snapshot must report validation error")
            if fault=="normal":
                t.wait(lambda rs: any(r["kind"]=="settled" and r.get("launch",{}).get("incoming") for r in rs), "automatic continuation settled")
                messages = target_calls[0]["messages"]
                require(any(m.get("role")=="toolResult" and m.get("toolName")=="restart-in-dir" for m in messages), "continuation missing persisted result")
                require(not any(m.get("role")=="user" and MARKER in json.dumps(m.get("content")) for m in messages), "marker must not become model/user text")
                require(shutdown["request"]["prompt"] in json.dumps(messages), "marker must transform to stored continuation")
                t.observe()
                n = len(self.kinds(read_jsonl(t.log),"provider"))
                t.send(MARKER+shutdown["request"]["childId"])
                require(len(self.kinds(t.observe(),"provider"))==n, "duplicate marker repeated provider request")
                t.send(MARKER+"stale-fixture-child")
                require(len(self.kinds(t.observe(),"provider"))==n, "stale marker repeated provider request")
                if reload:
                    t.send("/restart-test-reload")
                    restored=self.startup(t,3)
                    require(restored["sessionId"]==second["sessionId"] and restored["file"]==second["file"], "reload must retain the target session")
                    require(second["handoffArg"]==shutdown["request"]["childId"] and restored["handoffArg"]==second["handoffArg"], "native reload must retain supplied handoff argv witness")
                    require(restored["launch"]==second["launch"], "reload must remain in the same launcher child/incoming authority")
                    require(len(self.kinds(t.observe(),"provider"))==n, "reload itself unexpectedly called provider")
                    t.send(MARKER+shutdown["request"]["childId"])
                    after=t.observe()
                    require(len(self.kinds(after,"provider"))==n, "reloaded extension repeated consumed automatic continuation")
                    require(len(self.kinds(after,"health-request"))==1, "consumed marker after reload reached IC/model preparation")
                    require(b"already consumed in this launcher child" in t.output, "reload replay must be refused by the durable one-use receipt, not an unrelated guard failure")
                    saved=read_jsonl(restored["file"])
                    require(not any(r.get("message",{}).get("role")=="user" and MARKER in json.dumps(r["message"].get("content")) for r in saved), "replayed marker after reload became saved user/model text")
            else:
                require(any(r["kind"]=="fault-injected" for r in rows), "negative test must inject intended isolated fault")
        finally:
            t.close()

    def approval(self, tool=False, allow=True):
        name = f"approval-{'tool' if tool else 'command'}-{'yes' if allow else 'cancel'}"
        case, source, parent, env = self.prepare(name)
        target = parent / 'nested directory'
        target.mkdir()
        rc = parent / '.envrc'
        rc.write_text('# controlled fixture; never sourced by fake direnv\n')
        binaries = case / 'bin'
        binaries.mkdir()
        for binary in ('pi', 'python3'):
            (binaries / binary).symlink_to((self.bin / binary).resolve())
        fake = binaries / 'direnv'
        fake.write_text(f'#!{sys.executable}\n' + DIRENV_FIXTURE)
        fake.chmod(0o755)
        authorization = case / 'authorization'
        log = case / 'direnv.jsonl'
        baseline_config = str(case / 'baseline-config')
        env.update(PATH=str(binaries), TEST_TARGET=str(target), TEST_SOURCE=str(source),
                   TEST_AUTHORIZATION=str(authorization), TEST_DIRENV_LOG=str(log),
                   DIRENV_CONFIG=baseline_config)
        t = self.start(case, source, env)
        try:
            self.seed(t)
            initial = self.kinds(read_jsonl(t.log), 'startup')[0]
            t.send('restart tool' if tool else f'/restart-in-dir {target}')
            t.wait(lambda _: b'Allow and restart' in t.output, 'explicit Pi approval dialog')
            require(str(rc).encode() in t.output, 'dialog must show actual ancestor rc path')
            require(not authorization.exists(), 'showing dialog must not grant approval')
            require(not any(r.get('customType') == CHECKPOINT for r in read_jsonl(initial['file'])), 'dialog must precede checkpoint')
            require(len(self.kinds(read_jsonl(t.log), 'startup')) == 1, 'source Pi must remain running during dialog')
            # Built-in selection starts on Cancel. Down+Enter is explicit Allow.
            os.write(t.master, b'\x1b[B\r' if allow else b'\x1b')
            if allow:
                replacement = self.startup(t, 2)
                require(replacement['cwd'] == str(target), 'approved target cwd')
                require(replacement['sessionId'] != initial['sessionId'], 'approved cross-directory restart must fork')
                if tool:
                    rows = t.wait(lambda rs: any(r['kind'] == 'settled' and r.get('launch', {}).get('incoming') for r in rs), 'approved continuation settled')
                else:
                    rows = t.observe()
                self.assert_checkpoint(rows, tool)
                calls = [r for r in self.kinds(rows, 'provider') if r.get('launch', {}).get('incoming')]
                require(len(calls) == (1 if tool else 0), 'approval must retain normal user/tool continuation policy')
                require(authorization.exists(), 'explicit Allow must authorize the rc')
                operations = read_jsonl(log)
                require(sum(r['action'] == 'allow' for r in operations) == 1, 'exactly one user-authorized allow')
                require(all(r['config'] == baseline_config for r in operations), 'approval/launch must use baseline config, not source overrides')
            else:
                if tool:
                    t.wait(lambda rs: len(self.kinds(rs, 'settled')) >= 2, 'cancelled tool settled normally')
                else:
                    t.observe()
                inspected = t.command('/restart-test-inspect', 'inspect')
                require(inspected['sessionId'] == initial['sessionId'] and inspected['cwd'] == str(source), 'cancel must keep original Pi/session usable')
                require(inspected['actor']['ready'] is True, 'cancel must release actor handoff lease')
                require(not any(r.get('customType') == CHECKPOINT for r in read_jsonl(initial['file'])), 'cancel must not checkpoint')
                require(not authorization.exists(), 'Escape must not grant approval')
                require(not any(r['action'] == 'allow' for r in read_jsonl(log)), 'cancel must never invoke allow')
                require(len(self.kinds(read_jsonl(t.log), 'startup')) == 1, 'cancel must not restart')
        finally:
            t.close()

    def missing_owner(self):
        case, source, target, env = self.prepare("missing-owner", "missing-owner")
        t = self.start(case,source,env,["--model","proof/old"])
        try:
            self.seed(t)
            t.send("restart tool")
            end=time.monotonic()+TIMEOUT
            while t.process.poll() is None and time.monotonic()<end:
                t.drain()
            require(t.process.poll() is not None and t.process.returncode!=0, "missing flag owner must exit nonzero")
            rows=read_jsonl(t.log)
            self.assert_checkpoint(rows,True)
            require(len(self.kinds(rows,"startup"))==1, "missing flag owner must fail before replacement startup")
            require(len(self.kinds(rows,"provider"))==2, "missing owner replacement called provider")
            require(b"pi-restart-in-dir-handoff" in t.output, "missing-owner CLI diagnostic absent")
        finally:
            t.close()

    def run(self):
        tests = [("cross-directory command + recursive IC", self.command_cross),
                 ("same-directory native session + paused swarm",self.same_directory),
                 ("same-directory tool + startup metadata guard",lambda:self.same_directory(True)),
                 ("historical native settings",self.historical),
                 ("single-batch tool + exactly-once marker",self.tool),
                 ("resource reload preserves one-use continuation",lambda:self.tool("reload-once",reload=True)),
                 ("broken IC blocks automatic continuation",lambda:self.tool("broken-ic","broken-ic")),
                 ("missing IC health blocks automatic continuation",lambda:self.tool("no-health","no-health")),
                 ("missing flag owner exits before provider",self.missing_owner),
                 ("Pi approval dialog: command Allow",self.approval),
                 ("Pi approval dialog: tool Allow + one-shot continuation",lambda:self.approval(True)),
                 ("Pi approval dialog: command Escape preserves session",lambda:self.approval(False,False)),
                 ("Pi approval dialog: tool Escape releases lease",lambda:self.approval(True,False))]
        for name, test in tests:
            try:
                test()
                print(f"PASS {name}",flush=True)
                self.results.append({"test":name,"status":"PASS"})
            except Exception as error:
                print(f"FAIL {name}: {error}",flush=True)
                traceback.print_exc()
                self.results.append({"test":name,"status":"FAIL","error":str(error)})
        (self.root / "results.json").write_text(json.dumps(self.results,indent=2)+"\n")
        return 1 if any(r["status"]=="FAIL" for r in self.results) else 0


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pi",default=shutil.which("pi"),help="external Pi executable (must be 1.0.0)")
    parser.add_argument("--ic-source",required=True,help="patched IC output or extension directory")
    parser.add_argument("--actor-source",required=True,help="patched actor output or extension directory")
    parser.add_argument("--launcher",type=Path,default=REPO / "bin/pi-restartable")
    args=parser.parse_args()
    if not args.pi:
        parser.error("external pi is not in PATH; supply --pi")
    args.pi=str(Path(args.pi).resolve())
    # No model or extension is started by --version. Suppress user discovery anyway.
    version=subprocess.run([args.pi,"--version"],capture_output=True,text=True,timeout=10,
                           env={"PATH":os.defpath,"PI_TELEMETRY":"0","PI_SKIP_VERSION_CHECK":"1"})
    require(version.returncode==0 and version.stdout.strip()=="1.0.0", f"Pi 1.0.0 required, got {version.stdout!r} {version.stderr!r}")
    return Suite(args).run()


if __name__=="__main__":
    sys.exit(main())
