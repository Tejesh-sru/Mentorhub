const fs = require('fs');
const transcriptPath = 'C:/Users/asus/.gemini/antigravity/brain/e62966f8-5d2f-403f-ba82-68b2aa030c45/.system_generated/logs/transcript_full.jsonl';
const lines = fs.readFileSync(transcriptPath, 'utf8').trim().split('\n');
const obj = JSON.parse(lines[1239]);
console.log('Keys of 1239:', Object.keys(obj));
console.log('Content length:', (obj.content || '').length);
console.log('Media:', obj.media);
const idx = (obj.content || '').indexOf('Sl No,Roll No');
console.log('idx in content:', idx);
// Check if there are other fields or if the CSV is in a file in .user_uploaded
const uploadedDir = 'C:/Users/asus/.gemini/antigravity/brain/e62966f8-5d2f-403f-ba82-68b2aa030c45/.user_uploaded';
if (fs.existsSync(uploadedDir)) {
  console.log('Uploaded files:', fs.readdirSync(uploadedDir));
}
