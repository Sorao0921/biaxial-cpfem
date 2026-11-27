"""Regression for observed R13 Warning 20446 caused by a blank curve card."""
from pathlib import Path
import sys
import numpy as np
import pytest
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT))
from src.make_model_process.diamond_keywordset import validate_load_curves,blocks
from tools.preprocess.merge_all_diamond import render_deck

CURVE='*DEFINE_CURVE\n1,0,1,1,0,0,0,0\n0,0\n0.016,0.00811\n0.333,0.00811\n'


def solver_style_points(text):
    # Match the physical cards, including blank cards, shown in the user's d3hsp.
    for key,lines in blocks(text):
        if key=='*DEFINE_CURVE':
            raw=[l.strip() for l in lines if not l.lstrip().startswith('$')]
            return [[float(v) for v in l.replace(',',' ').split()] if l else [0.,0.] for l in raw[1:]]


def test_join_has_exactly_the_three_prescribed_curve_points(tmp_path):
    a=tmp_path/'curve.k';b=tmp_path/'mesh.k';a.write_text(CURVE);b.write_text('*NODE\n1,0,0,0\n')
    deck=render_deck([a,b])
    assert solver_style_points(deck)==[[0,0],[.016,.00811],[.333,.00811]]
    assert '0.333,0.00811\n*NODE' in deck
    assert len(validate_load_curves(deck)[1])==3


def test_blank_curve_card_reproduces_logged_fourth_zero_point_and_is_rejected():
    buggy=CURVE+'\n*NODE\n1,0,0,0\n'
    assert solver_style_points(buggy)[-1]==[0,0]
    with pytest.raises(ValueError,match='blank data card at point 4'):validate_load_curves(buggy)


def test_reverse_point_without_blank_is_rejected():
    with pytest.raises(ValueError,match='strictly increasing'):validate_load_curves(CURVE+'0,0\n*END\n')


def test_fixed_width_curve_and_comment_separator_are_safe():
    text='*DEFINE_CURVE\n'+f'{1:10d}'+f'{0:10d}'*7+'\n$ time, velocity\n'+''.join(f'{x:20.10f}{y:20.10f}\n' for x,y in [(0,0),(.016,.00811),(.333,.00811)])+'$ separator\n*END\n'
    assert np.array_equal(validate_load_curves(text)[1],[[0,0],[.016,.00811],[.333,.00811]])
