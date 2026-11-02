#!/usr/bin/env python3
"""Small, dependency-free HWPX paragraph editor used by hwpx-mode.el."""

import bisect
import copy
import difflib
import hashlib
import io
import json
import os
from pathlib import Path
import posixpath
import stat
import sys
import tempfile
from xml.dom import Node, minidom
import zipfile

HP = "http://www.hancom.co.kr/hwpml/2011/paragraph"
HH = "http://www.hancom.co.kr/hwpml/2011/head"
HC = "http://www.hancom.co.kr/hwpml/2011/core"
HS = "http://www.hancom.co.kr/hwpml/2011/section"
OPF = "http://www.idpf.org/2007/opf/"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def children(node, name):
    return [c for c in node.childNodes
            if c.nodeType == Node.ELEMENT_NODE
            and c.namespaceURI == HP and c.localName == name]


def parse_xml(data):
    doc = minidom.parseString(data)
    if doc.doctype is not None:
        raise ValueError("DTD-containing documents are not supported")
    return doc


def text_value(node):
    result = []
    for c in node.childNodes:
        if c.nodeType in (Node.TEXT_NODE, Node.CDATA_SECTION_NODE):
            result.append(c.data)
        elif c.namespaceURI == HP and c.localName == "lineBreak":
            result.append("\n")
        else:
            raise ValueError("Unsupported inline content")
    return "".join(result)


def paragraph_parts(para):
    runs = children(para, "run")
    texts = [t for run in runs for t in children(run, "t")]
    # Controls, drawings, fields, range markers, etc. are preserved, read-only.
    safe = bool(runs) and all(
        c.nodeType != Node.ELEMENT_NODE or c in texts
        for run in runs for c in run.childNodes)
    safe = safe and all(c.nodeType != Node.ELEMENT_NODE
                        or (c.namespaceURI == HP
                            and c.localName in ("run", "linesegarray"))
                        for c in para.childNodes)
    values = []
    for t in texts:
        try:
            values.append(text_value(t))
        except ValueError:
            safe = False
            values.append("".join(c.data for c in t.childNodes
                                  if c.nodeType == Node.TEXT_NODE))
    return runs, texts, values, safe


def ancestor(node, name):
    node = node.parentNode
    while node is not None:
        if node.namespaceURI == HP and node.localName == name:
            return node
        node = node.parentNode
    return None


def format_signature(node, masked=None):
    """Everything except text contents and the disposable line-layout cache."""
    if node.nodeType != Node.ELEMENT_NODE:
        return None
    if node.namespaceURI == HP and node.localName in ("t", "linesegarray"):
        return None
    children_signatures = []
    for child in node.childNodes:
        group = masked.get(id(child)) if masked else None
        if group is not None:
            marker = ("editable-list", group)
            if not children_signatures or children_signatures[-1] != marker:
                children_signatures.append(marker)
        else:
            signature = format_signature(child, masked)
            if signature is not None:
                children_signatures.append(signature)
    return (node.namespaceURI, node.localName,
            tuple(sorted(node.attributes.items())),
            tuple(children_signatures))


