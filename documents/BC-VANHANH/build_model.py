import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter as gl
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.formatting.rule import CellIsRule
from openpyxl.workbook.defined_name import DefinedName

OUT = '/home/ubuntu/BC_Unit_Economics_Model.xlsx'

# ── STYLES ──
NY = PatternFill('solid', fgColor='003366')
GD = PatternFill('solid', fgColor='FFB800')
LB = PatternFill('solid', fgColor='E8F4FD')
LG = PatternFill('solid', fgColor='F2F2F2')
GN = PatternFill('solid', fgColor='C6EFCE')
YL = PatternFill('solid', fgColor='FFEB9C')
RD = PatternFill('solid', fgColor='FFC7CE')
DB = PatternFill('solid', fgColor='D6E4F0')

FS = Font('Arial', bold=True, size=12, color='FFFFFF')
FH = Font('Arial', bold=True, size=10)
FN = Font('Arial', size=10)
FI = Font('Arial', size=10, color='0000FF')
FB = Font('Arial', bold=True, size=10)
FT = Font('Arial', bold=True, size=14, color='003366')
FG = Font('Arial', size=10, color='008000')
FBI = Font('Arial', bold=True, size=10, color='003366')

BD = Border(left=Side('thin'), right=Side('thin'), top=Side('thin'), bottom=Side('thin'))
AC = Alignment(horizontal='center', vertical='center')
AL = Alignment(horizontal='left', vertical='center', wrap_text=True)

RI = "'\u0110\u1ea7u V\u00e0o'"  # 'Đầu Vào'
RP = "'P&L 12T'"
RU1 = "'UE G1-G4'"
RU2 = "'UE G5-G7'"
RBE = "'H\u00f2a V\u1ed1n'"  # 'Hòa Vốn'

PKG = ["G1 \u2013 BC Performance Ads\u2122","G2 \u2013 BC SEO & Content\u2122",
       "G3 \u2013 BC Social Media\u2122","G4 \u2013 BC TikTok & Social Commerce\u2122",
       "G5 \u2013 BC Digital Brand\u2122","G6 \u2013 BC Marketing Automation\u2122",
       "G7 \u2013 BC Total Growth\u2122"]

PRICE = [[10.5,20,37.5],[10,23,45],[8,18.5,32.5],[10,25,50],[20,47.5,95],[6.5,16,35],[45,80,160]]
G6S = [12.5,27.5,65]
M1C = [[6,12.5,27],[6.5,15,31.5],[9.5,17.5,36],[12,25,52.5],[15,34,67.5],[23.5,38.5,62],[46.5,76,145]]
M2C = [[4,9,18.5],[5,11.5,23],[6,12.5,29.5],[8.5,0,0],[9.5,23,0],[0,0,0],[38.5,0,0]]
DCLI = [[3,2,1],[2,1,0],[2,1,0],[1,1,0],[1,0,0],[0,0,0],[0,1,0]]

def sc(c, v=None, fl=None, ft=None, nf=None, al_=None):
    if v is not None: c.value = v
    if fl: c.fill = fl
    if ft: c.font = ft
    if nf: c.number_format = nf
    c.alignment = al_ or AC
    c.border = BD
    return c

def shdr(ws, r, t, nc=6):
    ws.merge_cells(start_row=r, start_column=1, end_row=r, end_column=nc)
    sc(ws.cell(r,1), t, NY, FS, al_=AL)
    for c in range(2, nc+1):
        ws.cell(r,c).fill = NY; ws.cell(r,c).border = BD

def chdr(ws, r, hs):
    for i,h in enumerate(hs,1):
        sc(ws.cell(r,i), h, LG, FH)

# ═══════════════════════════════════
# CREATE WORKBOOK
# ═══════════════════════════════════
wb = openpyxl.Workbook()
ws_dash = wb.active; ws_dash.title = "Dashboard"
ws_inp = wb.create_sheet("\u0110\u1ea7u V\u00e0o")  # Đầu Vào
ws_ue1 = wb.create_sheet("UE G1-G4")
ws_ue2 = wb.create_sheet("UE G5-G7")
ws_pl = wb.create_sheet("P&L 12T")
ws_be = wb.create_sheet("H\u00f2a V\u1ed1n")  # Hòa Vốn
ws_sc = wb.create_sheet("K\u1ecbch B\u1ea3n")  # Kịch Bản

print("Workbook created with sheets:", wb.sheetnames)

# ═══════════════════════════════════
# TAB 2: ĐẦU VÀO
# ═══════════════════════════════════
ws = ws_inp
ws.sheet_properties.tabColor = "003366"
ws.column_dimensions['A'].width = 36
ws.column_dimensions['B'].width = 18
for c in 'CDEF': ws.column_dimensions[c].width = 15
ws.column_dimensions['G'].width = 3
ws.column_dimensions['H'].width = 32
for c in 'IJK': ws.column_dimensions[c].width = 13
ws.column_dimensions['L'].width = 3
ws.column_dimensions['M'].width = 32
for c in 'NOP': ws.column_dimensions[c].width = 13

ws.merge_cells('A1:F1')
sc(ws.cell(1,1), "C\u1ea4U H\u00ccNH \u0110\u1ea6U V\u00c0O \u2013 M\u00d4 H\u00ccNH T\u00c0I CH\u00cdNH BC VI\u1ec6T NAM", ft=FT, al_=AL)

# ── Section A: Clients ──
shdr(ws, 3, "PH\u1ea6N A \u2013 S\u1ed0 KH\u00c1CH H\u00c0NG HI\u1ec6N T\u1ea0I / K\u1ebe HO\u1ea0CH")
chdr(ws, 4, ["G\u00f3i d\u1ecbch v\u1ee5", "M\u00f4 h\u00ecnh NS", "C\u01a1 B\u1ea3n (CB)", "Ti\u00eau Chu\u1ea9n (TC)", "Cao C\u1ea5p (CC)", "T\u1ed5ng"])

dv = DataValidation(type="list", formula1='"M\u00f4 h\u00ecnh 1,M\u00f4 h\u00ecnh 2"', allow_blank=False)
dv.promptTitle = "M\u00f4 h\u00ecnh"
dv.prompt = "Ch\u1ecdn m\u00f4 h\u00ecnh nh\u00e2n s\u1ef1"
ws.add_data_validation(dv)

for i in range(7):
    r = 5+i
    sc(ws.cell(r,1), PKG[i], ft=FN, al_=AL)
    sc(ws.cell(r,2), "M\u00f4 h\u00ecnh 1", GD, FI)
    dv.add(ws.cell(r,2))
    for j in range(3):
        sc(ws.cell(r,3+j), DCLI[i][j], GD, FI, '#,##0')
    sc(ws.cell(r,6), f'=SUM(C{r}:E{r})', LB, FN, '#,##0')

