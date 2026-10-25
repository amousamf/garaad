/**
 * Tiri live results collector — Google Apps Script
 *
 * Receives data from the Tiri game (https://amousamf.github.io/Tiri/) and writes it
 * into this Google Sheet:
 *   Children  – one row per child registered on any phone (updated if a parent edits the child)
 *   Rounds    – one row per level played
 *   Summary   – live totals, per game and per child (formulas, updates by itself)
 *
 * SETUP (once):
 *   1. Create a new Google Sheet, then Extensions → Apps Script.
 *   2. Replace everything in Code.gs with this file and click Save.
 *   3. Choose the function "setup" in the toolbar and click Run. Allow the permissions.
 *   4. Deploy → New deployment → type "Web app".
 *        Execute as: Me      Who has access: Anyone
 *      Click Deploy and copy the Web app URL (ends in /exec).
 *   5. Send that URL to Claude so it can be added to the game.
 */

// Must match the key inside the game. It stops random traffic, it is not a password.
const TIRI_KEY = 'tiri-2026-amf';

const CHILD_COLS = ['child_id', 'family', 'child', 'age', 'age_group', 'device', 'registered_at', 'last_seen', 'stars', 'removed'];
const ROUND_COLS = ['id', 'received_at', 'family', 'child_id', 'child', 'child_age', 'age_group', 'date', 'time', 'game', 'game_id', 'level',
  'questions', 'right_first_try', 'wrong_tries', 'answers_shown', 'stars', 'passed', 'seconds', 'completed', 'sprint_score', 'device'];

function setup() {
  const ss = SpreadsheetApp.getActive();
  ss.rename('Tiri — live results');
  sheet_('Children', CHILD_COLS);
  sheet_('Rounds', ROUND_COLS);
  buildSummary_(ss);
  const extra = ss.getSheetByName('Sheet1');
  if (extra && extra.getLastRow() === 0 && ss.getSheets().length > 1) ss.deleteSheet(extra);
}

function doPost(e) {
  let body;
  try { body = JSON.parse(e.postData.contents); } catch (err) { return json_({ ok: false, error: 'bad json' }); }
  if (!body || body.key !== TIRI_KEY) return json_({ ok: false, error: 'bad key' });

  const lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    const now = new Date();
    const family = clean_(body.family, 40) || '(no family name)';
    const device = clean_(body.device, 20);
    const nChildren = upsertChildren_(body.children || [], family, device, now);
    const nRounds = appendRounds_(body.rounds || [], family, device, now);
    return json_({ ok: true, children: nChildren, rounds: nRounds });
  } finally {
    lock.releaseLock();
  }
}

function doGet() {
  return json_({ ok: true, app: 'Tiri collector' });
}

/* ---------- writers ---------- */
function upsertChildren_(children, family, device, now) {
  if (!children.length) return 0;
  const sh = sheet_('Children', CHILD_COLS);
  const last = sh.getLastRow();
  const ids = last > 1 ? sh.getRange(2, 1, last - 1, 1).getValues().map(r => String(r[0])) : [];
  const index = {}; ids.forEach((id, i) => index[id] = i + 2);
  let n = 0;
  children.slice(0, 50).forEach(c => {
    const id = clean_(c.child_id, 30); if (!id) return;
    const age = num_(c.age);
    const row = [id, family, clean_(c.child, 30), age, ageGroup_(age), device,
      index[id] ? sh.getRange(index[id], 7).getValue() : now, now, num_(c.stars), c.removed ? 'yes' : ''];
    if (index[id]) sh.getRange(index[id], 1, 1, row.length).setValues([row]);
    else { sh.appendRow(row); index[id] = sh.getLastRow(); }
    n++;
  });
  return n;
}

function appendRounds_(rounds, family, device, now) {
  if (!rounds.length) return 0;
  const sh = sheet_('Rounds', ROUND_COLS);
  const last = sh.getLastRow();
  const seen = new Set(last > 1 ? sh.getRange(2, 1, last - 1, 1).getValues().map(r => String(r[0])) : []);
  const rows = [];
  rounds.slice(0, 100).forEach(r => {
    const id = clean_(r.id, 40);
    if (!id || seen.has(id)) return;
    seen.add(id);
    rows.push([id, now, family, clean_(r.child_id, 30), clean_(r.child, 30), num_(r.child_age), clean_(r.age_group, 10),
      clean_(r.date, 10), clean_(r.time, 5), clean_(r.game, 40), clean_(r.game_id, 20), num_(r.level),
      num_(r.questions), num_(r.right_first_try), num_(r.wrong_tries), num_(r.answers_shown), num_(r.stars),
      r.passed ? 'yes' : 'no', num_(r.seconds), r.completed ? 'yes' : 'no', r.sprint_score == null ? '' : num_(r.sprint_score), device]);
  });
  if (rows.length) sh.getRange(sh.getLastRow() + 1, 1, rows.length, ROUND_COLS.length).setValues(rows);
  return rows.length;
}

