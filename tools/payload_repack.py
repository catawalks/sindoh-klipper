"""Repack the v0.1.1 stick payload (32ec81c0, built on the dev printer and
audited) into v0.1.2: same Debian root and DP200 firmware (fm/io of v0.1.0,
fork 9b174ab), new host files from the port commit and fork b3b8d837.
usage: repack.py SRC.tar.gz OUT_DIR BUILD_STRING [inspect]"""
import hashlib, io, os, subprocess, sys, tarfile, time

SRC, OUT, BUILD = sys.argv[1], sys.argv[2], sys.argv[3]
INSPECT = len(sys.argv) > 4
PORT = r'D:\DP200\backup\klipper_port'
FORK = r'C:\Users\temp.DESKTOP-L41KPL5\klipper'
FORK_OLD, FORK_NEW = '9b174ab', 'b3b8d837008105a5dd45362b7335ca12fd7407a8'
NOW = int(time.time())


def git(repo, *a):
    return subprocess.run(['git', '-C', repo] + list(a), check=True,
                          capture_output=True).stdout


def port(rel):
    # committed content only (the build is of a committed tree)
    return git(PORT, 'show', 'HEAD:' + rel)


src = tarfile.open(SRC, 'r:gz')
members = src.getmembers()
byname = {m.name: m for m in members}
print('source members', len(members))

ref_root = byname['./etc/dp200/rc.dp200']
ref_k = byname['./home/klipper/printer_data/config/printer.cfg']
ref_kk = byname['./home/klipper/klipper/klippy/klippy.py']
for n in ('./usr/bin/sudo', './etc/sudoers.d', './usr/local/sbin', './usr/sbin/dropbear'):
    print(n, 'present' if n in byname else 'MISSING')

# ---- what goes in: name -> (bytes, mode, owner ref) ----
new = {}
for f in ('dp200_screen.py', 'dp200_wifi.py', 'dp200_net.py'):
    new['./usr/local/bin/' + f] = (port('install/display/' + f), 0o755, ref_root)
for f in ('rc.dp200', 'init.mainline'):
    new['./etc/dp200/' + f] = (port('install/rootfs/etc/dp200/' + f), 0o755, ref_root)
for f in git(PORT, 'ls-tree', '--name-only', 'HEAD', 'install/printer/').decode().split():
    b = os.path.basename(f)
    if b.endswith('.sh') or b.endswith('.py'):
        new['./dp200/' + b] = (port(f), 0o755, ref_root)
new['./usr/local/sbin/dp200-power-request'] = (port('install/rootfs/usr/local/sbin/dp200-power-request'), 0o755, ref_root)
new['./etc/sudoers.d/dp200-power'] = (port('install/rootfs/etc/sudoers.d/dp200-power'), 0o440, ref_root)
new['./etc/dp200/build'] = ((BUILD + '\n').encode(), 0o644, ref_root)
C = './home/klipper/printer_data/config/'
for f in ('printer.cfg', 'dp200_printer.cfg', 'dp200_macros.cfg', 'dp200_adxl.cfg.off',
          'dp200_model_dp200.cfg', 'dp200_model_dp201.cfg', 'dp200_model_dp203.cfg',
          'printer_dp201.cfg'):
    new[C + f] = (port('klipper/config/' + f), 0o644, ref_k)
new[C + 'moonraker.conf'] = (port('install/rootfs/home/klipper/printer_data/config/moonraker.conf'), 0o644, ref_k)
# dp200_moonraker.conf: the port's, plus the pins make_payload.sh adds
# (moonraker's commit as shipped in v0.1.1, Klipper's the new fork commit)
old_mc = src.extractfile(byname[C + 'dp200_moonraker.conf']).read().decode()
mpin = old_mc.split('[update_manager moonraker]\npinned_commit: ')[1].split()[0]
mc = port('install/rootfs/home/klipper/printer_data/config/dp200_moonraker.conf').decode()
for r, c in (('klipper', FORK_NEW), ('moonraker', mpin)):
    mc += '\n# shipped commit: no updates from upstream (make_payload.sh)\n[update_manager %s]\npinned_commit: %s\n' % (r, c)
