# Arabic recordings for Garaad

Garaad's Arabic games play a teacher's recording for each sound when one exists. Until then the phone's own Arabic voice reads the text, which is fine for words but weak for single letters and syllables. So the Qaida sounds matter most.

There are 558 sounds. Start with priority 1 (letters and short vowels, 118 sounds), which covers Steps 1 to 3 of the Qaida games.

The same list is in `recordings.csv` (opens in Excel or Google Sheets), so the teacher can tick off each one.

## Before recording: check the Arabic

Every Arabic word and syllable below was prepared for the app and still needs a check by a qualified Arabic or Qaida teacher: spelling, vowel marks, and that the words suit children. Corrections go into `index.html` (search for `AR_DICT` for words, `AR_LETTERS` for letter names), then run `node tools/make-recording-list.js` to refresh this list.

## How to record

1. Use a quiet room. One voice for everything, ideally a teacher who teaches the Qaida.
2. Say each sound once, clearly, in the Qaida way, with a short pause before and after. Single sounds such as *ba* are said on their own, not as the letter name.
3. Trim silence at the start and end. Keep each file short (1–2 seconds; phrases up to 3).
4. Save as **mp3** (mono, 64 kbps is plenty). `.m4a` from an iPhone also works.
5. Name each file exactly as in the list, for example `letter-b.mp3` or `fatha-b.mp3`.

## How to add them to the app

On GitHub, open `audio/ar/`, choose **Add file › Upload files**, drop in the files and commit. A GitHub Action then updates `audio/ar/index.json` by itself, and the app plays the recordings from then on. Phones save them for offline use the next time a child opens the Arabic tab online.

To replace a recording, upload a file with the same name. Phones that saved the old one keep it until the app's offline cache is next updated, so get recordings right before schools use them.

## Priority 1 · Letters and short vowels (Steps 1–3)

