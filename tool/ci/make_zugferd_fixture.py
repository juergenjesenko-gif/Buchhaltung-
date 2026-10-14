"""Erzeugt test/fixtures/einvoice/zugferd_synthetisch.pdf: minimale PDF mit
eingebettetem factur-x.xml (FlateDecode). Nur Testdaten für den Parser."""
import sys, zlib

xml = open(sys.argv[1], 'rb').read()
data = zlib.compress(xml)
objs = [
    b"<< /Type /Catalog /Pages 2 0 R /Names << /EmbeddedFiles 5 0 R >> /AF [6 0 R] >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R >>",
    b"<< /Length 0 >>\nstream\n\nendstream",
    b"<< /Names [(factur-x.xml) 6 0 R] >>",
    b"<< /Type /Filespec /F (factur-x.xml) /UF (factur-x.xml) /AFRelationship /Data /EF << /F 7 0 R >> >>",
    b"<< /Type /EmbeddedFile /Subtype /text#2Fxml /Filter /FlateDecode /Length " + str(len(data)).encode() + b" >>\nstream\n" + data + b"\nendstream",
]
out = bytearray(b"%PDF-1.7\n%\xe2\xe3\xcf\xd3\n")
offsets = []
for i, o in enumerate(objs, 1):
    offsets.append(len(out))
    out += f"{i} 0 obj\n".encode() + o + b"\nendobj\n"
xref = len(out)
out += f"xref\n0 {len(objs)+1}\n0000000000 65535 f \n".encode()
for off in offsets:
    out += f"{off:010d} 00000 n \n".encode()
out += f"trailer\n<< /Size {len(objs)+1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
open(sys.argv[2], 'wb').write(out)