class Document:
    def __init__(self, data):
        self.data = data
        self.archive = zipfile.ZipFile(io.BytesIO(data))
        names = self.archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Duplicate ZIP entries")
        if self.archive.read("mimetype").strip() != b"application/hwp+zip":
            raise ValueError("Not an HWPX package")
        package = parse_xml(self.archive.read("Contents/content.hpf"))
        manifest = {n.getAttribute("id"): n.getAttribute("href") for n in
                    package.getElementsByTagNameNS(OPF, "item")}
        header = parse_xml(self.archive.read("Contents/header.xml"))
        self.header = header
        paragraph_styles = {n.getAttribute("id"): n for n in
                            header.getElementsByTagNameNS(HH, "paraPr")}
        self.paragraph_styles = paragraph_styles
        self.sections = {}
        self.paragraphs = {}
        self.entries = []
        for ref in package.getElementsByTagNameNS(OPF, "itemref"):
            href = manifest[ref.getAttribute("idref")]
            name = href if href in names else posixpath.normpath(
                posixpath.join("Contents", href))
            doc = parse_xml(self.archive.read(name))
            root = doc.documentElement
            if root.namespaceURI != HS or root.localName != "sec":
                continue
            if name in self.sections:
                raise ValueError("Repeated section in spine")
            self.sections[name] = doc
            section_no = len(self.sections)
            tables = list(doc.getElementsByTagNameNS(HP, "tbl"))
            for index, para in enumerate(doc.getElementsByTagNameNS(HP, "p")):
                if para.getElementsByTagNameNS(HP, "p"):
                    continue  # Container paragraph: list its cell paragraphs instead.
                _, _, values, safe = paragraph_parts(para)
                key = f"{name}#{index}"
                location = f"구역 {section_no} · 문단 {index + 1}"
                cell = ancestor(para, "tc")
                table = ancestor(para, "tbl")
                cell_info = None
                if cell is not None and table is not None:
                    addresses = children(cell, "cellAddr")
                    if addresses:
                        addr = addresses[0]
                        row = int(addr.getAttribute("rowAddr")) + 1
                        col = int(addr.getAttribute("colAddr")) + 1
                        location = (f"구역 {section_no} · 표 {tables.index(table) + 1} · "
                                    f"{row}행 {col}열 · 문단 {index + 1}")
                        spans = children(cell, "cellSpan")
                        span = spans[0] if spans else None
                        table_key = f"{name}/table{tables.index(table)}"
                        cell_info = dict(
                            id=f"{table_key}/{row},{col}", table=table_key,
                            row=row, column=col,
                            rowspan=int(span.getAttribute("rowSpan") or 1) if span else 1,
                            colspan=int(span.getAttribute("colSpan") or 1) if span else 1)
                self.paragraphs[key] = para
                list_info = None
                style = paragraph_styles.get(para.getAttribute("paraPrIDRef"))
                headings = style.getElementsByTagNameNS(HH, "heading") if style else []
                if headings and headings[0].getAttribute("type") == "BULLET":
                    heading = headings[0]
                    list_info = dict(type="BULLET", id_ref=heading.getAttribute("idRef"),
                                     level=max(0, min(9, int(heading.getAttribute("level") or 0))))
                self.entries.append(dict(id=key, location=location,
                                         text="".join(values), editable=safe,
                                         cell=cell_info, list=list_info))
        if not self.sections:
            raise ValueError("No document sections found")

    def inspect(self):
        return dict(source_sha256=digest(self.data), entries=self.entries)

    def render(self, edits, list_edits=None):
        list_edits = list_edits or {}
        groups = self.validate_lists(list_edits)
        if set(edits).intersection(i for change in list_edits.values() for i in change["ids"]):
            raise ValueError("A paragraph cannot have both text and list edits")
        masked = {id(node): key for key, (nodes, _) in groups.items() for node in nodes}
        original_format = {name: format_signature(doc.documentElement, masked)
                           for name, doc in self.sections.items()}
        known = {e["id"]: e for e in self.entries}
        changed = set()
        for key, value in edits.items():
            if key not in known:
                raise ValueError(f"Unknown paragraph: {key}")
            entry = known[key]
            if not entry["editable"]:
                raise ValueError(f"Paragraph contains unsupported controls: {key}")
            if not isinstance(value, str) or any(
                    (ord(c) < 32 and c != "\n")
                    or 0xD800 <= ord(c) <= 0xDFFF
                    or ord(c) in (0xFFFE, 0xFFFF) for c in value):
                raise ValueError("Use ordinary text and newlines; tabs are not supported")
            if value == entry["text"]:
                continue
            para = self.paragraphs[key]
            replace_text(para, value)
            # Old line coordinates may cause Hancom's corruption warning.
            for layout in children(para, "linesegarray"):
                para.removeChild(layout)
            # A containing table's host paragraph also caches layout geometry.
            parent = ancestor(para, "p")
            while parent is not None:
                for layout in children(parent, "linesegarray"):
                    parent.removeChild(layout)
                parent = ancestor(parent, "p")
            changed.add(key.rsplit("#", 1)[0])
        header_changed = False
        for key, (nodes, items) in groups.items():
            section = key.rsplit("#", 1)[0]
            new_nodes, styles_changed = self.replace_list(nodes, items)
            masked.update({id(node): key for node in new_nodes})
            header_changed |= styles_changed
            changed.add(section)
        if not changed:
            return self.data
        for name, doc in self.sections.items():
            if format_signature(doc.documentElement, masked) != original_format[name]:
                raise ValueError("Document formatting or structure changed; save aborted")
        for section in self.sections.values():
            for node in list(section.getElementsByTagNameNS(HP, "subList")):
                for child in list(node.childNodes):
                    if child.nodeType == Node.COMMENT_NODE and id(child) in masked:
                        node.removeChild(child)
        replacements = {name: self.sections[name].toxml(
            encoding="UTF-8", standalone=True) for name in changed}
        if header_changed:
            replacements["Contents/header.xml"] = self.header.toxml(
                encoding="UTF-8", standalone=True)
        if "Preview/PrvText.txt" in self.archive.namelist():
            first = {key: [item["text"] for item in change["items"]]
                     for key, change in list_edits.items()}
            skipped = {item for change in list_edits.values() for item in change["ids"][1:]}
            preview = []
            for entry in self.entries:
                key = entry["id"]
                if key in first:
                    preview.extend(first[key])
                elif key not in skipped:
                    preview.append(edits.get(key, entry["text"]))
            replacements["Preview/PrvText.txt"] = "\r\n".join(preview).encode("utf-8")
        out = io.BytesIO()
        with zipfile.ZipFile(out, "w") as target:
            target.comment = self.archive.comment
            for info in self.archive.infolist():
                target.writestr(copy.copy(info), replacements.get(
                    info.filename, self.archive.read(info.filename)))
        return out.getvalue()

    def validate_lists(self, list_edits):
        """Ensure every list is a contiguous, editable group in one cell."""
        entries = {entry["id"]: entry for entry in self.entries}
        groups, used = {}, set()
        for key, change in list_edits.items():
            ids, items = change.get("ids"), change.get("items")
            if not isinstance(ids, list) or not ids or ids[0] != key or not isinstance(items, list):
                raise ValueError("Invalid list edit")
            if len(ids) != len(set(ids)) or used.intersection(ids):
                raise ValueError("Duplicate list paragraph")
            used.update(ids)
            if any(i not in entries or not entries[i]["editable"] or
                   not entries[i]["list"] or not entries[i]["cell"] for i in ids):
                raise ValueError("List contains an unsupported paragraph")
            nodes = [self.paragraphs[i] for i in ids]
            parent = nodes[0].parentNode
            if any(n.parentNode is not parent for n in nodes):
                raise ValueError("List crosses cell boundaries")
            siblings = [n for n in parent.childNodes if n.nodeType == Node.ELEMENT_NODE]
            start = siblings.index(nodes[0])
            if siblings[start:start + len(nodes)] != nodes:
                raise ValueError("List paragraphs are not contiguous")
            for item in items:
                if not isinstance(item, dict) or not isinstance(item.get("text"), str) or \
                        type(item.get("level")) is not int or not 0 <= item["level"] <= 9:
                    raise ValueError("Invalid list item")
                if any((ord(c) < 32 and c != "\n") or 0xD800 <= ord(c) <= 0xDFFF
                       or ord(c) in (0xFFFE, 0xFFFF) for c in item["text"]):
                    raise ValueError("Invalid characters in list item")
            groups[key] = (nodes, items)
        return groups

    def replace_list(self, nodes, items):
        """Reuse matching paragraphs, clone new ones, and preserve cell geometry."""
        parent, doc = nodes[0].parentNode, nodes[0].ownerDocument
        old_texts = ["".join(paragraph_parts(n)[2]) for n in nodes]
        available = set(range(len(nodes)))
        choices = []
        for index, item in enumerate(items):
            matches = [i for i in available if old_texts[i] == item["text"]]
            if matches:
                chosen = min(matches, key=lambda i: abs(i - index))
                available.remove(chosen)
                choices.append((chosen, True))
            else:
                choices.append((None, False))
        for index, (chosen, exact) in enumerate(choices):
            if chosen is None:
                if available:
                    chosen = min(available, key=lambda i: abs(i - index))
                    available.remove(chosen)
                    choices[index] = (chosen, True)
                else:
                    choices[index] = (min(index, len(nodes) - 1), False)
        style_cache, changed_styles, result = {}, False, []
        other_paragraphs = [n for n in parent.childNodes
                            if n.nodeType == Node.ELEMENT_NODE and n.namespaceURI == HP
                            and n.localName == "p" and n not in nodes]
        if not items and other_paragraphs:
            # Keep a temporary marker for the structural comparison only.
            result.append(doc.createComment("hwpx-list"))
        elif not items:
            # HWPX cells require a paragraph even when their list is empty.
            node = nodes[0]
            style = self.paragraph_styles[node.getAttribute("paraPrIDRef")]
            plain = style.cloneNode(True)
            numeric = [int(i) for i in self.paragraph_styles if i.isdigit()]
            new_id = str(max(numeric, default=-1) + 1)
            plain.setAttribute("id", new_id)
            heading = plain.getElementsByTagNameNS(HH, "heading")[0]
            heading.setAttribute("type", "NONE")
            heading.setAttribute("idRef", "0")
            heading.setAttribute("level", "0")
            style.parentNode.appendChild(plain)
            if style.parentNode.hasAttribute("itemCnt"):
                style.parentNode.setAttribute("itemCnt", str(len([
                    n for n in style.parentNode.childNodes if n.nodeType == Node.ELEMENT_NODE])))
            self.paragraph_styles[new_id] = plain
            node.setAttribute("paraPrIDRef", new_id)
            replace_text(node, "")
            for layout in children(node, "linesegarray"):
                node.removeChild(layout)
            result.append(node)
            changed_styles = True
        used_ids = {p.getAttribute("id") for section in self.sections.values()
                    for p in section.getElementsByTagNameNS(HP, "p")}
        next_id = 1
        for item, (index, reuse) in zip(items, choices):
            node = nodes[index] if reuse else nodes[index].cloneNode(True)
            if not reuse:
                while str(next_id) in used_ids:
                    next_id += 1
                node.setAttribute("id", str(next_id))
                used_ids.add(str(next_id))
            original_style = node.getAttribute("paraPrIDRef")
            style = self.paragraph_styles[original_style]
            heading = style.getElementsByTagNameNS(HH, "heading")[0]
            old_level = int(heading.getAttribute("level") or 0)
            if old_level != item["level"]:
                cache_key = (original_style, item["level"])
                if cache_key not in style_cache:
                    new_style = style.cloneNode(True)
                    numeric = [int(i) for i in self.paragraph_styles if i.isdigit()]
                    new_id = str(max(numeric, default=-1) + 1)
                    new_style.setAttribute("id", new_id)
                    new_style.getElementsByTagNameNS(HH, "heading")[0].setAttribute(
                        "level", str(item["level"]))
                    # HWPUNIT is 1/7200 inch; one level adds about 5 mm.
                    for margin in new_style.getElementsByTagNameNS(HH, "margin"):
                        for left in margin.getElementsByTagNameNS(HC, "left"):
                            if left.getAttribute("unit") == "HWPUNIT":
                                value = int(left.getAttribute("value") or 0)
                                left.setAttribute("value", str(max(0, value +
                                                                  1417 * (item["level"] - old_level))))
                    style.parentNode.appendChild(new_style)
                    if style.parentNode.hasAttribute("itemCnt"):
                        style.parentNode.setAttribute("itemCnt", str(len([
                            n for n in style.parentNode.childNodes if n.nodeType == Node.ELEMENT_NODE])))
                    self.paragraph_styles[new_id] = new_style
                    style_cache[cache_key] = new_id
                    changed_styles = True
                node.setAttribute("paraPrIDRef", style_cache[cache_key])
            if "".join(paragraph_parts(node)[2]) != item["text"]:
                replace_text(node, item["text"])
            for layout in children(node, "linesegarray"):
                node.removeChild(layout)
            result.append(node)
        anchor = nodes[-1].nextSibling
        for node in nodes:
            parent.removeChild(node)
        for node in result:
            parent.insertBefore(node, anchor)
        host = ancestor(parent, "p")
        while host is not None:
            for layout in children(host, "linesegarray"):
                host.removeChild(layout)
            host = ancestor(host, "p")
        return result, changed_styles


