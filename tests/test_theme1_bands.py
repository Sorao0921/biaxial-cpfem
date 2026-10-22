import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import pytest

from src.dashboard.theme1_bands import read_height_bands, comparison_figure


def sample():
    return pd.DataFrame([
        dict(case_id=f's{s}t{t}', seed=s, texture='cube', rho=0, sd=2,
             state=t, eps_eq={2: .01, 3: .025, 4: .05, 5: .1}[t], signal='height_mean', band=b, energy=e, energy_fraction=e / 10)
        for s, t in [(1, 2), (1, 3), (1, 4), (1, 5), (2, 2), (2, 4), (2, 5)]
        for b, e in [('low', 5), ('mid', 3), ('high', 2)]
    ])


@pytest.mark.parametrize("varying", ["rho", "texture"])
@pytest.mark.parametrize("metric,scale", [("energy", 1), ("energy_fraction", 10)])
def test_stacked_bands_show_all_even_sd_with_missing_condition_gap(varying, metric, scale):
    rows = []
    for seed in (1, 2):
        for sd in (2, 3, 4, 6, 8, 10):
            for rho, texture in ((0, "brass"), (1, "cube")):
                if seed == 2 and sd == 4 and rho == 1:
                    continue
                for band, value in (("low", 5), ("mid", 3), ("high", 2)):
                    rows.append(dict(case_id=f"{seed}-{sd}-{rho}", seed=seed, sd=sd,
                                     rho=rho, texture=texture, band=band,
                                     energy=value, energy_fraction=value/10))
    figure = comparison_figure(pd.DataFrame(rows), varying, metric, "test")
    assert len(figure.axes) == 10
    for ax in figure.axes:
        patches = ax.patches
        assert len(patches) == 6
        # First bar stacks 5 + 3 + 2; vertical range uses their sum.
        np.testing.assert_allclose([patches[i].get_y() for i in (0, 2, 4)], [0, 5*scale, 8*scale])
        np.testing.assert_allclose([patches[i].get_height() for i in (0, 2, 4)], [5*scale, 3*scale, 2*scale])
    assert np.isnan(figure.axes[6].patches[1].get_height())
    assert figure.axes[0].get_ylim()[1] == pytest.approx(100 if metric == "energy_fraction" else 11.2)
    assert "sd=3" not in " ".join(ax.get_title() for ax in figure.axes)
    plt.close(figure)


def test_invalid_or_incomplete_saved_results_rejected(tmp_path):
    path = tmp_path / 'bands.csv'
    data = sample()
    data.to_csv(path, index=False)
    assert len(read_height_bands(path)) == len(data)
    for invalid in [data.iloc[1:], pd.concat([data, data.iloc[:1]]),
                    data.assign(energy_fraction=0.8), data.assign(energy=np.inf)]:
        invalid.to_csv(path, index=False)
        with pytest.raises(ValueError):
            read_height_bands(path)


def test_zero_energy_has_zero_share(tmp_path):
    path = tmp_path / 'bands.csv'
    sample().assign(energy=0, energy_fraction=0).to_csv(path, index=False)
    assert read_height_bands(path).energy_fraction.eq(0).all()


def test_strain_mapping_uses_state_not_filtered_row_order(tmp_path, monkeypatch):
    from types import SimpleNamespace
    from src.dashboard import theme1_bands as module
    def paths(rho, seed):
        return SimpleNamespace(equivalent_strain_csv=tmp_path / f"{seed}.csv")
    monkeypatch.setattr(module, "build_post_directories", paths)
    for seed in (1, 2):
        pd.DataFrame({"eps_eq": np.array([0, .01, .025, .05, .1]) * seed}).to_csv(tmp_path / f"{seed}.csv", index=False)
    data = sample().drop(columns="eps_eq")
    result = module.attach_equivalent_strain(data)
    np.testing.assert_allclose(result.loc[result.state.eq(5), "eps_eq"], [.1]*3 + [.2]*3)
    with pytest.raises(ValueError, match="対応"):
        module.attach_equivalent_strain(data.assign(state=13))
    pd.DataFrame({"eps_eq": [0, np.nan, .1]}).to_csv(tmp_path / '1.csv', index=False)
    with pytest.raises(ValueError, match="欠損"):
        module.attach_equivalent_strain(data)
