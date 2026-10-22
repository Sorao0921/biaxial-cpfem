"""Compare fixed Az/P+/P- height hypotheses without fitting simulated data."""
import argparse
import sys
from pathlib import Path

import pandas as pd
from src.config.pipeline_paths import THEME1_DIR
from tools.theme1.predict_initial_height import main as predict


def save_comparison(root):
    """Export a long table using only cases available for all three models."""
    frames=[]
    for activity,folder in [('az',root),('pplus',root/'pplus'),('pminus',root/'pminus')]:
        frame=pd.read_csv(folder/'evaluation.csv')
        frame['activity']=activity
        frames.append(frame)
    common=set.intersection(*(set(frame.case_id) for frame in frames))
    table=pd.concat([frame[frame.case_id.isin(common)] for frame in frames],ignore_index=True)
    table.sort_values(['case_id','activity']).to_csv(root/'model_comparison.csv',index=False)
    return table


def main():
    arguments=sys.argv[1:]
    parser=argparse.ArgumentParser(add_help=False)
    parser.add_argument('--output-dir',type=Path,default=THEME1_DIR/'initial_height_state13')
    known,_=parser.parse_known_args(arguments)
    if '--activity' in arguments:
        raise SystemExit('This command runs all activities; omit --activity')
    status=0
    for activity in ('az','pplus','pminus'):
        status |= predict([*arguments,'--activity',activity])
    if status==0:
        save_comparison(known.output_dir)
    return status


if __name__=='__main__':
    raise SystemExit(main())