sc(ws.cell(12,1), "T\u1ed4NG KH\u00c1CH H\u00c0NG", ft=FB, al_=AL)
sc(ws.cell(12,2), "", LB)
for c in range(3,7):
    sc(ws.cell(12,c), f'=SUM({gl(c)}5:{gl(c)}11)', LB, FB, '#,##0')

# ── Section B: Prices ──
shdr(ws, 14, "PH\u1ea6N B \u2013 GI\u00c1 D\u1ecaCH V\u1ee4 TRUNG B\u00ccNH (tri\u1ec7u VND/th\u00e1ng)", 5)
chdr(ws, 15, ["G\u00f3i d\u1ecbch v\u1ee5", "", "C\u01a1 B\u1ea3n", "Ti\u00eau Chu\u1ea9n", "Cao C\u1ea5p"])

for i in range(7):
    r = 16+i
    sc(ws.cell(r,1), PKG[i], ft=FN, al_=AL)
    sc(ws.cell(r,2), "", ft=FN)
    for j in range(3):
        sc(ws.cell(r,3+j), PRICE[i][j], GD, FI, '#,##0.0')

sc(ws.cell(23,1), "G6 \u2013 Ph\u00ed Setup (m\u1ed9t l\u1ea7n)", ft=Font('Arial', italic=True, size=10), al_=AL)
sc(ws.cell(23,2), "", ft=FN)
for j in range(3):
    sc(ws.cell(23,3+j), G6S[j], GD, FI, '#,##0.0')

# ── Section C: Staff ──
shdr(ws, 25, "PH\u1ea6N C \u2013 CHI PH\u00cd NH\u00c2N S\u1ef0", 2)
sc(ws.cell(26,1), "L\u01b0\u01a1ng tham chi\u1ebfu (tri\u1ec7u/th\u00e1ng gross)", ft=Font('Arial',italic=True,size=10), al_=AL)
chdr(ws, 27, ["V\u1ecb tr\u00ed", "L\u01b0\u01a1ng gross"])

salaries = [("Junior Specialist (0-2 n\u0103m)",10.5),("Mid-level (2-4 n\u0103m)",16.5),
            ("Senior Specialist (4+ n\u0103m)",25),("Senior PM / Account Manager",33),
            ("Account Director",52.5)]
for i,(t,s) in enumerate(salaries):
    r = 28+i
    sc(ws.cell(r,1), t, ft=FN, al_=AL)
    sc(ws.cell(r,2), s, GD, FI, '#,##0.0')

sc(ws.cell(34,1), "H\u1ec7 s\u1ed1 overhead (BHXH, th\u01b0\u1edfng...)", ft=FB, al_=AL)
sc(ws.cell(34,2), 1.15, GD, FI, '0.00')
sc(ws.cell(35,1), "S\u1ed1 nh\u00e2n vi\u00ean hi\u1ec7n t\u1ea1i (headcount)", ft=FB, al_=AL)
sc(ws.cell(35,2), 5, GD, FI, '#,##0')

# ── Section D: Fixed Costs ──
shdr(ws, 37, "PH\u1ea6N D \u2013 CHI PH\u00cd C\u1ed0 \u0110\u1ecaNH H\u00c0NG TH\u00c1NG (tri\u1ec7u VND)", 2)
chdr(ws, 38, ["H\u1ea1ng m\u1ee5c", "S\u1ed1 ti\u1ec1n"])

fixed = [("Thu\u00ea v\u0103n ph\u00f2ng",15),("L\u01b0\u01a1ng qu\u1ea3n l\u00fd (BG\u0110)",30),
         ("Chi ph\u00ed c\u00f4ng c\u1ee5 SaaS",13),("Chi ph\u00ed kh\u00e1c (\u0111i\u1ec7n, internet...)",5),
         ("Kh\u1ea5u hao thi\u1ebft b\u1ecb",3),("Marketing cho BC",5)]
for i,(t,v) in enumerate(fixed):
    r = 39+i
    sc(ws.cell(r,1), t, ft=FN, al_=AL)
    sc(ws.cell(r,2), v, GD, FI, '#,##0.0')

sc(ws.cell(45,1), "T\u1ed4NG CHI PH\u00cd C\u1ed0 \u0110\u1ecaNH", ft=FB, al_=AL)
sc(ws.cell(45,2), '=SUM(B39:B44)', LB, FB, '#,##0.0')

# ── Section E: Growth ──
shdr(ws, 47, "PH\u1ea6N E \u2013 GI\u1ea2 \u0110\u1ecaNH T\u0102NG TR\u01af\u1edeNG", 2)
chdr(ws, 48, ["Th\u00f4ng s\u1ed1", "Gi\u00e1 tr\u1ecb"])
sc(ws.cell(49,1), "T\u1ed1c \u0111\u1ed9 t\u0103ng KH m\u1ed7i th\u00e1ng (%)", ft=FN, al_=AL)
sc(ws.cell(49,2), 0.10, GD, FI, '0.0%')
sc(ws.cell(50,1), "T\u1ef7 l\u1ec7 churn KH m\u1ed7i th\u00e1ng (%)", ft=FN, al_=AL)
sc(ws.cell(50,2), 0.05, GD, FI, '0.0%')

# ── Reference Tables ──
ws.merge_cells('H3:K3')
sc(ws.cell(3,8), "B\u1ea2NG CHI PH\u00cd NH\u00c2N S\u1ef0/KH (tri\u1ec7u/th\u00e1ng)", ft=FBI, al_=AL)
for c in range(9,12): ws.cell(3,c).fill = PatternFill()

ws.merge_cells('H4:K4')
sc(ws.cell(4,8), "M\u00d4 H\u00ccNH 1 (Senior PM + Junior)", DB, FH, al_=AL)
for c in range(9,12): ws.cell(4,c).fill = DB

ref_hdrs = ["G\u00f3i", "CB", "TC", "CC"]
for i,h in enumerate(ref_hdrs):
    sc(ws.cell(5,8+i) if i==0 else ws.cell(5,8+i), h, LG, FH) if True else None
for i,h in enumerate(ref_hdrs):
    sc(ws.cell(5,8+i), h, LG, FH)

for i in range(7):
    r = 6+i
    sc(ws.cell(r,8), PKG[i].split(' \u2013 ')[0], ft=FN, al_=AL)
    for j in range(3):
        sc(ws.cell(r,9+j), M1C[i][j], ft=FN, nf='#,##0.0')

ws.merge_cells('M3:P3')
sc(ws.cell(3,13), "", ft=FBI)
ws.merge_cells('M4:P4')
sc(ws.cell(4,13), "M\u00d4 H\u00ccNH 2 (All Junior)", DB, FH, al_=AL)
for c in range(14,17): ws.cell(4,c).fill = DB

