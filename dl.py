import urllib.request, hashlib, os, time, sys

VER = "6.17.13"
BASES = [
    "https://mirrors.edge.kernel.org/pub/linux/kernel/v6.x",
    "https://cdn.kernel.org/pub/linux/kernel/v6.x",
]
NAME = "linux-%s.tar.xz" % VER
DEST = "/home/sogohimo/mb81-fix/src/" + NAME

def http(url, headers=None):
    h = {"User-Agent": "kernel-dl/1.0"}
    if headers:
        h.update(headers)
    return urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=90)

sha = None
for base in BASES:
    try:
        d = http(base + "/sha256sums.asc").read().decode(errors="replace")
        for line in d.splitlines():
            p = line.split()
            if len(p) >= 2 and p[1] == NAME:
                sha = p[0]
                break
        if sha:
            break
    except Exception as e:
        print("sha fetch fail", base, type(e).__name__, e, flush=True)
if not sha:
    print("FATAL: no target sha", flush=True)
    sys.exit(1)
print("TARGET_SHA", sha, flush=True)

def download_once(base):
    start = os.path.getsize(DEST) if os.path.exists(DEST) else 0
    r = http(base + "/" + NAME, {"Range": "bytes=%d-" % start})
    code = r.status
    if code == 200:
        start = 0
    mode = "ab" if (code == 206 and start > 0) else "wb"
    total = int(r.headers.get("Content-Length", 0) or 0)
    denom = (start + total) if total else 0
    got = 0
    t0 = time.time()
    last = -1
    with open(DEST, mode) as f:
        while True:
            b = r.read(1 << 20)
            if not b:
                break
            f.write(b)
            got += len(b)
            step = got >> 18
            if step != last:
                last = step
                pct = 100.0 * (start + got) / denom if denom else 0
                dt = time.time() - t0
                sp = got / dt / 1024 if dt > 0 else 0
                print("  %dKB (%.1f%%) %.0f KB/s" % (got // 1024, pct, sp), flush=True)
    return start, got

attempt = 0
while True:
    attempt += 1
    ok = False
    for base in BASES:
        try:
            print("[attempt %d] %s start" % (attempt, base), flush=True)
            s, g = download_once(base)
            print("[attempt %d] base done got=%d start=%d" % (attempt, g, s), flush=True)
            ok = True
            break
        except Exception as e:
            print("[attempt %d] %s FAIL %s: %s" % (attempt, base, type(e).__name__, e), flush=True)
    if not ok:
        print("all bases failed, retry in 5s", flush=True)
        time.sleep(5)
        continue
    h = hashlib.sha256(open(DEST, "rb").read()).hexdigest()
    print("want", sha, flush=True)
    print("got ", h, flush=True)
    if h == sha:
        print("SHA256 OK", flush=True)
        break
    print("SHA mismatch, deleting & retrying", flush=True)
    os.remove(DEST)

print("DOWNLOAD_COMPLETE", flush=True)
