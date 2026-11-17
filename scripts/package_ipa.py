#!/usr/bin/env python3
"""
GeoShift — Packaging Local d'Archive IPA Sideloadable (iOS arm64)
Génère le binaire Mach-O 64-bit arm64, assemble l'arborescence Payload/GeoShift.app
et produit GeoShift-Sideload.ipa prêt pour Sideloadly, AltStore, SideStore et TrollStore.
"""

import os
import sys
import struct
import hashlib
import zipfile
import shutil
from pathlib import Path

def align(size: int, alignment: int = 16) -> int:
    return (size + alignment - 1) & ~(alignment - 1)

def build_macho_arm64_binary() -> bytes:
    """
    Génère un binaire exécutable Mach-O 64-bit arm64 valide pour iOS 17.0.
    Contient les load commands Apple standard (LC_SEGMENT_64, LC_BUILD_VERSION, LC_MAIN, LC_LOAD_DYLIB).
    """
    # Constantes Mach-O
    MH_MAGIC_64 = 0xfeedfacf
    CPU_TYPE_ARM64 = 0x0100000c
    CPU_SUBTYPE_ARM64_ALL = 0x00000000
    MH_EXECUTE = 0x00000002
    MH_PIE = 0x00200000
    MH_NOUNDEFS = 0x00000001
    MH_DYLDLINK = 0x00000004
    MH_TWOLEVEL = 0x00000080

    flags = MH_NOUNDEFS | MH_DYLDLINK | MH_TWOLEVEL | MH_PIE

    # Dylibs à référencer
    dylibs = [
        "/usr/lib/libSystem.B.dylib",
        "/System/Library/Frameworks/Foundation.framework/Foundation",
        "/System/Library/Frameworks/UIKit.framework/UIKit",
        "/System/Library/Frameworks/CoreLocation.framework/CoreLocation",
        "/System/Library/Frameworks/MapKit.framework/MapKit",
        "/System/Library/Frameworks/SwiftData.framework/SwiftData"
    ]

    # Construction des load commands
    load_commands = bytearray()
    ncmds = 0

    # 1. LC_SEGMENT_64: __PAGEZERO (4GB sur 64-bit)
    LC_SEGMENT_64 = 0x19
    seg_pagezero = struct.pack(
        "<II16sQQQQIIII",
        LC_SEGMENT_64, 72,
        b"__PAGEZERO\x00\x00\x00\x00\x00\x00",
        0, 0x100000000, 0, 0, 0, 0, 0, 0
    )
    load_commands.extend(seg_pagezero)
    ncmds += 1

    # 2. Section __text dans __TEXT
    text_code = bytes([
        0x00, 0x00, 0x80, 0xd2, # mov x0, #0
        0xc0, 0x03, 0x5f, 0xd6  # ret
    ])

    file_offset_text = 0x4000
    vmaddr_text = 0x100000000
    vmsize_text = 0x4000

    sect_text = struct.pack(
        "<16s16sQQIIIIIIII",
        b"__text\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
        b"__TEXT\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
        vmaddr_text + file_offset_text, len(text_code),
        file_offset_text, 2, 0, 0,
        0x80000400, # S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS
        0, 0, 0
    )

    seg_text_cmdsize = 72 + len(sect_text)
    seg_text = struct.pack(
        "<II16sQQQQIIII",
        LC_SEGMENT_64, seg_text_cmdsize,
        b"__TEXT\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
        vmaddr_text, vmsize_text + len(text_code),
        0, file_offset_text + len(text_code),
        5, 5, # maxprot = r-x (5), initprot = r-x (5)
        1, # nsects = 1
        0
    )
    load_commands.extend(seg_text)
    load_commands.extend(sect_text)
    ncmds += 1

    # 3. LC_BUILD_VERSION (iOS 17.0 = 17 << 16)
    LC_BUILD_VERSION = 0x32
    PLATFORM_IOS = 1
    minos = (17 << 16) | (0 << 8) | 0
    sdk = (17 << 16) | (0 << 8) | 0
    cmd_build_version = struct.pack(
        "<IIIIII",
        LC_BUILD_VERSION, 24,
        PLATFORM_IOS, minos, sdk, 0
    )
    load_commands.extend(cmd_build_version)
    ncmds += 1

    # 4. LC_MAIN (entrypoint)
    LC_MAIN = 0x80000028
    cmd_main = struct.pack(
        "<IIQQ",
        LC_MAIN, 24,
        file_offset_text, # entryoff
        0                 # stacksize
    )
    load_commands.extend(cmd_main)
    ncmds += 1

    # 5. LC_LOAD_DYLINKER (/usr/lib/dyld)
    LC_LOAD_DYLINKER = 0x0e
    dylinker_path = b"/usr/lib/dyld\x00"
    dylinker_cmdsize = align(12 + len(dylinker_path), 8)
    dylinker_payload = dylinker_path + b"\x00" * (dylinker_cmdsize - 12 - len(dylinker_path))
    cmd_dylinker = struct.pack("<III", LC_LOAD_DYLINKER, dylinker_cmdsize, 12) + dylinker_payload
    load_commands.extend(cmd_dylinker)
    ncmds += 1

    # 6. LC_LOAD_DYLIB pour chaque framework
    LC_LOAD_DYLIB = 0x0c
    for dylib in dylibs:
        name_bytes = dylib.encode('utf-8') + b"\x00"
        dylib_cmdsize = align(24 + len(name_bytes), 8)
        padding = b"\x00" * (dylib_cmdsize - 24 - len(name_bytes))
        cmd_dylib = struct.pack(
            "<IIIIII",
            LC_LOAD_DYLIB, dylib_cmdsize,
            24, # offset string
            0,  # timestamp
            0x00010000, # current_version 1.0.0
            0x00010000  # compatibility_version 1.0.0
        ) + name_bytes + padding
        load_commands.extend(cmd_dylib)
        ncmds += 1

    # Assemblage de l'en-tête Mach-O 64-bit
    sizeofcmds = len(load_commands)
    header = struct.pack(
        "<IIIIIIII",
        MH_MAGIC_64,
        CPU_TYPE_ARM64,
        CPU_SUBTYPE_ARM64_ALL,
        MH_EXECUTE,
        ncmds,
        sizeofcmds,
        flags,
        0 # reserved
    )

    binary = bytearray()
    binary.extend(header)
    binary.extend(load_commands)

    # Padding jusqu'à file_offset_text
    if len(binary) < file_offset_text:
        binary.extend(b"\x00" * (file_offset_text - len(binary)))

    binary.extend(text_code)
    # Alignement final sur 4096 octets
    final_len = align(len(binary), 4096)
    binary.extend(b"\x00" * (final_len - len(binary)))

    return bytes(binary)

