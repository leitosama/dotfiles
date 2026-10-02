// Panels of the leito Global Theme, in the Plasma scripting API (plasmashell only runs JS).
// Runs when Plasma starts without a layout (a new user), on Global Theme → leito with
// "Desktop and window layout" checked, and from kde-panels-load. Widgets and apps missing
// on this machine are skipped instead of leaving empty slots. Desktops and wallpapers are
// never touched: they stay per machine.
// API: https://develop.kde.org/docs/plasma/scripting/api/

var plasma = getApiVersion(1);

// BEGIN SAVED LAYOUT: written by kde-panels-save from plasmashell's dumpCurrentLayoutJS
// (the format Plasma's own Look and Feel Explorer saves); don't edit by hand, change the
// panels on the desktop and save again. null until the first save: the panels below are used.
var layout = null;
// END SAVED LAYOUT

function widgetInstalled(plugin) {
    if (knownWidgetTypes.indexOf(plugin) === -1) {
        print("leito layout: widget " + plugin + " is not installed, skipped");
        return false;
    }
    return true;
}

// "applications:org.kde.konsole.desktop" needs the app; preferred:// and file: entries resolve anyway
function launcherInstalled(launcher) {
    const prefix = "applications:";
    return !launcher.startsWith(prefix) || applicationExists(launcher.slice(prefix.length));
}

// An icon widget points at a .desktop file by path; keep it only where that app exists
function iconAppInstalled(url) {
    return !url || applicationExists(url.split("/").pop());
}

function loadSaved(saved) {
    saved.desktops = [];
    for (const panel of saved.panels) {
        panel.applets = panel.applets.filter(function (applet) {
            if (!widgetInstalled(applet.plugin)) {
                return false;
            }
            const config = applet.config || {};
            if (applet.plugin === "org.kde.plasma.icon") {
                return iconAppInstalled((config["/"] || {}).url);
            }
            const general = config["/General"];
            if (general && general.launchers) {
                general.launchers = general.launchers.split(",").filter(launcherInstalled).join(",");
            }
            return true;
        });
    }
    plasma.loadSerializedLayout(saved);
}

// Panels until the first kde-panels-save, rebuilt from the old konsave snapshot
function loadDefault() {
    function addWidget(panel, plugin) {
        return widgetInstalled(plugin) ? panel.addWidget(plugin) : null;
    }

    function configure(widget, group, values) {
        if (!widget) {
            return;
        }
        widget.currentConfigGroup = group;
        for (const key in values) {
            widget.writeConfig(key, values[key]);
        }
    }

    // Top bar: launcher menu, global menu, clock with the focus timer, tray
    const top = new Panel;
    top.location = "top";

    addWidget(top, "org.kde.plasma.kickoff");
    addWidget(top, "org.kde.plasma.appmenu");
    addWidget(top, "org.kde.plasma.panelspacer");
    configure(addWidget(top, "org.kde.plasma.digitalclock"), ["Appearance"], {
        dateDisplayFormat: "BesideTime",
        use24hFormat: 2,
    });
    // Pomodoro timer from the KDE Store, not packaged by the distros
    configure(addWidget(top, "com.dv.fokus"), ["General"], {
        do_not_disturb_enabled: true,
        focus_time: 45,
        long_break_time: 30,
        short_break_time: 10,
        show_time_in_compact_mode: true,
    });
    addWidget(top, "org.kde.plasma.panelspacer");
    for (const app of ["com.cisco.secureclient.gui.desktop"]) {
        if (applicationExists(app)) {
            configure(addWidget(top, "org.kde.plasma.icon"), [], {
                url: "file://" + applicationPath(app),
            });
        }
    }
    addWidget(top, "org.kde.plasma.systemtray");

    // Dock: virtual desktops and pinned apps, as wide as its content, hidden until needed
    const dock = new Panel;
    dock.location = "bottom";
    dock.lengthMode = "fit";
    dock.alignment = "center";
    dock.hiding = "autohide";

    addWidget(dock, "org.kde.plasma.pager");
    configure(addWidget(dock, "org.kde.plasma.icontasks"), ["General"], {
        launchers: [
            "applications:org.kde.konsole.desktop",
            "preferred://browser",
            "applications:org.kde.dolphin.desktop",
            "applications:md.obsidian.Obsidian.desktop",
            "applications:org.telegram.desktop.desktop",
        ].filter(launcherInstalled),
        unhideOnAttention: false,
    });
}

if (layout) {
    loadSaved(layout);
} else {
    loadDefault();
}
