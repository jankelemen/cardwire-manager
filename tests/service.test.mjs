import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import vm from 'node:vm';

const serviceSource = readFileSync(new URL('../CardwireService.qml', import.meta.url), 'utf8');

function createService() {
    const requests = [];
    const deferred = [];
    const errors = [];
    const postApplyRefresh = { running: false, restart() { this.running = true; }, stop() { this.running = false; } };
    const root = {
        modes: [{ name: 'integrated' }, { name: 'hybrid' }, { name: 'smart' }],
        activeModeName: 'integrated', lastError: '', lastRefreshText: '',
        refreshing: false, applying: false, _refreshPending: false, _widgets: [],
        get busy() { return this.refreshing || this.applying; }
    };
    const context = {
        root, postApplyRefresh,
        Proc: { runCommand(id, command, callback, debounceMs, timeoutMs) { requests.push({ id, command, callback, timeoutMs }); } },
        Qt: { formatDateTime() { return '12:00:00'; }, callLater(callback) { if (!deferred.includes(callback)) deferred.push(callback); } },
        ToastService: { showError(title, message) { errors.push({ title, message }); } }
    };
    vm.createContext(context);
    vm.runInContext(serviceSource.match(/^    function [\s\S]*?^    }/gm).join('\n'), context);
    for (const [name, value] of Object.entries(context)) {
        if (typeof value === 'function') root[name] = value;
    }
    return {
        root, requests, errors, postApplyRefresh,
        respond(stdout, exitCode = 0) {
            const request = requests.shift();
            assert.ok(request, 'expected a pending command');
            request.callback(stdout, exitCode);
        },
        flush() { deferred.splice(0).forEach(callback => callback()); },
        verifySwitch() { assert.equal(postApplyRefresh.running, true); postApplyRefresh.stop(); root.refreshModeState(); }
    };
}

const state = mode => `Current Mode: ${mode}\nAvailable Mode: integrated, hybrid, smart\n`;

test('refresh parses installed Cardwire output', () => {
    const s = createService();
    s.root.refreshModeState();
    s.respond(state('Hybrid'));
    assert.equal(s.root.activeModeName, 'hybrid');
    assert.equal(s.root.modes.length, 3);
    assert.equal(s.root.modes[1].label, 'Hybrid');
    assert.equal(s.root.lastError, '');
    assert.equal(s.root.busy, false);
});

test('plural labels and CRLF output are supported', () => {
    const s = createService();
    s.root.refreshModeState();
    s.respond('Current Mode: SMART\r\nAvailable Modes: integrated, hybrid, smart\r\n');
    assert.equal(s.root.activeModeName, 'smart');
    assert.equal(s.root.modes.length, 3);
});

test('malformed or incomplete output preserves the last known mode', () => {
    for (const output of ['', 'Current Mode:\nAvailable Mode: hybrid', 'Current Mode: Hybrid\nAvailable Mode:', 'daemon unavailable']) {
        const s = createService();
        s.root.refreshModeState();
        s.respond(output);
        assert.equal(s.root.activeModeName, 'integrated');
        assert.equal(s.root.lastError, 'Unrecognized cardwire get output');
        assert.equal(s.root.busy, false);
    }
});

test('overlapping refreshes coalesce into one follow-up', () => {
    const s = createService();
    s.root.refreshModeState();
    s.root.refreshModeState();
    s.root.refreshModeState();
    assert.equal(s.requests.length, 1);
    s.respond(state('Integrated'));
    s.flush();
    assert.equal(s.requests.length, 1);
    s.respond(state('Hybrid'));
    s.flush();
    assert.equal(s.requests.length, 0);
    assert.equal(s.root.activeModeName, 'hybrid');
});

