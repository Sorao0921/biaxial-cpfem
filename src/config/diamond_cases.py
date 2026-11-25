"""Shared defaults for five-grain orientation, material and merge stages."""
SEEDS = list(range(1, 51))
DEGREES = [5, 15, 25]
TEXTURES = ['cube', 'goss', 'brass', 'copper', 's']
SAMPLES_PER_SEED = 1
VARIANT_SAMPLING = 'balanced'

from src.config.pipeline_paths import INPUTS_DIR, MODELS_DIR
ORIENTATION_DIR = INPUTS_DIR / 'orientation_diamond'
PARTSMAT_DIR = INPUTS_DIR / 'partsmat_diamond'
KEYWORDS_DIR = INPUTS_DIR / 'keywords_diamond'
OUTPUT_DIR = MODELS_DIR / 'diamond_models'
