import zipfile
import xml.etree.ElementTree as ET
import csv
import json
import re

xlsx_path = 'C:/Users/asus/.gemini/antigravity/brain/e62966f8-5d2f-403f-ba82-68b2aa030c45/.user_uploaded/media_1791735389378_6177fafd.xlsx'

with zipfile.ZipFile(xlsx_path, 'r') as z:
    shared_strings = []
    if 'xl/sharedStrings.xml' in z.namelist():
        ss_xml = ET.fromstring(z.read('xl/sharedStrings.xml'))
        for si in ss_xml.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}si'):
            texts = [t.text or '' for t in si.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t')]
            shared_strings.append(''.join(texts))

    sheet_xml = ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
    rows = []
    for row_el in sheet_xml.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}row'):
        row_dict = {}
        for c in row_el.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}c'):
            ref = c.attrib.get('r', '')
            col_letters = re.sub(r'[0-9]', '', ref)
            col_idx = 0
            for ch in col_letters:
                col_idx = col_idx * 26 + (ord(ch) - ord('A') + 1)
            col_idx -= 1
            t = c.attrib.get('t', '')
            v_el = c.find('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}v')
            is_el = c.find('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}is')
            val = ''
            if t == 's' and v_el is not None and v_el.text is not None:
                val = shared_strings[int(v_el.text)]
            elif t == 'inlineStr' and is_el is not None:
                val = ''.join([x.text or '' for x in is_el.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t')])
            elif v_el is not None and v_el.text is not None:
                val = v_el.text
            row_dict[col_idx] = val.strip()
        if row_dict:
            max_c = max(max(row_dict.keys()), 12)
            rows.append([row_dict.get(i, '') for i in range(13)])

with open('functions/scripts/real_data.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerows(rows)

headers = rows[0]
records = []
for r in rows[1:]:
    if not r[1]:
        continue
    records.append({
        'slNo': r[0],
        'rollNo': r[1].strip().upper(),
        'studentName': r[2].strip(),
        'branch': r[3].strip(),
        'batch': r[4].strip(),
        'mentorRollNo': r[5].strip().upper(),
        'mentorName': r[6].strip(),
        'leetcode': r[7].strip() or None,
        'codeforce': r[8].strip() or None,
        'hackerrank': r[9].strip() or None,
        'linkedin': r[10].strip() or None,
        'github': r[11].strip() or None,
        'resume': r[12].strip() or None,
    })

with open('functions/scripts/real_data.json', 'w', encoding='utf-8') as f:
    json.dump(records, f, indent=2)

batches = sorted(list(set(x['batch'] for x in records)))
mentors = sorted(list(set((x['mentorRollNo'], x['mentorName'], x['batch']) for x in records)))
print(f"Parsed {len(records)} student records!")
print(f"Batches ({len(batches)}): {batches}")
print(f"Unique (mentor, batch) pairs: {len(mentors)}")
print(f"Unique mentor roll numbers: {len(set(x['mentorRollNo'] for x in records))}")
