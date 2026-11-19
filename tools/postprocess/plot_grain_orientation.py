"""Plot saved grain rotation/GOS means and mean +/- population standard deviation bands against eps_eq.

Run from pipeline: python -m tools.postprocess.plot_grain_orientation
Each PNG contains five textures x two metrics; separate PNGs for each seed/sd.
No orientation recalculation, PDF, or intermediate summary files are required.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.ticker import MaxNLocator, FormatStrFormatter
import numpy as np
import pandas as pd

PIPELINE = Path(__file__).resolve().parents[2]
TEXTURES = ('cube', 'goss', 'brass', 'copper', 's')
METRICS = ('grain_rotation_deg', 'gos_deg')
COLORS = {-0.5: '#4477AA', 0.0: '#BB8800', 0.5: '#CC6677', 1.0: '#228877'}
STYLES = {-0.5: ('-', 'o'), 0.0: ('--', 's'), 0.5: ('-.', '^'), 1.0: (':', 'D')}
PATTERN = re.compile(r'grain_metrics_(cube|goss|brass|copper|s)_sd(\d+)_seed(\d+)_state(\d+)_to_state(\d+)\.csv')


def load_summary(root, seeds, spreads, rhos):
    rows = []
    seen = set()
    for rho in rhos:
        for seed in seeds:
            base = root / f'rho_{rho:g}' / f'rho_{rho:g}_seed{seed}'
            strain_path = base / 'eps_equivalent.csv'
            strain = pd.read_csv(strain_path, encoding='utf-8-sig')
            strain.columns = strain.columns.str.strip().str.lower()
            eps = pd.to_numeric(strain['eps_eq'], errors='raise').to_numpy(float)
            if len(eps) < 13 or not np.isfinite(eps).all() or (eps < 0).any() or (np.diff(eps) <= 0).any():
                raise ValueError(f'Invalid strain mapping: {strain_path}')
            # Saved data row 1 is state01, including its initial zero value.
            for path in sorted((base / 'angles' / 'grain_orientation_metrics').rglob('*.csv')):
                match = PATTERN.fullmatch(path.name)
                if not match:
                    continue
                texture, sd, file_seed, ref, state = match.groups()
                sd, file_seed, ref, state = map(int, (sd, file_seed, ref, state))
                if sd not in spreads or state not in range(2, 14) or ref != 1:
                    continue
                if file_seed != seed:
                    raise ValueError(f'Seed mismatch: {path}')
                key = (sd, seed, texture, state, rho)
                if key in seen:
                    raise ValueError(f'Duplicate condition: {path}')
                seen.add(key)
                frame = pd.read_csv(path, usecols=['part_id', 'reference_state', 'target_state', *METRICS])
                if (frame.empty or frame.part_id.isna().any() or frame.part_id.duplicated().any()
                        or not frame.reference_state.eq(1).all() or not frame.target_state.eq(state).all()
                        or not np.isfinite(frame[list(METRICS)].to_numpy(float)).all()
                        or (frame[list(METRICS)] < 0).any().any()):
                    raise ValueError(f'Invalid grain metrics: {path}')
                for metric in METRICS:
                    values = frame[metric].to_numpy(float)
                    mean = np.mean(values)
                    std = np.std(values, ddof=0)
                    rows.append(dict(sd=sd, seed=seed, texture=texture, state=state, rho=rho,
                                     metric=metric, eps_eq=eps[state - 1], n=len(frame),
                                     mean=mean, std=std, lower=mean - std, upper=mean + std))
    expected = {(sd, seed, tex, state, rho) for sd in spreads for seed in seeds
                for tex in TEXTURES for state in range(2, 14) for rho in rhos}
    missing = expected - seen
    if missing:
        raise ValueError(f'{len(missing)} missing conditions; examples: {sorted(missing)[:5]}')
    return pd.DataFrame(rows)


def render(data, destination, seeds, spreads, rhos, dpi):
    plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 10, 'axes.titlesize': 14})
    limits = {m: (min(0.0, data.loc[data.metric.eq(m), 'lower'].min() * 1.08),
                  data.loc[data.metric.eq(m), 'upper'].max() * 1.08) for m in METRICS}
    xmax = data.eps_eq.max()
    for seed in seeds:
        for sd in spreads:
            selected = data[data.seed.eq(seed) & data.sd.eq(sd)]
            fig, axes = plt.subplots(5, 2, figsize=(15, 14), sharex=True, sharey='col')
            try:
                fig.subplots_adjust(left=.08, right=.98, bottom=.085, top=.875, hspace=.28, wspace=.13)
                for i, texture in enumerate(TEXTURES):
                    for j, metric in enumerate(METRICS):
                        ax = axes[i, j]
                        for rho in rhos:
                            g = selected[selected.texture.eq(texture) & selected.metric.eq(metric)
                                         & selected.rho.eq(rho)].sort_values('state')
                            x = g.eps_eq.to_numpy()
                            linestyle, marker = STYLES[rho]
                            ax.fill_between(x, g.lower.to_numpy(), g.upper.to_numpy(), color=COLORS[rho], alpha=.13, linewidth=0)
                            ax.plot(x, g['mean'], color=COLORS[rho], linestyle=linestyle,
                                    marker=marker, markersize=3, linewidth=1.4)
                        ax.set_ylim(*limits[metric]); ax.set_xlim(0, xmax * 1.025)
                        ax.xaxis.set_major_locator(MaxNLocator(6))
                        ax.xaxis.set_major_formatter(FormatStrFormatter('%.2f'))
                        ax.grid(axis='y', color='#e3e5e8', linewidth=.6); ax.set_axisbelow(True)
                        ax.spines[['top', 'right']].set_visible(False)
                        ax.tick_params(axis='x', labelbottom=True, labelsize=9)
                        if j == 0:
                            ax.set_ylabel(texture.capitalize() + '\nAngle (deg)', fontsize=11, labelpad=11)
                        if i == 0:
                            ax.set_title(('Grain Rotation (relative to state 01)', 'GOS (current state)')[j], pad=13, fontweight='bold')
                        if i == 4:
                            ax.set_xlabel(r'Equivalent plastic strain $\varepsilon_{eq}^{p}$ (–)', fontsize=11)
                fig.suptitle(f'Grain Rotation and GOS | Initial spread = {sd} deg | Seed {seed}', y=.972, fontsize=18, fontweight='bold')
                handles = [Line2D([0], [0], color=COLORS[r], ls=STYLES[r][0], marker=STYLES[r][1], label=f'rho = {r:g}') for r in rhos]
                fig.legend(handles=handles, loc='upper center', bbox_to_anchor=(.52, .95), ncol=4, frameon=False, fontsize=12)
                counts = selected.n.unique()
                count_label = str(counts[0]) if len(counts) == 1 else f'{min(counts)}–{max(counts)}'
                fig.text(.5, .911, f'Line: mean | Shaded band: mean ± standard deviation | {count_label} grains per condition', ha='center', fontsize=11)
                fig.text(.08, .035, 'Each grain has equal weight. Seeds and initial spreads are kept separate. Shading shows grain-to-grain spread, not a confidence interval.\nStrain axis: saved eps_equivalent.csv (eps_eq); first data row corresponds to state 01. Population standard deviation (ddof=0); bands are not clipped at zero.', fontsize=9, color='#444444')
                path = destination / f'seed{seed}' / f'grain_rotation_gos_sd{sd}_seed{seed}.png'
                path.parent.mkdir(parents=True, exist_ok=True)
                fig.savefig(path, dpi=dpi)
                print(f'Saved {path}', flush=True)
            finally:
                plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seeds', nargs='+', type=int, choices=(1, 2, 3), default=[1, 2, 3])
    parser.add_argument('--sd', nargs='+', type=int, choices=(2, 4, 6, 8, 10), default=[2, 4, 6, 8, 10])
    parser.add_argument('--rho', nargs='+', type=float, choices=tuple(COLORS), default=list(COLORS))
    parser.add_argument('--input-root', type=Path, default=PIPELINE / 'outputs')
    parser.add_argument('--output-dir', type=Path, default=PIPELINE / 'outputs' / 'figures')
    parser.add_argument('--dpi', type=int, default=200)
    args = parser.parse_args()
    if args.dpi <= 0:
        parser.error('--dpi must be positive')
    seeds, spreads, rhos = (sorted(set(x)) for x in (args.seeds, args.sd, args.rho))
    data = load_summary(args.input_root, seeds, spreads, rhos)
    render(data, args.output_dir, seeds, spreads, rhos, args.dpi)


if __name__ == '__main__':
    main()