/* ---------- summary tab ---------- */
function buildSummary_(ss) {
  let sh = ss.getSheetByName('Summary');
  if (!sh) sh = ss.insertSheet('Summary', 0); else sh.clear();
  const C = "Children!", R = "Rounds!";
  const rows = [
    ['Tiri — live summary', ''],
    ['Updates by itself as phones send data.', ''],
    ['', ''],
    ['Families', `=IFERROR(COUNTUNIQUE(FILTER(${C}B2:B, ${C}J2:J<>"yes", ${C}A2:A<>"")),0)`],
    ['Children registered', `=COUNTIFS(${C}A2:A,"<>",${C}J2:J,"<>yes")`],
    ['Children who have played', `=IFERROR(COUNTUNIQUE(FILTER(${R}D2:D, ${R}D2:D<>"")),0)`],
    ['Levels played', `=COUNTA(${R}A2:A)`],
    ['Levels passed', `=COUNTIF(${R}R2:R,"yes")`],
    ['Questions answered', `=SUM(${R}M2:M)`],
    ['Right first time', `=SUM(${R}N2:N)`],
    ['Accuracy', `=IFERROR(B10/B9,0)`],
    ['Wrong tries', `=SUM(${R}O2:O)`],
    ['Minutes played', `=ROUND(SUM(${R}S2:S)/60)`],
    ['Last activity', `=IFERROR(MAX(${R}B2:B),"")`],
  ];
  sh.getRange(1, 1, rows.length, 2).setValues(rows);
  sh.getRange('A1').setFontSize(16).setFontWeight('bold');
  sh.getRange('A2').setFontColor('#5B6483');
  sh.getRange('A4:A14').setFontWeight('bold');
  sh.getRange('B11').setNumberFormat('0%');
  sh.getRange('B14').setNumberFormat('yyyy-mm-dd hh:mm');

  sh.getRange('D3').setValue('By game').setFontWeight('bold');
  sh.getRange('D4').setFormula(
    `=IFERROR(QUERY(${R}A2:V, "select J, count(A), sum(M), sum(N), max(L) where A is not null group by J order by count(A) desc label J 'Game', count(A) 'Levels played', sum(M) 'Questions', sum(N) 'Right first time', max(L) 'Highest level'", 0), "No data yet")`);

  sh.getRange('J3').setValue('By child').setFontWeight('bold');
  sh.getRange('J4').setFormula(
    `=IFERROR(QUERY(${R}A2:V, "select C, E, F, count(A), sum(M), sum(N), max(B) where A is not null group by C, E, F order by count(A) desc label C 'Family', E 'Child', F 'Age', count(A) 'Levels played', sum(M) 'Questions', sum(N) 'Right first time', max(B) 'Last played'", 0), "No data yet")`);

  sh.getRange('D20').setValue('By day').setFontWeight('bold');
  sh.getRange('D21').setFormula(
    `=IFERROR(QUERY(${R}A2:V, "select H, count(A), sum(M), sum(N) where A is not null group by H order by H desc label H 'Date', count(A) 'Levels played', sum(M) 'Questions', sum(N) 'Right first time'", 0), "No data yet")`);
  sh.setColumnWidth(1, 200);
  sh.setFrozenRows(2);
}

/* ---------- helpers ---------- */
function sheet_(name, cols) {
  const ss = SpreadsheetApp.getActive();
  let sh = ss.getSheetByName(name);
  if (!sh) sh = ss.insertSheet(name);
  if (sh.getLastRow() === 0) {
    sh.getRange(1, 1, 1, cols.length).setValues([cols]).setFontWeight('bold').setBackground('#E8EDFD');
    sh.setFrozenRows(1);
  }
  return sh;
}
function ageGroup_(a) { return !a ? '' : a <= 5 ? '3-5' : a <= 8 ? '6-8' : '9-12'; }
function clean_(v, max) {
  if (v === null || v === undefined) return '';
  let s = String(v).replace(/[\u0000-\u001f]/g, ' ').trim().slice(0, max || 100);
  if (/^[=+\-@]/.test(s)) s = "'" + s; // never let text become a formula
  return s;
}
function num_(v) { const n = Number(v); return isFinite(n) ? n : 0; }
function json_(o) { return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON); }
