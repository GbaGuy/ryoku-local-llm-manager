pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// Finds every installed engine (Strata, TabbyAPI, llama.cpp) and its ready models through
// bin/strata-models, polls their user units, and starts/stops the selected model (one at a time).
Item {
    id: svc

    property var pluginApi
    readonly property string bin: pluginApi ? pluginApi.pluginDir + "/bin/strata-models" : ""
    readonly property string stateDir: pluginApi ? pluginApi.stateDir : ""

    property var models: []            // [{ key, engine, label, port, unit }]
    property string current: ""        // selected model key, "engine:name"
    property string state: "unknown"   // the "most active" systemctl is-active result across units
    property var unitStates: ({})      // unit -> systemctl is-active result
    readonly property var engines: models.reduce((a, m) => a.includes(m.engine) ? a : a.concat([m.engine]), [])
    readonly property var units: {
        const u = models.reduce((a, m) => a.includes(m.unit) ? a : a.concat([m.unit]), []);
        return u.length ? u : ["strata.service"];
    }
    readonly property var selected: models.find(m => m.key === current) || null
    readonly property bool running: state === "active"
    readonly property bool busy: state === "activating" || state === "deactivating" || ctl.running

    // the running model: the selected one, while its engine's unit is up (starts always go through it)
    function isRunning(key) {
        const m = svc.models.find(x => x.key === key);
        return !!m && key === svc.current && svc.unitStates[m.unit] === "active";
    }
    function engineState(engine) {
        const m = svc.models.find(x => x.engine === engine);
        return m ? (svc.unitStates[m.unit] || "unknown") : "unknown";
    }

    function refresh() {
        if (!poll.running) poll.running = true;
        if (bin && !list.running) list.running = true;
        if (bin && !cur.running) cur.running = true;
    }
    function run(cmd, next) {
        if (ctl.running) return;
        ctl.command = cmd;
        svc.state = next;
        ctl.running = true;
    }
    function toggle() {
        svc.run(svc.running ? [svc.bin, "stop"] : [svc.bin, "start", svc.stateDir],
                svc.running ? "deactivating" : "activating");
    }
    // start this model now (stops whatever else runs), or stop it if it is the one running
    function toggleModel(key) {
        if (svc.isRunning(key)) return svc.run([svc.bin, "stop"], "deactivating");
        svc.current = key;
        svc.run([svc.bin, "run", key, svc.stateDir], "activating");
    }
    function pick(key) {
        if (key === svc.current) return;
        svc.current = key;
        svc.run([svc.bin, "use", key, svc.stateDir], svc.running ? "activating" : svc.state);
    }

    Process {
        id: poll
        command: ["systemctl", "--user", "is-active"].concat(svc.units)
        stdout: StdioCollector {
            onStreamFinished: {
                const st = this.text.split("\n");
                const map = {};
                svc.units.forEach((u, i) => map[u] = st[i] || "unknown");
                svc.unitStates = map;
                svc.state = ["active", "activating", "deactivating", "failed", "inactive"]
                    .find(k => st.includes(k)) || "unknown";
            }
        }
    }
    Process {
        id: list
        command: [svc.bin, "list", svc.stateDir]
        stdout: StdioCollector {
            onStreamFinished: svc.models = this.text.split("\n").filter(l => l.length).map(l => {
                const f = l.split("\t");
                return { key: f[0], engine: f[1], label: f[2], port: f[3], unit: f[4] };
            })
        }
    }
    Process {
        id: cur
        command: [svc.bin, "current", svc.stateDir]
        stdout: StdioCollector { onStreamFinished: svc.current = this.text.trim() }
    }
    Process {
        id: ctl
        onExited: svc.refresh()
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: svc.refresh()
    }
}