test('a switch cannot overlap an older read and inherit its stale response', () => {
    const s = createService();
    s.root.refreshModeState();
    s.root.setMode('hybrid');
    assert.equal(s.requests.length, 1);
    assert.ok(s.requests[0].id.endsWith('.get'));
    s.respond(state('Integrated'));
    s.root.setMode('hybrid');
    s.respond('Mode has been set to Hybrid');
    s.verifySwitch();
    s.respond(state('Hybrid'));
    assert.equal(s.root.activeModeName, 'hybrid');
});

test('verification is scheduled without polling or a widget callback', () => {
    const s = createService();
    s.root.setMode('hybrid');
    s.root.refreshModeState();
    s.root.refreshModeState();
    assert.equal(s.requests.length, 1);
    s.respond('Mode has been set to Hybrid');
    s.verifySwitch();
    s.respond(state('Hybrid'));
    s.flush();
    assert.equal(s.root.activeModeName, 'hybrid');
    assert.equal(s.requests.length, 0);
    assert.equal(s.root.busy, false);
});

test('verification requested during a read is queued rather than discarded', () => {
    const s = createService();
    s.root.setMode('hybrid');
    s.respond('Mode has been set to Hybrid');
    s.root.refreshModeState();
    s.verifySwitch();
    s.respond(state('Integrated'));
    s.flush();
    assert.equal(s.requests.length, 1);
    s.respond(state('Hybrid'));
    assert.equal(s.root.activeModeName, 'hybrid');
});

test('duplicate switches are blocked by the service', () => {
    const s = createService();
    s.root.setMode('hybrid');
    s.root.setMode('smart');
    assert.equal(s.requests.length, 1);
    assert.equal(s.requests[0].command.at(-1), 'hybrid');
});

test('failed switches retain the mode and actionable diagnostics', () => {
    const s = createService();
    s.root.setMode('hybrid');
    s.root.refreshModeState();
    s.respond('error: cardwired daemon is not running. Is the service up?', 1);
    assert.equal(s.root.activeModeName, 'integrated');
    assert.equal(s.root.lastError, s.errors[0].message);
    assert.match(s.root.lastError, /daemon is not running/);
    assert.equal(s.postApplyRefresh.running, false);
    assert.equal(s.root.busy, false);
});

test('a failed replacement switch cancels older delayed verification', () => {
    const s = createService();
    s.root.setMode('hybrid');
    s.respond('Mode has been set to Hybrid');
    s.root.setMode('smart');
    assert.equal(s.postApplyRefresh.running, false);
    s.respond('permission denied', 1);
    assert.equal(s.root.lastError, 'permission denied');
    assert.equal(s.postApplyRefresh.running, false);
});

test('read failures and timeouts release the busy state', () => {
    for (const [output, exitCode] of [['permission denied', 1], ['', 124]]) {
        const s = createService();
        s.root.refreshModeState();
        s.respond(output, exitCode);
        assert.equal(s.root.lastError, output || 'cardwire get exited 124');
        assert.equal(s.root.busy, false);
    }
});

test('multiple widgets share startup and release their registrations', () => {
    const s = createService();
    const first = { pollingEnabled: true, pollIntervalSeconds: 15 };
    const second = { pollingEnabled: true, pollIntervalSeconds: 30 };
    s.root.registerWidget(first);
    s.root.registerWidget(second);
    assert.equal(s.requests.length, 1);
    assert.equal(s.root._widgets.length, 2);
    s.root.unregisterWidget(first);
    s.root.unregisterWidget(second);
    assert.equal(s.root._widgets.length, 0);
});

test('command wrapper captures stderr without interpreting arguments as shell code', () => {
    const s = createService();
    const modeName = 'hybrid; $(printf unsafe)';
    s.root.setMode(modeName);
    const command = s.requests[0].command;
    assert.equal(command.at(-1), modeName);
    const result = spawnSync(command[0], [...command.slice(1, 4), 'sh', '-c', 'printf "%s" "$1" >&2; exit 7', 'diagnostic', modeName], { encoding: 'utf8' });
    assert.equal(result.status, 7);
    assert.equal(result.stdout, modeName);
    assert.equal(result.stderr, '');
});
