#!/bin/bash
# Captura notificaciones via dbus-monitor y emite JSON por stdout
# Formato: {"app": "...", "summary": "...", "body": "..."}
dbus-monitor --session "type='method_call',interface='org.freedesktop.Notifications',member='Notify'" 2>/dev/null | \
python3 -u -c "
import sys, json, re
fields = []
in_notif = False
for line in sys.stdin:
    line = line.rstrip()
    if 'member=Notify' in line and 'org.freedesktop.Notifications' in line:
        in_notif = True
        fields = []
    elif in_notif:
        m = re.match(r'\s+string \"(.*)\"', line)
        if m:
            fields.append(m.group(1))
        if len(fields) >= 4:
            # [0]=app_name  [1]=icon  [2]=summary  [3]=body
            print(json.dumps({'app': fields[0], 'summary': fields[2], 'body': fields[3]}), flush=True)
            in_notif = False
"
