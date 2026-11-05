from pathlib import Path
import csv,statistics,math,json
from reportlab.pdfgen.canvas import Canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.lib.pagesizes import A4,landscape
from reportlab.lib.colors import HexColor,white
from reportlab.platypus import Paragraph,Table,TableStyle
from reportlab.lib.styles import ParagraphStyle
from PIL import Image
from pypdf import PdfReader
ROOT=Path('output/pdf/dq_examples_state02')
rows=list(csv.DictReader((ROOT/'selected_cases.csv').open()))
allrows=list(csv.DictReader((ROOT/'all_case_metrics.csv').open()))
pdfmetrics.registerFont(UnicodeCIDFont('HeiseiKakuGo-W5'));FONT='HeiseiKakuGo-W5'
W,H=landscape(A4);M=32;BLUE='#17324d';GREY='#526274'
styles={s:ParagraphStyle(s,fontName=FONT,fontSize=size,leading=leading,wordWrap='CJK',textColor=HexColor(BLUE)) for s,size,leading in [('body',11,17),('small',9,14),('heading',18,25)]}
PDF=ROOT/'dq_prediction_success_and_difficult_examples.pdf'
c=Canvas(str(PDF),pagesize=(W,H));c.setTitle('D+Q 初期起点予測：成功例・不成功例 各10ケース');c.setAuthor('Research analysis')
page=0

def para(text,x,y,width,style='body'):
 p=Paragraph(text,styles[style]);w,h=p.wrap(width,H);p.drawOn(c,x,y-h);return y-h

def start(title,subtitle=''):
 global page
 page+=1;c.setFillColor(HexColor(BLUE));c.rect(0,H-9,W,9,fill=1,stroke=0)
 para(title,M,H-29,W-2*M,'heading')
 if subtitle:para(subtitle,M,H-61,W-2*M,'small')
 c.setFont(FONT,8);c.setFillColor(HexColor(GREY));c.drawString(M,18,'D + Q / state02 / Initial-origin prediction / 2026-10-30');c.drawRightString(W-M,18,str(page))

def end():c.showPage()
def num(r,k):return float(r[k])
def feature(r):return '谷' if r['feature']=='valley' else '山'
def tex(r):return r['texture'].capitalize() if r['texture']!='s' else 'S'
def pct(v):return f'{float(v)*100:.1f}%'

start('D＋Qによる初期起点予測：成功例・不成功例', 'state02の300ケースを再評価 / 成功10例・不成功10例 / 各群は谷5例・山5例')
y=H-101
for title,text in [
 ('この資料で評価する「成功」','初期情報から予測した谷・山の粒領域が、CPFEMの起点をどれだけ捕捉するかを評価する。高さの振幅や表面全体の形状再現を成功の条件とはしない。'),
 ('比較の読み方','左：D＋Qの予測高さ。中央：CPFEMの高さと起点。右：予測粒領域とCPFEM起点の重なり。緑の星（谷）／三角（山）が捕捉、紫の×が未捕捉。高さの色域は各場の2-98%で独立に設定し、振幅合わせは行わない。全図を初期材料座標に揃える。'),
 ('選定ルール','成功例は捕捉率75%以上・予測面積率35%以下・面積当たり捕捉効率2以上から、捕捉率を優先して選定。不成功例は低捕捉率を優先した。各特徴・各群で同じtextureは原則3例まで、同じrhoは3例までとし、20例の条件は重複させた。S方位の課題も示すため、F04にはSの谷で最低捕捉率の例を掲載する。'),
 ('共通の計算・検出条件','既存D＋Qの設定を使用：m=0.05、予測用相当ひずみ0.00901、応答差保持率0.75、表面結合0、Q拘束係数1。予測粒の採択閾値は近傍に対する局所的な低さ（山は符号反転）のRMSの0.5倍。CPFEMを用いた係数・閾値の再調整は行わない。'),
 ('集計対象と留意点','rho=-0.5, 0, 0.5, 1、texture 5種類、sd=2, 4, 6, 8, 10、seed=1, 2, 3の300ケース（谷・山で600評価）。計算失敗0件。各例は比較説明用の選択例であり、全体の平均性能を表す標本ではない。粒界上の起点は、支持する粒のいずれかが予測領域に含まれれば1回だけ捕捉と数える。')]:
 y=para(title,M,y,W-2*M,'body')-3;y=para(text,M,y,W-2*M,'small')-16
end()
start('掲載例一覧','R：起点捕捉率 / A：予測面積率 / E=R/A：面積当たり捕捉効率（信頼確率ではなく集中度）')
data=[['例','対象','Texture','rho','sd','seed','捕捉 / 全起点','R','A','E','頁']]
for i,r in enumerate(rows):
 r['pdf_page']=i+3
 data.append([r['example_id'],feature(r),tex(r),f"{num(r,'rho'):g}",r['sd'],r['seed'],f"{r['captured']} / {r['origin_count']}",pct(r['capture_rate']),pct(r['area_fraction']),f"{num(r,'efficiency'):.2f}",str(i+3)])