| File | Arabic | What it is |
|---|---|---|
| `letter-a.mp3` | أَلِف | name of the letter ا |
| `letter-b.mp3` | بَاء | name of the letter ب |
| `letter-t.mp3` | تَاء | name of the letter ت |
| `letter-th.mp3` | ثَاء | name of the letter ث |
| `letter-j.mp3` | جِيم | name of the letter ج |
| `letter-hh.mp3` | حَاء | name of the letter ح |
| `letter-kh.mp3` | خَاء | name of the letter خ |
| `letter-d.mp3` | دَال | name of the letter د |
| `letter-dh.mp3` | ذَال | name of the letter ذ |
| `letter-r.mp3` | رَاء | name of the letter ر |
| `letter-z.mp3` | زَاي | name of the letter ز |
| `letter-s.mp3` | سِين | name of the letter س |
| `letter-sh.mp3` | شِين | name of the letter ش |
| `letter-ss.mp3` | صَاد | name of the letter ص |
| `letter-dd.mp3` | ضَاد | name of the letter ض |
| `letter-tt.mp3` | طَاء | name of the letter ط |
| `letter-zz.mp3` | ظَاء | name of the letter ظ |
| `letter-ay.mp3` | عَيْن | name of the letter ع |
| `letter-gh.mp3` | غَيْن | name of the letter غ |
| `letter-f.mp3` | فَاء | name of the letter ف |
| `letter-q.mp3` | قَاف | name of the letter ق |
| `letter-k.mp3` | كَاف | name of the letter ك |
| `letter-l.mp3` | لَام | name of the letter ل |
| `letter-m.mp3` | مِيم | name of the letter م |
| `letter-n.mp3` | نُون | name of the letter ن |
| `letter-h.mp3` | هَاء | name of the letter ه |
| `letter-w.mp3` | وَاو | name of the letter و |
| `letter-y.mp3` | يَاء | name of the letter ي |
| `name-fatha.mp3` | فَتْحَة | the word fatha |
| `name-kasra.mp3` | كَسْرَة | the word kasra |
| `name-damma.mp3` | ضَمَّة | the word damma |
| `name-tanfath.mp3` | فَتْحَتَان | the word tanween fatha |
| `name-tankasr.mp3` | كَسْرَتَان | the word tanween kasra |
| `name-tandamm.mp3` | ضَمَّتَان | the word tanween damma |
| `fatha-hm.mp3` | أَ | هَمْزَة with fatha |
| `kasra-hm.mp3` | إِ | هَمْزَة with kasra |
| `damma-hm.mp3` | أُ | هَمْزَة with damma |
| `fatha-b.mp3` | بَ | بَاء with fatha |
| `kasra-b.mp3` | بِ | بَاء with kasra |
| `damma-b.mp3` | بُ | بَاء with damma |
| `fatha-t.mp3` | تَ | تَاء with fatha |
| `kasra-t.mp3` | تِ | تَاء with kasra |
| `damma-t.mp3` | تُ | تَاء with damma |
| `fatha-th.mp3` | ثَ | ثَاء with fatha |
| `kasra-th.mp3` | ثِ | ثَاء with kasra |
| `damma-th.mp3` | ثُ | ثَاء with damma |
| `fatha-j.mp3` | جَ | جِيم with fatha |
| `kasra-j.mp3` | جِ | جِيم with kasra |
| `damma-j.mp3` | جُ | جِيم with damma |
| `fatha-hh.mp3` | حَ | حَاء with fatha |
| `kasra-hh.mp3` | حِ | حَاء with kasra |
| `damma-hh.mp3` | حُ | حَاء with damma |
| `fatha-kh.mp3` | خَ | خَاء with fatha |
| `kasra-kh.mp3` | خِ | خَاء with kasra |
| `damma-kh.mp3` | خُ | خَاء with damma |
| `fatha-d.mp3` | دَ | دَال with fatha |
| `kasra-d.mp3` | دِ | دَال with kasra |
| `damma-d.mp3` | دُ | دَال with damma |
| `fatha-dh.mp3` | ذَ | ذَال with fatha |
| `kasra-dh.mp3` | ذِ | ذَال with kasra |
| `damma-dh.mp3` | ذُ | ذَال with damma |
| `fatha-r.mp3` | رَ | رَاء with fatha |
| `kasra-r.mp3` | رِ | رَاء with kasra |
| `damma-r.mp3` | رُ | رَاء with damma |
| `fatha-z.mp3` | زَ | زَاي with fatha |
| `kasra-z.mp3` | زِ | زَاي with kasra |
| `damma-z.mp3` | زُ | زَاي with damma |
| `fatha-s.mp3` | سَ | سِين with fatha |
| `kasra-s.mp3` | سِ | سِين with kasra |
| `damma-s.mp3` | سُ | سِين with damma |
| `fatha-sh.mp3` | شَ | شِين with fatha |
| `kasra-sh.mp3` | شِ | شِين with kasra |
| `damma-sh.mp3` | شُ | شِين with damma |
| `fatha-ss.mp3` | صَ | صَاد with fatha |
| `kasra-ss.mp3` | صِ | صَاد with kasra |
| `damma-ss.mp3` | صُ | صَاد with damma |
| `fatha-dd.mp3` | ضَ | ضَاد with fatha |
| `kasra-dd.mp3` | ضِ | ضَاد with kasra |
| `damma-dd.mp3` | ضُ | ضَاد with damma |
| `fatha-tt.mp3` | طَ | طَاء with fatha |
| `kasra-tt.mp3` | طِ | طَاء with kasra |
| `damma-tt.mp3` | طُ | طَاء with damma |
| `fatha-zz.mp3` | ظَ | ظَاء with fatha |
| `kasra-zz.mp3` | ظِ | ظَاء with kasra |
| `damma-zz.mp3` | ظُ | ظَاء with damma |
| `fatha-ay.mp3` | عَ | عَيْن with fatha |
| `kasra-ay.mp3` | عِ | عَيْن with kasra |
| `damma-ay.mp3` | عُ | عَيْن with damma |
| `fatha-gh.mp3` | غَ | غَيْن with fatha |
| `kasra-gh.mp3` | غِ | غَيْن with kasra |
| `damma-gh.mp3` | غُ | غَيْن with damma |
| `fatha-f.mp3` | فَ | فَاء with fatha |
| `kasra-f.mp3` | فِ | فَاء with kasra |
| `damma-f.mp3` | فُ | فَاء with damma |
| `fatha-q.mp3` | قَ | قَاف with fatha |
| `kasra-q.mp3` | قِ | قَاف with kasra |
| `damma-q.mp3` | قُ | قَاف with damma |
| `fatha-k.mp3` | كَ | كَاف with fatha |
| `kasra-k.mp3` | كِ | كَاف with kasra |
| `damma-k.mp3` | كُ | كَاف with damma |
| `fatha-l.mp3` | لَ | لَام with fatha |
| `kasra-l.mp3` | لِ | لَام with kasra |
| `damma-l.mp3` | لُ | لَام with damma |
| `fatha-m.mp3` | مَ | مِيم with fatha |
| `kasra-m.mp3` | مِ | مِيم with kasra |
| `damma-m.mp3` | مُ | مِيم with damma |
| `fatha-n.mp3` | نَ | نُون with fatha |
| `kasra-n.mp3` | نِ | نُون with kasra |
| `damma-n.mp3` | نُ | نُون with damma |
| `fatha-h.mp3` | هَ | هَاء with fatha |
| `kasra-h.mp3` | هِ | هَاء with kasra |
| `damma-h.mp3` | هُ | هَاء with damma |
| `fatha-w.mp3` | وَ | وَاو with fatha |
| `kasra-w.mp3` | وِ | وَاو with kasra |
| `damma-w.mp3` | وُ | وَاو with damma |
| `fatha-y.mp3` | يَ | يَاء with fatha |
| `kasra-y.mp3` | يِ | يَاء with kasra |
| `damma-y.mp3` | يُ | يَاء with damma |

## Priority 2 · Words and phrases (Steps 5–6)

