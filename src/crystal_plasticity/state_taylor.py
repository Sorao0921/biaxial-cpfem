"""Compatibility entry point; implementation is unified in taylor_pipeline."""
from src.crystal_plasticity.taylor_pipeline import (
    TARGET_COLUMNS, calculate_state_frame, input_signature, main,
    ensure_record as ensure_state_record,
    export_record as export_state_record,
    output_path as state_output_path,
)

if __name__ == "__main__":
    main()
