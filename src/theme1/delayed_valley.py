"""Freeze state02 candidates and inspect later reference detections only.

Material coordinates pair node IDs; changing reference thresholds/crop can alter
appearance. Labels describe detected geometry, not a causal nucleation proof.
"""
import numpy as np
import pandas as pd
from src.theme1.valley_bottom import reference_bottom_lines
from src.theme1.valley_evaluation import _surface


def point_segment_distances(points,segments):
    points=np.asarray(points,float).reshape(-1,2);segments=np.asarray(segments,float).reshape(-1,2,2)
    if not len(segments):return np.full(len(points),np.inf)
    result=[]
    a=segments[:,0];v=segments[:,1]-a;length2=np.sum(v*v,axis=1)
    for p in points:
        t=np.clip(np.sum((p-a)*v,axis=1)/np.maximum(length2,np.finfo(float).tiny),0,1)
        result.append(float(np.linalg.norm(p-(a+t[:,None]*v),axis=1).min()))
    return np.array(result)


def classify_reference(detected,top,prior_segments,prior_origins,*,line_tolerance,origin_tolerance):
    lines=detected['segments'].copy();origins=detected['origins'].copy()
    material=lines[['material_x_a','material_y_a','material_x_b','material_y_b']].to_numpy(float).reshape(-1,2,2)
    # Connected new line components touching ANY old line are growth/connection.
    parent={}
    def root(n):
        parent.setdefault(n,n)
        if parent[n]!=n:parent[n]=root(parent[n])
        return parent[n]
    for r in lines.itertuples():
        a,b=root(int(r.node_a)),root(int(r.node_b));parent[b]=a
    component=np.array([root(int(n)) for n in lines.node_a],int)
    endpoint_dist=point_segment_distances(material.reshape(-1,2),prior_segments).reshape(-1,2).min(axis=1) if len(lines) else np.array([])
    old_components=set(component[endpoint_dist<=line_tolerance])
    lines['component_id']=component;lines['new_disconnected_valley']=~lines.component_id.isin(old_components)
    origin_xy=top.iloc[origins.node_id.to_numpy(int)-1][['x','y']].to_numpy(float) if len(origins) else np.empty((0,2))
    nearest_origin=np.array([np.linalg.norm(np.asarray(prior_origins).reshape(-1,2)-p,axis=1).min() if len(prior_origins) else np.inf for p in origin_xy])
    origin_to_old_line=point_segment_distances(origin_xy,prior_segments)
    new_nodes=set(lines.loc[lines.new_disconnected_valley,'node_a'])|set(lines.loc[lines.new_disconnected_valley,'node_b'])
    novel=nearest_origin>origin_tolerance
    origins['material_x']=origin_xy[:,0];origins['material_y']=origin_xy[:,1]
    origins['nearest_historical_origin_distance']=nearest_origin
    origins['nearest_historical_line_distance']=origin_to_old_line
    origins['novel_origin']=novel
    origins['appearance']=np.select([~novel,origins.node_id.isin(new_nodes)],
        ['continued_or_returned_origin','new_origin_in_new_valley'],default='new_origin_on_existing_or_expanding_valley')
    return lines,origins,material,origin_xy


def _boundary_point_hits(points,edges,tolerance):
    hits={}
    for key,frame in edges.groupby('boundary_id'):
        segments=frame[['x_a','y_a','x_b','y_b']].to_numpy(float).reshape(-1,2,2)
        hits[key]=set(np.flatnonzero(point_segment_distances(points,segments)<=tolerance+1.e-12))
    return hits


