"""HWPX round trips using synthetic, non-personal fixtures."""
import copy
import importlib.util
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location(
    "bridge", Path(__file__).resolve().parents[1] / "hwpx_bridge.py")
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


def fixture():
    section = f'''<hs:sec xmlns:hs="{bridge.HS}" xmlns:hp="{bridge.HP}">
<hp:p id="1"><hp:run charPrIDRef="1"><hp:t>Hello </hp:t></hp:run><hp:run charPrIDRef="2"><hp:t>world</hp:t></hp:run><hp:linesegarray/></hp:p>
<hp:p id="2"><hp:run charPrIDRef="3"/><hp:linesegarray/></hp:p>
<hp:p id="3"><hp:run charPrIDRef="1"><hp:ctrl/><hp:t>Read only</hp:t></hp:run></hp:p>
<hp:p id="6"><hp:run><hp:tbl><hp:tr><hp:tc><hp:subList><hp:p><hp:run charPrIDRef="1"><hp:t>항목</hp:t></hp:run></hp:p></hp:subList><hp:cellAddr rowAddr="0" colAddr="0"/><hp:cellSpan rowSpan="1" colSpan="1"/></hp:tc><hp:tc><hp:subList><hp:p><hp:run charPrIDRef="2"><hp:t>기존값</hp:t></hp:run></hp:p></hp:subList><hp:cellAddr rowAddr="0" colAddr="1"/><hp:cellSpan rowSpan="1" colSpan="1"/></hp:tc></hp:tr><hp:tr><hp:tc><hp:subList><hp:p><hp:run charPrIDRef="1"><hp:t>빈칸</hp:t></hp:run></hp:p></hp:subList><hp:cellAddr rowAddr="1" colAddr="0"/><hp:cellSpan rowSpan="1" colSpan="1"/></hp:tc><hp:tc><hp:subList><hp:p><hp:run charPrIDRef="2"/></hp:p></hp:subList><hp:cellAddr rowAddr="1" colAddr="1"/><hp:cellSpan rowSpan="1" colSpan="1"/></hp:tc></hp:tr></hp:tbl></hp:run></hp:p>
<hp:p id="4"><hp:run><hp:tbl><hp:tr><hp:tc><hp:subList><hp:p id="5"><hp:run charPrIDRef="1"><hp:t>Cell</hp:t></hp:run><hp:linesegarray/></hp:p></hp:subList><hp:cellAddr rowAddr="0" colAddr="1"/><hp:cellSpan rowSpan="2" colSpan="3"/></hp:tc></hp:tr></hp:tbl></hp:run><hp:linesegarray/></hp:p>
</hs:sec>'''
    out = io.BytesIO()
    with zipfile.ZipFile(out, "w") as z:
        z.writestr("mimetype", "application/hwp+zip")
        z.writestr("Contents/content.hpf", f'''<opf:package xmlns:opf="{bridge.OPF}"><opf:manifest><opf:item id="s" href="Contents/section0.xml"/></opf:manifest><opf:spine><opf:itemref idref="s"/></opf:spine></opf:package>''')
        z.writestr("Contents/section0.xml", section, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("Contents/header.xml", b"<styles>untouched</styles>")
        z.writestr("BinData/image.png", b"preserved-image")
        z.writestr("Preview/PrvText.txt", b"Hello world")
        z.comment = b"preserved-comment"
    return out.getvalue()


def bullet_fixture(line_break=False):
    """A single merged cell containing three automatic bullet paragraphs."""
    section = f'''<hs:sec xmlns:hs="{bridge.HS}" xmlns:hp="{bridge.HP}">
<hp:p><hp:run><hp:tbl><hp:tr><hp:tc><hp:subList>
<hp:p paraPrIDRef="42"><hp:run charPrIDRef="1"><hp:t>First bullet with enough text to test ordinary Org paragraph filling and indentation without changing the text in the original document.  </hp:t></hp:run><hp:linesegarray/></hp:p>
<hp:p paraPrIDRef="43"><hp:run charPrIDRef="2"><hp:t>Nested bullet</hp:t></hp:run><hp:linesegarray/></hp:p>
<hp:p paraPrIDRef="42"><hp:run charPrIDRef="1"><hp:t>Last bullet</hp:t></hp:run><hp:linesegarray/></hp:p>
</hp:subList><hp:cellAddr rowAddr="0" colAddr="0"/><hp:cellSpan rowSpan="1" colSpan="2"/></hp:tc></hp:tr></hp:tbl></hp:run></hp:p></hs:sec>'''
    if line_break:
        section = section.replace("<hp:t>Last bullet</hp:t>",
                                  "<hp:t>Last bullet<hp:lineBreak/>continued</hp:t>")
    header = f'''<hh:head xmlns:hh="{bridge.HH}" xmlns:hc="{bridge.HC}"><hh:refList><hh:paraProperties>
<hh:paraPr id="42"><hh:heading type="BULLET" idRef="7" level="0"/><hh:margin><hc:left value="0" unit="HWPUNIT"/></hh:margin></hh:paraPr>
<hh:paraPr id="43"><hh:heading type="BULLET" idRef="7" level="1"/><hh:margin><hc:left value="1417" unit="HWPUNIT"/></hh:margin></hh:paraPr>
</hh:paraProperties></hh:refList></hh:head>'''
    out = io.BytesIO()
    with zipfile.ZipFile(io.BytesIO(fixture())) as source, zipfile.ZipFile(out, "w") as target:
        for info in source.infolist():
            data = source.read(info.filename)
            if info.filename == "Contents/section0.xml":
                data = section.encode()
            elif info.filename == "Contents/header.xml":
                data = header.encode()
            target.writestr(copy.copy(info), data)
    return out.getvalue()


class RoundTripTests(unittest.TestCase):
    def setUp(self):
        self.data = fixture()
        self.doc = bridge.Document(self.data)
        self.key = self.doc.entries[0]["id"]

    def test_no_edits_are_byte_identical(self):
        self.assertEqual(self.doc.render({}), self.data)

    def test_cell_bullets_are_metadata_and_keep_original_styles(self):
        before = bridge.Document(bullet_fixture())
        self.assertEqual([e["list"]["level"] for e in before.entries], [0, 1, 0])
        self.assertTrue(all(e["cell"] and e["list"]["type"] == "BULLET" for e in before.entries))
        self.assertEqual(before.render({}), before.data)
        key = before.entries[1]["id"]
        after = bridge.Document(before.render({key: "Edited nested bullet"}))
        self.assertEqual(after.entries[1]["text"], "Edited nested bullet")
        self.assertEqual(after.entries[1]["list"], before.entries[1]["list"])
        self.assertEqual(after.archive.read("Contents/header.xml"), before.archive.read("Contents/header.xml"))
        self.assertEqual(after.paragraphs[key].getAttribute("paraPrIDRef"), "43")

    def test_list_insert_delete_and_nesting_preserve_cell_structure(self):
        before = bridge.Document(bullet_fixture())
        ids = [entry["id"] for entry in before.entries]
        first, _, last = [entry["text"] for entry in before.entries]
        change = {ids[0]: {"ids": ids, "items": [
            {"text": first, "level": 0},
            {"text": "New nested item", "level": 2},
            {"text": last, "level": 1}]}}
        after = bridge.Document(before.render({}, change))
        self.assertEqual([entry["text"] for entry in after.entries],
                         [first, "New nested item", last])
        self.assertEqual([entry["list"]["level"] for entry in after.entries], [0, 2, 1])
        self.assertTrue(all(entry["cell"]["colspan"] == 2 for entry in after.entries))
        self.assertEqual(after.paragraphs[after.entries[0]["id"]].getAttribute("paraPrIDRef"), "42")
        nested = after.paragraphs[after.entries[1]["id"]]
        style = after.paragraph_styles[nested.getAttribute("paraPrIDRef")]
        self.assertEqual(style.getElementsByTagNameNS(bridge.HC, "left")[0].getAttribute("value"), "2834")
        self.assertIn(b"New nested item", after.archive.read("Preview/PrvText.txt"))

    def test_deleting_all_bullets_leaves_an_empty_cell(self):
        before = bridge.Document(bullet_fixture())
        ids = [entry["id"] for entry in before.entries]
        after = bridge.Document(before.render({}, {ids[0]: {"ids": ids, "items": []}}))
        self.assertEqual(len(after.entries), 1)
        self.assertEqual(after.entries[0]["text"], "")
        self.assertIsNone(after.entries[0]["list"])
        self.assertEqual(after.entries[0]["cell"]["colspan"], 2)

    def test_deleting_a_list_keeps_other_cell_paragraphs(self):
        original = bridge.Document(bullet_fixture())
        out = io.BytesIO()
        with zipfile.ZipFile(out, "w") as target:
            for info in original.archive.infolist():
                data = original.archive.read(info.filename)
                if info.filename == "Contents/section0.xml":
                    data = data.replace(b'</hp:subList>',
                                        b'<hp:p><hp:run><hp:t>Other text</hp:t></hp:run></hp:p></hp:subList>')
                target.writestr(copy.copy(info), data)
        before = bridge.Document(out.getvalue())
        ids = [entry["id"] for entry in before.entries if entry["list"]]
        after = bridge.Document(before.render({}, {ids[0]: {"ids": ids, "items": []}}))
        self.assertEqual([entry["text"] for entry in after.entries], ["Other text"])
        self.assertNotIn(b"hwpx-list", after.archive.read("Contents/section0.xml"))

    def test_format_change_is_rejected_before_save(self):
        replace = bridge.replace_text

        def unexpected_style_change(para, value):
            replace(para, value)
            para.setAttribute("styleIDRef", "unexpected")

        with patch.object(bridge, "replace_text", unexpected_style_change):
            with self.assertRaisesRegex(ValueError, "formatting or structure changed"):
                self.doc.render({self.key: "Edited"})

    def test_text_styles_escaping_and_member_preservation(self):
        value = "Hello 한글 & <world> 😀"
        after = bridge.Document(self.doc.render({self.key: value}))
        self.assertEqual(after.entries[0]["text"], value)
        p = after.paragraphs[self.key]
        self.assertEqual([r.getAttribute("charPrIDRef") for r in bridge.children(p, "run")], ["1", "2"])
        self.assertEqual(bridge.paragraph_parts(p)[2], ["Hello 한글 & <", "world> 😀"])
        self.assertFalse(bridge.children(p, "linesegarray"))
        for name in self.doc.archive.namelist():
            if name not in ("Contents/section0.xml", "Preview/PrvText.txt"):
                self.assertEqual(self.doc.archive.read(name), after.archive.read(name))
        self.assertEqual(after.archive.comment, self.doc.archive.comment)
        self.assertEqual(after.archive.infolist()[0].filename, "mimetype")
        self.assertEqual(after.archive.infolist()[0].compress_type, zipfile.ZIP_STORED)

    def test_empty_cell_and_line_breaks(self):
        key = self.doc.entries[1]["id"]
        after = bridge.Document(self.doc.render({key: "새 참석자\n둘째 줄\n"}))
        self.assertEqual(after.entries[1]["text"], "새 참석자\n둘째 줄\n")
        p = after.paragraphs[key]
        self.assertEqual(bridge.children(p, "run")[0].getAttribute("charPrIDRef"), "3")
        self.assertEqual(len(p.getElementsByTagNameNS(bridge.HP, "lineBreak")), 2)

    def test_table_structure_and_host_layout(self):
        key = self.doc.entries[-1]["id"]
        self.assertIn("1행 2열", self.doc.entries[-1]["location"])
        after = bridge.Document(self.doc.render({key: "수정된 셀"}))
        p = after.paragraphs[key]
        span = bridge.children(bridge.ancestor(p, "tc"), "cellSpan")[0]
        self.assertEqual(span.getAttribute("rowSpan"), "2")
        self.assertEqual(span.getAttribute("colSpan"), "3")
        self.assertFalse(bridge.children(bridge.ancestor(p, "p"), "linesegarray"))

    def test_rejects_unsupported_and_invalid_edits(self):
        for key, value in [(self.doc.entries[2]["id"], "unsafe"),
                           ("unknown", "text"), (self.key, "tab\there"),
                           (self.key, "bad\x00text")]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                bridge.Document(self.data).render({key: value})

    def test_spine_order(self):
        out = io.BytesIO()
        with zipfile.ZipFile(out, "w") as z:
            for info in self.doc.archive.infolist():
                data = self.doc.archive.read(info.filename)
                if info.filename == "Contents/content.hpf":
                    data = data.replace(b'</opf:manifest>', b'<opf:item id="s1" href="section1.xml"/></opf:manifest>')
                    data = data.replace(b'<opf:spine>', b'<opf:spine><opf:itemref idref="s1"/>')
                z.writestr(copy.copy(info), data)
            z.writestr("Contents/section1.xml", self.doc.archive.read("Contents/section0.xml"))
        self.assertTrue(bridge.Document(out.getvalue()).entries[0]["id"].startswith("Contents/section1.xml#"))

    def test_source_preservation_and_disk_conflicts(self):
        with tempfile.TemporaryDirectory() as tmp:
            source, target = Path(tmp) / "양식.hwpx", Path(tmp) / "수정.hwpx"
            source.write_bytes(self.data)
            req = dict(source_sha256=bridge.digest(self.data), edits={self.key: "Edited"})
            with self.assertRaises(ValueError):
                bridge.save(source, source, req)
            result = bridge.save(source, target, req)
            self.assertEqual(source.read_bytes(), self.data)
            self.assertEqual(bridge.Document(target.read_bytes()).entries[0]["text"], "Edited")
            with self.assertRaises(ValueError):
                bridge.save(source, target, req)
            req["output_sha256"] = result["output_sha256"]
            req["edits"][self.key] = "Second save"
            bridge.save(source, target, req)
            target.write_bytes(b"changed elsewhere")
            with self.assertRaises(ValueError):
                bridge.save(source, target, req)
            self.assertEqual(target.read_bytes(), b"changed elsewhere")
            source.write_bytes(b"changed source")
            with self.assertRaises(ValueError):
                bridge.save(source, Path(tmp) / "other.hwpx", req)
            self.assertFalse((Path(tmp) / "other.hwpx").exists())

    def test_confirmed_original_overwrite_checks_hash_and_preserves_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "양식.hwpx"
            source.write_bytes(self.data)
            source.chmod(0o640)
            request = dict(source_sha256=bridge.digest(self.data),
                           output_sha256=bridge.digest(self.data),
                           edits={self.key: "Overwritten"})
            with self.assertRaisesRegex(ValueError, "confirmation"):
                bridge.save(source, source, request)
            self.assertEqual(source.read_bytes(), self.data)
            request["overwrite_original"] = True
            result = bridge.save(source, source, request)
            self.assertTrue(result["source_overwritten"])
            self.assertEqual(bridge.Document(source.read_bytes()).entries[0]["text"], "Overwritten")
            self.assertEqual(source.stat().st_mode & 0o777, 0o640)
            with self.assertRaisesRegex(ValueError, "Source changed"):
                bridge.save(source, source, request)
            request.update(source_sha256=result["output_sha256"],
                           output_sha256=result["output_sha256"],
                           edits={self.key: "Hello world"})
            bridge.save(source, source, request)
            self.assertEqual(bridge.Document(source.read_bytes()).entries[0]["text"], "Hello world")

    def test_confirmed_symlink_overwrite_updates_original_and_retains_link(self):
        with tempfile.TemporaryDirectory() as tmp:
            source, alias = Path(tmp) / "source.hwpx", Path(tmp) / "alias.hwpx"
            source.write_bytes(self.data)
            alias.symlink_to(source)
            result = bridge.save(source, alias, dict(
                source_sha256=bridge.digest(self.data),
                output_sha256=bridge.digest(self.data), overwrite_original=True,
                edits={self.key: "Via symlink"}))
            self.assertTrue(result["source_overwritten"])
            self.assertTrue(alias.is_symlink())
            self.assertEqual(bridge.Document(source.read_bytes()).entries[0]["text"], "Via symlink")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] in ("--fixture", "--bullet-fixture", "--bullet-break-fixture"):
        data = fixture() if sys.argv[1] == "--fixture" else bullet_fixture(
            line_break=sys.argv[1] == "--bullet-break-fixture")
        Path(sys.argv[2]).write_bytes(data)
    else:
        unittest.main()