for i,h in enumerate(ref_hdrs):
    sc(ws.cell(5,13+i), h, LG, FH)

for i in range(7):
    r = 6+i
    sc(ws.cell(r,13), PKG[i].split(' \u2013 ')[0], ft=FN, al_=AL)
    for j in range(3):
        val = M2C[i][j]
        sc(ws.cell(r,14+j), val if val > 0 else "N/A", ft=FN, nf='#,##0.0')

ws.freeze_panes = 'A5'

# ═══════════════════════════════════
# TAB 3: UE G1-G4
# ═══════════════════════════════════
ws = ws_ue1
ws.sheet_properties.tabColor = "2E75B6"
ws.column_dimensions['A'].width = 28
for c in 'BCD': ws.column_dimensions[c].width = 18

ws.merge_cells('A1:D1')
sc(ws.cell(1,1), "UNIT ECONOMICS \u2013 G\u00d3I 1 \u0110\u1ebeN 4", ft=FT, al_=AL)

ue_labels = ["Doanh thu/KH/th\u00e1ng", "Chi ph\u00ed NS/KH/th\u00e1ng", "Chi ph\u00ed tools/KH",
             "L\u1ee3i nhu\u1eadn g\u1ed9p/KH", "Bi\u00ean LN g\u1ed9p (%)", "Chi ph\u00ed overhead/KH",
             "L\u1ee3i nhu\u1eadn r\u00f2ng/KH", "Bi\u00ean LN r\u00f2ng (%)", "S\u1ed1 KH h\u00f2a v\u1ed1n"]
tier_hdrs = ["Ch\u1ec9 s\u1ed1", "C\u01a1 B\u1ea3n (CB)", "Ti\u00eau Chu\u1ea9n (TC)", "Cao C\u1ea5p (CC)"]

for gi in range(4):
    sr = 3 + gi * 12
    shdr(ws, sr, PKG[gi], 4)
    chdr(ws, sr+1, tier_hdrs)
    for li, lbl in enumerate(ue_labels):
        r = sr + 2 + li
        sc(ws.cell(r, 1), lbl, ft=FB if li in [3,4,7,8] else FN, al_=AL)
    
    for tj in range(3):
        col = 2+tj; cl = gl(col)
        pr = 16+gi; cr = 6+gi  # price row, ref cost row (ref table starts at row 6)
        ir = 5+gi  # input client/model row
        pcol = gl(3+tj); m1c = gl(9+tj); m2c = gl(14+tj)
        
        rev_r = sr+2
        sc(ws.cell(rev_r,col), f'={RI}!{pcol}{16+gi}', LB, FG, '#,##0.0')
        
        staff_r = sr+3
        # Use ref table rows 6+gi (aligned with ref table, not client row)
        sc(ws.cell(staff_r,col), f'=IF({RI}!$B${ir}="M\u00f4 h\u00ecnh 1",{RI}!${m1c}${cr},{RI}!${m2c}${cr})*{RI}!$B$34', LB, FN, '#,##0.0')
        
        tools_r = sr+4
        sc(ws.cell(tools_r,col), f'=IFERROR({RI}!$B$41/{RI}!$F$12,0)', LB, FN, '#,##0.0')
        
        gp_r = sr+5
        sc(ws.cell(gp_r,col), f'={cl}{rev_r}-{cl}{staff_r}-{cl}{tools_r}', LB, FB, '#,##0.0')
        
        gm_r = sr+6
        sc(ws.cell(gm_r,col), f'=IF({cl}{rev_r}=0,0,{cl}{gp_r}/{cl}{rev_r})', LB, FN, '0.0%')
        
        oh_r = sr+7
        sc(ws.cell(oh_r,col), f'=IFERROR(({RI}!$B$45-{RI}!$B$41)/{RI}!$F$12,0)', LB, FN, '#,##0.0')
        
        np_r = sr+8
        sc(ws.cell(np_r,col), f'={cl}{gp_r}-{cl}{oh_r}', LB, FB, '#,##0.0')
        
        nm_r = sr+9
        sc(ws.cell(nm_r,col), f'=IF({cl}{rev_r}=0,0,{cl}{np_r}/{cl}{rev_r})', LB, FN, '0.0%')
        
        be_r = sr+10
        sc(ws.cell(be_r,col), f'=IFERROR(ROUNDUP({RI}!$B$45/IF({cl}{rev_r}-{cl}{staff_r}<=0,0.001,{cl}{rev_r}-{cl}{staff_r}),0),0)', LB, FN, '#,##0')

# Summary heatmap
sum_sr = 3 + 4*12 + 1  # after 4 package blocks
shdr(ws, sum_sr, "T\u00d3M T\u1eaeT BI\u00caN L\u1ee2I NHU\u1eacN G\u1ed8P", 4)
chdr(ws, sum_sr+1, ["G\u00f3i", "CB", "TC", "CC"])
for gi in range(4):
    r = sum_sr+2+gi
    gm_r_src = 3 + gi*12 + 6  # gross margin row for this package
    sc(ws.cell(r,1), PKG[gi].split('\u2122')[0], ft=FN, al_=AL)
    for tj in range(3):
        sc(ws.cell(r,2+tj), f'={gl(2+tj)}{gm_r_src}', LB, FN, '0.0%')

cf_range = f'B{sum_sr+2}:D{sum_sr+5}'
ws.conditional_formatting.add(cf_range, CellIsRule(operator='greaterThan', formula=['0.4'], fill=GN))
ws.conditional_formatting.add(cf_range, CellIsRule(operator='between', formula=['0.2','0.4'], fill=YL))
ws.conditional_formatting.add(cf_range, CellIsRule(operator='lessThan', formula=['0.2'], fill=RD))

ws.freeze_panes = 'A3'

# ═══════════════════════════════════
# TAB 4: UE G5-G7
# ═══════════════════════════════════
ws = ws_ue2
ws.sheet_properties.tabColor = "2E75B6"
ws.column_dimensions['A'].width = 32
for c in 'BCD': ws.column_dimensions[c].width = 18

ws.merge_cells('A1:D1')
sc(ws.cell(1,1), "UNIT ECONOMICS \u2013 G\u00d3I 5 \u0110\u1ebe N 7", ft=FT, al_=AL)

# ── G5: Digital Brand (project-based) ──
shdr(ws, 3, PKG[4], 4)
chdr(ws, 4, ["Ch\u1ec9 s\u1ed1", "C\u01a1 B\u1ea3n", "Ti\u00eau Chu\u1ea9n", "Cao C\u1ea5p"])

