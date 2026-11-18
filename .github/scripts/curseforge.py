"""Builds the addon zip and uploads it to CurseForge (used by .github/workflows/curseforge.yml).

  python .github/scripts/curseforge.py zip <out_dir>
      Builds "<Addon> <Version>.zip" the same way package.ps1 does: the addon folder
      (with the root CHANGELOG.md copied in) plus the BleakfibersQuestTracker-Forever
      legacy stub folder. Prints the zip path.

  python .github/scripts/curseforge.py upload <zip>
      Uploads the zip. Environment:
        CURSEFORGE_TOKEN    API token (CurseForge > Authors > My API Tokens)
        CHANGELOG_FILE      release notes (Markdown); when empty, the version's CHANGELOG.md section is used
        TAG                 the release tag; must match the .toc version (v1.3.3 for 1.3.3)
        RELEASE_TYPE        release | beta | alpha (default release)
        CURSEFORGE_DRY_RUN  "1": check the token, project and game version, upload nothing

The CurseForge project ID comes from "## X-Curse-Project-ID:" in the addon's .toc.
The game version is the CurseForge "Forever" version matching the .toc Interface
(16001 -> 1.60.1), or the newest Forever version when CurseForge hasn't listed that one yet.
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADDON = "NullgatesQuestTracker-Forever"
LEGACY = "BleakfibersQuestTracker-Forever"
API = "https://wow.curseforge.com/api"


def fail(msg):
    print("::error::" + msg)
    sys.exit(1)


def toc_field(name):
    with open(os.path.join(ROOT, ADDON, ADDON + ".toc"), encoding="utf-8-sig") as f:
        m = re.search(r"^## %s:\s*(.+?)\s*$" % re.escape(name), f.read(), re.M)
    return m.group(1) if m else None


def changelog_section(version):
    with open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8") as f:
        text = f.read()
    m = re.search(r"^## \[%s\].*?(?=^## \[|\Z)" % re.escape(version), text, re.M | re.S)
    return m.group(0).strip() if m else ""


def add_folder(zf, folder):
    base = os.path.join(ROOT, folder)
    for dirpath, _, files in os.walk(base):
        for name in sorted(files):
            path = os.path.join(dirpath, name)
            zf.write(path, os.path.relpath(path, ROOT).replace(os.sep, "/"))


def build_zip(out_dir):
    version = toc_field("Version") or fail("No '## Version:' in the .toc")
    os.makedirs(out_dir, exist_ok=True)
    zip_path = os.path.join(out_dir, "%s %s.zip" % (ADDON, version))
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        add_folder(zf, ADDON)
        zf.write(os.path.join(ROOT, "CHANGELOG.md"), ADDON + "/CHANGELOG.md")
        if os.path.isfile(os.path.join(ROOT, LEGACY, LEGACY + ".toc")):
            add_folder(zf, LEGACY)
    print(zip_path)


def request(path, token, data=None, content_type=None):
    req = urllib.request.Request(API + path, data=data, headers={"X-Api-Token": token})
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read().decode("utf-8") or "null")
    except urllib.error.HTTPError as e:
        fail("CurseForge %s returned %d: %s" % (path, e.code, e.read().decode("utf-8", "replace")[:500]))


def interface_version():
    n = int(toc_field("Interface") or fail("No '## Interface:' in the .toc"))
    return "%d.%d.%d" % (n // 10000, (n // 100) % 100, n % 100)


def pick_game_version(token):
    types = [t for t in request("/game/version-types", token)
             if "forever" in (t.get("name", "") + " " + t.get("slug", "")).lower()]
    if not types:
        fail("CurseForge lists no 'Forever' game version type")
    type_ids = {t["id"] for t in types}
    versions = [v for v in request("/game/versions", token) if v.get("gameVersionTypeID") in type_ids]
    if not versions:
        fail("CurseForge lists no versions for the Forever game version type")
    wanted = interface_version()
    exact = [v for v in versions if v.get("name") == wanted]
    if exact:
        return exact[0]
    newest = max(versions, key=lambda v: [int(x) for x in re.findall(r"\d+", v.get("name", "0"))] or [0])
    print("::warning::CurseForge has no Forever version %s yet; using the newest, %s" % (wanted, newest["name"]))
    return newest


def multipart(fields, file_field, file_path):
    boundary = uuid.uuid4().hex
    parts = []
    for name, value in fields.items():
        parts.append(('--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n'
                      % (boundary, name, value)).encode("utf-8"))
    with open(file_path, "rb") as f:
        payload = f.read()
    parts.append(('--%s\r\nContent-Disposition: form-data; name="%s"; filename="%s"\r\n'
                  'Content-Type: application/zip\r\n\r\n' % (boundary, file_field, os.path.basename(file_path))).encode("utf-8"))
    parts.append(payload + b"\r\n")
    parts.append(("--%s--\r\n" % boundary).encode("utf-8"))
    return b"".join(parts), "multipart/form-data; boundary=" + boundary


def upload(zip_path):
    token = os.environ.get("CURSEFORGE_TOKEN") or fail("Add the repository secret CURSEFORGE_TOKEN (a CurseForge API token).")
    project = toc_field("X-Curse-Project-ID") or fail("Add '## X-Curse-Project-ID: <id>' to the .toc.")
    version = toc_field("Version")
    dry_run = os.environ.get("CURSEFORGE_DRY_RUN") == "1"
    tag = os.environ.get("TAG", "")
    if not dry_run and tag.lstrip("vV") != version:
        fail("Tag %s does not match the .toc version %s" % (tag, version))
    if not os.path.isfile(zip_path):
        fail("No zip at " + zip_path)

    notes = ""
    if os.environ.get("CHANGELOG_FILE") and os.path.isfile(os.environ["CHANGELOG_FILE"]):
        with open(os.environ["CHANGELOG_FILE"], encoding="utf-8") as f:
            notes = f.read().strip()
    notes = notes or changelog_section(version) or dry_run and "(dry run)" or fail("No release notes and no [%s] section in CHANGELOG.md" % version)

    game_version = pick_game_version(token)
    metadata = {
        "changelog": notes,
        "changelogType": "markdown",
        "displayName": "%s %s" % (ADDON, version),
        "gameVersions": [game_version["id"]],
        "releaseType": os.environ.get("RELEASE_TYPE") or "release",
    }
    print("Project %s, game version %s (id %s), %s" % (project, game_version["name"], game_version["id"], metadata["releaseType"]))
    if dry_run:
        print("Dry run: token, project and game version are fine; nothing uploaded.")
        return
    body, content_type = multipart({"metadata": json.dumps(metadata)}, "file", zip_path)
    result = request("/projects/%s/upload-file" % project, token, body, content_type)
    print("Uploaded file id %s" % (result or {}).get("id"))


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "zip":
        build_zip(sys.argv[2])
    elif len(sys.argv) == 3 and sys.argv[1] == "upload":
        upload(sys.argv[2])
    else:
        fail(__doc__)