new[C + 'dp200_moonraker.conf'] = (mc.encode(), 0o644, ref_k)
# klippy: every file the fork changed since v0.1.1's commit
K = './home/klipper/klipper/'
changed = git(FORK, 'diff', '--name-status', FORK_OLD, FORK_NEW, '--', 'klippy').decode().splitlines()
for line in changed:
    st, path = line.split('\t')[0], line.split('\t')[-1]
    assert st[0] in 'AM', line
    new[K + path] = (git(FORK, 'show', FORK_NEW + ':' + path), 0o644, ref_kk)
new[K + 'klippy/.version'] = (git(FORK, 'describe', '--always', '--tags', '--long', FORK_NEW).strip() + b'\n', 0o644, ref_kk)
links = {'./usr/local/sbin/' + n: 'dp200-power-request' for n in ('reboot', 'poweroff', 'halt')}

changes = []
for n, (data, mode, ref) in sorted(new.items()):
    if n in byname:
        old = src.extractfile(byname[n]).read()
        if old != data:
            changes.append('M ' + n)
    else:
        changes.append('A ' + n)
for n in links:
    changes.append(('M ' if n in byname else 'A ') + n + ' -> dp200-power-request')
print('\n'.join(changes))
if INSPECT:
    sys.exit(0)

os.makedirs(OUT, exist_ok=True)
NAME = os.path.join(OUT, 'dp200_klipper_payload.tar.gz')
dst = tarfile.open(NAME, 'w:gz', format=tarfile.GNU_FORMAT, compresslevel=9)
done = set()


def put(n, data, mode, ref):
    ti = tarfile.TarInfo(n)
    ti.size, ti.mode, ti.mtime = len(data), mode, NOW
    ti.uid, ti.gid, ti.uname, ti.gname = ref.uid, ref.gid, ref.uname, ref.gname
    dst.addfile(ti, io.BytesIO(data))


def put_link(n, target):
    ti = tarfile.TarInfo(n)
    ti.type, ti.linkname, ti.mode, ti.mtime = tarfile.SYMTYPE, target, 0o777, NOW
    ti.uid, ti.gid, ti.uname, ti.gname = ref_root.uid, ref_root.gid, ref_root.uname, ref_root.gname
    dst.addfile(ti)


def add_missing_under(prefix):
    for n in sorted(new):
        if n not in done and n.startswith(prefix):
            put(n, *new[n]); done.add(n)
    for n in sorted(links):
        if n not in done and n.startswith(prefix):
            put_link(n, links[n]); done.add(n)


dirs = [m.name for m in members if m.isdir()]
for m in members:
    if m.name in done:
        # already written right after its directory (below): writing it
        # again made every replaced file appear twice (e5a4dd83, 11-25)
        continue
    if m.name in new:
        put(m.name, *new[m.name]); done.add(m.name)
    elif m.name in links:
        put_link(m.name, links[m.name]); done.add(m.name)
    elif m.isfile():
        dst.addfile(m, src.extractfile(m))
    else:
        dst.addfile(m)
    if m.isdir():
        # new files go right after their directory's entry
        for n in sorted(set(new) | set(links)):
            if n not in done and os.path.dirname(n) == m.name.rstrip('/'):
                if n in new:
                    put(n, *new[n])
                else:
                    put_link(n, links[n])
                done.add(n)
left = (set(new) | set(links)) - done
assert not left, left
dst.close()

h = hashlib.md5(open(NAME, 'rb').read()).hexdigest()
open(NAME + '.md5', 'w', newline='\n').write('%s  dp200_klipper_payload.tar.gz\n' % h)
t = tarfile.open(NAME, 'r:gz')
size = sum(m.size for m in t.getmembers())
open(NAME + '.size', 'w', newline='\n').write('%d\n' % (size // 1024))
# no SSH keys of any kind (as make_payload.sh)
import re
bad = [m.name for m in t.getmembers()
       if re.search(r'(^|/)(\.ssh/|authorized_keys|ssh_host_|dropbear_.*_host_key)', m.name)]
assert not bad, bad
print('payload', os.path.getsize(NAME), 'bytes, md5', h, 'unpacked', size // 1024, 'KiB,',
      len(t.getmembers()), 'members')