g5_labels = ["DT/d\u1ef1 \u00e1n","CP NS/d\u1ef1 \u00e1n","CP tools/d\u1ef1 \u00e1n",
             "LN g\u1ed9p/d\u1ef1 \u00e1n","Bi\u00ean LN g\u1ed9p (%)",
             "S\u1ed1 d\u1ef1 \u00e1n/th\u00e1ng","DT t\u1ed5ng/th\u00e1ng","LN t\u1ed5ng/th\u00e1ng"]
for li,lbl in enumerate(g5_labels):
    sc(ws.cell(5+li,1), lbl, ft=FB if li in [3,4] else FN, al_=AL)

gi5 = 4  # G5 index
for tj in range(3):
    col=2+tj; cl=gl(col); cr=6+gi5; ir=5+gi5
    pcol=gl(3+tj); m1c=gl(9+tj); m2c=gl(14+tj)
    sc(ws.cell(5,col), f'={RI}!{pcol}{16+gi5}', LB, FG, '#,##0.0')  # revenue/project
    sc(ws.cell(6,col), f'=IF({RI}!$B${ir}="M\u00f4 h\u00ecnh 1",{RI}!${m1c}${cr},{RI}!${m2c}${cr})*{RI}!$B$34', LB, FN, '#,##0.0')
    sc(ws.cell(7,col), f'=IFERROR({RI}!$B$41/{RI}!$F$12,0)', LB, FN, '#,##0.0')
    sc(ws.cell(8,col), f'={cl}5-{cl}6-{cl}7', LB, FB, '#,##0.0')
    sc(ws.cell(9,col), f'=IF({cl}5=0,0,{cl}8/{cl}5)', LB, FN, '0.0%')
    sc(ws.cell(10,col), f'={RI}!{pcol}{ir}', LB, FG, '#,##0')  # projects/month from client count
    sc(ws.cell(11,col), f'={cl}5*{cl}10', LB, FB, '#,##0.0')
    sc(ws.cell(12,col), f'={cl}8*{cl}10', LB, FB, '#,##0.0')

# ── G6: Marketing Automation ──
shdr(ws, 14, PKG[5], 4)
chdr(ws, 15, ["Ch\u1ec9 s\u1ed1", "C\u01a1 B\u1ea3n", "Ti\u00eau Chu\u1ea9n", "Cao C\u1ea5p"])

g6_labels = ["Ph\u00ed setup (1 l\u1ea7n)","DT h\u00e0ng th\u00e1ng/KH","CP NS/KH/th\u00e1ng",
             "CP tools/KH","LN h\u00e0ng th\u00e1ng/KH","Bi\u00ean LN th\u00e1ng (%)",
             "Th\u00e1ng recover setup","S\u1ed1 KH","DT t\u1ed5ng/th\u00e1ng","LN t\u1ed5ng/th\u00e1ng"]
for li,lbl in enumerate(g6_labels):
    sc(ws.cell(16+li,1), lbl, ft=FB if li in [4,5,6] else FN, al_=AL)

gi6 = 5
for tj in range(3):
    col=2+tj; cl=gl(col); cr=6+gi6; ir=5+gi6
    pcol=gl(3+tj); m1c=gl(9+tj); m2c=gl(14+tj)
    sc(ws.cell(16,col), f'={RI}!{pcol}23', LB, FG, '#,##0.0')  # setup from row 23
    sc(ws.cell(17,col), f'={RI}!{pcol}{16+gi6}', LB, FG, '#,##0.0')  # monthly price
    sc(ws.cell(18,col), f'=IF({RI}!$B${ir}="M\u00f4 h\u00ecnh 1",{RI}!${m1c}${cr},{RI}!${m2c}${cr})*{RI}!$B$34', LB, FN, '#,##0.0')
    sc(ws.cell(19,col), f'=IFERROR({RI}!$B$41/{RI}!$F$12,0)', LB, FN, '#,##0.0')
    sc(ws.cell(20,col), f'={cl}17-{cl}18-{cl}19', LB, FB, '#,##0.0')
    sc(ws.cell(21,col), f'=IF({cl}17=0,0,{cl}20/{cl}17)', LB, FN, '0.0%')
    sc(ws.cell(22,col), f'=IFERROR(ROUNDUP({cl}16/IF({cl}20<=0,0.001,{cl}20),0),0)', LB, FB, '#,##0')
    sc(ws.cell(23,col), f'={RI}!{pcol}{ir}', LB, FG, '#,##0')  # client count
    sc(ws.cell(24,col), f'={cl}17*{cl}23', LB, FB, '#,##0.0')
    sc(ws.cell(25,col), f'={cl}20*{cl}23', LB, FB, '#,##0.0')

# ── G7: Total Growth ──
shdr(ws, 27, PKG[6], 4)
chdr(ws, 28, ["Ch\u1ec9 s\u1ed1", "Growth Starter", "Growth Pro", "Growth Enterprise"])

g7_labels = ["DT/KH/th\u00e1ng","CP NS/KH/th\u00e1ng","LN g\u1ed9p/KH","Bi\u00ean LN g\u1ed9p (%)",
             "FTE quy \u0111\u1ed5i","DT/FTE (tri\u1ec7u)","S\u1ed1 KH","DT t\u1ed5ng/th\u00e1ng"]
for li,lbl in enumerate(g7_labels):
    sc(ws.cell(29+li,1), lbl, ft=FB if li in [2,3,5] else FN, al_=AL)

gi7 = 6
for tj in range(3):
    col=2+tj; cl=gl(col); cr=6+gi7; ir=5+gi7
    pcol=gl(3+tj); m1c=gl(9+tj); m2c=gl(14+tj)
    sc(ws.cell(29,col), f'={RI}!{pcol}{16+gi7}', LB, FG, '#,##0.0')
    sc(ws.cell(30,col), f'=IF({RI}!$B${ir}="M\u00f4 h\u00ecnh 1",{RI}!${m1c}${cr},{RI}!${m2c}${cr})*{RI}!$B$34', LB, FN, '#,##0.0')
    sc(ws.cell(31,col), f'={cl}29-{cl}30', LB, FB, '#,##0.0')
    sc(ws.cell(32,col), f'=IF({cl}29=0,0,{cl}31/{cl}29)', LB, FN, '0.0%')
    # FTE = staff cost / avg salary (mid-level B30 * overhead B34)
    sc(ws.cell(33,col), f'=IFERROR({cl}30/({RI}!$B$30*{RI}!$B$34),0)', LB, FN, '0.0')
    sc(ws.cell(34,col), f'=IFERROR({cl}29/{cl}33,0)', LB, FB, '#,##0.0')
    sc(ws.cell(35,col), f'={RI}!{pcol}{ir}', LB, FG, '#,##0')
    sc(ws.cell(36,col), f'={cl}29*{cl}35', LB, FB, '#,##0.0')

