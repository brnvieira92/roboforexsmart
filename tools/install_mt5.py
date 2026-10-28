"""Install a verified, matching EA source bundle into an existing MT5 Data Folder.

Usage: py tools/install_mt5.py "C:\\path\\shown-by-MT5-Open-Data-Folder"
Does not compile, start MT5, change credentials, or enable trading.
"""
import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import shutil

BUNDLE = Path(__file__).resolve().parents[1] / 'mt5'


def verified_sources(bundle=BUNDLE):
    bundle = Path(bundle)
    manifest = json.loads((bundle / 'manifest.json').read_text(encoding='utf-8'))
    expected = {'ForexSmart.mq5', *(p.relative_to(bundle).as_posix() for p in (bundle / 'Include').glob('*.mqh'))}
    if set(manifest['files']) != expected:
        raise ValueError('Incomplete source manifest; update the whole Git checkout')
    sources = {}
    for relative, digest in manifest['files'].items():
        path = Path(relative)
        if path.is_absolute() or '..' in path.parts:
            raise ValueError('Unsafe manifest path')
        content = (bundle / path).read_bytes()
        if hashlib.sha256(content).hexdigest() != digest:
            raise ValueError(f'Bundle mismatch: {relative}; update the whole Git checkout')
        sources[path] = content
    return manifest['version'], sources


def install(data_folder, bundle=BUNDLE):
    version, sources = verified_sources(bundle)
    data_folder = Path(data_folder).resolve()
    if not (data_folder / 'MQL5').is_dir():
        raise ValueError('Select the Data Folder containing MQL5, not the project or Experts folder')
    target = data_folder / 'MQL5' / 'Experts'
    backup = data_folder / 'ForexSmart-backups' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup.mkdir(parents=True, exist_ok=False)
    originals = {}
    for relative in sources:
        destination = target / relative
        originals[relative] = destination.read_bytes() if destination.exists() else None
        if destination.exists():
            saved = backup / relative
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(destination, saved)
    compiled = target / 'ForexSmart.ex5'
    if compiled.exists():
        shutil.copy2(compiled, backup / compiled.name)
    try:
        for relative, content in sources.items():
            destination = target / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(content)
        for relative, content in sources.items():
            if (target / relative).read_bytes() != content:
                raise OSError(f'Installed file mismatch: {relative}')
    except Exception:
        for relative, content in originals.items():
            destination = target / relative
            if content is None:
                destination.unlink(missing_ok=True)
            else:
                destination.write_bytes(content)
        raise
    return version, len(sources), backup


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('data_folder', type=Path)
    args = parser.parse_args()
    version, count, backup = install(args.data_folder)
    print(f'Installed verified source bundle v{version}: {count} files.')
    print(f'Backup: {backup}')
    print('Compile MQL5/Experts/ForexSmart.mq5 with F7. Compilation was NOT performed.')
