"""Read-only, allowlisted host audit. Never read credential or key contents."""
import glob
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import time

report = {"collectedAt": int(time.time()), "sections": {}}
current = None


def probe(name, args, json_output=False, select=None, accepted=(0,)):
    try:
        result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=20)
        if result.returncode not in accepted:
            value = {"status": "unavailable", "exitCode": result.returncode}
        elif len(result.stdout) > 512 * 1024:
            value = {"status": "unavailable", "reason": "probe output exceeded 512 KiB"}
        else:
            data = json.loads(result.stdout) if json_output else result.stdout.decode(errors="replace").strip()
            value = {"status": "ok", "data": select(data) if select else data}
    except (OSError, subprocess.TimeoutExpired, ValueError, TypeError, KeyError):
        value = {"status": "unavailable", "reason": "tool missing, timed out, or returned invalid data"}
    current[name] = value
    return value.get("data")


def fields(value, keys):
    return {k: value[k] for k in keys if k in value}


def api(name, path, *options, select=None):
    return probe(name, ["pvesh", "get", path, *options, "--output-format", "json"], True, select)


def metadata(path):
    try:
        info = path.stat()
        return {"path": str(path), "mode": oct(info.st_mode & 0o777), "size": info.st_size}
    except OSError:
        return {"path": str(path), "status": "missing_or_unreadable"}


def system():
    for name, args in {
        "version": ["pveversion"], "uptime": ["uptime"], "memory": ["free", "-m"],
        "filesystems": ["df", "-h"], "storage": ["pvesm", "status"],
        "containers": ["pct", "list"], "vms": ["qm", "list"],
    }.items():
        probe(name, args)


def disks():
    devices = probe("devices", ["lsblk", "--json", "--bytes", "-o", "NAME,PATH,SIZE,MODEL,SERIAL,TYPE,FSTYPE,UUID,PARTUUID,MOUNTPOINTS"], True)
    holders = {}
    for path in sorted(Path("/sys/class/block").glob("*/holders")):
        try:
            holders[path.parent.name] = [p.name for p in path.iterdir()]
        except OSError:
            pass
    current["holders"] = {"status": "ok", "data": holders}
    probe("stableIds", ["find", "/dev/disk/by-id", "-maxdepth", "1", "-type", "l", "-printf", "%f -> %l\n"])
    probe("swap", ["swapon", "--show", "--json"], True)
    probe("lvm", ["lvs", "--reportformat", "json", "-o", "lv_name,vg_name,lv_size,segtype,devices"], True)
    probe("zfs", ["zpool", "status", "-P"])
    for device in (devices or {}).get("blockdevices", []):
        if device.get("type") != "disk":
            continue
        def health(data):
            selected = fields(data, ("model_name", "model_number", "serial_number", "smart_status", "power_on_time", "temperature"))
            nvme = data.get("nvme_smart_health_information_log", {})
            selected["nvme"] = fields(nvme, ("critical_warning", "available_spare", "percentage_used", "media_errors", "num_err_log_entries", "power_on_hours"))
            selected["ata"] = [fields(a, ("id", "name", "value", "worst", "thresh", "raw")) for a in data.get("ata_smart_attributes", {}).get("table", []) if a.get("id") in (5, 9, 171, 172, 187, 197, 198, 199, 202)]
            return selected
        # SMART exit status is a bitmask; health warnings still carry useful JSON.
        probe("health:" + device["name"], ["smartctl", "-j", "-i", "-H", "-A", device["path"]], True, health, tuple(range(256)))


def boot():
    current["uefi"] = {"status": "ok", "data": Path("/sys/firmware/efi").is_dir()}
    probe("entries", ["efibootmgr", "-v"])
    probe("secureBoot", ["mokutil", "--sb-state"])
    probe("proxmoxBoot", ["proxmox-boot-tool", "status"])
    probe("root", ["findmnt", "--json", "--target", "/", "-o", "TARGET,SOURCE,FSTYPE,UUID"], True)
    probe("efi", ["findmnt", "--json", "--mountpoint", "/boot/efi", "-o", "TARGET,SOURCE,FSTYPE,UUID"], True)
    current["note"] = {"status": "ok", "data": "Firmware entries and Linux disk detection do not establish that an NVMe actually boots."}