# Summary heatmap G5-G7
shdr(ws, 38, "T\u00d3M T\u1eaeT BI\u00caN L\u1ee2I NHU\u1eacN G\u1ed8P", 4)
chdr(ws, 39, ["G\u00f3i", "CB", "TC", "CC"])
sc(ws.cell(40,1), "G5 \u2013 Digital Brand", ft=FN, al_=AL)
for tj in range(3): sc(ws.cell(40,2+tj), f'={gl(2+tj)}9', LB, FN, '0.0%')  # G5 gross margin
sc(ws.cell(41,1), "G6 \u2013 Marketing Auto", ft=FN, al_=AL)
for tj in range(3): sc(ws.cell(41,2+tj), f'={gl(2+tj)}21', LB, FN, '0.0%')
sc(ws.cell(42,1), "G7 \u2013 Total Growth", ft=FN, al_=AL)
for tj in range(3): sc(ws.cell(42,2+tj), f'={gl(2+tj)}32', LB, FN, '0.0%')

ws.conditional_formatting.add('B40:D42', CellIsRule(operator='greaterThan', formula=['0.4'], fill=GN))
ws.conditional_formatting.add('B40:D42', CellIsRule(operator='between', formula=['0.2','0.4'], fill=YL))
ws.conditional_formatting.add('B40:D42', CellIsRule(operator='lessThan', formula=['0.2'], fill=RD))

ws.freeze_panes = 'A3'

print("UE tabs built")

# ═══════════════════════════════════
# TAB 5: P&L 12 THÁNG
# ═══════════════════════════════════
ws = ws_pl
ws.sheet_properties.tabColor = "548235"
ws.column_dimensions['A'].width = 30
for ci in range(2, 15):
    ws.column_dimensions[gl(ci)].width = 14

ws.merge_cells('A1:N1')
sc(ws.cell(1,1), "B\u00c1O C\u00c1O L\u00c3I L\u1ed6 D\u1ef0 KI\u1ebe N 12 TH\u00c1NG (tri\u1ec7u VND)", ft=FT, al_=AL)

# Revenue section
shdr(ws, 3, "DOANH THU", 14)
hdrs = ["H\u1ea1ng m\u1ee5c"] + [f"T{i}" for i in range(1,13)] + ["T\u1ed5ng N\u0103m"]
chdr(ws, 4, hdrs)

for gi in range(7):
    r = 5+gi
    sc(ws.cell(r,1), PKG[gi], ft=FN, al_=AL)
    # T1: SUMPRODUCT(clients, prices)
    cr = 5+gi  # client row in input
    pr = 16+gi  # price row in input
    sc(ws.cell(r,2), f'=SUMPRODUCT({RI}!C{cr}:E{cr},{RI}!C{pr}:E{pr})', LB, FN, '#,##0.0')
    for mi in range(3,14):
        sc(ws.cell(r,mi), f'={gl(mi-1)}{r}*(1+{RI}!$B$49-{RI}!$B$50)', LB, FN, '#,##0.0')
    sc(ws.cell(r,14), f'=SUM(B{r}:M{r})', LB, FB, '#,##0.0')

sc(ws.cell(12,1), "T\u1ed4NG DOANH THU", ft=FB, al_=AL)
for ci in range(2,15):
    sc(ws.cell(12,ci), f'=SUM({gl(ci)}5:{gl(ci)}11)', LB, FB, '#,##0.0')

# Staff cost section
shdr(ws, 14, "CHI PH\u00cd NH\u00c2N S\u1ef0", 14)

for gi in range(7):
    r = 15+gi
    sc(ws.cell(r,1), PKG[gi], ft=FN, al_=AL)
    cr = 5+gi; rcr = 6+gi  # input client row, ref cost row
    parts = []
    for tj in range(3):
        cc=gl(3+tj); m1=gl(9+tj); m2=gl(14+tj)
        parts.append(f'IF({RI}!$B${cr}="M\u00f4 h\u00ecnh 1",{RI}!{m1}{rcr},{RI}!{m2}{rcr})*{RI}!{cc}{cr}')
    sc(ws.cell(r,2), f'=({("+".join(parts))})*{RI}!$B$34', LB, FN, '#,##0.0')
    for mi in range(3,14):
        sc(ws.cell(r,mi), f'={gl(mi-1)}{r}*(1+{RI}!$B$49-{RI}!$B$50)', LB, FN, '#,##0.0')
    sc(ws.cell(r,14), f'=SUM(B{r}:M{r})', LB, FB, '#,##0.0')

sc(ws.cell(22,1), "T\u1ed4NG CHI PH\u00cd NS", ft=FB, al_=AL)
for ci in range(2,15):
    sc(ws.cell(22,ci), f'=SUM({gl(ci)}15:{gl(ci)}21)', LB, FB, '#,##0.0')

# Gross Profit
sc(ws.cell(24,1), "L\u1ee2I NHU\u1eacN G\u1ed8P", ft=FB, al_=AL)
for ci in range(2,15):
    sc(ws.cell(24,ci), f'={gl(ci)}12-{gl(ci)}22', LB, FB, '#,##0.0')

sc(ws.cell(25,1), "Bi\u00ean LN g\u1ed9p (%)", ft=FN, al_=AL)
for ci in range(2,15):
    sc(ws.cell(25,ci), f'=IF({gl(ci)}12=0,0,{gl(ci)}24/{gl(ci)}12)', LB, FN, '0.0%')

# Fixed costs
shdr(ws, 27, "CHI PH\u00cd C\u1ed0 \u0110\u1ecaNH H\u00c0NG TH\u00c1NG", 14)
fixed_labels = ["Chi ph\u00ed c\u00f4ng c\u1ee5 SaaS","Thu\u00ea v\u0103n ph\u00f2ng","L\u01b0\u01a1ng BG\u0110",
                "Chi ph\u00ed kh\u00e1c","Kh\u1ea5u hao","Marketing"]
fixed_refs = [41,39,40,42,43,44]  # B row in Input

for fi,(lbl,fref) in enumerate(zip(fixed_labels,fixed_refs)):
    r = 28+fi
    sc(ws.cell(r,1), lbl, ft=FN, al_=AL)
    for ci in range(2,14):
        sc(ws.cell(r,ci), f'={RI}!$B${fref}', LB, FN, '#,##0.0')
    sc(ws.cell(r,14), f'=SUM(B{r}:M{r})', LB, FN, '#,##0.0')

sc(ws.cell(34,1), "T\u1ed4NG CP C\u1ed0 \u0110\u1ecaNH", ft=FB, al_=AL)
for ci in range(2,15):
    sc(ws.cell(34,ci), f'=SUM({gl(ci)}28:{gl(ci)}33)', LB, FB, '#,##0.0')

# EBITDA
sc(ws.cell(36,1), "EBITDA", ft=FB, al_=AL)
for ci in range(2,15):
    sc(ws.cell(36,ci), f'={gl(ci)}24-{gl(ci)}34', LB, FB, '#,##0.0')