def replace_text(para, value):
    """Distribute changed text across the existing character-style runs."""
    runs, texts, values, _ = paragraph_parts(para)
    doc = para.ownerDocument
    if not texts:
        prefix = (runs[0].prefix + ":") if runs[0].prefix else ""
        texts = [doc.createElementNS(HP, prefix + "t")]
        runs[0].appendChild(texts[0])
        values = [""]
    old = "".join(values)
    ends = []
    total = 0
    for v in values:
        total += len(v)
        ends.append(total)
    result = [""] * len(texts)
    # Equal text keeps its original run; inserted text inherits the run to
    # its left (or the first run at the beginning of the paragraph).
    for tag, i, j, a, b in difflib.SequenceMatcher(
            None, old, value, autojunk=False).get_opcodes():
        if tag == "equal":
            for k in range(i, j):
                owner = min(bisect.bisect_right(ends, k), len(texts) - 1)
                result[owner] += old[k]
        elif tag in ("replace", "insert"):
            anchor = i if tag == "replace" else max(0, i - 1)
            owner = min(bisect.bisect_right(ends, anchor), len(texts) - 1)
            result[owner] += value[a:b]
    for node, text in zip(texts, result):
        for c in list(node.childNodes):
            node.removeChild(c)
        for index, line in enumerate(text.split("\n")):
            if index:
                prefix = (node.prefix + ":") if node.prefix else ""
                node.appendChild(doc.createElementNS(HP, prefix + "lineBreak"))
            if line:
                node.appendChild(doc.createTextNode(line))


