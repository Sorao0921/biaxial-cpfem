"""Place the two standalone Windows runner files next to diamond decks."""
from pathlib import Path
import argparse
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from src.config.diamond_cases import OUTPUT_DIR
from src.make_model_process.keyword_output import check_output, write_output

BUNDLE_DIR = ROOT / 'external/diamond_runner'
RUNNER_FILES = ('prepare.ps1', 'RUN_ALL.bat')


def runner_payload(source, target):
    payload = source.read_bytes()
    if source.name == 'RUN_ALL.bat' and target.is_file():
        # Keep solver settings edited on the analysis machine when updating code.
        existing = target.read_text(encoding='utf-8')
        settings = dict(re.findall(r'^set "(DIAMOND_(?:SOLVER|NCPU|MEMORY))=(.*)"$', existing, re.M))
        if settings:
            text = payload.decode('utf-8').replace('\r\n', '\n')
            for key, value in settings.items():
                text = re.sub(r'^set "' + key + r'=.*"$', lambda _: f'set "{key}={value}"', text, flags=re.M)
            payload = text.replace('\n', '\r\n').encode('utf-8')
    return payload


def deploy_runner(output_dir=OUTPUT_DIR, overwrite=False):
    output_dir = Path(output_dir)
    prepared = []
    for name in RUNNER_FILES:
        source = BUNDLE_DIR / name
        target = output_dir / name
        payload = runner_payload(source, target)
        check_output(target, payload, overwrite=overwrite, reuse_existing=True)
        prepared.append((target, payload))
    for target, payload in prepared:
        write_output(target, payload, overwrite=overwrite, reuse_existing=True)
    return [p for p, _ in prepared]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=OUTPUT_DIR)
    parser.add_argument('--overwrite', action='store_true')
    args = parser.parse_args(argv)
    files = deploy_runner(args.output_dir, args.overwrite)
    print(f'Deployed {len(files)} Windows runner files to {args.output_dir}')


if __name__ == '__main__':
    main()