sc(ws.cell(37,1), "EBITDA Margin (%)", ft=FN, al_=AL)
for ci in range(2,15):
    sc(ws.cell(37,ci), f'=IF({gl(ci)}12=0,0,{gl(ci)}36/{gl(ci)}12)', LB, FN, '0.0%')

# Metrics
sc(ws.cell(39,1), "S\u1ed0 KH T\u1ed4NG", ft=FB, al_=AL)
sc(ws.cell(39,2), f'={RI}!$F$12', LB, FN, '#,##0')
for ci in range(3,14):
    sc(ws.cell(39,ci), f'=ROUND({gl(ci-1)}39*(1+{RI}!$B$49-{RI}!$B$50),0)', LB, FN, '#,##0')
sc(ws.cell(39,14), f'=M39', LB, FN, '#,##0')

sc(ws.cell(40,1), "DOANH THU / NH\u00c2N VI\u00caN", ft=FN, al_=AL)
for ci in range(2,15):
    sc(ws.cell(40,ci), f'=IFERROR({gl(ci)}12/{RI}!$B$35,0)', LB, FN, '#,##0.0')

# Conditional formatting EBITDA
ws.conditional_formatting.add('B36:N36', CellIsRule(operator='greaterThan', formula=['0'], fill=GN))
ws.conditional_formatting.add('B36:N36', CellIsRule(operator='lessThan', formula=['0'], fill=RD))

ws.freeze_panes = 'B5'
print("P&L tab built")

# ═══════════════════════════════════
# TAB 6: HÒA VỐN
# ═══════════════════════════════════
ws = ws_be
ws.sheet_properties.tabColor = "BF8F00"
ws.column_dimensions['A'].width = 36
for c in 'BCDEFG': ws.column_dimensions[c].width = 15

ws.merge_cells('A1:F1')
sc(ws.cell(1,1), "PH\u00c2N T\u00cdCH H\u00d2A V\u1ed0N", ft=FT, al_=AL)

# Section 1: Break-even by clients
shdr(ws, 3, "H\u00d2A V\u1ed0N THEO S\u1ed0 KH\u00c1CH H\u00c0NG", 3)

be_items = [
    ("T\u1ed5ng doanh thu th\u00e1ng", f'={RP}!B12', '#,##0.0'),
    ("T\u1ed5ng chi ph\u00ed NS th\u00e1ng", f'={RP}!B22', '#,##0.0'),
    ("T\u1ed5ng chi ph\u00ed c\u1ed1 \u0111\u1ecbnh", f'={RI}!$B$45', '#,##0.0'),
    ("S\u1ed1 KH hi\u1ec7n t\u1ea1i", f'={RI}!$F$12', '#,##0'),
    ("DT b\u00ecnh qu\u00e2n/KH", '=IFERROR(B4/B7,0)', '#,##0.0'),
    ("CP NS b\u00ecnh qu\u00e2n/KH", '=IFERROR(B5/B7,0)', '#,##0.0'),
    ("Contribution margin/KH", '=B8-B9', '#,##0.0'),
    ("S\u1ed0 KH H\u00d2A V\u1ed0N", '=IFERROR(ROUNDUP(B6/IF(B10<=0,0.001,B10),0),0)', '#,##0'),
    ("C\u1ea7n th\u00eam (so v\u1edbi hi\u1ec7n t\u1ea1i)", '=IF(B11>B7,B11-B7,0)', '#,##0'),
]
for i,(lbl,frm,nf) in enumerate(be_items):
    r = 4+i
    sc(ws.cell(r,1), lbl, ft=FB if i in [6,7,8] else FN, al_=AL)
    sc(ws.cell(r,2), frm, LB, FG if i<4 else FB if i>=6 else FN, nf)

# Section 2: Break-even by time
shdr(ws, 14, "H\u00d2A V\u1ed0N THEO TH\u1edcI GIAN", 3)

sc(ws.cell(15,1), "EBITDA th\u00e1ng 1", ft=FN, al_=AL)
sc(ws.cell(15,2), f'={RP}!B36', LB, FG, '#,##0.0')

sc(ws.cell(16,1), "T\u1ed1c \u0111\u1ed9 t\u0103ng tr\u01b0\u1edfng r\u00f2ng/th\u00e1ng", ft=FN, al_=AL)
sc(ws.cell(16,2), f'={RI}!$B$49-{RI}!$B$50', LB, FN, '0.0%')

sc(ws.cell(17,1), "TH\u00c1NG D\u1ef0 KI\u1ebe N H\u00d2A V\u1ed0N", ft=FB, al_=AL)
bef = f'=IF({RP}!B36>=0,1,IF({RP}!B12-{RP}!B22<=0,0,IFERROR(ROUNDUP(1+LOG({RI}!$B$45/({RP}!B12-{RP}!B22))/LOG(1+{RI}!$B$49-{RI}!$B$50),0),0)))'
sc(ws.cell(17,2), bef, LB, FB, '#,##0')

# Section 3: Sensitivity
shdr(ws, 19, "\u0110\u1ed8 NH\u1ea0Y BI\u00caN EBITDA: GI\u00c1 vs CHI PH\u00cd NS", 7)
sc(ws.cell(20,1), "Thay \u0111\u1ed5i gi\u00e1 \u2193 \\ Thay \u0111\u1ed5i CP NS \u2192", ft=FH, al_=AL)

changes = [-0.20, -0.10, 0, 0.10, 0.20]
for j,cc in enumerate(changes):
    sc(ws.cell(20,2+j), cc, LG, FH, '0%')

for i,pc in enumerate(changes):
    r = 21+i
    sc(ws.cell(r,1), pc, LG, FH, '0%')
    for j in range(5):
        col = 2+j; cl = gl(col)
        f = f'=IFERROR(({RP}!$B$12*(1+$A{r})-{RP}!$B$22*(1+{cl}$20)-{RI}!$B$45)/IF({RP}!$B$12*(1+$A{r})=0,1,{RP}!$B$12*(1+$A{r})),0)'
        sc(ws.cell(r,col), f, LB, FN, '0.0%')

ws.conditional_formatting.add('B21:F25', CellIsRule(operator='greaterThan', formula=['0.15'], fill=GN))
ws.conditional_formatting.add('B21:F25', CellIsRule(operator='between', formula=['0','0.15'], fill=YL))
ws.conditional_formatting.add('B21:F25', CellIsRule(operator='lessThan', formula=['0'], fill=RD))

# Section 4: Price sensitivity on margin
shdr(ws, 27, "\u0110\u1ed8 NH\u1ea0Y BI\u00caN EBITDA: S\u1ed0 KH vs GI\u00c1", 7)
sc(ws.cell(28,1), "Thay \u0111\u1ed5i s\u1ed1 KH \u2193 \\ Thay \u0111\u1ed5i gi\u00e1 \u2192", ft=FH, al_=AL)

