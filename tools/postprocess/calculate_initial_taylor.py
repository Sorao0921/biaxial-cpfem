"""Compatibility entry point for initial orientations; uses the unified workflow."""
from src.crystal_plasticity.taylor_pipeline import main, mesh_counts

if __name__ == "__main__":
    main(default_states=[1])