| File | Arabic | What it is |
|---|---|---|
| `word-cat.mp3` | قِطَّة | word: cat 🐱 |
| `word-dog.mp3` | كَلْب | word: dog 🐶 |
| `word-cow.mp3` | بَقَرَة | word: cow 🐄 |
| `word-goat.mp3` | مَاعِز | word: goat 🐐 |
| `word-sheep.mp3` | خَرُوف | word: sheep 🐑 |
| `word-camel.mp3` | جَمَل | word: camel 🐪 |
| `word-hen.mp3` | دَجَاجَة | word: hen 🐔 |
| `word-fish.mp3` | سَمَكَة | word: fish 🐟 |
| `word-bird.mp3` | طَائِر | word: bird 🐦 |
| `word-horse.mp3` | حِصَان | word: horse 🐴 |
| `word-lion.mp3` | أَسَد | word: lion 🦁 |
| `word-elephant.mp3` | فِيل | word: elephant 🐘 |
| `word-duck.mp3` | بَطَّة | word: duck 🦆 |
| `word-rabbit.mp3` | أَرْنَب | word: rabbit 🐰 |
| `word-monkey.mp3` | قِرْد | word: monkey 🐒 |
| `word-frog.mp3` | ضِفْدَع | word: frog 🐸 |
| `word-mango.mp3` | مَانْجُو | word: mango 🥭 |
| `word-banana.mp3` | مَوْز | word: banana 🍌 |
| `word-apple.mp3` | تُفَّاحَة | word: apple 🍎 |
| `word-orange.mp3` | بُرْتُقَالَة | word: orange 🍊 |
| `word-milk.mp3` | حَلِيب | word: milk 🥛 |
| `word-bread.mp3` | خُبْز | word: bread 🍞 |
| `word-egg.mp3` | بَيْضَة | word: egg 🥚 |
| `word-rice.mp3` | أَرُزّ | word: rice 🍚 |
| `word-water.mp3` | مَاء | word: water 💧 |
| `word-tea.mp3` | شَاي | word: tea 🍵 |
| `word-cake.mp3` | كَعْكَة | word: cake 🍰 |
| `word-watermelon.mp3` | بَطِّيخ | word: watermelon 🍉 |
| `word-carrot.mp3` | جَزَر | word: carrot 🥕 |
| `word-tomato.mp3` | طَمَاطِم | word: tomato 🍅 |
| `word-meat.mp3` | لَحْم | word: meat 🍖 |
| `word-lemon.mp3` | لَيْمُون | word: lemon 🍋 |
| `word-red.mp3` | أَحْمَر | word: red 🔴 |
| `word-blue.mp3` | أَزْرَق | word: blue 🔵 |
| `word-green.mp3` | أَخْضَر | word: green 🟢 |
| `word-yellow.mp3` | أَصْفَر | word: yellow 🟡 |
| `word-black.mp3` | أَسْوَد | word: black ⚫ |
| `word-white.mp3` | أَبْيَض | word: white ⚪ |
| `word-purple.mp3` | بَنَفْسَجِيّ | word: purple 🟣 |
| `word-brown.mp3` | بُنِّيّ | word: brown 🟤 |
| `word-one.mp3` | وَاحِد | word: one 1️⃣ |
| `word-two.mp3` | اِثْنَان | word: two 2️⃣ |
| `word-three.mp3` | ثَلَاثَة | word: three 3️⃣ |
| `word-four.mp3` | أَرْبَعَة | word: four 4️⃣ |
| `word-five.mp3` | خَمْسَة | word: five 5️⃣ |
| `word-six.mp3` | سِتَّة | word: six 6️⃣ |
| `word-seven.mp3` | سَبْعَة | word: seven 7️⃣ |
| `word-eight.mp3` | ثَمَانِيَة | word: eight 8️⃣ |
| `word-nine.mp3` | تِسْعَة | word: nine 9️⃣ |
| `word-ten.mp3` | عَشَرَة | word: ten 🔟 |
| `word-bed.mp3` | سَرِير | word: bed 🛏️ |
| `word-door.mp3` | بَاب | word: door 🚪 |
| `word-chair.mp3` | كُرْسِيّ | word: chair 🪑 |
| `word-cup.mp3` | كُوب | word: cup ☕ |
| `word-spoon.mp3` | مِلْعَقَة | word: spoon 🥄 |
| `word-plate.mp3` | صَحْن | word: plate 🍽️ |
| `word-house.mp3` | بَيْت | word: house 🏠 |
| `word-key.mp3` | مِفْتَاح | word: key 🔑 |
| `word-clock.mp3` | سَاعَة | word: clock 🕰️ |
| `word-phone.mp3` | هَاتِف | word: phone 📱 |
| `word-book.mp3` | كِتَاب | word: book 📖 |
| `word-ball.mp3` | كُرَة | word: ball ⚽ |
| `word-bag.mp3` | حَقِيبَة | word: bag 🎒 |
| `word-broom.mp3` | مِكْنَسَة | word: broom 🧹 |
| `word-soap.mp3` | صَابُون | word: soap 🧼 |
| `word-television.mp3` | تِلْفَاز | word: television 📺 |
| `word-eye.mp3` | عَيْن | word: eye 👁️ |
| `word-ear.mp3` | أُذُن | word: ear 👂 |
| `word-nose.mp3` | أَنْف | word: nose 👃 |
| `word-mouth.mp3` | فَم | word: mouth 👄 |
| `word-hand.mp3` | يَد | word: hand ✋ |
| `word-foot.mp3` | قَدَم | word: foot 🦶 |
| `word-tooth.mp3` | سِنّ | word: tooth 🦷 |
| `word-leg.mp3` | رِجْل | word: leg 🦵 |
| `word-arm.mp3` | ذِرَاع | word: arm 💪 |
| `word-tongue.mp3` | لِسَان | word: tongue 👅 |
| `word-heart.mp3` | قَلْب | word: heart ❤️ |
| `word-finger.mp3` | إِصْبَع | word: finger ☝️ |
| `word-mother.mp3` | أُمّ | word: mother 👩 |
| `word-father.mp3` | أَب | word: father 👨 |
| `word-baby.mp3` | طِفْل | word: baby 👶 |
| `word-girl.mp3` | بِنْت | word: girl 👧 |
| `word-boy.mp3` | وَلَد | word: boy 👦 |
| `word-grandmother.mp3` | جَدَّة | word: grandmother 👵 |
| `word-grandfather.mp3` | جَدّ | word: grandfather 👴 |
| `word-teacher.mp3` | مُعَلِّمَة | word: teacher 👩‍🏫 |
| `word-doctor.mp3` | طَبِيب | word: doctor 👨‍⚕️ |
| `word-police-officer.mp3` | شُرْطِيّ | word: police officer 👮 |
| `word-shirt.mp3` | قَمِيص | word: shirt 👕 |
| `word-dress.mp3` | فُسْتَان | word: dress 👗 |
| `word-shoe.mp3` | حِذَاء | word: shoe 👟 |
| `word-cap.mp3` | قُبَّعَة | word: cap 🧢 |
| `word-sock.mp3` | جَوْرَب | word: sock 🧦 |
| `word-coat.mp3` | مِعْطَف | word: coat 🧥 |
| `word-trousers.mp3` | سِرْوَال | word: trousers 👖 |
| `word-scarf.mp3` | وِشَاح | word: scarf 🧣 |
| `word-glasses.mp3` | نَظَّارَة | word: glasses 👓 |
| `word-gloves.mp3` | قُفَّاز | word: gloves 🧤 |
| `word-ring.mp3` | خَاتَم | word: ring 💍 |
| `word-umbrella.mp3` | مِظَلَّة | word: umbrella ☂️ |
| `word-sun.mp3` | شَمْس | word: sun ☀️ |
| `word-moon.mp3` | قَمَر | word: moon 🌙 |
| `word-star.mp3` | نَجْمَة | word: star ⭐ |
| `word-tree.mp3` | شَجَرَة | word: tree 🌳 |
| `word-flower.mp3` | وَرْدَة | word: flower 🌸 |
| `word-rain.mp3` | مَطَر | word: rain 🌧️ |
| `word-car.mp3` | سَيَّارَة | word: car 🚗 |
| `word-bus.mp3` | حَافِلَة | word: bus 🚌 |
| `word-boat.mp3` | قَارِب | word: boat ⛵ |
| `word-plane.mp3` | طَائِرَة | word: plane ✈️ |
| `word-bike.mp3` | دَرَّاجَة | word: bike 🚲 |
| `word-train.mp3` | قِطَار | word: train 🚂 |
| `word-sea.mp3` | بَحْر | word: sea 🌊 |
| `word-mountain.mp3` | جَبَل | word: mountain ⛰️ |
| `word-school.mp3` | مَدْرَسَة | word: school 🏫 |
| `phrase-salam.mp3` | السَّلَامُ عَلَيْكُمْ | phrase 👋 |
| `phrase-morning.mp3` | صَبَاحُ الْخَيْرِ | phrase 🌅 |
| `phrase-thanks.mp3` | شُكْرًا | phrase 🙏 |
| `phrase-name.mp3` | مَا اسْمُكَ؟ | phrase ❓ |
| `phrase-fine.mp3` | أَنَا بِخَيْرٍ | phrase 😊 |
| `phrase-bye.mp3` | مَعَ السَّلَامَةِ | phrase 👋 |
| `phrase-welcome.mp3` | أَهْلًا وَسَهْلًا | phrase 🤗 |