kh_changes = [-0.30, -0.15, 0, 0.15, 0.30]
for j,pc in enumerate(changes):
    sc(ws.cell(28,2+j), pc, LG, FH, '0%')
for i,kc in enumerate(kh_changes):
    r = 29+i
    sc(ws.cell(r,1), kc, LG, FH, '0%')
    for j in range(5):
        col=2+j; cl=gl(col)
        f = f'=IFERROR(({RP}!$B$12*(1+{cl}$28)*(1+$A{r})-{RP}!$B$22*(1+$A{r})-{RI}!$B$45)/IF({RP}!$B$12*(1+{cl}$28)*(1+$A{r})=0,1,{RP}!$B$12*(1+{cl}$28)*(1+$A{r})),0)'
        sc(ws.cell(r,col), f, LB, FN, '0.0%')

ws.conditional_formatting.add('B29:F33', CellIsRule(operator='greaterThan', formula=['0.15'], fill=GN))
ws.conditional_formatting.add('B29:F33', CellIsRule(operator='between', formula=['0','0.15'], fill=YL))
ws.conditional_formatting.add('B29:F33', CellIsRule(operator='lessThan', formula=['0'], fill=RD))

ws.freeze_panes = 'A3'
print("Break-even tab built")

# ═══════════════════════════════════
# TAB 7: KỊCH BẢN
# ═══════════════════════════════════
ws = ws_sc
ws.sheet_properties.tabColor = "C55A11"
ws.column_dimensions['A'].width = 36
for c in 'BCD': ws.column_dimensions[c].width = 20

ws.merge_cells('A1:D1')
sc(ws.cell(1,1), "SO S\u00c1NH 3 K\u1ecaCH B\u1ea2N", ft=FT, al_=AL)

shdr(ws, 3, "GI\u1ea2 \u0110\u1ecaNH K\u1ecaCH B\u1ea2N", 4)
chdr(ws, 4, ["Th\u00f4ng s\u1ed1", "Th\u1eadn Tr\u1ecdng", "C\u01a1 S\u1edf", "L\u1ea1c Quan"])

sc_params = [
    ("T\u1ed1c \u0111\u1ed9 t\u0103ng KH/th\u00e1ng", [0.05, 0.10, 0.15], '0.0%'),
    ("T\u1ef7 l\u1ec7 churn/th\u00e1ng", [0.08, 0.05, 0.03], '0.0%'),
    ("H\u1ec7 s\u1ed1 \u0111i\u1ec1u ch\u1ec9nh gi\u00e1", [0.85, 1.00, 1.10], '0.00'),
]
for i,(lbl,vals,nf) in enumerate(sc_params):
    r = 5+i
    sc(ws.cell(r,1), lbl, ft=FN, al_=AL)
    for j,v in enumerate(vals):
        sc(ws.cell(r,2+j), v, GD, FI, nf)

shdr(ws, 9, "K\u1ebe T QU\u1ea2 D\u1ef0 KI\u1ebe N", 4)
chdr(ws, 10, ["Ch\u1ec9 s\u1ed1", "Th\u1eadn Tr\u1ecdng", "C\u01a1 S\u1edf", "L\u1ea1c Quan"])

result_labels = [
    "DT th\u00e1ng 1 (tri\u1ec7u)",
    "CP NS th\u00e1ng 1",
    "CP c\u1ed1 \u0111\u1ecbnh/th\u00e1ng",
    "EBITDA th\u00e1ng 1",
    "",
    "DT th\u00e1ng 6",
    "CP NS th\u00e1ng 6",
    "EBITDA th\u00e1ng 6",
    "",
    "DT th\u00e1ng 12",
    "CP NS th\u00e1ng 12",
    "EBITDA th\u00e1ng 12",
    "",
    "Th\u00e1ng h\u00f2a v\u1ed1n",
    "Headcount c\u1ea7n T12",
]
for i,lbl in enumerate(result_labels):
    r = 11+i
    if lbl:
        sc(ws.cell(r,1), lbl, ft=FB if 'EBITDA' in lbl or 'h\u00f2a' in lbl else FN, al_=AL)

for j in range(3):
    col = 2+j; cl = gl(col)
    # DT T1 = Base_Rev * price_factor
    sc(ws.cell(11,col), f'={RP}!$B$12*{cl}7', LB, FN, '#,##0.0')
    # CP NS T1
    sc(ws.cell(12,col), f'={RP}!$B$22', LB, FN, '#,##0.0')
    # CP CĐ
    sc(ws.cell(13,col), f'={RI}!$B$45', LB, FN, '#,##0.0')
    # EBITDA T1
    sc(ws.cell(14,col), f'={cl}11-{cl}12-{cl}13', LB, FB, '#,##0.0')
    # DT T6
    sc(ws.cell(16,col), f'={cl}11*(1+{cl}5-{cl}6)^5', LB, FN, '#,##0.0')
    # CP NS T6
    sc(ws.cell(17,col), f'={cl}12*(1+{cl}5-{cl}6)^5', LB, FN, '#,##0.0')
    # EBITDA T6
    sc(ws.cell(18,col), f'={cl}16-{cl}17-{cl}13', LB, FB, '#,##0.0')
    # DT T12
    sc(ws.cell(20,col), f'={cl}11*(1+{cl}5-{cl}6)^11', LB, FN, '#,##0.0')
    # CP NS T12
    sc(ws.cell(21,col), f'={cl}12*(1+{cl}5-{cl}6)^11', LB, FN, '#,##0.0')
    # EBITDA T12
    sc(ws.cell(22,col), f'={cl}20-{cl}21-{cl}13', LB, FB, '#,##0.0')
    # Break-even month
    bef2 = f'=IF({cl}14>=0,1,IF({cl}11-{cl}12<=0,0,IFERROR(ROUNDUP(1+LOG({cl}13/({cl}11-{cl}12))/LOG(1+{cl}5-{cl}6),0),0)))'
    sc(ws.cell(24,col), bef2, LB, FB, '#,##0')
    # Headcount T12
    sc(ws.cell(25,col), f'=ROUND({RI}!$B$35*(1+{cl}5-{cl}6)^11,0)', LB, FN, '#,##0')

# Conditional formatting EBITDA rows
for erow in [14,18,22]:
    rng = f'B{erow}:D{erow}'
    ws.conditional_formatting.add(rng, CellIsRule(operator='greaterThan', formula=['0'], fill=GN))
    ws.conditional_formatting.add(rng, CellIsRule(operator='lessThan', formula=['0'], fill=RD))

ws.freeze_panes = 'A3'
print("Scenarios tab built")