def guests():
    resources = api("inventory", "/cluster/resources", "--type", "vm", select=lambda rows: [fields(r, ("vmid", "node", "type", "name", "status", "maxdisk", "maxmem", "uptime")) for r in rows])
    for guest in resources or []:
        kind = "lxc" if guest["type"] == "lxc" else "qemu"
        def config(data):
            keys = ("hostname", "name", "rootfs", "unprivileged", "onboot", "startup", "hookscript", "bios", "boot", "machine", "scsihw", "features", "lxc.idmap", "lxc.mount.entry", "lxc.cgroup2.devices.allow", "lxc")
            selected = fields(data, keys)
            # Deliberately omit descriptions, cloud-init credentials, SSH keys and arbitrary config fields.
            for key, value in data.items():
                if any(key.startswith(prefix) and key[len(prefix):].isdigit() for prefix in ("mp", "dev", "net", "hostpci", "usb", "scsi", "virtio", "sata", "ide", "efidisk", "tpmstate", "unused")):
                    selected[key] = value
            # Raw LXC entries are filtered rather than exposing arbitrary values.
            if "lxc" in selected:
                entries = selected.pop("lxc")
                if isinstance(entries, list):
                    selected["lxc"] = [entry for entry in entries if isinstance(entry, list) and len(entry) == 2 and entry[0] in ("lxc.idmap", "lxc.mount.entry", "lxc.cgroup2.devices.allow")]
            return selected
        api("config:" + str(guest["vmid"]), f'/nodes/{guest["node"]}/{kind}/{guest["vmid"]}/config', select=config)


def backups():
    nodes = api("nodes", "/nodes", select=lambda rows: [fields(r, ("node", "status")) for r in rows])
    storages = api("storage", "/storage", select=lambda rows: [fields(r, ("storage", "type", "server", "datastore", "path", "content", "nodes", "disable")) for r in rows])
    for node in nodes or []:
        if node.get("status") != "online":
            continue
        name = node["node"]
        api("tasks:" + name, f"/nodes/{name}/tasks", "--typefilter", "vzdump", "--limit", "20", select=lambda rows: [fields(r, ("upid", "starttime", "endtime", "status", "type", "id")) for r in rows])
        for storage in storages or []:
            if storage.get("type") != "pbs" or storage.get("disable"):
                continue
            api("snapshots:" + name + ":" + storage["storage"], f'/nodes/{name}/storage/{storage["storage"]}/content', "--content", "backup", select=lambda rows: [fields(r, ("volid", "vmid", "ctime", "size", "format", "subtype")) for r in rows])
    current["limits"] = {"status": "ok", "data": "Snapshot listing and successful jobs are not restore tests. PBS verification, host/library backup coverage and restore-test evidence are not established by this audit."}


def mounts():
    mounted = probe("mounted", ["findmnt", "--json", "-o", "TARGET,SOURCE,FSTYPE"], True)
    entries = []
    try:
        for line in Path("/etc/fstab").read_text().splitlines():
            parts = shlex.split(line, comments=True)
            if len(parts) >= 3:
                entries.append({"source": parts[0], "target": parts[1], "fstype": parts[2]})
        current["fstab"] = {"status": "ok", "data": entries}
    except (OSError, ValueError):
        current["fstab"] = {"status": "unavailable"}
    units = probe("units", ["systemctl", "list-units", "--type=mount", "--all", "--output=json", "--no-pager"], True, lambda rows: [fields(r, ("unit", "load", "active", "sub")) for r in rows])
    for unit in units or []:
        name = unit["unit"]
        probe("unit:" + name, ["systemctl", "show", name, "-p", "Where", "-p", "What", "-p", "Type", "-p", "FragmentPath", "-p", "SourcePath", "-p", "UnitFileState"])
    current["limits"] = {"status": "ok", "data": "Compare mounted paths with fstab and unit SourcePath/FragmentPath. No persistent definition found is not proof a mount is manual; ZFS and other services may manage it. Mount options are omitted to avoid credentials."}


def recovery():
    paths = [Path(p) for p in glob.glob("/etc/pve/priv/storage/*.enc") + glob.glob("/etc/pve/priv/storage/*.pw")]
    paths += [Path(p) for p in ("/var/lib/tailscale/tailscaled.state", "/var/lib/pve-cluster/config.db", "/usr/local/lib/pbs-env", "/var/spool/cron/crontabs/root")]
    current["fileMetadata"] = {"status": "ok", "data": [metadata(p) for p in paths]}
    current["customFiles"] = {"status": "ok", "data": sorted(glob.glob("/usr/local/sbin/*") + glob.glob("/etc/systemd/system/*.service") + glob.glob("/etc/systemd/system/*.timer") + glob.glob("/etc/systemd/system/*.mount"))}
    probe("timers", ["systemctl", "list-timers", "--all", "--no-pager"])
    current["limits"] = {"status": "ok", "data": "Presence/permissions only. Key usability, off-host copies and contents of custom backup scripts have not been verified."}


collectors = {"system": system, "disks": disks, "boot": boot, "guests": guests, "backups": backups, "mounts": mounts, "recovery": recovery}
for section in json.loads(sys.argv[1]):
    current = {}
    report["sections"][section] = {"probes": current}
    try:
        collectors[section]()
    except Exception:
        current["collector"] = {"status": "unavailable", "reason": "collector could not complete"}
    report["sections"][section]["status"] = "partial" if any(p["status"] != "ok" for p in current.values()) else "ok"
print(json.dumps(report))