## Priority 3 · Tanween and long vowels (Step 3)

| File | Arabic | What it is |
|---|---|---|
| `tanfath-hm.mp3` | ءً | هَمْزَة with tanween fatha |
| `tankasr-hm.mp3` | ءٍ | هَمْزَة with tanween kasra |
| `tandamm-hm.mp3` | ءٌ | هَمْزَة with tanween damma |
| `tanfath-b.mp3` | بًا | بَاء with tanween fatha |
| `tankasr-b.mp3` | بٍ | بَاء with tanween kasra |
| `tandamm-b.mp3` | بٌ | بَاء with tanween damma |
| `tanfath-t.mp3` | تًا | تَاء with tanween fatha |
| `tankasr-t.mp3` | تٍ | تَاء with tanween kasra |
| `tandamm-t.mp3` | تٌ | تَاء with tanween damma |
| `tanfath-th.mp3` | ثًا | ثَاء with tanween fatha |
| `tankasr-th.mp3` | ثٍ | ثَاء with tanween kasra |
| `tandamm-th.mp3` | ثٌ | ثَاء with tanween damma |
| `tanfath-j.mp3` | جًا | جِيم with tanween fatha |
| `tankasr-j.mp3` | جٍ | جِيم with tanween kasra |
| `tandamm-j.mp3` | جٌ | جِيم with tanween damma |
| `tanfath-hh.mp3` | حًا | حَاء with tanween fatha |
| `tankasr-hh.mp3` | حٍ | حَاء with tanween kasra |
| `tandamm-hh.mp3` | حٌ | حَاء with tanween damma |
| `tanfath-kh.mp3` | خًا | خَاء with tanween fatha |
| `tankasr-kh.mp3` | خٍ | خَاء with tanween kasra |
| `tandamm-kh.mp3` | خٌ | خَاء with tanween damma |
| `tanfath-d.mp3` | دًا | دَال with tanween fatha |
| `tankasr-d.mp3` | دٍ | دَال with tanween kasra |
| `tandamm-d.mp3` | دٌ | دَال with tanween damma |
| `tanfath-dh.mp3` | ذًا | ذَال with tanween fatha |
| `tankasr-dh.mp3` | ذٍ | ذَال with tanween kasra |
| `tandamm-dh.mp3` | ذٌ | ذَال with tanween damma |
| `tanfath-r.mp3` | رًا | رَاء with tanween fatha |
| `tankasr-r.mp3` | رٍ | رَاء with tanween kasra |
| `tandamm-r.mp3` | رٌ | رَاء with tanween damma |
| `tanfath-z.mp3` | زًا | زَاي with tanween fatha |
| `tankasr-z.mp3` | زٍ | زَاي with tanween kasra |
| `tandamm-z.mp3` | زٌ | زَاي with tanween damma |
| `tanfath-s.mp3` | سًا | سِين with tanween fatha |
| `tankasr-s.mp3` | سٍ | سِين with tanween kasra |
| `tandamm-s.mp3` | سٌ | سِين with tanween damma |
| `tanfath-sh.mp3` | شًا | شِين with tanween fatha |
| `tankasr-sh.mp3` | شٍ | شِين with tanween kasra |
| `tandamm-sh.mp3` | شٌ | شِين with tanween damma |
| `tanfath-ss.mp3` | صًا | صَاد with tanween fatha |
| `tankasr-ss.mp3` | صٍ | صَاد with tanween kasra |
| `tandamm-ss.mp3` | صٌ | صَاد with tanween damma |
| `tanfath-dd.mp3` | ضًا | ضَاد with tanween fatha |
| `tankasr-dd.mp3` | ضٍ | ضَاد with tanween kasra |
| `tandamm-dd.mp3` | ضٌ | ضَاد with tanween damma |
| `tanfath-tt.mp3` | طًا | طَاء with tanween fatha |
| `tankasr-tt.mp3` | طٍ | طَاء with tanween kasra |
| `tandamm-tt.mp3` | طٌ | طَاء with tanween damma |
| `tanfath-zz.mp3` | ظًا | ظَاء with tanween fatha |
| `tankasr-zz.mp3` | ظٍ | ظَاء with tanween kasra |
| `tandamm-zz.mp3` | ظٌ | ظَاء with tanween damma |
| `tanfath-ay.mp3` | عًا | عَيْن with tanween fatha |
| `tankasr-ay.mp3` | عٍ | عَيْن with tanween kasra |
| `tandamm-ay.mp3` | عٌ | عَيْن with tanween damma |
| `tanfath-gh.mp3` | غًا | غَيْن with tanween fatha |
| `tankasr-gh.mp3` | غٍ | غَيْن with tanween kasra |
| `tandamm-gh.mp3` | غٌ | غَيْن with tanween damma |
| `tanfath-f.mp3` | فًا | فَاء with tanween fatha |
| `tankasr-f.mp3` | فٍ | فَاء with tanween kasra |
| `tandamm-f.mp3` | فٌ | فَاء with tanween damma |
| `tanfath-q.mp3` | قًا | قَاف with tanween fatha |
| `tankasr-q.mp3` | قٍ | قَاف with tanween kasra |
| `tandamm-q.mp3` | قٌ | قَاف with tanween damma |
| `tanfath-k.mp3` | كًا | كَاف with tanween fatha |
| `tankasr-k.mp3` | كٍ | كَاف with tanween kasra |
| `tandamm-k.mp3` | كٌ | كَاف with tanween damma |
| `tanfath-l.mp3` | لًا | لَام with tanween fatha |
| `tankasr-l.mp3` | لٍ | لَام with tanween kasra |
| `tandamm-l.mp3` | لٌ | لَام with tanween damma |
| `tanfath-m.mp3` | مًا | مِيم with tanween fatha |
| `tankasr-m.mp3` | مٍ | مِيم with tanween kasra |
| `tandamm-m.mp3` | مٌ | مِيم with tanween damma |
| `tanfath-n.mp3` | نًا | نُون with tanween fatha |
| `tankasr-n.mp3` | نٍ | نُون with tanween kasra |
| `tandamm-n.mp3` | نٌ | نُون with tanween damma |
| `tanfath-h.mp3` | هًا | هَاء with tanween fatha |
| `tankasr-h.mp3` | هٍ | هَاء with tanween kasra |
| `tandamm-h.mp3` | هٌ | هَاء with tanween damma |
| `tanfath-w.mp3` | وًا | وَاو with tanween fatha |
| `tankasr-w.mp3` | وٍ | وَاو with tanween kasra |
| `tandamm-w.mp3` | وٌ | وَاو with tanween damma |
| `tanfath-y.mp3` | يًا | يَاء with tanween fatha |
| `tankasr-y.mp3` | يٍ | يَاء with tanween kasra |
| `tandamm-y.mp3` | يٌ | يَاء with tanween damma |
| `madda-hm.mp3` | آ | هَمْزَة with long a (madd alif) |
| `maddi-hm.mp3` | إِي | هَمْزَة with long i (madd ya) |
| `maddu-hm.mp3` | أُو | هَمْزَة with long u (madd waw) |
| `madda-b.mp3` | بَا | بَاء with long a (madd alif) |
| `maddi-b.mp3` | بِي | بَاء with long i (madd ya) |
| `maddu-b.mp3` | بُو | بَاء with long u (madd waw) |
| `madda-t.mp3` | تَا | تَاء with long a (madd alif) |
| `maddi-t.mp3` | تِي | تَاء with long i (madd ya) |
| `maddu-t.mp3` | تُو | تَاء with long u (madd waw) |
| `madda-th.mp3` | ثَا | ثَاء with long a (madd alif) |
| `maddi-th.mp3` | ثِي | ثَاء with long i (madd ya) |
| `maddu-th.mp3` | ثُو | ثَاء with long u (madd waw) |
| `madda-j.mp3` | جَا | جِيم with long a (madd alif) |
| `maddi-j.mp3` | جِي | جِيم with long i (madd ya) |
| `maddu-j.mp3` | جُو | جِيم with long u (madd waw) |
| `madda-hh.mp3` | حَا | حَاء with long a (madd alif) |
| `maddi-hh.mp3` | حِي | حَاء with long i (madd ya) |
| `maddu-hh.mp3` | حُو | حَاء with long u (madd waw) |
| `madda-kh.mp3` | خَا | خَاء with long a (madd alif) |
| `maddi-kh.mp3` | خِي | خَاء with long i (madd ya) |
| `maddu-kh.mp3` | خُو | خَاء with long u (madd waw) |
| `madda-d.mp3` | دَا | دَال with long a (madd alif) |
| `maddi-d.mp3` | دِي | دَال with long i (madd ya) |
| `maddu-d.mp3` | دُو | دَال with long u (madd waw) |
| `madda-dh.mp3` | ذَا | ذَال with long a (madd alif) |
| `maddi-dh.mp3` | ذِي | ذَال with long i (madd ya) |
| `maddu-dh.mp3` | ذُو | ذَال with long u (madd waw) |
| `madda-r.mp3` | رَا | رَاء with long a (madd alif) |
| `maddi-r.mp3` | رِي | رَاء with long i (madd ya) |
| `maddu-r.mp3` | رُو | رَاء with long u (madd waw) |
| `madda-z.mp3` | زَا | زَاي with long a (madd alif) |
| `maddi-z.mp3` | زِي | زَاي with long i (madd ya) |
| `maddu-z.mp3` | زُو | زَاي with long u (madd waw) |
| `madda-s.mp3` | سَا | سِين with long a (madd alif) |
| `maddi-s.mp3` | سِي | سِين with long i (madd ya) |
| `maddu-s.mp3` | سُو | سِين with long u (madd waw) |
| `madda-sh.mp3` | شَا | شِين with long a (madd alif) |
| `maddi-sh.mp3` | شِي | شِين with long i (madd ya) |
| `maddu-sh.mp3` | شُو | شِين with long u (madd waw) |
| `madda-ss.mp3` | صَا | صَاد with long a (madd alif) |
| `maddi-ss.mp3` | صِي | صَاد with long i (madd ya) |
| `maddu-ss.mp3` | صُو | صَاد with long u (madd waw) |
| `madda-dd.mp3` | ضَا | ضَاد with long a (madd alif) |
| `maddi-dd.mp3` | ضِي | ضَاد with long i (madd ya) |
| `maddu-dd.mp3` | ضُو | ضَاد with long u (madd waw) |
| `madda-tt.mp3` | طَا | طَاء with long a (madd alif) |
| `maddi-tt.mp3` | طِي | طَاء with long i (madd ya) |
| `maddu-tt.mp3` | طُو | طَاء with long u (madd waw) |
| `madda-zz.mp3` | ظَا | ظَاء with long a (madd alif) |
| `maddi-zz.mp3` | ظِي | ظَاء with long i (madd ya) |
| `maddu-zz.mp3` | ظُو | ظَاء with long u (madd waw) |
| `madda-ay.mp3` | عَا | عَيْن with long a (madd alif) |
| `maddi-ay.mp3` | عِي | عَيْن with long i (madd ya) |
| `maddu-ay.mp3` | عُو | عَيْن with long u (madd waw) |
| `madda-gh.mp3` | غَا | غَيْن with long a (madd alif) |
| `maddi-gh.mp3` | غِي | غَيْن with long i (madd ya) |
| `maddu-gh.mp3` | غُو | غَيْن with long u (madd waw) |
| `madda-f.mp3` | فَا | فَاء with long a (madd alif) |
| `maddi-f.mp3` | فِي | فَاء with long i (madd ya) |
| `maddu-f.mp3` | فُو | فَاء with long u (madd waw) |
| `madda-q.mp3` | قَا | قَاف with long a (madd alif) |
| `maddi-q.mp3` | قِي | قَاف with long i (madd ya) |
| `maddu-q.mp3` | قُو | قَاف with long u (madd waw) |
| `madda-k.mp3` | كَا | كَاف with long a (madd alif) |
| `maddi-k.mp3` | كِي | كَاف with long i (madd ya) |
| `maddu-k.mp3` | كُو | كَاف with long u (madd waw) |
| `madda-l.mp3` | لَا | لَام with long a (madd alif) |
| `maddi-l.mp3` | لِي | لَام with long i (madd ya) |
| `maddu-l.mp3` | لُو | لَام with long u (madd waw) |
| `madda-m.mp3` | مَا | مِيم with long a (madd alif) |
| `maddi-m.mp3` | مِي | مِيم with long i (madd ya) |
| `maddu-m.mp3` | مُو | مِيم with long u (madd waw) |
| `madda-n.mp3` | نَا | نُون with long a (madd alif) |
| `maddi-n.mp3` | نِي | نُون with long i (madd ya) |
| `maddu-n.mp3` | نُو | نُون with long u (madd waw) |
| `madda-h.mp3` | هَا | هَاء with long a (madd alif) |
| `maddi-h.mp3` | هِي | هَاء with long i (madd ya) |
| `maddu-h.mp3` | هُو | هَاء with long u (madd waw) |
| `madda-w.mp3` | وَا | وَاو with long a (madd alif) |
| `maddi-w.mp3` | وِي | وَاو with long i (madd ya) |
| `maddu-w.mp3` | وُو | وَاو with long u (madd waw) |
| `madda-y.mp3` | يَا | يَاء with long a (madd alif) |
| `maddi-y.mp3` | يِي | يَاء with long i (madd ya) |
| `maddu-y.mp3` | يُو | يَاء with long u (madd waw) |