# ═══════════════════════════════════
# TAB 1: DASHBOARD
# ═══════════════════════════════════
ws = ws_dash
ws.sheet_properties.tabColor = "003366"
ws.column_dimensions['A'].width = 34
ws.column_dimensions['B'].width = 20
ws.column_dimensions['C'].width = 20
ws.column_dimensions['D'].width = 20
ws.column_dimensions['E'].width = 22

ws.merge_cells('A1:E1')
sc(ws.cell(1,1), "DASHBOARD \u2013 BC VI\u1ec6T NAM T\u00c0I CH\u00cdNH", ft=Font('Arial',bold=True,size=16,color='003366'), al_=AL)

shdr(ws, 3, "T\u1ed4NG QUAN T\u00c0I CH\u00cdNH TH\u00c1NG HI\u1ec6N T\u1ea0I", 5)

dash_items = [
    ("T\u1ed5ng doanh thu th\u00e1ng", f'={RP}!B12', '#,##0.0', FG),
    ("T\u1ed5ng chi ph\u00ed nh\u00e2n s\u1ef1", f'={RP}!B22', '#,##0.0', FG),
    ("T\u1ed5ng chi ph\u00ed c\u1ed1 \u0111\u1ecbnh", f'={RP}!B34', '#,##0.0', FG),
    ("L\u1ee3i nhu\u1eadn g\u1ed9p", f'={RP}!B24', '#,##0.0', FB),
    ("Bi\u00ean LN g\u1ed9p", f'={RP}!B25', '0.0%', FB),
    ("EBITDA", f'={RP}!B36', '#,##0.0', FB),
    ("EBITDA Margin", f'={RP}!B37', '0.0%', FB),
    ("S\u1ed1 KH hi\u1ec7n t\u1ea1i", f'={RI}!$F$12', '#,##0', FG),
    ("S\u1ed1 KH h\u00f2a v\u1ed1n", f'={RBE}!B11', '#,##0', FG),
    ("Th\u00e1ng h\u00f2a v\u1ed1n d\u1ef1 ki\u1ebfn", f'={RBE}!B17', '#,##0', FG),
]
for i,(lbl,frm,nf,ft_) in enumerate(dash_items):
    r = 4+i
    sc(ws.cell(r,1), lbl, ft=FB if i>=3 else FN, al_=AL)
    sc(ws.cell(r,2), frm, LB, ft_, nf)

# Health status with conditional formatting
sc(ws.cell(4,3), "Tr\u1ea1ng th\u00e1i", LG, FH)
for i in range(len(dash_items)):
    r = 4+i
    if i in [5,6]:  # EBITDA items
        if i == 5:
            sc(ws.cell(r,3), f'=IF(B{r}>0,"\u2714 T\u1ed1t",IF(B{r}>-10,"\u25d0 C\u1ea7n c\u1ea3i thi\u1ec7n","\u2718 Th\u1ea5p"))', LB, FN)
        elif i == 6:
            sc(ws.cell(r,3), f'=IF(B{r}>0.15,"\u2714 T\u1ed1t",IF(B{r}>0,"\u25d0 TB","\u2718 L\u1ed7"))', LB, FN)

# Revenue & margin by package
shdr(ws, 15, "DOANH THU & MARGIN THEO G\u00d3I", 5)
chdr(ws, 16, ["G\u00f3i d\u1ecbch v\u1ee5", "DT/th\u00e1ng", "Bi\u00ean LN g\u1ed9p", "S\u1ed1 KH", "Tr\u1ea1ng th\u00e1i"])

for gi in range(7):
    r = 17+gi
    sc(ws.cell(r,1), PKG[gi], ft=FN, al_=AL)
    sc(ws.cell(r,2), f'={RP}!B{5+gi}', LB, FG, '#,##0.0')
    sc(ws.cell(r,3), f'=IF({RP}!B{5+gi}=0,0,({RP}!B{5+gi}-{RP}!B{15+gi})/{RP}!B{5+gi})', LB, FN, '0.0%')
    sc(ws.cell(r,4), f'={RI}!F{5+gi}', LB, FG, '#,##0')
    sc(ws.cell(r,5), f'=IF(C{r}>0.4,"\u2714 T\u1ed1t",IF(C{r}>0.2,"\u25d0 TB","\u2718 C\u1ea7n c\u1ea3i thi\u1ec7n"))', LB, FN)

# Conditional formatting on margins
ws.conditional_formatting.add('C17:C23', CellIsRule(operator='greaterThan', formula=['0.4'], fill=GN))
ws.conditional_formatting.add('C17:C23', CellIsRule(operator='between', formula=['0.2','0.4'], fill=YL))
ws.conditional_formatting.add('C17:C23', CellIsRule(operator='lessThan', formula=['0.2'], fill=RD))

# Year summary
shdr(ws, 25, "D\u1ef0 B\u00c1O N\u0102M (12 TH\u00c1NG)", 3)
year_items = [
    ("T\u1ed5ng DT n\u0103m", f'={RP}!N12', '#,##0.0'),
    ("T\u1ed5ng LN g\u1ed9p n\u0103m", f'={RP}!N24', '#,##0.0'),
    ("T\u1ed5ng EBITDA n\u0103m", f'={RP}!N36', '#,##0.0'),
    ("EBITDA Margin n\u0103m", f'={RP}!N37', '0.0%'),
    ("S\u1ed1 KH cu\u1ed1i n\u0103m", f'={RP}!M39', '#,##0'),
]
for i,(lbl,frm,nf) in enumerate(year_items):
    r = 26+i
    sc(ws.cell(r,1), lbl, ft=FB, al_=AL)
    sc(ws.cell(r,2), frm, LB, FG, nf)

ws.freeze_panes = 'A3'
print("Dashboard built")

# ═══════════════════════════════════
# NAMED RANGES
# ═══════════════════════════════════
named = [
    ('TotalClients', "'\u0110\u1ea7u V\u00e0o'!$F$12"),
    ('TotalFixed', "'\u0110\u1ea7u V\u00e0o'!$B$45"),
    ('ToolsCost', "'\u0110\u1ea7u V\u00e0o'!$B$41"),
    ('OverheadRate', "'\u0110\u1ea7u V\u00e0o'!$B$34"),
    ('GrowthRate', "'\u0110\u1ea7u V\u00e0o'!$B$49"),
    ('ChurnRate', "'\u0110\u1ea7u V\u00e0o'!$B$50"),
    ('Headcount', "'\u0110\u1ea7u V\u00e0o'!$B$35"),
]
for name, ref in named:
    dn = DefinedName(name, attr_text=ref)
    wb.defined_names.add(dn)

# ═══════════════════════════════════
# SAVE
# ═══════════════════════════════════
wb.save(OUT)
print(f"Saved to {OUT}")
print("Sheet names:", wb.sheetnames)