def save(source, output, request):
    # Replace the actual file behind a symlink, retaining the symlink itself.
    source, output = Path(source).resolve(), Path(output).resolve()
    data = source.read_bytes()
    if digest(data) != request["source_sha256"]:
        raise ValueError("Source changed on disk; reopen the document")
    source_overwritten = source == output
    if source_overwritten and request.get("overwrite_original") is not True:
        raise ValueError("Overwriting the original requires confirmation")
    expected = request.get("output_sha256")

    def check_output():
        actual = digest(output.read_bytes()) if output.exists() else None
        if actual != expected:
            raise ValueError("Output exists or changed on disk; choose another filename")

    check_output()
    output_mode = stat.S_IMODE(output.stat().st_mode) if output.exists() else None
    rendered = Document(data).render(request["edits"], request.get("list_edits"))
    # Reparse the result before replacing any destination.
    Document(rendered)
    fd, temp = tempfile.mkstemp(prefix=".hwpx-", dir=output.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(rendered)
            stream.flush()
            os.fsync(stream.fileno())
        if output_mode is not None:
            os.chmod(temp, output_mode)
        if digest(source.read_bytes()) != request["source_sha256"]:
            raise ValueError("Source changed on disk; reopen the document")
        check_output()
        os.replace(temp, output)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)
    return dict(output_sha256=digest(rendered), source_overwritten=source_overwritten)


def main():
    action = sys.argv[1]
    if action == "inspect" and len(sys.argv) == 3:
        result = Document(Path(sys.argv[2]).read_bytes()).inspect()
    elif action == "save" and len(sys.argv) == 4:
        result = save(sys.argv[2], sys.argv[3], json.load(sys.stdin))
    else:
        raise ValueError("Usage: hwpx_bridge.py inspect FILE | save SOURCE OUTPUT")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
