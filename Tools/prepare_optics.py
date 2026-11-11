"""Build a compact, offline optical table from pinned source files. No source code is executed.
Inputs live under Tools/OpticsSource; see Data/Optics/PROVENANCE.md for URLs/licences.
"""
from pathlib import Path
import csv, io, json, hashlib, zipfile, xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "Tools/OpticsSource"
OUT = ROOT / "Data/Optics"
OUT.mkdir(exist_ok=True)
PINNED_SHA256 = {'jerlov-v0.3.3.zip': '03c211d71125e7ac057f3e4f57185fbc173570d543715f52b1f85f6de8dcafdb', '20221121-Dstl_MIOP_analysis_v3.xlsx': '9fb2b2be2ec49b86f682cd238c03098f8f713958070e3f3e3770e41c2d6102ba', 'ip_jerlov.csv': '3c77b093a0f976651f41ffc267af3f6ecabac88a1556f3ea39fb9ff74a362a9b', 'CIE_xyz_1931_2deg.csv': 'fa663e3535a7e0763a745993a1f0a192eb0275ac46ad2d1befd7626841e713c1', 'CIE_std_illum_D65.csv': 'e76f210bffff3d552ef7113025da5f325d5dfec200dd4b878b1a2f3a507032cb'}
for name, expected_hash in PINNED_SHA256.items():
    assert hashlib.sha256((SRC/name).read_bytes()).hexdigest() == expected_hash, name
archive = zipfile.ZipFile(SRC / "jerlov-v0.3.3.zip")
prefix = archive.namelist()[0].split("/")[0] + "/"
def table(name):
    return list(csv.DictReader(io.StringIO(archive.read(prefix+"jerlov/data/"+name).decode("utf-8"))))
# Validate all exported a/b values against the original authors' rounded 1 nm table.
book = zipfile.ZipFile(SRC / "20221121-Dstl_MIOP_analysis_v3.xlsx")
ns = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
strings = ["".join(si.itertext()) for si in ET.fromstring(book.read("xl/sharedStrings.xml")).findall("m:si", ns)]
cells = {}
for c in ET.fromstring(book.read("xl/worksheets/sheet2.xml")).findall(".//m:c", ns):
    v = c.find("m:v", ns)
    if v is not None: cells[c.attrib["r"]] = strings[int(v.text)] if c.attrib.get("t") == "s" else v.text
primary = {}
for row in range(6, 507):
    wavelength = int(float(cells["B"+str(row)]))
    for index, key in enumerate(["IB", "II", "III", "1C", "3C", "5C"]):
        for quantity, first in [("a", ord("C")), ("b", ord("I"))]:
            primary[key, wavelength, quantity] = float(cells[chr(first+index)+str(row)])
iops = {(r["water_type"], int(r["wavelength_nm"]), r["quantity"]):r for r in table("williamson2022_iop.csv")}
kd = {(r["water_type"], int(r["wavelength_nm"])):r for r in table("jerlov1976_kd.csv")}
primary_kd = {int(r["Wavelength"]):r for r in csv.DictReader((SRC/"ip_jerlov.csv").open()) if r.get("Wavelength", "").strip()}
cmf = {int(r["wavelength_nm"]):r for r in table("cie1931_2deg_cmf.csv")}
d65 = {int(r["wavelength_nm"]):float(r["relative_spectral_power"]) for r in table("cie_d65.csv")}
wavelengths = list(range(400, 701, 5))
# Independently validate every colour-table sample against the official CIE datasets.
primary_cmf = {int(r[0]):[float(v) for v in r[1:]] for r in csv.reader((SRC/"CIE_xyz_1931_2deg.csv").open())}
primary_d65 = {int(r[0]):float(r[1]) for r in csv.reader((SRC/"CIE_std_illum_D65.csv").open())}
for w in wavelengths:
    for i,k in enumerate(["x_bar","y_bar","z_bar"]): assert abs(float(cmf[w][k])-primary_cmf[w][i]) < 1.01e-7, (w,k)
    assert abs(d65[w]-primary_d65[w]) < 1e-10, w
result = {"schema":1, "wavelength_nm":wavelengths, "step_nm":5,
    "cmf_xyz":[primary_cmf[w] for w in wavelengths],
    "d65":[primary_d65[w]/100 for w in wavelengths], "waters":{},
    "iop_source":"Williamson & Hollins 2022, DOI 10.1364/AO.470464; Dstl figshare 20290782 v3",
    "kd_source":"Jerlov classification Kd, primary Dstl ip_jerlov.csv; historical class table, not co-located IOP measurements",
    "carrier":"jerlov 0.3.3 (Zenodo 23149627), e19934a; tables checked against primary files",
    "cie_source":"CIE 2019, DOI 10.25039/CIE.DS.xvudnb9b and 10.25039/CIE.DS.hjfjmt59; CC BY-SA 4.0; cropped to 400-700 nm and sampled at 5 nm",
    "licence":"Crown copyright (2022), Dstl. OGL v3.0; figshare metadata also CC BY 4.0. Carrier Apache-2.0.",
    "sha256":{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [SRC/name for name in PINNED_SHA256]}}
for key, kd_col in zip(["IB","II","III","1C","3C","5C"],["c_IB","d_II","e_III","f_1C","g_3C","h_5C"]):
    water = {"a":[],"b":[],"kd":[],"iop_status":[],"kd_status":[]}
    for w in wavelengths:
        for q in ["a","b"]:
            row=iops[key,w,q]
            v=float(row["value_per_m"])
            assert abs(v-primary[key,w,q]) < 1e-12, (key,w,q)
            assert v>=0
            water[q].append(v)
        value=float(kd[key,w]["Kd_downwelling_per_m"])
        assert abs(value-float(primary_kd[w][kd_col]))<1e-12
        water["kd"].append(value)
        water["iop_status"].append(iops[key,w,"a"]["status"])
        water["kd_status"].append(kd[key,w]["status"])
    result["waters"][key]=water
path=OUT/"water_spectra.dat"
path.write_text(json.dumps(result,separators=(",",":"),ensure_ascii=False)+"\n",encoding="utf-8")
(OUT/"jerlov-LICENSE.txt").write_bytes(archive.read(prefix+"LICENSE"))
(OUT/"jerlov-NOTICE.txt").write_bytes(archive.read(prefix+"NOTICE"))
print(f"Exported {len(result['waters'])} profiles x {len(wavelengths)} wavelengths; {path.stat().st_size} bytes. Primary a/b/Kd checks pass.")

(OUT/"CIE-NOTICE.txt").write_text("""Colour reference data: International Commission on Illumination (CIE), Vienna, AT (2019).
Colour-matching functions of CIE 1931 standard colorimetric observer.
https://doi.org/10.25039/CIE.DS.xvudnb9b
CIE standard illuminant D65. https://doi.org/10.25039/CIE.DS.hjfjmt59
Licensed under Creative Commons Attribution-ShareAlike 4.0 International:
https://creativecommons.org/licenses/by-sa/4.0/
Changes: wavelength subset 400-700 nm at 5 nm, D65 divided by 100, bundled in water_spectra.dat.
The derived table water_spectra.dat is distributed under CC BY-SA 4.0, retaining the
Dstl/OGL/CC BY and jerlov attribution recorded in that file and jerlov-NOTICE.txt.
No endorsement by the source authors or CIE is implied.
""",encoding="utf-8")
