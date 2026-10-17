#!/usr/bin/env python3
"""Keep only the named animation clips in a .glb and drop the binary data nothing uses.

    tools/trim_glb.py <in.glb> <out.glb> <clip> [<clip> ...]

Mesh, skin, texture and node data are copied byte for byte; only the animations not named
are removed, and the accessors and buffer views that only they referenced go with them.
Prints the clips kept and the size before and after.
"""
import json
import struct
import sys


def read_glb(path):
    data = open(path, "rb").read()
    magic, version, length = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67 and version == 2, "not a glb 2.0 file"
    offset = 12
    doc = None
    blob = b""
    while offset < length:
        chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
        payload = data[offset + 8:offset + 8 + chunk_len]
        if chunk_type == 0x4E4F534A:
            doc = json.loads(payload)
        elif chunk_type == 0x004E4942:
            blob = payload
        offset += 8 + chunk_len
    return doc, blob


def write_glb(path, doc, blob):
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * ((4 - len(text) % 4) % 4)
    blob += b"\0" * ((4 - len(blob) % 4) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(text) + 8 + len(blob))
    out += struct.pack("<II", len(text), 0x4E4F534A) + text
    out += struct.pack("<II", len(blob), 0x004E4942) + blob
    open(path, "wb").write(out)


def trim(doc, blob, keep):
    doc["animations"] = [a for a in doc.get("animations", []) if a["name"] in keep]
    used_accessors = set()
    for mesh in doc.get("meshes", []):
        for prim in mesh["primitives"]:
            used_accessors.update(prim["attributes"].values())
            if "indices" in prim:
                used_accessors.add(prim["indices"])
            for target in prim.get("targets", []):
                used_accessors.update(target.values())
    for skin in doc.get("skins", []):
        if "inverseBindMatrices" in skin:
            used_accessors.add(skin["inverseBindMatrices"])
    for anim in doc["animations"]:
        for sampler in anim["samplers"]:
            used_accessors.add(sampler["input"])
            used_accessors.add(sampler["output"])
    used_views = set()
    for i in sorted(used_accessors):
        acc = doc["accessors"][i]
        if "bufferView" in acc:
            used_views.add(acc["bufferView"])
        sparse = acc.get("sparse")
        if sparse:
            used_views.add(sparse["indices"]["bufferView"])
            used_views.add(sparse["values"]["bufferView"])
    for image in doc.get("images", []):
        if "bufferView" in image:
            used_views.add(image["bufferView"])
    # Rebuild the buffer from the views still in use, 4-byte aligned, and renumber.
    view_map = {}
    new_views = []
    new_blob = bytearray()
    for i in sorted(used_views):
        view = dict(doc["bufferViews"][i])
        start = view.get("byteOffset", 0)
        chunk = blob[start:start + view["byteLength"]]
        new_blob += b"\0" * ((4 - len(new_blob) % 4) % 4)
        view["byteOffset"] = len(new_blob)
        view["buffer"] = 0
        new_blob += chunk
        view_map[i] = len(new_views)
        new_views.append(view)
    acc_map = {}
    new_accessors = []
    for i in sorted(used_accessors):
        acc = dict(doc["accessors"][i])
        if "bufferView" in acc:
            acc["bufferView"] = view_map[acc["bufferView"]]
        if acc.get("sparse"):
            acc["sparse"] = json.loads(json.dumps(acc["sparse"]))
            acc["sparse"]["indices"]["bufferView"] = view_map[acc["sparse"]["indices"]["bufferView"]]
            acc["sparse"]["values"]["bufferView"] = view_map[acc["sparse"]["values"]["bufferView"]]
        acc_map[i] = len(new_accessors)
        new_accessors.append(acc)
    for mesh in doc.get("meshes", []):
        for prim in mesh["primitives"]:
            prim["attributes"] = {k: acc_map[v] for k, v in prim["attributes"].items()}
            if "indices" in prim:
                prim["indices"] = acc_map[prim["indices"]]
            prim["targets"] = [{k: acc_map[v] for k, v in t.items()} for t in prim.get("targets", [])] or prim.get("targets", [])
            if not prim.get("targets"):
                prim.pop("targets", None)
    for skin in doc.get("skins", []):
        if "inverseBindMatrices" in skin:
            skin["inverseBindMatrices"] = acc_map[skin["inverseBindMatrices"]]
    for anim in doc["animations"]:
        for sampler in anim["samplers"]:
            sampler["input"] = acc_map[sampler["input"]]
            sampler["output"] = acc_map[sampler["output"]]
    for image in doc.get("images", []):
        if "bufferView" in image:
            image["bufferView"] = view_map[image["bufferView"]]
    doc["bufferViews"] = new_views
    doc["accessors"] = new_accessors
    doc["buffers"] = [{"byteLength": len(new_blob)}]
    return doc, bytes(new_blob)


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(2)
    src, dst, keep = sys.argv[1], sys.argv[2], sys.argv[3:]
    doc, blob = read_glb(src)
    have = {a["name"] for a in doc.get("animations", [])}
    missing = [k for k in keep if k not in have]
    if missing:
        print("missing clips: " + ", ".join(missing))
        sys.exit(1)
    before = 12 + len(blob)
    doc, blob = trim(doc, blob, set(keep))
    write_glb(dst, doc, blob)
    import os
    print("kept %d clips: %s" % (len(doc["animations"]), ", ".join(a["name"] for a in doc["animations"])))
    print("%s: %.2f MB -> %.2f MB" % (dst, os.path.getsize(src) / 1e6, os.path.getsize(dst) / 1e6))


if __name__ == "__main__":
    main()
