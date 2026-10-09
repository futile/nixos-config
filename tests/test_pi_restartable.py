#!/usr/bin/env python3
"""No live Pi, providers, or envrc: fake executable/PTY supervisor regressions."""
import hashlib
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import pty
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

SCRIPT = Path(__file__).parents[1] / "bin/pi-restartable"
loader = importlib.machinery.SourceFileLoader("pi_restartable", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
launcher = importlib.util.module_from_spec(spec)
loader.exec_module(launcher)

FAKE = r'''
import json, os, pathlib, signal, sys, time
control = pathlib.Path(os.environ['PI_RESTARTABLE_CONTROL_DIR'])
launch = json.loads((control / 'launch.json').read_text())
root = pathlib.Path(os.environ['TEST_ROOT'])
logs = root / 'logs'
records = logs.read_text().splitlines() if logs.exists() else []
case = os.environ.get('CASE', 'normal')
record = {'argv': sys.argv[1:], 'cwd': os.getcwd(), 'launch': launch,
          'env': {k:v for k,v in os.environ.items() if k.startswith('PI_RESTARTABLE_')},
          'diff': os.environ.get('DIRENV_DIFF'), 'pid': os.getpid(),
          'executable': sys.argv[0], 'control': str(control),
          'modes': [control.stat().st_mode & 0o777, (control / 'launch.json').stat().st_mode & 0o777]}
with logs.open('a') as out:
    out.write(json.dumps(record) + '\n')
if case.startswith('approval'):
    replies = []
    rc = None
    for i, action in enumerate(['status', 'allow']):
        request_id = format(i + 1, '032x')
        request = {'version':1, 'childId':launch['childId'], 'requestId':request_id,
                   'action':action, 'target':os.environ['TARGET'], 'rc':rc}
        temp = control / 'approval-temp'
        temp.write_text(json.dumps(request)); temp.chmod(0o600)
        temp.replace(control / 'approval-request.json')
        response = control / ('approval-response.' + request_id + '.json')
        deadline = time.monotonic() + 4
        while not response.exists():
            if time.monotonic() > deadline: sys.exit(45)
            time.sleep(.01)
        reply = json.loads(response.read_text()); replies.append(reply)
        if action == 'status' and reply['ok']:
            rc = reply['status']['rc']
            if case == 'approval_edit': pathlib.Path(rc['path']).write_text('changed')
        if not reply['ok'] or rc is None: break
    (root / 'approval-replies').write_text(json.dumps(replies))
    sys.exit(0)
if launch['incoming'] and case != 'repeat':
    if case == 'stale':
        request = launch['incoming']
        temp = control / 'temp'
        temp.write_text(json.dumps(request)); temp.chmod(0o600)
        temp.replace(control / 'request.json')
    sys.exit(7 if case == 'replacement_fail' else 0)
if case == 'repeat' and len(records) >= 2:
    sys.exit(0)
source = str(root / ('source ' + str(len(records)) + ' ;$().jsonl'))
request = {'version':1, 'childId':launch['childId'], 'source':source,
    'sourceCwd':os.getcwd(), 'target':os.path.realpath(os.environ['TARGET']),
    'invocation':'tool' if os.environ.get('TOOL') else 'command',
    'continue':bool(os.environ.get('TOOL')), 'checkpointId':'checkpoint-' + str(len(records)),
    'expected':{'model':{'provider':'fake','modelId':'model'},'thinkingLevel':'high'},
    'prompt':'private continuation' if os.environ.get('TOOL') else None}
data = {k:request[k] for k in ('version','childId','sourceCwd','target','invocation','continue')}
header = {'type':'session', 'version':3, 'id':'session-id', 'cwd':os.getcwd()}
entry = {'type':'custom', 'id':request['checkpointId'], 'customType':'pi-restart-in-dir/checkpoint', 'data':data}
if case == 'wrong_checkpoint': entry['id'] = 'wrong'
if case == 'wrong_header': header['cwd'] = '/wrong'
if case == 'header_alias': header['cwd'] = str(root / 'start-alias')
if case == 'checkpoint_type': entry['data']['continue'] = 0
with open(source, 'w') as out:
    for value in [header, entry]: out.write(json.dumps(value) + '\n')
if case == 'trailing_entry':
    with open(source, 'a') as out: out.write(json.dumps({'type':'message', 'id':'later'}) + '\n')
if case == 'bad_jsonl':
    with open(source, 'a') as out: out.write('{broken\n')
if case == 'stale_initial': request['childId'] = 'old'
if case == 'extra': request['secret'] = 'DO_NOT_PRINT_SECRET'
if case == 'type': request['continue'] = 1
if case == 'consistency': request['prompt'] = 'DO_NOT_PRINT_SECRET'
if case == 'relative': request['target'] = 'relative'
if case == 'source_missing': pathlib.Path(source).unlink()
if case == 'target_missing': pathlib.Path(os.environ['TARGET']).rmdir()
if case == 'no_request': sys.exit(0)
raw = json.dumps(request)
if case == 'malformed': raw = '{"secret":"DO_NOT_PRINT_SECRET"'
if case == 'oversize': raw = ' ' * 65537
if case == 'duplicate': raw = raw[:-1] + ',"version":1}'
temp = control / 'temp'
temp.write_text(raw); temp.chmod(0o600)
temp.replace(control / 'request.json')
if case == 'permissions': (control / 'request.json').chmod(0o644)
if case == 'directory_permissions': control.chmod(0o755)
if case == 'symlink_request':
    (control / 'request.json').unlink()
    (control / 'request.json').symlink_to(source)
if case == 'fifo_request':
    (control / 'request.json').unlink()
    os.mkfifo(control / 'request.json', 0o600)
if case == 'profile':
    link = root / 'bin' / 'pi'
    link.unlink(); link.symlink_to(root / 'other-pi')
if case == 'pinned_missing': pathlib.Path(sys.argv[0]).unlink()
if case == 'direnv_remove': (root / 'bin' / 'direnv').unlink()
if case == 'direnv_add':
    path = root / 'bin' / 'direnv'
    path.write_text((root / 'direnv-template').read_text()); path.chmod(0o755)
if case.startswith('signal'):
    def stop(signum, frame):
        if case == 'signal_direct': (control / 'request.json').unlink(missing_ok=True)
        sys.exit(0)
    signal.signal(signal.SIGTERM, stop); signal.signal(signal.SIGHUP, stop); signal.signal(signal.SIGINT, stop)
    (root / 'ready').write_text(str(os.getpid()))
    while True: time.sleep(.02)
sys.exit(9 if case == 'exit_fail' else 0)
'''

DIRENV = r'''
import json, os, pathlib, sys
root = pathlib.Path(os.environ['TEST_ROOT'])
with (root / 'direnv-logs').open('a') as out:
    out.write(json.dumps({'argv':sys.argv[1:], 'cwd':os.getcwd(), 'diff':os.environ.get('DIRENV_DIFF'), 'path':os.environ.get('PATH')}) + '\n')
if sys.argv[1] == 'status':
    permission = root / 'permission'
    found = None if os.environ.get('DIRENV_NONE') else {'path':str(pathlib.Path(os.environ['TARGET']) / '.envrc'), 'allowed':int(permission.read_text()) if permission.exists() else 1}
    print(json.dumps({'state':{'foundRC':found, 'loadedRC':{'path':'/wrong', 'allowed':0}}}))
    sys.exit(0)
if sys.argv[1] == 'allow':
    if sys.argv[2] != os.environ['TARGET']: sys.exit(31)
    (root / 'permission').write_text('0')
    if os.environ.get('DIRENV_CHANGE_ON_ALLOW'):
        (pathlib.Path(os.environ['TARGET']) / '.envrc').write_text('changed during allow')
    sys.exit(0)
if os.environ.get('DIRENV_FAIL'):
    print('.envrc is blocked. Run direnv allow to approve its content', file=sys.stderr)
    sys.exit(23)
os.environ['PATH'] = '/unusable-target-path'
os.execv(sys.argv[3], sys.argv[3:])
'''


class ClassificationTests(unittest.TestCase):
    def test_drop_startup_and_carry_exact_whitelist_aliases(self):
        args = ['--offline', '-na', '--tui-mode', 'regular', '--verbose', '--session', 'a', '--fork', 'b', '--session-id', 'id', '-c', '-r', '--model', 'm', '--provider', 'p', '--thinking', 'high', '-n', 'name', '-a', '@file', 'prompt']
        self.assertEqual(launcher.classify(args), (['--offline', '-na', '--tui-mode', 'regular', '--verbose'], [], True))

    def test_delimiter_drops_all_prompt_options(self):
        self.assertEqual(launcher.classify(['--offline', '--', '--tools', 'bash', '--print', '@input']), (['--offline'], [], True))

    def test_unknown_and_resource_options_only_record_names(self):
        for args, names in [(['--api-key', 'SECRET'], ['--api-key']), (['--unknown=SECRET'], ['--unknown']), (['--tools', 'bash', '-e', './extension'], ['--tools', '-e']), (['--no-session', '-ne', '-nc', '-nt'], ['--no-session', '-ne', '-nc', '-nt']), (['--offline=true'], ['--offline'])]:
            with self.subTest(args=args):
                self.assertEqual(launcher.classify(args)[1], names)
                self.assertNotIn('SECRET', repr(launcher.classify(args)))

    def test_invalid_supported_shapes_are_unsupported(self):
        for args in [['--thinking', 'invalid'], ['--tui-mode', 'wrong'], ['--mode', 'tui'], ['--session'], ['--tui-mode']]:
            with self.subTest(args=args):
                self.assertEqual(launcher.classify(args)[1], [args[0]])

    def test_noninteractive_modes_and_commands(self):
        for args in [['-p'], ['--help'], ['-v'], ['--export', 'a'], ['--list-models'], ['--mode', 'json'], ['--mode', 'rpc'], ['auth', 'check'], ['config'], ['mcp', 'list']]:
            with self.subTest(args=args):
                self.assertFalse(launcher.classify(args)[2])
        self.assertTrue(launcher.classify(['--mode', 'text'])[2])


class ApprovalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='approval-test-')
        self.root = Path(self.temp.name).resolve()
        self.control = self.root / 'control'
        self.control.mkdir(mode=0o700)
        self.rc = self.root / '.envrc'
        self.rc.write_text('not executable')
        self.child_id = 'child-identity'
        self.request = {'version':1, 'childId':self.child_id, 'requestId':'a' * 32,
                        'action':'status', 'target':str(self.root), 'rc':None}
        self.blocked = {'state':'blocked', 'rc':{'path':str(self.rc), 'fingerprint':hashlib.sha256(b'not executable').hexdigest()}}

    def tearDown(self):
        self.temp.cleanup()

    def test_fingerprint_matches_standard_sha256_across_chunks(self):
        for content in [b'', b'normal envrc', bytes(range(256)) * 1025]:
            with self.subTest(size=len(content)), mock.patch.object(launcher.time, 'monotonic', return_value=0):
                self.assertEqual(launcher.rc_fingerprint(io.BytesIO(content)), hashlib.sha256(content).hexdigest())

    def test_fingerprint_deadline_stops_continuously_growing_reads(self):
        stream = mock.Mock()
        stream.read.return_value = b'x' * (64 * 1024)
        times = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5]
        with mock.patch.object(launcher.time, 'monotonic', side_effect=times):
            with self.assertRaisesRegex(launcher.Invalid, 'fingerprint timed out'):
                launcher.rc_fingerprint(stream)
        self.assertEqual(stream.read.call_args_list, [mock.call(64 * 1024)] * 5)
        # A regular-file read that itself overruns the budget also fails on return.
        with mock.patch.object(launcher.time, 'monotonic', side_effect=[0, 0, 6]):
            with self.assertRaisesRegex(launcher.Invalid, 'fingerprint timed out'):
                launcher.rc_fingerprint(io.BytesIO(b'small'))

    def test_status_uses_found_not_loaded_rc_and_exact_enum(self):
        for value, state in [(0, 'allowed'), (1, 'blocked'), (2, 'denied')]:
            raw = json.dumps({'state':{'foundRC':{'path':str(self.rc), 'allowed':value}, 'loadedRC':{'path':'/not-found', 'allowed':0}}}).encode()
            with self.subTest(value=value), mock.patch.object(launcher, 'direnv_command', return_value=raw):
                result = launcher.direnv_status('/direnv', str(self.root), {})
                self.assertEqual(result, {**self.blocked, 'state':state})
        for raw in [b'{}', b'null', b'{"state":{"foundRC":{"path":"/rc","allowed":true}}}', b'{"state":{"foundRC":{"path":"/rc","allowed":3}}}', b'{bad']:
            with self.subTest(raw=raw), mock.patch.object(launcher, 'direnv_command', return_value=raw):
                with self.assertRaises(launcher.Invalid): launcher.direnv_status('/direnv', str(self.root), {})
        with mock.patch.object(launcher, 'direnv_command', return_value=b'{"state":{"foundRC":null}}'):
            self.assertEqual(launcher.direnv_status('/direnv', str(self.root), {}), {'state':'none', 'rc':None})

    def test_metadata_rejects_stale_extra_types_and_unavailable_targets(self):
        cases = [{'version':True}, {'version':2}, {'childId':'old'}, {'requestId':'A'*32}, {'requestId':'a'*31}, {'extra':1}, {'rc':self.blocked['rc']}, {'action':'unknown'}, {'target':'relative'}, {'target':str(self.root / 'missing')}, {'action':'allow', 'rc':{'path':str(self.rc), 'fingerprint':'G'*64}}]
        for change in cases:
            with self.subTest(change=change), self.assertRaises(launcher.Invalid):
                launcher.approval_metadata({**self.request, **change}, self.child_id)
        alias = self.root / 'alias'
        alias.symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(launcher.Invalid): launcher.approval_metadata({**self.request, 'target':str(alias)}, self.child_id)

    def test_allow_races_denied_already_allowed_and_child_exit(self):
        request = {**self.request, 'action':'allow', 'rc':self.blocked['rc']}
        cases = [(self.blocked, False, False), ({**self.blocked, 'state':'denied'}, True, False), ({**self.blocked, 'state':'allowed'}, True, True), ({**self.blocked, 'rc':{**self.blocked['rc'], 'path':str(self.root / 'other')}}, True, False), ({**self.blocked, 'rc':{**self.blocked['rc'], 'fingerprint':'0'*64}}, True, False)]
        for status, alive, succeeds in cases:
            with self.subTest(status=status, alive=alive), mock.patch.object(launcher, 'direnv_status', return_value=status), mock.patch.object(launcher, 'direnv_command') as command:
                if succeeds:
                    self.assertEqual(launcher.approval_result(request, self.child_id, {}, lambda:alive), status)
                else:
                    with self.assertRaises(launcher.Invalid): launcher.approval_result(request, self.child_id, {}, lambda:alive)
                command.assert_not_called()

    def test_post_allow_must_confirm_identical_allowed_rc(self):
        request = {**self.request, 'action':'allow', 'rc':self.blocked['rc']}
        for after in [self.blocked, {'state':'none', 'rc':None}, {**self.blocked, 'state':'allowed', 'rc':{**self.blocked['rc'], 'fingerprint':'0'*64}}]:
            with self.subTest(after=after), mock.patch.object(launcher, 'direnv_status', side_effect=[self.blocked, after]), mock.patch.object(launcher, 'direnv_command') as command:
                with self.assertRaises(launcher.Invalid) as error: launcher.approval_result(request, self.child_id, {}, lambda:True)
                self.assertIn('permission may have changed', str(error.exception))
                command.assert_called_once()

    def test_private_ipc_response_consumption_replay_and_rejected_files(self):
        seen = set()
        request_path = self.control / 'approval-request.json'
        response_path = self.control / ('approval-response.' + self.request['requestId'] + '.json')
        with mock.patch.object(launcher, 'approval_result', return_value=self.blocked) as result:
            launcher.atomic_json(request_path, self.request)
            launcher.serve_approval(self.control, self.child_id, seen, {}, lambda:True)
            self.assertFalse(request_path.exists())
            response = launcher.private_json(response_path)
            self.assertEqual(response, {'version':1, 'childId':self.child_id, 'requestId':self.request['requestId'], 'ok':True, 'status':self.blocked})
            self.assertEqual(response_path.stat().st_mode & 0o777, 0o600)
            launcher.atomic_json(request_path, self.request)
            launcher.serve_approval(self.control, self.child_id, seen, {}, lambda:True)
            self.assertFalse(launcher.private_json(response_path)['ok'])
            result.assert_called_once()
            response_path.unlink()
            for kind in ['malformed', 'oversize', 'permissions', 'symlink', 'fifo']:
                with self.subTest(kind=kind):
                    if kind == 'symlink': request_path.symlink_to(self.rc)
                    elif kind == 'fifo': os.mkfifo(request_path, 0o600)
                    else:
                        request_path.write_text('{' if kind == 'malformed' else ' ' * 65537 if kind == 'oversize' else json.dumps(self.request))
                        request_path.chmod(0o644 if kind == 'permissions' else 0o600)
                    launcher.serve_approval(self.control, self.child_id, seen, {}, lambda:True)
                    self.assertFalse(os.path.lexists(request_path))
                    self.assertFalse(response_path.exists())
            result.assert_called_once()

    def test_direnv_timeout_failure_never_echoes_output(self):
        for outcome in [subprocess.TimeoutExpired('direnv', 5, output=b'SECRET'), subprocess.CompletedProcess([], 1, stdout=b'SECRET'), subprocess.CompletedProcess([], 0, stdout=b'x'*65537)]:
            with self.subTest(outcome=outcome):
                options = {'side_effect':outcome} if isinstance(outcome, Exception) else {'return_value':outcome}
                with mock.patch.object(launcher.subprocess, 'run', **options) as run:
                    with self.assertRaises(launcher.Invalid) as error: launcher.direnv_command('/direnv', ['status', '--json'], str(self.root), {'DIRENV_DIFF':'secret'})
                    self.assertNotIn('SECRET', str(error.exception))
                    self.assertEqual(run.call_args.kwargs['timeout'], 5)
                    self.assertEqual(run.call_args.kwargs['env'], {'DIRENV_DIFF':'secret'})

    @unittest.skipUnless(shutil.which('direnv'), 'optional real direnv unavailable')
    def test_isolated_real_direnv_symlink_rc_approval_and_deny_without_execution(self):
        project = self.root / 'project'
        project.mkdir()
        contents = self.root / 'contents'
        contents.mkdir()
        marker = self.root / 'EXECUTED'
        content = contents / 'rc'
        content.write_text('printf executed > ' + shlex.quote(str(marker)) + '\n')
        # A wrong file-argument approval would resolve into this unrelated RC.
        (contents / '.envrc').write_text('unrelated')
        (project / '.envrc').symlink_to(content)
        baseline = {k:v for k,v in os.environ.items() if not k.startswith(('DIRENV', 'PI_RESTARTABLE_'))}
        for key in ['HOME', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME', 'DIRENV_CONFIG']:
            directory = self.root / key
            directory.mkdir()
            baseline[key] = str(directory)
        request = {**self.request, 'target':str(project)}
        before = launcher.approval_result(request, self.child_id, baseline, lambda:True)
        self.assertEqual(before['state'], 'blocked')
        self.assertEqual(before['rc']['path'], str(project / '.envrc'))
        after = launcher.approval_result({**request, 'action':'allow', 'rc':before['rc']}, self.child_id, baseline, lambda:True)
        self.assertEqual(after, {**before, 'state':'allowed'})
        direnv = shutil.which('direnv', path=baseline['PATH'])
        other = launcher.direnv_status(direnv, str(contents), baseline)
        self.assertEqual(other['state'], 'blocked')
        launcher.direnv_command(direnv, ['deny', str(project)], str(project), baseline)
        denied = launcher.approval_result(request, self.child_id, baseline, lambda:True)
        self.assertEqual(denied, {**before, 'state':'denied'})
        with self.assertRaises(launcher.Invalid): launcher.approval_result({**request, 'action':'allow', 'rc':denied['rc']}, self.child_id, baseline, lambda:True)
        self.assertFalse(marker.exists())


class SupervisorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='restart-test-')
        self.root = Path(self.temp.name).resolve()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.start = self.root / 'old cwd'
        self.start.mkdir()
        self.target = self.root / "new cwd ' ;$(touch SHOULD_NOT_EXIST)"
        self.target.mkdir()
        self.write_executable(self.root / 'real-pi', FAKE)
        (self.bin / 'pi').symlink_to(self.root / 'real-pi')
        self.env = {**os.environ, 'PATH':str(self.bin), 'TEST_ROOT':str(self.root), 'TARGET':str(self.target), 'DIRENV_DIFF':'inherited-diff', 'PI_RESTARTABLE_CHILD_ID':'stale', 'PI_RESTARTABLE_CONTROL_DIR':'stale', 'PI_RESTARTABLE_LAUNCHER_PID':'1', 'PI_RESTARTABLE_SECRET':'stale'}
        self.process = None
        self.master = None

    def tearDown(self):
        if self.process and self.process.poll() is None:
            self.process.kill()
            self.process.wait()
        if self.process and self.process.stderr:
            self.process.stderr.close()
        if self.master is not None:
            os.close(self.master)
        self.temp.cleanup()

    def write_executable(self, path, body):
        path.write_text('#!' + sys.executable + '\n' + body)
        path.chmod(0o755)

    def start_wrapper(self, args=(), case='normal', tty=True):
        self.env['CASE'] = case
        if tty:
            self.master, slave = pty.openpty()
        else:
            slave = subprocess.DEVNULL
        self.process = subprocess.Popen([sys.executable, str(SCRIPT), *args], cwd=self.start, env=self.env, stdin=slave, stdout=slave, stderr=subprocess.PIPE, text=True)
        if tty:
            os.close(slave)
        return self.process

    def finish(self):
        _, error = self.process.communicate(timeout=8)
        return self.process.returncode, error

    def run_wrapper(self, args=(), case='normal', tty=True):
        self.start_wrapper(args, case, tty)
        return self.finish()

    def logs(self):
        path = self.root / 'logs'
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_cross_directory_fork_argv_environment_and_fresh_authority(self):
        args = ['--offline', '-na', '--verbose', '--tui-mode', 'regular', '--model', 'old', '--provider', 'old-provider', '--thinking', 'low', '--name', 'old name', '-a', '--session', 'old-selection', '@old-file', 'old prompt', '--', '--tools']
        self.env['TOOL'] = '1'
        self.assertEqual(self.run_wrapper(args)[0], 0)
        first, second = self.logs()
        self.assertEqual(first['argv'], args)
        request = second['launch']['incoming']
        self.assertEqual(second['argv'], ['--offline', '-na', '--verbose', '--tui-mode', 'regular', '--fork', request['source'], '--pi-restart-in-dir-handoff', first['launch']['childId'], 'pi-restart-in-dir:' + first['launch']['childId']])
        self.assertEqual(second['cwd'], str(self.target))
        self.assertEqual(first['cwd'], str(self.start))
        self.assertNotEqual(first['launch']['childId'], second['launch']['childId'])
        self.assertEqual(request['childId'], first['launch']['childId'])
        for record in (first, second):
            self.assertEqual(record['modes'], [0o700, 0o600])
            self.assertEqual(record['launch']['version'], 2)
            self.assertEqual(record['launch']['launcherPid'], self.process.pid)
            self.assertEqual(set(record['env']), {'PI_RESTARTABLE_CONTROL_DIR', 'PI_RESTARTABLE_CHILD_ID', 'PI_RESTARTABLE_LAUNCHER_PID'})
            self.assertEqual(record['diff'], 'inherited-diff')
        self.assertFalse(Path(first['control']).exists())
        self.assertFalse((self.root / 'SHOULD_NOT_EXIST').exists())
        self.assertTrue(Path(request['source']).exists())

    def test_symlink_tmpdir_exports_canonical_control_and_handoff_works(self):
        temporary = self.root / 'actual-tmp'
        temporary.mkdir()
        alias = self.root / 'tmp-alias'
        alias.symlink_to(temporary, target_is_directory=True)
        self.env['TMPDIR'] = str(alias)
        self.assertEqual(self.run_wrapper()[0], 0)
        records = self.logs()
        self.assertEqual(len(records), 2)
        for record in records:
            self.assertEqual(record['env']['PI_RESTARTABLE_CONTROL_DIR'], record['control'])
            self.assertEqual(record['control'], os.path.realpath(record['control']))
            self.assertEqual(Path(record['control']).parent, temporary)
            self.assertFalse(Path(record['control']).exists())

    def test_same_directory_resumes_session_without_prompt_marker(self):
        self.env['TARGET'] = str(self.start)
        self.assertEqual(self.run_wrapper(['--mode', 'text', '-c'])[0], 0)
        first, second = self.logs()
        source = second['launch']['incoming']['source']
        self.assertEqual(second['argv'], ['--session', source, '--pi-restart-in-dir-handoff', first['launch']['childId']])
        self.assertEqual(second['cwd'], str(self.start))

    def test_same_directory_canonical_alias_and_historical_header_spelling(self):
        alias = self.root / 'start-alias'
        alias.symlink_to(self.start, target_is_directory=True)
        self.env['TARGET'] = str(alias)
        self.assertEqual(self.run_wrapper(case='header_alias')[0], 0)
        self.assertEqual(self.logs()[1]['argv'][0], '--session')
        self.assertEqual(self.logs()[1]['cwd'], str(self.start))
        source = Path(self.logs()[1]['launch']['incoming']['source'])
        self.assertEqual(json.loads(source.read_text().splitlines()[0])['cwd'], str(alias))

    def test_profile_symlink_swap_keeps_pinned_pi(self):
        self.write_executable(self.root / 'other-pi', "raise SystemExit('WRONG VERSION')\n")
        self.assertEqual(self.run_wrapper(case='profile')[0], 0)
        self.assertEqual([row['executable'] for row in self.logs()], [str(self.root / 'real-pi')] * 2)
        self.assertEqual((self.bin / 'pi').resolve(), self.root / 'other-pi')

    def test_pinned_executable_disappearance_does_not_substitute(self):
        self.write_executable(self.root / 'other-pi', "raise SystemExit('WRONG VERSION')\n")
        status, error = self.run_wrapper(case='pinned_missing')
        self.assertEqual(status, 1)
        self.assertEqual(len(self.logs()), 1)
        self.assertIn('no fallback or retry', error)
        self.assertIn(shlex.quote(str(self.target)), error)
        self.assertIn('Saved source recovery:', error)

    def test_optional_direnv_runs_from_child_cwd_and_cannot_change_pin(self):
        self.write_executable(self.bin / 'direnv', DIRENV)
        self.assertEqual(self.run_wrapper()[0], 0)
        records = [json.loads(line) for line in (self.root / 'direnv-logs').read_text().splitlines()]
        self.assertEqual([r['cwd'] for r in records], [str(self.start), str(self.target)])
        for record in records:
            self.assertEqual(record['argv'][:3], ['exec', '.', str(self.root / 'real-pi')])
            self.assertEqual(record['diff'], 'inherited-diff')
        self.assertEqual(len(self.logs()), 2)

    def test_direnv_rechecked_after_removal(self):
        self.write_executable(self.bin / 'direnv', DIRENV)
        self.assertEqual(self.run_wrapper(case='direnv_remove')[0], 0)
        self.assertEqual(len((self.root / 'direnv-logs').read_text().splitlines()), 1)
        self.assertEqual(len(self.logs()), 2)

    def test_direnv_rechecked_after_appearance(self):
        self.write_executable(self.root / 'direnv-template', DIRENV)
        self.assertEqual(self.run_wrapper(case='direnv_add')[0], 0)
        self.assertEqual(len((self.root / 'direnv-logs').read_text().splitlines()), 1)
        self.assertEqual(len(self.logs()), 2)

    def test_direnv_failure_is_not_bypassed(self):
        self.write_executable(self.bin / 'direnv', DIRENV)
        self.env['DIRENV_FAIL'] = '1'
        status, error = self.run_wrapper()
        self.assertEqual(status, 23)
        self.assertIn('blocked', error)
        self.assertEqual(self.logs(), [])

    def test_non_tty_forwards_once_no_restart(self):
        status, _ = self.run_wrapper(['--offline', 'prompt'], tty=False)
        self.assertEqual(status, 1)
        first, = self.logs()
        self.assertEqual(first['argv'], ['--offline', 'prompt'])
        self.assertFalse(first['launch']['interactive'])

    def test_noninteractive_modes_forward_once_no_authority(self):
        for args in [['--mode', 'rpc'], ['-p', 'prompt'], ['--help'], ['--version']]:
            with self.subTest(args=args):
                self.assertEqual(self.run_wrapper(args)[0], 1)
                self.assertEqual(self.logs()[-1]['argv'], args)
                self.assertFalse(self.logs()[-1]['launch']['interactive'])
                self.process.stderr.close()
                os.close(self.master)
                self.master = None

    def test_unsupported_initial_argv_preserved_without_secret_metadata(self):
        args = ['--api-key', 'DO_NOT_PRINT_SECRET', '--custom=DO_NOT_PRINT_SECRET', '--no-session', '-nt']
        status, error = self.run_wrapper(args)
        self.assertEqual(status, 1)
        first, = self.logs()
        self.assertEqual(first['argv'], args)
        self.assertEqual(first['launch']['unsupported'], ['--api-key', '--custom', '--no-session', '-nt'])
        self.assertNotIn('DO_NOT_PRINT_SECRET', json.dumps(first['launch']) + error)

    def test_ordinary_exit_and_nonclean_exit_never_restart(self):
        self.assertEqual(self.run_wrapper(case='no_request')[0], 0)
        self.assertEqual(len(self.logs()), 1)
        self.process.stderr.close(); os.close(self.master); self.master = None
        self.assertEqual(self.run_wrapper(case='exit_fail')[0], 9)
        self.assertEqual(len(self.logs()), 2)

    def test_malformed_stale_nondurable_and_unavailable_requests(self):
        for case in ['malformed', 'oversize', 'duplicate', 'extra', 'type', 'consistency', 'relative', 'permissions', 'directory_permissions', 'checkpoint_type', 'symlink_request', 'fifo_request', 'stale_initial', 'wrong_checkpoint', 'wrong_header', 'trailing_entry', 'bad_jsonl', 'source_missing', 'target_missing']:
            with self.subTest(case=case):
                if not self.target.exists(): self.target.mkdir()
                before = len(self.logs())
                status, error = self.run_wrapper(case=case)
                self.assertEqual(status, 1)
                self.assertEqual(len(self.logs()), before + 1)
                self.assertNotIn('DO_NOT_PRINT_SECRET', error)
                self.process.stderr.close(); os.close(self.master); self.master = None

    def test_request_cannot_be_consumed_by_replacement_again(self):
        self.assertEqual(self.run_wrapper(case='stale')[0], 1)
        self.assertEqual(len(self.logs()), 2)

    def test_multiple_restarts_have_nonoverlapping_fresh_metadata(self):
        self.assertEqual(self.run_wrapper(case='repeat')[0], 0)
        records = self.logs()
        self.assertEqual(len(records), 3)
        self.assertEqual(len({r['launch']['childId'] for r in records}), 3)
        self.assertEqual(records[2]['argv'][0], '--session')
        self.assertNotEqual(records[1]['launch']['incoming']['childId'], records[2]['launch']['incoming']['childId'])

    def await_ready(self):
        deadline = time.monotonic() + 4
        while not (self.root / 'ready').exists():
            if self.process.poll() is not None or time.monotonic() >= deadline:
                self.fail('fake child did not become ready')
            time.sleep(.01)
        return int((self.root / 'ready').read_text())

    def test_wrapper_signals_cancel_even_when_child_exits_zero_and_reap(self):
        for sig in [signal.SIGINT, signal.SIGTERM, signal.SIGHUP]:
            with self.subTest(sig=sig):
                (self.root / 'ready').unlink(missing_ok=True)
                self.start_wrapper(case='signal_wrapper')
                pid = self.await_ready()
                self.process.send_signal(sig)
                status, error = self.finish()
                self.assertEqual(status, 128 + sig)
                self.assertIn('cancelled', error)
                with self.assertRaises(ProcessLookupError): os.kill(pid, 0)
                self.process.stderr.close(); os.close(self.master); self.master = None
        self.assertEqual(len(self.logs()), 3)

    def test_direct_child_term_and_hup_invalidate_request_before_clean_exit(self):
        for sig in [signal.SIGTERM, signal.SIGHUP]:
            with self.subTest(sig=sig):
                (self.root / 'ready').unlink(missing_ok=True)
                self.start_wrapper(case='signal_direct')
                pid = self.await_ready()
                os.kill(pid, sig)
                self.assertEqual(self.finish()[0], 0)
                with self.assertRaises(ProcessLookupError): os.kill(pid, 0)
                self.process.stderr.close(); os.close(self.master); self.master = None
        self.assertEqual(len(self.logs()), 2)

    def test_replacement_failure_reports_quoted_recovery_once(self):
        status, error = self.run_wrapper(case='replacement_fail')
        self.assertEqual(status, 7)
        self.assertEqual(len(self.logs()), 2)
        self.assertIn('cd -- ' + shlex.quote(str(self.target)), error)
        self.assertIn('Saved source recovery:', error)

    def test_missing_external_pi_and_self_resolution_fail(self):
        (self.bin / 'pi').unlink()
        self.assertEqual(self.run_wrapper()[0], 1)
        self.assertEqual(self.logs(), [])
        self.process.stderr.close(); os.close(self.master); self.master = None
        (self.bin / 'pi').symlink_to(SCRIPT)
        self.assertEqual(self.run_wrapper()[0], 1)
        self.assertEqual(self.logs(), [])
        self.process.stderr.close(); os.close(self.master); self.master = None
        (self.bin / 'pi').unlink()
        self.write_executable(self.bin / 'pi-restartable', "raise SystemExit('WRAPPER SHOULD NOT RUN')\n")
        (self.bin / 'pi').symlink_to(self.bin / 'pi-restartable')
        self.assertEqual(self.run_wrapper()[0], 1)
        self.assertEqual(self.logs(), [])

    def test_live_child_approval_uses_baseline_not_direnv_child_environment(self):
        self.write_executable(self.bin / 'direnv', DIRENV)
        (self.target / '.envrc').write_text('never execute this')
        self.assertEqual(self.run_wrapper(case='approval')[0], 0)
        replies = json.loads((self.root / 'approval-replies').read_text())
        self.assertEqual([r['status']['state'] for r in replies], ['blocked', 'allowed'])
        self.assertEqual(replies[0]['status']['rc'], replies[1]['status']['rc'])
        self.assertEqual(replies[0]['status']['rc']['fingerprint'], hashlib.sha256(b'never execute this').hexdigest())
        records = [json.loads(line) for line in (self.root / 'direnv-logs').read_text().splitlines()]
        self.assertEqual([r['argv'] for r in records[1:]], [['status', '--json'], ['status', '--json'], ['allow', str(self.target)], ['status', '--json']])
        for record in records:
            self.assertEqual(record['diff'], 'inherited-diff')
            self.assertEqual(record['path'], str(self.bin))
        self.assertEqual([r['cwd'] for r in records[1:]], [str(self.target)] * 4)
        self.assertEqual(len(self.logs()), 1)

    def test_live_child_changed_rc_refuses_approval(self):
        self.write_executable(self.bin / 'direnv', DIRENV)
        (self.target / '.envrc').write_text('before')
        self.assertEqual(self.run_wrapper(case='approval_edit')[0], 0)
        replies = json.loads((self.root / 'approval-replies').read_text())
        self.assertTrue(replies[0]['ok'])
        self.assertFalse(replies[1]['ok'])
        self.assertFalse((self.root / 'permission').exists())

    def test_live_child_post_allow_change_reports_partial_grant_without_handoff(self):
        self.write_executable(self.bin / 'direnv', DIRENV)
        self.env['DIRENV_CHANGE_ON_ALLOW'] = '1'
        (self.target / '.envrc').write_text('before')
        self.assertEqual(self.run_wrapper(case='approval')[0], 0)
        replies = json.loads((self.root / 'approval-replies').read_text())
        self.assertTrue(replies[0]['ok'])
        self.assertFalse(replies[1]['ok'])
        self.assertIn('permission may have changed', replies[1]['error'])
        self.assertEqual((self.root / 'permission').read_text(), '0')
        self.assertEqual(len(self.logs()), 1)
        self.assertEqual(list(self.root.glob('source *.jsonl')), [])
        records = [json.loads(line) for line in (self.root / 'direnv-logs').read_text().splitlines()]
        self.assertEqual([r['argv'][0] for r in records], ['exec', 'status', 'status', 'allow', 'status'])
        self.assertEqual(records[0]['cwd'], str(self.start))

    def test_live_child_optional_direnv_missing_returns_unavailable(self):
        self.assertEqual(self.run_wrapper(case='approval')[0], 0)
        reply, = json.loads((self.root / 'approval-replies').read_text())
        self.assertEqual(reply['status'], {'state':'unavailable', 'rc':None})

    def test_private_request_rejects_wrong_owner(self):
        control = self.root / 'private-control'
        control.mkdir(mode=0o700)
        launcher.atomic_json(control / 'request.json', {'version':1})
        with mock.patch.object(launcher.os, 'getuid', return_value=os.getuid() + 1):
            with self.assertRaises(launcher.Invalid):
                launcher.private_json(control / 'request.json')


if __name__ == '__main__':
    unittest.main()