## Priority 4 · Sukoon and shaddah (Step 4)

| File | Arabic | What it is |
|---|---|---|
| `sukoona-b.mp3` | أَبْ | بَاء with sukoon after fatha |
| `sukooni-b.mp3` | إِبْ | بَاء with sukoon after kasra |
| `sukoonu-b.mp3` | أُبْ | بَاء with sukoon after damma |
| `sukoona-t.mp3` | أَتْ | تَاء with sukoon after fatha |
| `sukooni-t.mp3` | إِتْ | تَاء with sukoon after kasra |
| `sukoonu-t.mp3` | أُتْ | تَاء with sukoon after damma |
| `sukoona-th.mp3` | أَثْ | ثَاء with sukoon after fatha |
| `sukooni-th.mp3` | إِثْ | ثَاء with sukoon after kasra |
| `sukoonu-th.mp3` | أُثْ | ثَاء with sukoon after damma |
| `sukoona-j.mp3` | أَجْ | جِيم with sukoon after fatha |
| `sukooni-j.mp3` | إِجْ | جِيم with sukoon after kasra |
| `sukoonu-j.mp3` | أُجْ | جِيم with sukoon after damma |
| `sukoona-hh.mp3` | أَحْ | حَاء with sukoon after fatha |
| `sukooni-hh.mp3` | إِحْ | حَاء with sukoon after kasra |
| `sukoonu-hh.mp3` | أُحْ | حَاء with sukoon after damma |
| `sukoona-kh.mp3` | أَخْ | خَاء with sukoon after fatha |
| `sukooni-kh.mp3` | إِخْ | خَاء with sukoon after kasra |
| `sukoonu-kh.mp3` | أُخْ | خَاء with sukoon after damma |
| `sukoona-d.mp3` | أَدْ | دَال with sukoon after fatha |
| `sukooni-d.mp3` | إِدْ | دَال with sukoon after kasra |
| `sukoonu-d.mp3` | أُدْ | دَال with sukoon after damma |
| `sukoona-dh.mp3` | أَذْ | ذَال with sukoon after fatha |
| `sukooni-dh.mp3` | إِذْ | ذَال with sukoon after kasra |
| `sukoonu-dh.mp3` | أُذْ | ذَال with sukoon after damma |
| `sukoona-r.mp3` | أَرْ | رَاء with sukoon after fatha |
| `sukooni-r.mp3` | إِرْ | رَاء with sukoon after kasra |
| `sukoonu-r.mp3` | أُرْ | رَاء with sukoon after damma |
| `sukoona-z.mp3` | أَزْ | زَاي with sukoon after fatha |
| `sukooni-z.mp3` | إِزْ | زَاي with sukoon after kasra |
| `sukoonu-z.mp3` | أُزْ | زَاي with sukoon after damma |
| `sukoona-s.mp3` | أَسْ | سِين with sukoon after fatha |
| `sukooni-s.mp3` | إِسْ | سِين with sukoon after kasra |
| `sukoonu-s.mp3` | أُسْ | سِين with sukoon after damma |
| `sukoona-sh.mp3` | أَشْ | شِين with sukoon after fatha |
| `sukooni-sh.mp3` | إِشْ | شِين with sukoon after kasra |
| `sukoonu-sh.mp3` | أُشْ | شِين with sukoon after damma |
| `sukoona-ss.mp3` | أَصْ | صَاد with sukoon after fatha |
| `sukooni-ss.mp3` | إِصْ | صَاد with sukoon after kasra |
| `sukoonu-ss.mp3` | أُصْ | صَاد with sukoon after damma |
| `sukoona-dd.mp3` | أَضْ | ضَاد with sukoon after fatha |
| `sukooni-dd.mp3` | إِضْ | ضَاد with sukoon after kasra |
| `sukoonu-dd.mp3` | أُضْ | ضَاد with sukoon after damma |
| `sukoona-tt.mp3` | أَطْ | طَاء with sukoon after fatha |
| `sukooni-tt.mp3` | إِطْ | طَاء with sukoon after kasra |
| `sukoonu-tt.mp3` | أُطْ | طَاء with sukoon after damma |
| `sukoona-zz.mp3` | أَظْ | ظَاء with sukoon after fatha |
| `sukooni-zz.mp3` | إِظْ | ظَاء with sukoon after kasra |
| `sukoonu-zz.mp3` | أُظْ | ظَاء with sukoon after damma |
| `sukoona-ay.mp3` | أَعْ | عَيْن with sukoon after fatha |
| `sukooni-ay.mp3` | إِعْ | عَيْن with sukoon after kasra |
| `sukoonu-ay.mp3` | أُعْ | عَيْن with sukoon after damma |
| `sukoona-gh.mp3` | أَغْ | غَيْن with sukoon after fatha |
| `sukooni-gh.mp3` | إِغْ | غَيْن with sukoon after kasra |
| `sukoonu-gh.mp3` | أُغْ | غَيْن with sukoon after damma |
| `sukoona-f.mp3` | أَفْ | فَاء with sukoon after fatha |
| `sukooni-f.mp3` | إِفْ | فَاء with sukoon after kasra |
| `sukoonu-f.mp3` | أُفْ | فَاء with sukoon after damma |
| `sukoona-q.mp3` | أَقْ | قَاف with sukoon after fatha |
| `sukooni-q.mp3` | إِقْ | قَاف with sukoon after kasra |
| `sukoonu-q.mp3` | أُقْ | قَاف with sukoon after damma |
| `sukoona-k.mp3` | أَكْ | كَاف with sukoon after fatha |
| `sukooni-k.mp3` | إِكْ | كَاف with sukoon after kasra |
| `sukoonu-k.mp3` | أُكْ | كَاف with sukoon after damma |
| `sukoona-l.mp3` | أَلْ | لَام with sukoon after fatha |
| `sukooni-l.mp3` | إِلْ | لَام with sukoon after kasra |
| `sukoonu-l.mp3` | أُلْ | لَام with sukoon after damma |
| `sukoona-m.mp3` | أَمْ | مِيم with sukoon after fatha |
| `sukooni-m.mp3` | إِمْ | مِيم with sukoon after kasra |
| `sukoonu-m.mp3` | أُمْ | مِيم with sukoon after damma |
| `sukoona-n.mp3` | أَنْ | نُون with sukoon after fatha |
| `sukooni-n.mp3` | إِنْ | نُون with sukoon after kasra |
| `sukoonu-n.mp3` | أُنْ | نُون with sukoon after damma |
| `sukoona-h.mp3` | أَهْ | هَاء with sukoon after fatha |
| `sukooni-h.mp3` | إِهْ | هَاء with sukoon after kasra |
| `sukoonu-h.mp3` | أُهْ | هَاء with sukoon after damma |
| `shaddaa-b.mp3` | أَبَّ | بَاء with shaddah and fatha |
| `shaddai-b.mp3` | أَبِّ | بَاء with shaddah and kasra |
| `shaddau-b.mp3` | أَبُّ | بَاء with shaddah and damma |
| `shaddaa-t.mp3` | أَتَّ | تَاء with shaddah and fatha |
| `shaddai-t.mp3` | أَتِّ | تَاء with shaddah and kasra |
| `shaddau-t.mp3` | أَتُّ | تَاء with shaddah and damma |
| `shaddaa-th.mp3` | أَثَّ | ثَاء with shaddah and fatha |
| `shaddai-th.mp3` | أَثِّ | ثَاء with shaddah and kasra |
| `shaddau-th.mp3` | أَثُّ | ثَاء with shaddah and damma |
| `shaddaa-j.mp3` | أَجَّ | جِيم with shaddah and fatha |
| `shaddai-j.mp3` | أَجِّ | جِيم with shaddah and kasra |
| `shaddau-j.mp3` | أَجُّ | جِيم with shaddah and damma |
| `shaddaa-hh.mp3` | أَحَّ | حَاء with shaddah and fatha |
| `shaddai-hh.mp3` | أَحِّ | حَاء with shaddah and kasra |
| `shaddau-hh.mp3` | أَحُّ | حَاء with shaddah and damma |
| `shaddaa-kh.mp3` | أَخَّ | خَاء with shaddah and fatha |
| `shaddai-kh.mp3` | أَخِّ | خَاء with shaddah and kasra |
| `shaddau-kh.mp3` | أَخُّ | خَاء with shaddah and damma |
| `shaddaa-d.mp3` | أَدَّ | دَال with shaddah and fatha |
| `shaddai-d.mp3` | أَدِّ | دَال with shaddah and kasra |
| `shaddau-d.mp3` | أَدُّ | دَال with shaddah and damma |
| `shaddaa-dh.mp3` | أَذَّ | ذَال with shaddah and fatha |
| `shaddai-dh.mp3` | أَذِّ | ذَال with shaddah and kasra |
| `shaddau-dh.mp3` | أَذُّ | ذَال with shaddah and damma |
| `shaddaa-r.mp3` | أَرَّ | رَاء with shaddah and fatha |
| `shaddai-r.mp3` | أَرِّ | رَاء with shaddah and kasra |
| `shaddau-r.mp3` | أَرُّ | رَاء with shaddah and damma |
| `shaddaa-z.mp3` | أَزَّ | زَاي with shaddah and fatha |
| `shaddai-z.mp3` | أَزِّ | زَاي with shaddah and kasra |
| `shaddau-z.mp3` | أَزُّ | زَاي with shaddah and damma |
| `shaddaa-s.mp3` | أَسَّ | سِين with shaddah and fatha |
| `shaddai-s.mp3` | أَسِّ | سِين with shaddah and kasra |
| `shaddau-s.mp3` | أَسُّ | سِين with shaddah and damma |
| `shaddaa-sh.mp3` | أَشَّ | شِين with shaddah and fatha |
| `shaddai-sh.mp3` | أَشِّ | شِين with shaddah and kasra |
| `shaddau-sh.mp3` | أَشُّ | شِين with shaddah and damma |
| `shaddaa-ss.mp3` | أَصَّ | صَاد with shaddah and fatha |
| `shaddai-ss.mp3` | أَصِّ | صَاد with shaddah and kasra |
| `shaddau-ss.mp3` | أَصُّ | صَاد with shaddah and damma |
| `shaddaa-dd.mp3` | أَضَّ | ضَاد with shaddah and fatha |
| `shaddai-dd.mp3` | أَضِّ | ضَاد with shaddah and kasra |
| `shaddau-dd.mp3` | أَضُّ | ضَاد with shaddah and damma |
| `shaddaa-tt.mp3` | أَطَّ | طَاء with shaddah and fatha |
| `shaddai-tt.mp3` | أَطِّ | طَاء with shaddah and kasra |
| `shaddau-tt.mp3` | أَطُّ | طَاء with shaddah and damma |
| `shaddaa-zz.mp3` | أَظَّ | ظَاء with shaddah and fatha |
| `shaddai-zz.mp3` | أَظِّ | ظَاء with shaddah and kasra |
| `shaddau-zz.mp3` | أَظُّ | ظَاء with shaddah and damma |
| `shaddaa-ay.mp3` | أَعَّ | عَيْن with shaddah and fatha |
| `shaddai-ay.mp3` | أَعِّ | عَيْن with shaddah and kasra |
| `shaddau-ay.mp3` | أَعُّ | عَيْن with shaddah and damma |
| `shaddaa-gh.mp3` | أَغَّ | غَيْن with shaddah and fatha |
| `shaddai-gh.mp3` | أَغِّ | غَيْن with shaddah and kasra |
| `shaddau-gh.mp3` | أَغُّ | غَيْن with shaddah and damma |
| `shaddaa-f.mp3` | أَفَّ | فَاء with shaddah and fatha |
| `shaddai-f.mp3` | أَفِّ | فَاء with shaddah and kasra |
| `shaddau-f.mp3` | أَفُّ | فَاء with shaddah and damma |
| `shaddaa-q.mp3` | أَقَّ | قَاف with shaddah and fatha |
| `shaddai-q.mp3` | أَقِّ | قَاف with shaddah and kasra |
| `shaddau-q.mp3` | أَقُّ | قَاف with shaddah and damma |
| `shaddaa-k.mp3` | أَكَّ | كَاف with shaddah and fatha |
| `shaddai-k.mp3` | أَكِّ | كَاف with shaddah and kasra |
| `shaddau-k.mp3` | أَكُّ | كَاف with shaddah and damma |
| `shaddaa-l.mp3` | أَلَّ | لَام with shaddah and fatha |
| `shaddai-l.mp3` | أَلِّ | لَام with shaddah and kasra |
| `shaddau-l.mp3` | أَلُّ | لَام with shaddah and damma |
| `shaddaa-m.mp3` | أَمَّ | مِيم with shaddah and fatha |
| `shaddai-m.mp3` | أَمِّ | مِيم with shaddah and kasra |
| `shaddau-m.mp3` | أَمُّ | مِيم with shaddah and damma |
| `shaddaa-n.mp3` | أَنَّ | نُون with shaddah and fatha |
| `shaddai-n.mp3` | أَنِّ | نُون with shaddah and kasra |
| `shaddau-n.mp3` | أَنُّ | نُون with shaddah and damma |
| `shaddaa-h.mp3` | أَهَّ | هَاء with shaddah and fatha |
| `shaddai-h.mp3` | أَهِّ | هَاء with shaddah and kasra |
| `shaddau-h.mp3` | أَهُّ | هَاء with shaddah and damma |