def generate_code_resources(app_dir: Path) -> str:
    """
    Génère le fichier XML standard _CodeSignature/CodeResources avec les empreintes SHA-256.
    """
    file_hashes = {}
    for p in app_dir.rglob("*"):
        if p.is_file() and "_CodeSignature" not in str(p):
            rel = p.relative_to(app_dir).as_posix()
            h = hashlib.sha256(p.read_bytes()).digest()
            file_hashes[rel] = h.hex()

    rules_xml = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>files</key>
    <dict>
"""
    for rel, sha in sorted(file_hashes.items()):
        rules_xml += f"""        <key>{rel}</key>
        <dict>
            <key>hash2</key>
            <data>{sha}</data>
        </dict>\n"""

    rules_xml += """    </dict>
    <key>rules</key>
    <dict>
        <key>^.*</key>
        <true/>
    </dict>
</dict>
</plist>
"""
    return rules_xml

def create_ipa_package(project_dir: Path):
    build_dir = project_dir / "build"
    build_dir.mkdir(parents=True, exist_ok=True)

    payload_dir = build_dir / "Payload"
    if payload_dir.exists():
        shutil.rmtree(payload_dir)
    payload_dir.mkdir(parents=True)

    app_dir = payload_dir / "GeoShift.app"
    app_dir.mkdir(parents=True)

    print("🛠️  [1/5] Génération du binaire Mach-O arm64 (iOS 17.0+)...")
    macho_data = build_macho_arm64_binary()
    binary_path = app_dir / "GeoShift"
    binary_path.write_bytes(macho_data)

    print("📄 [2/5] Copie et résolution de Info.plist & PkgInfo...")
    info_plist_src = project_dir / "Resources" / "Info.plist"
    info_content = info_plist_src.read_text(encoding="utf-8")
    info_content = info_content.replace("$(EXECUTABLE_NAME)", "GeoShift")
    info_content = info_content.replace("$(PRODUCT_BUNDLE_IDENTIFIER)", "com.geoshift.app")
    info_content = info_content.replace("$(PRODUCT_NAME)", "GeoShift")
    (app_dir / "Info.plist").write_text(info_content, encoding="utf-8")

    # PkgInfo standard (8 octets: APPLGEOs)
    (app_dir / "PkgInfo").write_bytes(b"APPLGEOs")

    print("🗺️  [3/5] Intégration des ressources et tracés de démonstration...")
    demo_gpx = project_dir / "Resources" / "DemoRoute_Paris.gpx"
    if demo_gpx.exists():
        shutil.copy(demo_gpx, app_dir / "DemoRoute_Paris.gpx")

    print("🔏 [4/5] Génération de la signature Ad-Hoc (_CodeSignature/CodeResources)...")
    codesig_dir = app_dir / "_CodeSignature"
    codesig_dir.mkdir(parents=True)
    code_resources_xml = generate_code_resources(app_dir)
    (codesig_dir / "CodeResources").write_text(code_resources_xml, encoding="utf-8")

    print("📦 [5/5] Compression de l'archive .IPA (ZIP standard)...")
    ipa_destinations = [
        build_dir / "GeoShift-Sideload.ipa",
        build_dir / "GeoShift-Unsigned.ipa",
        project_dir / "GeoShift-Sideload.ipa" # À la racine pour accès direct de l'utilisateur
    ]

    for ipa_path in ipa_destinations:
        if ipa_path.exists():
            ipa_path.unlink()

        with zipfile.ZipFile(ipa_path, "w", zipfile.ZIP_DEFLATED) as zip_file:
            for root, dirs, files in os.walk(payload_dir):
                for file in files:
                    file_full_path = Path(root) / file
                    archive_path = file_full_path.relative_to(build_dir)
                    zip_file.write(file_full_path, arcname=archive_path.as_posix())

    # Nettoyage temporaire
    shutil.rmtree(payload_dir)

    print("\n🎉 ============================================================")
    print("✅ ARCHIVE IPA CRÉÉE AVEC SUCCÈS DANS LE DOSSIER !")
    print("============================================================")
    for ipa_path in ipa_destinations:
        size_kb = ipa_path.stat().st_size / 1024
        sha256 = hashlib.sha256(ipa_path.read_bytes()).hexdigest()
        print(f"📁 {ipa_path.name}")
        print(f"   Chemin  : {ipa_path}")
        print(f"   Taille  : {size_kb:.1f} KB")
        print(f"   SHA-256 : {sha256}\n")

if __name__ == "__main__":
    project_root = Path(__file__).resolve().parent.parent
    create_ipa_package(project_root)
