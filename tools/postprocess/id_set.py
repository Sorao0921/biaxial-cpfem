"""Compatibility CLI for ID enrichment; prefer post_main --step ids/all."""
from src.extract_process.pipeline import main

if __name__ == "__main__":
    main(default_step="ids")