def validate_delayed_candidates(onset_result,heights,model_dir):
    """heights must include state02; later states never update prediction sets."""
    if 2 not in heights:raise ValueError('state02 baseline is required')
    states=sorted(s for s in heights if s>=2)
    top,geometry,faces=_surface(model_dir)
    full_edges=onset_result['taylor_boundary_segments']
    boundary_edges=full_edges[full_edges.candidate].copy()
    boundary_tolerance=onset_result['taylor_union_method']['matching_tolerance']
    grid_step=min(np.diff(np.unique(top.x)).min(),np.diff(np.unique(top.y)).min())
    diameter=onset_result['metadata']['reference_definition']['neighborhood_diameter']
    origin_tolerance=.5*diameter;line_tolerance=grid_step*1.01
    grain_sets={name:set(frame.loc[frame.predicted_feature,'item_id'].astype(int)) for name,frame in onset_result['flags'].query('threshold_factor==1').groupby('model')}
    candidates=[]
    for model,pids in grain_sets.items():
        flags=onset_result['flags'].query('threshold_factor==1');flags=flags[flags.model==model].set_index('item_id')
        initial_line=onset_result['reference_bottom_grains'].set_index('part_id').full_line_feature
        for pid in sorted(pids):candidates.append(dict(channel=model,candidate_type='grain',candidate_id=str(pid),
            baseline_origin=bool(flags.loc[pid,'reference_feature']),baseline_line=bool(initial_line.get(pid,False))))
    baseline_boundary_origins=set(onset_result['taylor_origin_boundary'].boundary_id)
    for key in sorted(boundary_edges.boundary_id.unique()):
        candidates.append(dict(channel='taylor_boundary',candidate_type='boundary',candidate_id=str(key),baseline_origin=key in baseline_boundary_origins,baseline_line=False))
    candidate_frame=pd.DataFrame(candidates,columns=['channel','candidate_type','candidate_id','baseline_origin','baseline_line'])
    baseline_ids=onset_result['node_heights'].node_id.to_numpy(int)
    kept=np.all(np.isin(faces,baseline_ids),axis=1)
    required_nodes={}
    for face,pid in zip(faces[kept],geometry.loc[kept].part_id):required_nodes.setdefault(int(pid),set()).update(map(int,face))
    observations=[];origin_rows=[];line_rows=[];capture_rows=[];state_rows=[]
    prior_segments=np.empty((0,2,2));prior_origins=np.empty((0,2))
    for state in states:
        ref=reference_bottom_lines(heights[state],model_dir)
        if state==2:
            # Use the exact frozen baseline detection for initial novelty history.
            ref.update(segments=onset_result['bottom_lines'],support=onset_result['bottom_line_support'],origins=onset_result['origins'],origin_support=onset_result['origin_support'])
        lines,origins,material,origin_xy=classify_reference(ref,top,prior_segments,prior_origins,line_tolerance=line_tolerance,origin_tolerance=origin_tolerance)
        if state==2:
            lines['new_disconnected_valley']=False;origins['novel_origin']=False;origins['appearance']='baseline'
        lines['state']=state;origins['state']=state
        origin_rows.append(origins);line_rows.append(lines)
        support=ref['origin_support'];line_support=ref['support']
        boundary_origin_hits=_boundary_point_hits(origin_xy,boundary_edges,boundary_tolerance)
        boundary_line_hits=_boundary_point_hits(material.mean(axis=1) if len(material) else np.empty((0,2)),boundary_edges,boundary_tolerance)
        visible_nodes=set(heights[state].node_id.astype(int))
        visible_grains=set(geometry.loc[np.all(np.isin(faces,list(visible_nodes)),axis=1),'part_id'].astype(int))
        novel_positions=set(np.flatnonzero(origins.novel_origin))
        new_valley_positions=set(np.flatnonzero(origins.appearance.eq('new_origin_in_new_valley')))
        new_line_positions=set(np.flatnonzero(lines.new_disconnected_valley))
        for c in candidate_frame.itertuples():
            if c.candidate_type=='grain':
                pid=int(c.candidate_id);visible=pid in visible_grains and required_nodes.get(pid,set())<=visible_nodes
                # Require full baseline crop correspondence to avoid partial-grain censoring.
                hits=set(np.flatnonzero(origins.origin_id.isin(support.loc[support.part_id==pid,'origin_id'])))
                line_hits=set(np.flatnonzero(lines.segment_id.isin(line_support.loc[line_support.part_id==pid,'segment_id'])))
            else:
                edges=boundary_edges[boundary_edges.boundary_id==c.candidate_id]
                visible=(set(edges.node_a)|set(edges.node_b))<=visible_nodes
                hits=boundary_origin_hits.get(c.candidate_id,set());line_hits=boundary_line_hits.get(c.candidate_id,set())
            observations.append(dict(state=state,channel=c.channel,candidate_type=c.candidate_type,candidate_id=c.candidate_id,
                baseline_origin=c.baseline_origin,baseline_line=c.baseline_line,visible=visible,
                has_line=bool(line_hits) if visible else False,has_origin=bool(hits) if visible else False,
                has_novel_origin=bool(hits&novel_positions) if visible else False,
                has_new_valley_origin=bool(hits&new_valley_positions) if visible else False,
                has_new_disconnected_line=bool(line_hits&new_line_positions) if visible else False))
        for model,pids in grain_sets.items():
            for pos,o in enumerate(origins.itertuples()):
                own=set(support.loc[support.origin_id==o.origin_id,'part_id'].astype(int))
                grain_hit=bool(own&pids);boundary_hit=any(pos in values for values in boundary_origin_hits.values())
                capture_rows.append(dict(state=state,model=model,origin_id=o.origin_id,appearance=o.appearance,
                    model_captured=grain_hit,boundary_captured=boundary_hit,union_captured=grain_hit or boundary_hit))
        state_rows.append(dict(state=state,line_segments=len(lines),origins=len(origins),
            novel_origins=int(origins.novel_origin.sum()),new_valley_origins=int(origins.appearance.eq('new_origin_in_new_valley').sum()),
            new_disconnected_line_components=int(lines.loc[lines.new_disconnected_valley,'component_id'].nunique()),
            height_blue_cutoff=ref['metadata']['blue_height_cutoff']))
        prior_segments=np.concatenate([prior_segments,material]);prior_origins=np.concatenate([prior_origins,origin_xy])
    obs=pd.DataFrame(observations,columns=['state','channel','candidate_type','candidate_id','baseline_origin','baseline_line','visible','has_line','has_origin','has_novel_origin','has_new_valley_origin','has_new_disconnected_line']);summary=[]
    for c in candidate_frame.itertuples():
        frame=obs[(obs.channel==c.channel)&(obs.candidate_id==c.candidate_id)&(obs.state>2)&obs.visible]
        row=c._asdict();row.pop('Index',None)
        base=obs[(obs.channel==c.channel)&(obs.candidate_id==c.candidate_id)&(obs.state==2)].iloc[0]
        row['baseline_line']=bool(base.has_line);row['pending_at_state02']=not c.baseline_origin
        for key in ['line','origin','novel_origin','new_valley_origin','new_disconnected_line']:
            hits=frame.loc[frame['has_'+key],'state'];row['first_'+key+'_state']=(2 if key=='line' and row['baseline_line'] else 2 if key=='origin' and c.baseline_origin else int(hits.min()) if len(hits) else np.nan)
        row['all_later_states_visible']=bool(len(frame)==len(states)-1)
        summary.append(row)
    summary=pd.DataFrame(summary,columns=['channel','candidate_type','candidate_id','baseline_origin','baseline_line','pending_at_state02','first_line_state','first_origin_state','first_novel_origin_state','first_new_valley_origin_state','first_new_disconnected_line_state','all_later_states_visible']);counts=[]
    for channel,frame in summary.groupby('channel',sort=False):
        pending=frame[frame.pending_at_state02]
        counts.append(dict(channel=channel,initial_candidates=len(frame),unmatched_state02=len(pending),
            later_origin=int(pending.first_origin_state.notna().sum()),later_novel_origin=int(pending.first_novel_origin_state.notna().sum()),
            later_new_valley_origin=int(pending.first_new_valley_origin_state.notna().sum()),
            still_unmatched=int(pending.first_origin_state.isna().sum()),
            censored=int((~pending.all_later_states_visible).sum())))
    return dict(summary=pd.DataFrame(counts),candidates=summary,observations=obs,states=pd.DataFrame(state_rows),
        origins=pd.concat(origin_rows,ignore_index=True),lines=pd.concat(line_rows,ignore_index=True),captures=pd.DataFrame(capture_rows),
        metadata=dict(method_version='delayed_candidates_v1',baseline_state=2,states=states,
            missing_states=sorted(set(range(2,max(states)+1))-set(states)),line_tolerance=line_tolerance,origin_tolerance=origin_tolerance,
            predictions_frozen=True,reference_detection='same blue-area, trough and prominence rules independently at each state',
            novelty='compared with all earlier OBSERVED states in initial material coordinates; reappearances near historical origins are not new',
            new_valley='a current connected trough component has no node within one grid step of any historical trough',
            caveat='detected appearance, not causal nucleation proof; threshold crossings, sparse output and sub-tolerance drift remain ambiguous; candidates are censored when not visible'))