t=Table(data,colWidths=[40,36,75,45,35,40,115,78,78,67,35],rowHeights=20)
t.setStyle(TableStyle([('FONTNAME',(0,0),(-1,-1),FONT),('FONTSIZE',(0,0),(-1,-1),9),('VALIGN',(0,0),(-1,-1),'MIDDLE'),('BACKGROUND',(0,0),(-1,0),HexColor(BLUE)),('TEXTCOLOR',(0,0),(-1,0),white),('ROWBACKGROUNDS',(0,1),(-1,10),[HexColor('#eff7f4'),white]),('ROWBACKGROUNDS',(0,11),(-1,-1),[HexColor('#fcf1f4'),white]),('LINEBELOW',(0,10),(-1,10),1,HexColor(GREY))]))
t.wrap(W,H);t.drawOn(c,M,H-92-420)
para('S01-S10：起点捕捉の成功例。F01-F10：捕捉率が低い例。F03・F05は少数領域への集中度が高く、「過度の絞り込み」による取りこぼしとして区別する。',M,63,W-2*M,'small');end()
for r in rows:
 good=r['group']=='success';R=num(r,'capture_rate');A=num(r,'area_fraction');E=num(r,'efficiency');ft=feature(r)
 category='成功例' if good else ('取りこぼし例（絞り込みが強い）' if E>=2.5 else '不成功例（起点位置の捕捉が難しい）')
 start(f"{r['example_id']}  {category} / {ft}の起点",f"{tex(r)} | sd={r['sd']} | rho={num(r,'rho'):g} | seed={r['seed']} | CPFEM state02, equivalent plastic strain={num(r,'eps_eq'):.8f}")
 labels=[('起点捕捉率',pct(R)),('捕捉数 / 全起点',f"{r['captured']} / {r['origin_count']}"),('予測面積率',pct(A)),('面積当たり捕捉効率',f'{E:.2f}')]
 gap=10;bw=(W-2*M-3*gap)/4
 for i,(label,value) in enumerate(labels):
  x=M+i*(bw+gap);c.setFillColor(HexColor('#edf3f7'));c.roundRect(x,H-136,bw,48,5,fill=1,stroke=0)
  para(label,x+10,H-93,bw-20,'small');c.setFont(FONT,18);c.setFillColor(HexColor(BLUE));c.drawString(x+10,H-124,value)
 image=ROOT/r['map_file'];iw,ih=Image.open(image).size;dw=W-2*M;dh=dw*ih/iw
 c.drawImage(str(image),M,H-151-dh,width=dw,height=dh,mask='auto')
 y=H-166-dh
 if good:
  msg=f"予測領域は評価面積の{pct(A)}に限定され、その中に{pct(R)}の起点を捕捉する。右図では緑の記号が着色した予測粒領域に対応し、未捕捉は{r['missed']}点残る。"
 elif E>=2.5:
  msg=f"予測領域は面積の{pct(A)}と狭く、{r['missed']}点を取りこぼす。一方、捕捉効率は{E:.2f}で、選んだ領域への起点の集中は保たれる。位置予測の全面的な失敗ではなく、候補領域の絞り込みが強い例として読む。"
 else:
  msg=f"面積の{pct(A)}を候補とする一方、{r['missed']} / {r['origin_count']}点が予測領域外となる。右図の紫の×が、D＋Qの候補粒では覆えなかった起点位置を示す。"
 y=para(msg,M,y,W-2*M,'body')-8
 y=para(f"補助確認：局所的な顕著さ（検出時のprominence）が大きい上位{r['top10_count']}起点では{r['top10_captured']}点を捕捉。これは全起点捕捉率に追加した確認であり、検出・選定閾値の変更ではない。",M,y,W-2*M,'small')-6
 if not good and r['texture'] in ('brass','s'):
  para('考察候補：粒内の不均一変形・方位回転との対応を確認する。図だけから原因を確定せず、GOSなどとの空間対応を次の検証に用いる。',M,y,W-2*M,'small')
 else:para('高さの色域は各場で独立。着色粒の判定は周囲に対する局所高さに基づくため、左図の青／赤の範囲と右図の予測領域は必ずしも一致しない。',M,y,W-2*M,'small')
 end()
c.save()
reader=PdfReader(PDF);assert len(reader.pages)==22
for p in reader.pages: assert len(p.extract_text())>100
with (ROOT/'selected_cases.csv').open('w',newline='') as stream:
 writer=csv.DictWriter(stream,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
(ROOT/'pdf_checks.json').write_text(json.dumps({'pages':len(reader.pages),'examples':len(rows),'source_cases':300,'failed_cases':0,'size_bytes':PDF.stat().st_size},indent=2))
print(PDF,len(reader.pages),'pages',PDF.stat().st_size,'bytes')
