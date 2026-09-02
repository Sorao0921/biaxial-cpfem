from src.mapping import plot_workflow
from src.mapping.plot_workflow import PlotSummary


def test_plot_summary_adds_saved_and_skipped_counts() -> None:
    assert PlotSummary(saved=2, skipped=1) + PlotSummary(saved=3, skipped=4) == (
        PlotSummary(saved=5, skipped=5)
    )


def test_plot_all_mapping_results_dispatches_selected_types(monkeypatch) -> None:
    calls: list[tuple[str, float, int]] = []

    def fake_height(rho, seed, **kwargs):
        calls.append(("height", rho, seed))
        return PlotSummary(saved=1)

    def fake_shear(rho, seed, **kwargs):
        calls.append(("shear", rho, seed))
        return PlotSummary(saved=2)

    def unexpected_orientation(*args, **kwargs):
        raise AssertionError("orientation plotting should not be dispatched")

    monkeypatch.setattr(plot_workflow, "plot_surface_heights", fake_height)
    monkeypatch.setattr(plot_workflow, "plot_shear_strains", fake_shear)
    monkeypatch.setattr(
        plot_workflow, "plot_orientation_metrics", unexpected_orientation
    )

    summaries = plot_workflow.plot_all_mapping_results(
        0.5,
        3,
        plot_types=("height", "shear"),
    )

    assert calls == [("height", 0.5, 3), ("shear", 0.5, 3)]
    assert summaries == {
        "height": PlotSummary(saved=1),
        "shear": PlotSummary(saved=2),
    }


def test_plot_all_mapping_results_rejects_unknown_type() -> None:
    try:
        plot_workflow.plot_all_mapping_results(1, 2, plot_types=("unknown",))
    except ValueError as error:
        assert "unknown" in str(error).lower()
    else:
        raise AssertionError("unknown plot type was accepted")
