import json
import re

transcript_path = r'C:\Users\asus\.gemini\antigravity\brain\5f23f838-406d-4193-8f14-013602591997\.system_generated\logs\transcript_full.jsonl'
with open(transcript_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for line in reversed(lines):
    step = json.loads(line)
    if step.get('type') == 'USER_INPUT' and 'Sl No' in step.get('content', ''):
        content = step.get('content', '')
        if 'Sl No,Roll No' in content:
            csv_content = content[content.find('Sl No,Roll No'):]
            with open(r'c:\Users\asus\Downloads\mentorhub_firebase\mentorhub_firebase\functions\scripts\real_data.csv', 'w', encoding='utf-8') as out_f:
                out_f.write(csv_content.strip())
            print(f'Extracted CSV to real_data.csv, {len(csv_content)} bytes.')
            break
