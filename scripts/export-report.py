"""Render the implementation report as a self-contained printable HTML file."""

from pathlib import Path
import re
import markdown

root = Path(__file__).resolve().parents[1]
source = root / "docs" / "bao-cao-trien-khai.md"
target = root / "docs" / "bao-cao-trien-khai.html"
content = source.read_text(encoding="utf-8")
content = re.sub(r"```mermaid\n.*?```", "", content, flags=re.DOTALL)
body = markdown.markdown(content, extensions=["tables", "fenced_code"])
target.write_text(
    """<!doctype html><html lang="vi"><head><meta charset="utf-8">
<title>Báo cáo triển khai EcoSense</title><style>
@page { size: A4; margin: 18mm 18mm 16mm; }
body { font-family: Arial, 'Segoe UI', sans-serif; color: #193632; font-size: 11pt; line-height: 1.5; }
h1 { color: #18715f; font-size: 24pt; border-bottom: 3px solid #18715f; padding-bottom: 8px; }
h2 { color: #18715f; font-size: 15pt; margin-top: 22px; break-after: avoid; }
p, li { margin: 6px 0; }
table { border-collapse: collapse; width: 100%; font-size: 9.5pt; margin: 10px 0; }
th, td { border: 1px solid #cdded9; padding: 7px; text-align: left; vertical-align: top; }
th { background: #e7f4f1; }
tr { break-inside: avoid; }
img { display: block; max-height: 135mm; width: auto; max-width: 100%; margin: 10px auto; break-inside: avoid; }
code { background: #eef4f2; padding: 1px 3px; }
</style></head><body>"""
    + body + "</body></html>", encoding="utf-8"
)
print(target)
