// Builds the Arabic recording list (audio/ar/recordings.csv and audio/ar/RECORDINGS.md) from the Arabic data in index.html.
// Run from the repo folder: node tools/make-recording-list.js
const fs = require('fs'), vm = require('vm'), path = require('path');
const root = path.join(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const cut = (from, to) => { const i = html.indexOf(from), j = html.indexOf(to, i); if (i < 0 || j < 0) throw new Error('marker not found: ' + from); return html.slice(i, j); };
const code = cut('const WORLDS = {', 'const findPhrase')
  + cut('/* ================= ARABIC', '\nconst GAMES = {')
  + '\n;({AR_LETTERS, SYL_LETTERS, SK_LETTERS, AR_MARKS, sylText, sylKey, sukText, shdText, sukKey, AR_ALL, AR_PHRASES, wordRec, ARABIC});';
const stub = { choices: a => a.join(''), esc: s => s, T: (lv, a) => a[Math.min(lv, a.length) - 1], pick: a => a[0], shuffle: a => a.slice(), R: a => a, me: null };
const A = vm.runInNewContext(code, stub);

const rows = [];
const add = (priority, file, arabic, what, game) => rows.push({ priority, file, arabic, what, game });
const marks = ['a', 'i', 'u', 'an', 'in', 'un', 'aa', 'ii', 'uu'];
const markName = { a: 'fatha', i: 'kasra', u: 'damma', an: 'tanween fatha', in: 'tanween kasra', un: 'tanween damma', aa: 'long a (madd alif)', ii: 'long i (madd ya)', uu: 'long u (madd waw)' };
const gameOf = { a: 'Short Vowels', i: 'Short Vowels', u: 'Short Vowels', an: 'Tanween', in: 'Tanween', un: 'Tanween', aa: 'Long Vowels', ii: 'Long Vowels', uu: 'Long Vowels' };

A.AR_LETTERS.forEach(L => add(1, `letter-${L.k}`, L.n, `name of the letter ${L.c}`, 'Letter Sounds, Twin Letters, Letter Train'));
['a', 'i', 'u', 'an', 'in', 'un'].forEach(v => add(1, `name-${A.AR_MARKS[v].id}`, A.AR_MARKS[v].n, `the word ${markName[v]}`, 'Short Vowels, Tanween (spelling on levels 1–3)'));
A.SYL_LETTERS.forEach(L => ['a', 'i', 'u'].forEach(v => add(1, A.sylKey(L, v), A.sylText(L, v), `${L.n} with ${markName[v]}`, gameOf[v])));
A.AR_ALL.forEach(w => add(2, A.wordRec(w.w), w.a, `word: ${w.w} ${w.e}`, 'Arabic Words, Say It in Arabic, English to Arabic, Arabic to English'));
A.AR_PHRASES.forEach(([t, e, id]) => add(2, id, t, `phrase ${e}`, 'Say It Back (level 10), welcome on the Arabic page'));
A.SYL_LETTERS.forEach(L => ['an', 'in', 'un'].forEach(v => add(3, A.sylKey(L, v), A.sylText(L, v), `${L.n} with ${markName[v]}`, gameOf[v])));
A.SYL_LETTERS.forEach(L => ['aa', 'ii', 'uu'].forEach(v => add(3, A.sylKey(L, v), A.sylText(L, v), `${L.n} with ${markName[v]}`, gameOf[v])));
A.SK_LETTERS.forEach(L => ['a', 'i', 'u'].forEach(v => add(4, A.sukKey(L, v, 'sukoon'), A.sukText(L, v), `${L.n} with sukoon after ${markName[v]}`, 'Sukoon, Say It Back')));
A.SK_LETTERS.forEach(L => ['a', 'i', 'u'].forEach(v => add(4, A.sukKey(L, v, 'shadda'), A.shdText(L, v), `${L.n} with shaddah and ${markName[v]}`, 'Shaddah, Say It Back')));

const files = new Set(); rows.forEach(r => { if (files.has(r.file)) throw new Error('duplicate ' + r.file); files.add(r.file); });
const q = s => /[",\n]/.test(s) ? `"${String(s).replace(/"/g, '""')}"` : s;
const out = path.join(root, 'audio', 'ar');
fs.writeFileSync(path.join(out, 'recordings.csv'), '﻿priority,file,arabic,what it is,used in\n' + rows.map(r => [r.priority, r.file + '.mp3', r.arabic, r.what, r.game].map(q).join(',')).join('\n') + '\n');

const by = p => rows.filter(r => r.priority === p);
const table = list => '| File | Arabic | What it is |\n|---|---|---|\n' + list.map(r => `| \`${r.file}.mp3\` | ${r.arabic} | ${r.what} |`).join('\n');
const md = `# Arabic recordings for Garaad

Garaad's Arabic games play a teacher's recording for each sound when one exists. Until then the phone's own Arabic voice reads the text, which is fine for words but weak for single letters and syllables. So the Qaida sounds matter most.

There are ${rows.length} sounds. Start with priority 1 (letters and short vowels, ${by(1).length} sounds), which covers Steps 1 to 3 of the Qaida games.

The same list is in \`recordings.csv\` (opens in Excel or Google Sheets), so the teacher can tick off each one.

## Before recording: check the Arabic

Every Arabic word and syllable below was prepared for the app and still needs a check by a qualified Arabic or Qaida teacher: spelling, vowel marks, and that the words suit children. Corrections go into \`index.html\` (search for \`AR_DICT\` for words, \`AR_LETTERS\` for letter names), then run \`node tools/make-recording-list.js\` to refresh this list.

## How to record

1. Use a quiet room. One voice for everything, ideally a teacher who teaches the Qaida.
2. Say each sound once, clearly, in the Qaida way, with a short pause before and after. Single sounds such as *ba* are said on their own, not as the letter name.
3. Trim silence at the start and end. Keep each file short (1–2 seconds; phrases up to 3).
4. Save as **mp3** (mono, 64 kbps is plenty). \`.m4a\` from an iPhone also works.
5. Name each file exactly as in the list, for example \`letter-b.mp3\` or \`fatha-b.mp3\`.

## How to add them to the app

On GitHub, open \`audio/ar/\`, choose **Add file › Upload files**, drop in the files and commit. A GitHub Action then updates \`audio/ar/index.json\` by itself, and the app plays the recordings from then on. Phones save them for offline use the next time a child opens the Arabic tab online.

To replace a recording, upload a file with the same name. Phones that saved the old one keep it until the app's offline cache is next updated, so get recordings right before schools use them.

## Priority 1 · Letters and short vowels (Steps 1–3)

${table(by(1))}

## Priority 2 · Words and phrases (Steps 5–6)

${table(by(2))}

## Priority 3 · Tanween and long vowels (Step 3)

${table(by(3))}

## Priority 4 · Sukoon and shaddah (Step 4)

${table(by(4))}
`;
fs.writeFileSync(path.join(out, 'RECORDINGS.md'), md);
console.log(rows.length, 'recordings;', [1, 2, 3, 4].map(p => `priority ${p}: ${by(p).length}`).join(', '));
