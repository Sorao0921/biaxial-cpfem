from pathlib import Path
import pandas as pd,json
out=Path('output/pdf/dq_examples_state02');df=pd.read_csv(out/'all_case_metrics.csv')
assert len(df)==600 and df.case.nunique()==300
selected=[];used=set()
for group in ['success','difficult']:
 for feature in ['valley','peak']:
  pool=df[df.feature.eq(feature)&df.origin_count.ge(20)].copy()
  if group=='success':pool=pool[pool.capture_rate.ge(.75)&pool.area_fraction.le(.35)&pool.efficiency.ge(2)].sort_values(['capture_rate','efficiency'],ascending=False)
  else:pool=pool.sort_values(['capture_rate','efficiency'])
  textures={};rhos={};count=0
  for _,row in pool.iterrows():
   if row['case'] in used or textures.get(row.texture,0)>=3 or rhos.get(row.rho,0)>=3:continue
   item=row.to_dict();item.update(group=group,example_id=('S' if group=='success' else 'F')+f'{(0 if feature=="valley" else 5)+count+1:02d}')
   selected.append(item);used.add(row['case']);textures[row.texture]=textures.get(row.texture,0)+1;rhos[row.rho]=rhos.get(row.rho,0)+1;count+=1
   if count==5:break
  assert count==5,(group,feature,count)
# Include the lowest-capture S-texture valley as a distinct failure mode.
replacement=df[df.feature.eq('valley') & df.texture.eq('s') & df.origin_count.ge(20)].sort_values(['capture_rate','efficiency']).iloc[0].to_dict()
replacement.update(group='difficult',example_id='F04')
selected=[replacement if r['example_id']=='F04' else r for r in selected]
pd.DataFrame(selected).to_csv(out/'selected_cases.csv',index=False)
(out/'selection_method.json').write_text(json.dumps(dict(cases=300,feature_evaluations=600,groups='5 valleys + 5 peaks per success/difficult group',success='capture>=0.75, area<=0.35, efficiency>=2; descending capture then efficiency',difficult='ascending capture then efficiency',diversity='maximum 3 per texture and 3 per rho within each group-feature subset; all 20 cases unique',minimum_origins=20,diversity_override='F04 is the lowest-capture S-texture valley to include all five textures in the atlas'),indent=2))
print(pd.DataFrame(selected)[['example_id','feature','texture','rho','sd','seed','capture_rate','area_fraction','efficiency']].round(3).to_string(index=False))
