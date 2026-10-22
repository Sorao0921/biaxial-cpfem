"""Three initial-only models; CPFEM coordinates enter only evaluation."""
import hashlib
import json
from pathlib import Path
import numpy as np
import pandas as pd
from src.theme1.initial_mismatch import predict_indicator_models
from src.theme1.sachs_equilibrium import predict_equilibrium_from_initial
from src.theme1.neighbor_height import evaluate_coordinates

MODEL_NAMES=('k_only','d_q','equilibrium')
LABELS={'k_only':'A: K only (ND contrast D)','d_q':'B: D + Q (no 3D equilibrium)',
        'equilibrium':'C: 3D equilibrium','cpfem':'Reference: CPFEM state13'}


def predict_three_models(orientation_path,model_dir,*,rho,m=.05,strain=.1,heterogeneity=.75,coupling=1.,q_coupling=1.,poisson=.3):
    reduced=predict_indicator_models(orientation_path,model_dir,rho=rho,m=m,strain=strain,
        heterogeneity=heterogeneity,coupling=coupling,q_coupling=q_coupling)
    equilibrium=predict_equilibrium_from_initial(orientation_path,model_dir,rho=rho,m=m,strain=strain,
        heterogeneity=heterogeneity,poisson=poisson)
    beta=reduced['predictions']['k_only']['metadata']['beta']
    if not np.isclose(beta,equilibrium['metadata']['beta'],atol=1.e-9,rtol=0):raise ValueError('Initial stress-ratio mismatch between models')
    models={**reduced['predictions'],'equilibrium':equilibrium}
    config={'version':1,'rho':float(rho),'m':float(m),'strain':float(strain),'heterogeneity':float(heterogeneity),
        'surface_coupling':float(coupling),'q_coupling':float(q_coupling),'poisson':float(poisson),
        'beta':beta,'orientation':models['k_only']['metadata']['orientation_source'],
        'mesh':models['k_only']['metadata']['initial_model_source'],'input_versions':models['k_only']['metadata']['input_versions']}
    config_id=hashlib.sha256(json.dumps(config,sort_keys=True).encode()).hexdigest()[:12]
    return {'models':models,'indicators':reduced['indicators'],'interfaces':reduced['interfaces'],
            'surface_edges':reduced['surface_edges'],'configuration':config,'config_id':config_id}


def evaluate_three_models(prediction,cpfem):
    """Pair by top-surface row IDs, retain raw heights; never refit a model."""
    selected={};pairs={};rows=[]
    for name in MODEL_NAMES:
        selected[name],pairs[name],metrics=evaluate_coordinates(prediction['models'][name]['coordinates'],cpfem)
        error=pairs[name].z_predicted-pairs[name].z_actual
        metrics['mean_height_bias']=float(error.mean())
        metrics['centered_height_rmse']=float(np.sqrt(np.mean((error-error.mean())**2)))
        metrics['std_ratio']=metrics['predicted_height_std']/metrics['actual_height_std'] if metrics['actual_height_std']>0 else np.nan
        meta=prediction['models'][name]['metadata']
        metrics['model']=name
        if name=='equilibrium':
            for key in ['relative_free_force_residual','iterations','finite_geometry_valid','inverted_deformed_elements','maximum_eigenstrain_norm']:
                metrics[key]=meta[key]
        else:
            metrics['positive_predicted_thickness']=bool(prediction['models'][name]['grains'].linear_height_positive.all())
        rows.append(metrics)
    selected['cpfem']=cpfem.copy()
    return {'selected':selected,'pairs':pairs,'metrics':pd.DataFrame(rows)}


def save_initial_prediction(prediction,directory):
    """Save all initial predictions BEFORE CPFEM data are read by the caller."""
    directory=Path(directory);directory.mkdir(parents=True,exist_ok=True)
    for key in ['indicators','interfaces','surface_edges']:prediction[key].to_csv(directory/(key+'.csv'),index=False)
    (directory/'configuration.json').write_text(json.dumps(prediction['configuration'],ensure_ascii=False,indent=2)+'\n')
    for name in MODEL_NAMES:
        model=prediction['models'][name];target=directory/name;target.mkdir(exist_ok=True)
        for key in ['coordinates','grains','displacements','initial_tensors']:
            if key in model:model[key].to_csv(target/(key+'.csv'),index=False)
        (target/'model.json').write_text(json.dumps(model['metadata'],ensure_ascii=False,indent=2)+'\n')
