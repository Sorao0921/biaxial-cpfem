"""Local minima on measured trough graphs, counted as origin events.

Prominence/separation are specified from reference display range and initial
geometry, never from prediction scores. Several origins may occupy one valley.
"""
import heapq
import numpy as np
import pandas as pd


def local_origins(lines,*,height_span,grain_diameter,prominence_fraction=.05,separation_fraction=.5):
    columns=['origin_id','node_id','x','y','z','prominence','graph_degree','plateau_nodes','component_id']
    member_columns=['origin_id','node_id']
    if lines.empty:return pd.DataFrame(columns=columns),pd.DataFrame(columns=member_columns)
    if min(height_span,grain_diameter)<0 or prominence_fraction<0 or separation_fraction<0:raise ValueError('Invalid origin scales')
    xyz={};adj={}
    for r in lines.itertuples():
        a,b=int(r.node_a),int(r.node_b)
        xyz[a]=np.array([r.x_a,r.y_a,r.z_a]);xyz[b]=np.array([r.x_b,r.y_b,r.z_b])
        adj.setdefault(a,{})[b]=float(r.length);adj.setdefault(b,{})[a]=float(r.length)
    nodes=sorted(xyz);tol=64*np.finfo(float).eps*max(1.,max(abs(p[2]) for p in xyz.values()))
    # Collapse equal-height connected plateaus before local-minimum tests.
    group={};plateaus=[]
    for node in nodes:
        if node in group:continue
        index=len(plateaus);stack=[node];members=[];group[node]=index
        while stack:
            u=stack.pop();members.append(u)
            for v in adj[u]:
                if v not in group and abs(xyz[v][2]-xyz[u][2])<=tol:group[v]=index;stack.append(v)
        plateaus.append(members)
    graph={i:set() for i in range(len(plateaus))}
    heights=np.array([min(xyz[n][2] for n in members) for members in plateaus])
    for u in nodes:
        for v in adj[u]:
            if group[u]!=group[v]:graph[group[u]].add(group[v])
    # Flood from low to high: a minimum dies at its first saddle connecting it
    # to a lower minimum. The deepest minimum uses its component's height span.
    parent={};birth={};peak={};prominence={};component={}
    def root(i):
        while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
        return i
    for i in sorted(graph,key=lambda k:(heights[k],k)):
        parent[i]=i;birth[i]=i;peak[i]=heights[i]
        for j in graph[i]:
            if j not in parent:continue
            a,b=root(i),root(j)
            if a==b:continue
            winner,loser=(a,b) if (heights[birth[a]],birth[a])<=(heights[birth[b]],birth[b]) else (b,a)
            prominence[birth[loser]]=float(heights[i]-heights[birth[loser]])
            parent[loser]=winner;peak[winner]=max(peak[a],peak[b],heights[i])
    for i in graph:
        r=root(i);component[i]=r
    for r in set(component.values()):prominence[birth[r]]=float(peak[r]-heights[birth[r]])
    candidates=[]
    for i,neighbors in graph.items():
        # Exclude truncated line ends and a flat whole component.
        if len(neighbors)<2 or any(heights[j]<heights[i]-tol for j in neighbors):continue
        strength=prominence.get(i,0.)
        if strength<=max(tol,prominence_fraction*height_span):continue
        members=plateaus[i];center=np.mean([xyz[n][:2] for n in members],axis=0)
        representative=min(members,key=lambda n:(np.linalg.norm(xyz[n][:2]-center),n))
        candidates.append((representative,i,strength))
    # Suppress near-duplicate minima only along the same connected trough.
    kept=[];blocked=set();separation=separation_fraction*grain_diameter
    for node,i,strength in sorted(candidates,key=lambda c:(xyz[c[0]][2],-c[2],c[0])):
        if node in blocked:continue
        kept.append((node,i,strength));queue=[(0.,node)];distance={node:0.}
        while queue:
            d,u=heapq.heappop(queue)
            if d>separation or d!=distance[u]:continue
            blocked.add(u)
            for v,length in adj[u].items():
                new=d+length
                if new<=separation and new<distance.get(v,np.inf):distance[v]=new;heapq.heappush(queue,(new,v))
    rows=[];members=[]
    for oid,(node,i,strength) in enumerate(kept):
        p=xyz[node]
        rows.append(dict(origin_id=oid,node_id=node,x=p[0],y=p[1],z=p[2],prominence=strength,graph_degree=len(graph[i]),plateau_nodes=len(plateaus[i]),component_id=component[i]))
        members.extend(dict(origin_id=oid,node_id=n) for n in plateaus[i])
    return pd.DataFrame(rows,columns=columns),pd.DataFrame(members,columns=member_columns)
