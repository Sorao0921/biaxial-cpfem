"""Assemble Japanese supervisor-ready PDFs from validated case maps.

Use bundled Python (ReportLab + pypdf), after build_all_case_atlas.
"""
from pathlib import Path
import argparse
import csv
import json
import math
import zipfile
import hashlib
from PIL import Image as PILImage
import shutil

from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4,landscape
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle,PageBreak,Image,KeepTogether
from pypdf import PdfReader

pdfmetrics.registerFont(UnicodeCIDFont('HeiseiKakuGo-W5'))
FONT='HeiseiKakuGo-W5'
STYLE=ParagraphStyle('body',fontName=FONT,fontSize=10,leading=16,wordWrap='CJK',spaceAfter=8)
HEADING=ParagraphStyle('heading',parent=STYLE,fontSize=20,leading=27,spaceAfter=14,textColor=colors.HexColor('#15354b'))
SMALL=ParagraphStyle('small',parent=STYLE,fontSize=8,leading=12)


def p(text,style=STYLE):return Paragraph(text,style)
def table(data,widths=None):
    result=Table(data,colWidths=widths,repeatRows=1,hAlign='LEFT')
    result.setStyle(TableStyle([('FONTNAME',(0,0),(-1,-1),FONT),('FONTSIZE',(0,0),(-1,-1),8),
        ('LEADING',(0,0),(-1,-1),11),('BOTTOMPADDING',(0,0),(-1,-1),4),('TOPPADDING',(0,0),(-1,-1),4),
        ('BACKGROUND',(0,0),(-1,0),colors.HexColor('#15354b')),('TEXTCOLOR',(0,0),(-1,0),colors.white),
        ('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.HexColor('#edf3f7'),colors.white]),
        ('LINEBELOW',(0,0),(-1,0),.5,colors.HexColor('#15354b'))]))
    return result


def number(row,key):return float(row[key])
def fmt(x):return f'{float(x):.3f}' if math.isfinite(float(x)) else 'undefined'


def assemble(root,rows,output,label):
    groups={}
    for row in rows:groups.setdefault((row['rho'],row['texture']),[]).append(row)
    correlations=sorted(number(r,'nodal_pearson') for r in rows if math.isfinite(number(r,'nodal_pearson')))
    import statistics
    story=[p('初期Kに基づく表面高さ予測',HEADING),p(f'全ケース比較マップ・精度一覧 / {label} / 2026年10月15日'),
        p(f'対象は既存のstate13高さデータ {len(rows)} ケース。初期方位・初期メッシュ・事前指定負荷だけから予測し、解析高さは予測完了後の比較にだけ使用した。全ケースで同じモデル・係数を使用し、結果に合わせた重み選択や振幅調整は行っていない。'),
        p(f'節点高さ相関の中央値：{statistics.median(correlations):.3f} / 最小：{min(correlations):.3f} / 最大：{max(correlations):.3f}。相関は山谷の位置関係を表し、振幅の一致を保証しない。'),
        p('共通条件：Kのみ、m=0.05、指定相当対数ひずみ=0.1、粒間結合=1、面内配合=0.5、低K抵抗あり、初期指標の標準化なし。応力比は各ケースの初期体積平均ひずみ比が指定rhoに一致するよう逆算。',SMALL)]
    summary=[['rho','組織','件数','相関中央値','相関範囲','RMSE中央値','振幅比中央値']]
    for (rho,texture),items in groups.items():
        rs=[number(x,'nodal_pearson') for x in items]
        summary.append([rho,texture,len(items),f'{statistics.median(rs):.3f}',f'{min(rs):.3f} - {max(rs):.3f}',
            f"{statistics.median(number(x,'raw_height_rmse') for x in items):.3g}",
            f"{statistics.median(number(x,'std_ratio') for x in items):.3f}"])
    story+=[table(summary,[55,75,40,90,120,125,120]),Spacer(1,8),p('集計はケースを等重みで扱う。組織間で条件構成が異なるため、中央値だけから優劣を断定しない。',SMALL),PageBreak()]
    story += [p('比較の読み方とモデルの範囲',HEADING),
        p('各図は左が初期Kからの予測、右がstate13解析結果。高さは元のz座標で、値の正規化・平均引き・振幅合わせを行わない。色範囲だけを予測・解析の節点値を合わせた2〜98百分位に設定し、範囲外は端の色で表示する。誤差計算には全値を使用する。色範囲はケースごとに異なるため、ケース間の振幅はカラーバーと精度一覧で確認する。'),
        p('予測仮説：周囲よりKが大きい粒、または粒間方向を考慮したRD・TD伸長寄与が周囲より大きい粒を沈み込みの駆動源とする。共有粒界長／初期粒重心間距離を幾何重みに使い、粒間結合で沈み込みを周囲へ伝える。低K粒では伝達を弱める。'),
        p('ND差と面内差は各0.5で配合する。非圧縮条件でK_RD+K_TD=K_NDとなるため、独立なひずみとして足し合わせない。低K抵抗は初期の正K面積平均に対する相対値から定める仮説であり、実際の剛性を表すものではない。'),
        p('評価値：Pearson rは同じ節点IDの予測高さと解析高さの相関（1が同じ傾向、0が線形相関なし、負値は逆の傾向）。RMSEは元のz座標での二乗平均平方根誤差。biasは予測平均−解析平均。std(pred/actual)は高さ標準偏差の比で、1より小さいと予測振幅が小さい。単位は元データの座標単位。長さの物理単位はこの資料では推定していない。'),
        p('限界：力学平衡・三次元粒間適合・結晶回転・加工硬化は解いていない。平均板厚は事前指定ひずみ0.1から定めており、各解析のstate13ひずみに合わせていない。応力比逆算が一致させるのは初期モデルの平均面内ひずみ比で、変形中の局所ひずみ全体ではない。表面グラフと平坦な下面を使う近似予測として評価する。'),
        p('対象範囲：既存state13高さがある全ケースを含む。未実行条件を補間していない。表面端部を除いたデータを優先し、ない場合は全表面データを使用する。図は初期メッシュの面接続を使い、欠損領域を架空の三角形で埋めていない。',SMALL),PageBreak()]
    for index in range(0,len(rows),2):
        story.append(p(f'比較マップ / {label} / {index+1}-{min(index+2,len(rows))} of {len(rows)}',SMALL))
        for row in rows[index:index+2]:
            original=root/row['map_file']
            assets=root.parent.parent.parent/'tmp/pdfs/atlas_assets'
            assets.mkdir(parents=True,exist_ok=True)
            compressed=assets/(original.stem+'.jpg')
            if not compressed.exists() or compressed.stat().st_mtime<original.stat().st_mtime:
                PILImage.open(original).convert('RGB').save(compressed,quality=80,optimize=True)
            story.append(Image(str(compressed),width=730,height=730*3.7/11,hAlign='CENTER'))
        story.append(PageBreak())
    # Explicit pages make the tabular appendix easy to cite and inspect.
    for index in range(0,len(rows),22):
        story.append(p(f'精度一覧 / {index+1}-{min(index+22,len(rows))}',HEADING))
        values=[['組織','rho','seed','sd','beta','相関 r','RMSE','bias','振幅比']]
        for row in rows[index:index+22]:
            values.append([row['texture'],row['rho'],row['seed'],row['sd'],f"{number(row,'beta'):.5f}",fmt(row['nodal_pearson']),
                f"{number(row,'raw_height_rmse'):.3g}",f"{number(row,'mean_height_bias'):.3g}",fmt(row['std_ratio'])])
        story.append(table(values,[75,55,45,40,90,80,110,110,90]))
        if index+22<len(rows):story.append(PageBreak())
    def footer(canvas,doc):
        canvas.setFont(FONT,8);canvas.setFillColor(colors.HexColor('#536574'))
        canvas.drawString(28,15,'Initial-only K model | No fitting to simulation height | 2026-10-15')
        canvas.drawRightString(813,15,str(doc.page))
    doc=SimpleDocTemplate(str(output),pagesize=landscape(A4),rightMargin=28,leftMargin=28,topMargin=25,bottomMargin=28,
        title=f'Initial K surface-height prediction - {label}',author='Research comparison',pageCompression=1)
    doc.build(story,onFirstPage=footer,onLaterPages=footer)
    count=len(PdfReader(output).pages)
    expected=2+math.ceil(len(rows)/2)+math.ceil(len(rows)/22)
    assert count==expected,(output,count,expected)
    return count


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,default=Path('output/pdf/all_cases_20261015'));parser.add_argument('--pdf-only',action='store_true');args=parser.parse_args()
    root=args.root.resolve()
    with (root/'accuracy_all_cases.csv').open(encoding='utf-8-sig') as stream:rows=list(csv.DictReader(stream))
    counts={}
    counts['comparison_atlas_all_240_cases.pdf']=assemble(root,rows,root/'comparison_atlas_all_240_cases.pdf','全240ケース')
    for rho in sorted(set(x['rho'] for x in rows),key=float):
        subset=[x for x in rows if x['rho']==rho];name=f'comparison_atlas_rho_{float(rho):g}.pdf'
        counts[name]=assemble(root,subset,root/name,f'rho={float(rho):g} / {len(subset)}ケース')
    for index,row in enumerate(rows):row['atlas_page']=3+index//2
    with (root/'accuracy_all_cases.csv').open('w',encoding='utf-8-sig',newline='') as stream:
        writer=csv.DictWriter(stream,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    text='''# 初期Kによる全ケース表面高さ予測 - 指導教員確認用

2026年10月15日時点の既存state13高さデータ240ケース。Kベースの最新モデルのみ。

## 最初に開くファイル
- comparison_atlas_all_240_cases.pdf: 計算条件、読み方、全240ケースの予測／解析比較、精度表。
- comparison_atlas_rho_*.pdf: 同じ内容をひずみ比ごとに分割。
- accuracy_all_cases.csv: 全240ケースの精度。atlas_page列が全ケース版PDFの掲載ページ。
- accuracy_by_texture_rho.csv: ひずみ比・組織別集計。ケースを等重みで集計。
- individual_maps/: ケース別の比較PNG。

## 条件
m=0.05、指定相当対数ひずみ=0.1、粒間結合lambda=1、面内配合alpha=0.5、低K抵抗あり、初期指標の標準化なし。K以外の指標を高さ予測の入力に混合していない。応力比betaは初期全粒の体積平均D_TD/D_RDが指定rhoとなるよう自動逆算。どの条件も実測高さから選択・調整していない。

周囲とのK差による沈み込みと、RD・TD伸長差（粒間方向を考慮）による沈み込みを配合し、粒間結合で周囲へ伝える。正K面積平均よりKが小さい粒ほど伝達を弱める。これは力学平衡を解くCPモデルではなく、追加仮説を含む表面グラフモデル。

## 表示と評価
- 左：初期Kからの予測。右：state13の解析高さ。
- 高さは元のz座標。正規化・実測平均への移動・振幅合わせはしていない。
- ペアごとに予測・解析節点高さをプールした2〜98百分位を共通色範囲とする。ケース間では色範囲が異なる。
- 相関と誤差は表示範囲によらず、対応する全節点IDで計算。
- nodal_pearson: 節点高さのPearson相関。位置分布の一致をみるが、振幅は保証しない。
- raw_height_rmse: sqrt(mean((z_pred-z_actual)^2))。
- mean_height_bias: mean(z_pred-z_actual)。
- centered_height_rmse: 誤差の平均だけを差し引いたRMSE。評価用であり予測や図は変更しない。
- predicted_height_std / actual_height_std: 高さの母標準偏差（ddof=0）。
- std_ratio: predicted_height_std/actual_height_std。1が振幅一致。
- 元座標の長さ単位は付け替えていない。図は数値を1000倍して「x10^-3」表記。
- 初期モデルの平均ひずみ比の一致は、全せん断成分や変形中の局所ひずみの一致を保証しない。
- 指定ひずみ0.1はstate13の実測値に合わせたものではない。RMSEやbiasは平均板厚条件の違いも含む。

## 対象・欠落
既存の高さ出力が存在する240条件を対象とし、未実行の条件組合せは追加していない。state13までの比較可能な高さケースは全240件で、予測失敗は0件。表面端部除外データを優先、なければraw表面データ。source_manifest.csvに実測元ファイル・ハッシュを記録。

## 詳細データと再現
- data/<case>/<config>/: 初期粒指標、粒間重み、予測高さ、予測条件、state13実測座標、節点比較表。
- initial_inputs/: 各ケースの初期方位、およびseedごとの初期nodes/elements。
- reproduce/: 使用コードとモデル説明のスナップショット。
- conditions.json: 共通条件。各caseのmodel.jsonに自動計算beta・初期平均rho等。
- source_manifest.csv: 入力・実測の元ファイルとSHA256。

プロジェクトPython環境で、保存したsrcとtoolsをプロジェクトルートに置いて実行：
python -m tools.theme1.predict_neighbor_height --outputs <解析出力ルート> --orientations <initial_inputs/inputs/orientation> --spatial-models <initial_inputs/spatial_model> --output-dir <再計算先>
python -m tools.theme1.build_all_case_atlas --root <再計算先の親>
図の再作成にはdata/evaluation.csvのdirectoryとheight_sourceを展開先に合わせる。数値比較は各caseのactual_coordinates_state13.csvとevaluation_predicted_coordinates.csvから独立に再計算可能。元のd3plotや変形履歴は同梱していない。予測は変形履歴を必要としない。

共有用ZIPはPDF・CSV・説明のみ。個別PNGと詳細再現データは別ZIP。
'''
    (root/'README_先生向け.md').write_text(text,encoding='utf-8')
    (root/'pdf_page_counts.json').write_text(json.dumps(counts,indent=2)+'\n')
    shared=['comparison_atlas_all_240_cases.pdf','accuracy_all_cases.csv','accuracy_by_texture_rho.csv','README_先生向け.md','conditions.json','source_manifest.csv']
    shutil.copy2(Path(__file__),root/'reproduce/tools/theme1'/Path(__file__).name)
    for archive,files in [
        ('teacher_review_package.zip',[root/x for x in shared]),
        ('individual_comparison_maps.zip',list((root/'individual_maps').glob('*.png'))),
        ('prediction_data_and_reproduction.zip',[x for folder in ['data','initial_inputs','reproduce'] for x in (root/folder).rglob('*') if x.is_file()]+[root/'conditions.json',root/'source_manifest.csv',root/'README_先生向け.md'])]:
        if args.pdf_only and archive!='teacher_review_package.zip':continue
        with zipfile.ZipFile(root/archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as zipped:
            for file in files:zipped.write(file,file.relative_to(root))
    print(json.dumps(counts,indent=2))
    print('Packages verified:',len(rows),'cases')


if __name__=='__main__':main()
