# Timbre glossary — ar

Status: AI-authored and AI-reviewed terminology decisions, 2026-10-25. Not human/native-speaker approved. Device wording and RTL layout require native/device QA.

## 1. Locale decisions
- Locale and variant: ar, neutral Modern Standard Arabic, not a regional dialect.
- Register: direct neutral masculine singular imperatives, avoiding gendered adjectives about the reader where possible. Warm teacher voice; no added marketing or celebration.
- Buttons: short verbal nouns or direct action verbs. Instructions use clear imperatives. Preserve pinned tabs ضبط، تعلّم، التقدّم.
- Quotes/punctuation: «…», Arabic comma ، and question mark ؟; ordinary full stop. Apostrophe ’ only in retained foreign names; ellipsis … only. Normal Arabic word spacing, no double spaces.
- Digits: ASCII 0–9 in literal numbers, including lessons. Runtime placeholders use device formatting. Units Hz, BPM, XP, ¢, A4 unchanged; other units below.
- Capitalization: no Arabic casing; brands retain their spelling. Never translate or inflect Timbre, Timbre Pro, Pro, Apple, iPhone, iPad, Apple Watch, App Store, Apple Music, Game Center, Siri, ChordPro.
- Interface note names come from placeholders. Lesson note/chord letters and signs remain exactly C, B, F♯, B♭, Em, G7 etc. Accidentals: دييز / بيمول / دييز مزدوج / بيمول مزدوج. Tuner direction is أخفض / أعلى, not accidentals.
- Legal path: الإعدادات › حساب Apple › الاشتراكات. Keep every cancellation, renewal and free-tier fact; do not shorten legal facts for layout.
- Apple features: الشاشة الرئيسية / شاشة القفل / أداة / الأنشطة المباشرة / الاختصارات / مركز التحكم / المشاركة العائلية / الحس اللمسي. Apple Watch, Game Center, Siri unchanged.
- Siri: short spoken commands; retain ${applicationName} and every token. Next/Again/Slower must work spoken and on controls.
- RTL: begin with an Arabic word. When unavoidable, prefix U+200F and document it. Isolate Latin values adjoining punctuation with U+2068/U+2069 and document each use. Do not apply needless invisible marks.
- Arguments: no inflection or suffix attached to unknown values; rephrase around a label. Preserve argument order or number all arguments when reordering.
- Plurals: zero, one, two, few, many, other; preserve the numeric argument in each. Flat counted strings use neutral labels where necessary.

## 2. Binding terminology
Instrument names and tunings use the catalogue rows. Precision Expert is خبير, distinct from the Pro plan. Keep all ChordPro syntax and loop markers A/B unchanged.

| English / App key | Translation |
|---|---|
| Songs | الأغاني |
| Your songs | أغانيك |
| Quest | مهمة |
| Song sheet | صفحة الكلمات والتآلفات |
| Chart | مخطط التآلفات |
| Player view | عرض العازف |
| Chord view / Neck view | عرض التآلف / عرض العنق |
| Show me | أرني |
| Strum to tune | اضبط بالعزف على الأوتار |
| Tune by feel / Feel | الضبط بالاهتزاز / الاهتزاز |
| Tanpura drone | نغمة التانبورا الممتدة |
| Intonation | دقة النغمات |
| Placement check | اختبار المستوى |
| Play along | العزف مع المرافقة |
| Take | محاولة مسجلة |
| Loop A–B, Set A, Set B | تكرار A–B، تعيين A، تعيين B |
| Studio (lighter) / Real-time 3D | الاستوديو (أخف) / عرض ثلاثي الأبعاد آني |
| tuner / tune (verb) / tuning | موالف / ضبط / توليفة ضبط |
| flat / sharp (direction) | أخفض من المطلوب / أعلى من المطلوب |
| cents / minutes / seconds / milliseconds | سنت / دقائق / ثوانٍ / ميلي ثانية |
| lock | ثبات النغمة عند الضبط الصحيح |
| string / peg / headstock | وتر / مفتاح ضبط / رأس العنق |
| reference tone / reference pitch / Concert Pitch | نغمة مرجعية / طبقة مرجعية / الطبقة الفعلية |
| written pitch / temperament | الطبقة المكتوبة / نظام التقسيم النغمي |
| chromatic / strobe | كروماتي / ستروب |
| capo / transpose / transposition | كابو / نقل المقام / نقل المقام |
| fret / open string / finger 1–4 | دستان / وتر مطلق / إصبع 1–4 |
| chord / chord shape / barre | تآلف / شكل التآلف / باريه |
| major / minor / seventh / power chord | كبير / صغير / سابع / تآلف القوة |
| key / scale / major scale / pentatonic box | مقام / سلم / سلم كبير / نمط السلم الخماسي |
| half step / whole step / interval / third / fifth / octave | نصف درجة / درجة كاملة / مسافة نغمية / ثالثة / خامسة / أوكتاف |
| bar / beat / tempo / downbeat / count | مازورة / نبضة / سرعة الإيقاع / النبضة الأولى / العد |
| strum / downstroke / upstroke / chop / chunk / mute | عزف على الأوتار / ضربة لأسفل / ضربة لأعلى / ضربة مكتومة قصيرة / ضربة مكتومة / كتم |
| pick (plectrum / play / choose) | ريشة / نقر / اختيار |
| fingerpicking / hammer-on / pull-off / slide / bend / vibrato | نقر بالأصابع / هامر أون / بول أوف / انزلاق / ثني الوتر / اهتزاز النغمة |
| bowing / open-string bowing / tune (noun) | العزف بالقوس / العزف بالقوس على وتر مطلق / لحن |
| cadence / V chord / I–IV–V / pickup | قفلة / تآلف V / I–IV–V / تمهيد قبل المازورة |
| Intro / Verse 1 / Chorus / Bridge / Solo / Outro / Tag / section | مقدمة / مقطع 1 / لازمة / جسر / عزف منفرد / خاتمة / ذيل / قسم |
| streak / streak freeze / best run | سلسلة أيام متتالية / حماية السلسلة / أطول سلسلة |
| badge / achievement / level / stars / combo / score / round | شارة / إنجاز / مستوى / نجوم / سلسلة إصابات / نتيجة / جولة |
| challenge (friend / lesson) | تحدّي صديق / تحدّي الدرس |
| course / unit / lesson / step / quiz / hint | مسار / وحدة / درس / خطوة / اختبار / تلميح |
| subscription / renew / cancel / free trial / trial ends | اشتراك / تجديد / إلغاء / تجربة مجانية / نهاية التجربة |
| yearly / monthly / lifetime / payment method / billing issue | سنوي / شهري / مدى الحياة / طريقة الدفع / مشكلة فوترة |
| Privacy Policy | سياسة الخصوصية |
| Ear Training / Music Theory / Rhythm / Singing | تدريب الأذن / نظرية الموسيقى / الإيقاع / الغناء |
| Originals / Standards & Classics / Songbook | أغانٍ أصلية / المعايير والكلاسيكيات / كتاب الأغاني |
| Timbre | Timbre |
| Timbre Pro | Timbre Pro |
| XP | XP |
| Hz | Hz |
| A4 | A4 |
| Standard | قياسي |
| Tune | ضبط |
| Learn | تعلّم |
| Practice | التمرين |
| Progress | التقدّم |
| Settings | الإعدادات |
| Today | اليوم |
| Bullseye | في الصميم |
| Ear training | تدريب الأذن |
| Drone | نغمة ممتدة |
| Tanpura | تانبورا |
| Metronome | مترونوم |
| Speed trainer | مدرّب السرعة |
| Chords | الكوردات |
| Scales | السلالم |
| Haptics | الاهتزاز |
| Tune up | ضبط الآلة |
| Tuning | الضبط |
| In tune | مضبوط |
| flat | منخفض |
| sharp | مرتفع |
| Cents | سنت |
| Concert Pitch | طبقة الحفل |
| Temperament | نظام التسوية |
| Chromatic | كروماتيك |
| Note names | أسماء النوتات |
| Solfège | صولفيج |
| Sargam | سارغام |
| Key | النغمة |
| Octave | الأوكتاف |
| Tempo | سرعة الإيقاع |
| best run | أفضل سلسلة |
| Combo | كومبو |
| Lesson | درس |
| Free trial | تجربة مجانية |
| Yearly | سنوي |
| Monthly | شهري |
| Lifetime | مدى الحياة |
| Restore purchases | استعادة المشتريات |
| Terms | الشروط |
| timbre_catalog_family_bowed_strings | الوتريات ذات القوس |
| timbre_catalog_family_folk_world_strings | آلات وترية شعبية وعالمية |
| timbre_catalog_family_guitar | جيتار |
| timbre_catalog_family_keys | مفاتيح |
| timbre_catalog_family_mallet_percussion_hand | آلات النقر، الإيقاع واليد |
| timbre_catalog_family_mandolin | مندولين |
| timbre_catalog_family_ukulele | يوكوليلي |
| timbre_catalog_family_winds | آلات نفخ |
| timbre_catalog_instrument_autoharp_chromatic_36 | أوتوهارب |
| timbre_catalog_instrument_balalaika_prima_3 | بالالايكا (بريما) |
| timbre_catalog_instrument_banjo_five_5 | بانجو (5 أوتار) |
| timbre_catalog_instrument_bansuri_standard_0 | بانسوري |
| timbre_catalog_instrument_bass_double_4 | كونترباص (4 و 5 أوتار) |
| timbre_catalog_instrument_bass_electric_4 | غيتار باس (4 و 5 أوتار) |
| timbre_catalog_instrument_bouzouki_greek_8 | بزق يوناني (تيتراخوردو) |
| timbre_catalog_instrument_bouzouki_irish_8 | بوزوكي أيرلندي |
| timbre_catalog_instrument_cello_standard_4 | تشيلو |
| timbre_catalog_instrument_charango_standard_10 | تشارانغو |
| timbre_catalog_instrument_clarinet_bb_0 | كلارينيت (Bb / A) |
| timbre_catalog_instrument_didgeridoo_standard_0 | ديدجيريدو |
| timbre_catalog_instrument_domra_prima_3 | دومرا |
| timbre_catalog_instrument_dulcimer_appalachian_3 | دالسيمر أبالاشي / جبلي |
| timbre_catalog_instrument_dulcimer_hammered_0 | دولسيمر مطروق |
| timbre_catalog_instrument_erhu_standard_2 | إرهو |
| timbre_catalog_instrument_flute_concert_0 | ناي |
| timbre_catalog_instrument_french_horn_f_0 | هورن فرنسي (فا) |
| timbre_catalog_instrument_gayageum_standard_12 | جاياغوم |
| timbre_catalog_instrument_guitar_acoustic_12 | غيتار 12 وتراً |
| timbre_catalog_instrument_guitar_acoustic_6 | جيتار صوتي / كهربائي |
| timbre_catalog_instrument_guitar_baritone_6 | جيتار باريتون |
| timbre_catalog_instrument_guitar_electric_7 | غيتار بـ 7 أوتار |
| timbre_catalog_instrument_guitar_guitalele_6 | جيتاليل / غويليل |
| timbre_catalog_instrument_guitar_guitarron_6 | جيتارون (مكسيكي) |
| timbre_catalog_instrument_guitar_tenor_4 | جيتار تينور |
| timbre_catalog_instrument_guqin_standard_7 | غوتشين |
| timbre_catalog_instrument_guzheng_standard_21 | غوتشنغ |
| timbre_catalog_instrument_handpan_standard_0 | هانبان / طبلة اللسان الفولاذية |
| timbre_catalog_instrument_harmonica_diatonic_0 | هارمونيكا (دياتونيك) |
| timbre_catalog_instrument_kalimba_standard_17 | كاليمبا (بيانو الإبهام) |
| timbre_catalog_instrument_keys_accordion_0 | أكورديون / كونسرتينا |
| timbre_catalog_instrument_keys_harpsichord_0 | هاربسيكورد |
| timbre_catalog_instrument_keys_piano_0 | بيانو / بيانو رقمي |
| timbre_catalog_instrument_kora_standard_21 | كورا |
| timbre_catalog_instrument_koto_standard_13 | كوتو |
| timbre_catalog_instrument_lute_renaissance_6 | العود النهضوي |
| timbre_catalog_instrument_mallet_marimba_0 | ماريمبا / إكسيليفون / غلوكنسبيل / فيبرافون |
| timbre_catalog_instrument_mandocello_standard_8 | ماندوتشيلو |
| timbre_catalog_instrument_mandola_standard_8 | ماندولا |
| timbre_catalog_instrument_mandolin_octave_8 | ماندولين أوكتاف |
| timbre_catalog_instrument_mandolin_standard_8 | مندولين |
| timbre_catalog_instrument_ocarina_standard_0 | أوكارينا |
| timbre_catalog_instrument_oud_arabic_11 | عود (عربي) |
| timbre_catalog_instrument_pipa_standard_4 | بيبا |
| timbre_catalog_instrument_recorder_standard_0 | ريكوردر (سوبرانو / ألتو) |
| timbre_catalog_instrument_sarod_standard_0 | سارود |
| timbre_catalog_instrument_saxophone_standard_0 | ساكسفون (ألتو Eb / تينور Bb) |
| timbre_catalog_instrument_shakuhachi_1_8_0 | شاكوهاتشي (1.8 شاكو) |
| timbre_catalog_instrument_shamisen_standard_3 | شاميسن |
| timbre_catalog_instrument_sitar_standard_7 | سيتار |
| timbre_catalog_instrument_timpani_standard_0 | تيمباني |
| timbre_catalog_instrument_tin_whistle_d_0 | صافرة القصدير |
| timbre_catalog_instrument_trombone_bb_0 | ترومبون (Bb) |
| timbre_catalog_instrument_trumpet_bb_0 | بوق (Bb) |
| timbre_catalog_instrument_ukulele_baritone_4 | يوكوليلي باريتون |
| timbre_catalog_instrument_ukulele_bass_4 | يوكوليلي باس (UBass) |
| timbre_catalog_instrument_ukulele_soprano_4 | يوكوليلي (سوبرانو / كونسرت / تينور) |
| timbre_catalog_instrument_viola_standard_4 | فيولا |
| timbre_catalog_instrument_violin_standard_4 | كمان |
| timbre_catalog_reference_mode_reference_chromatic | كروماتيك / نغمة مرجعية |
| timbre_catalog_tuning_autoharp_chromatic_36_standard | قياسي |
| timbre_catalog_tuning_balalaika_prima_3_guitar_style | نمط الجيتار |
| timbre_catalog_tuning_balalaika_prima_3_standard | قياسي |
| timbre_catalog_tuning_banjo_five_5_double_c | دو مزدوج (Double C) |
| timbre_catalog_tuning_banjo_five_5_open_d | ري مفتوح (Open D) |
| timbre_catalog_tuning_banjo_five_5_standard | قياسي |
| timbre_catalog_tuning_bansuri_standard_0_standard | العرف الشائع (حدد الخاص بك) |
| timbre_catalog_tuning_bass_double_4_five | خمسة أوتار (سي منخفض) |
| timbre_catalog_tuning_bass_double_4_solo | ضبط منفرد |
| timbre_catalog_tuning_bass_double_4_standard | قياسي |
| timbre_catalog_tuning_bass_electric_4_drop_d | Drop D |
| timbre_catalog_tuning_bass_electric_4_five | خمسة أوتار (سي منخفض) |
| timbre_catalog_tuning_bass_electric_4_standard | قياسي |
| timbre_catalog_tuning_bouzouki_greek_8_standard | قياسي |
| timbre_catalog_tuning_bouzouki_greek_8_trichordo | تريتشوردو (D A D) |
| timbre_catalog_tuning_bouzouki_irish_8_standard | قياسي |
| timbre_catalog_tuning_cello_standard_4_standard | قياسي |
| timbre_catalog_tuning_charango_standard_10_standard | قياسي |
| timbre_catalog_tuning_clarinet_bb_0_standard | قياسي |
| timbre_catalog_tuning_didgeridoo_standard_0_standard | العرف الشائع (حدد الخاص بك) |
| timbre_catalog_tuning_domra_prima_3_four_string | 4 أوتار (أخماس، تشبه الماندولين) |
| timbre_catalog_tuning_domra_prima_3_standard | قياسي |
| timbre_catalog_tuning_dulcimer_appalachian_3_daa | DAA |
| timbre_catalog_tuning_dulcimer_appalachian_3_dac | DAC |
| timbre_catalog_tuning_dulcimer_appalachian_3_dgd | DGD |
| timbre_catalog_tuning_dulcimer_appalachian_3_standard | قياسي |
| timbre_catalog_tuning_dulcimer_hammered_0_common_g | Pathfinder 15/14 |
| timbre_catalog_tuning_dulcimer_hammered_0_standard | Pathfinder 12/11 |
| timbre_catalog_tuning_erhu_standard_2_standard | قياسي |
| timbre_catalog_tuning_flute_concert_0_standard | قياسي |
| timbre_catalog_tuning_french_horn_f_0_standard | قياسي |
| timbre_catalog_tuning_gayageum_standard_12_standard | العرف الشائع (قم بتعيين الخاص بك) |
| timbre_catalog_tuning_guitar_acoustic_12_standard | قياسي |
| timbre_catalog_tuning_guitar_acoustic_6_dadgad | DADGAD |
| timbre_catalog_tuning_guitar_acoustic_6_drop_d | دروب دي (Drop D) |
| timbre_catalog_tuning_guitar_acoustic_6_eb_std | Eb قياسي |
| timbre_catalog_tuning_guitar_acoustic_6_open_d | ضبط D المفتوح |
| timbre_catalog_tuning_guitar_acoustic_6_open_g | سول مفتوح (Open G) |
| timbre_catalog_tuning_guitar_acoustic_6_standard | قياسي |
| timbre_catalog_tuning_guitar_baritone_6_a_to_a | من A إلى A |
| timbre_catalog_tuning_guitar_baritone_6_standard | قياسي |
| timbre_catalog_tuning_guitar_electric_7_drop_a | Drop A |
| timbre_catalog_tuning_guitar_electric_7_standard | قياسي |
| timbre_catalog_tuning_guitar_guitalele_6_standard | قياسي |
| timbre_catalog_tuning_guitar_guitarron_6_standard | قياسي |
| timbre_catalog_tuning_guitar_tenor_4_standard | قياسي |
| timbre_catalog_tuning_guqin_standard_7_standard | اتفاقية شائعة (قم بضبطها بنفسك) |
| timbre_catalog_tuning_guzheng_standard_21_c_pentatonic | دو الكبير الخماسي |
| timbre_catalog_tuning_guzheng_standard_21_g_pentatonic | صول الكبير الخماسي |
| timbre_catalog_tuning_guzheng_standard_21_standard | قياسي |
| timbre_catalog_tuning_handpan_standard_0_standard | الاتفاقية الشائعة (حدد الخاصة بك) |
| timbre_catalog_tuning_harmonica_diatonic_0_key_a | مفتاح لا (A) |
| timbre_catalog_tuning_harmonica_diatonic_0_key_bb | مفتاح سي بيمول (Bb) |
| timbre_catalog_tuning_harmonica_diatonic_0_key_d | مفتاح ري (D) |
| timbre_catalog_tuning_harmonica_diatonic_0_key_eb | مفتاح مي بيمول (Eb) |
| timbre_catalog_tuning_harmonica_diatonic_0_key_f | مفتاح F |
| timbre_catalog_tuning_harmonica_diatonic_0_key_g | مفتاح صول (G) |
| timbre_catalog_tuning_harmonica_diatonic_0_standard | قياسي |
| timbre_catalog_tuning_kalimba_standard_17_standard | الاصطلاح الشائع (حدد اصطلاحك الخاص) |
| timbre_catalog_tuning_keys_accordion_0_a440 | A4 = 440 |
| timbre_catalog_tuning_keys_accordion_0_standard | قياسي |
| timbre_catalog_tuning_keys_harpsichord_0_modern_a440 | النغمة الحديثة (A4 = 440) |
| timbre_catalog_tuning_keys_harpsichord_0_standard | قياسي |
| timbre_catalog_tuning_keys_piano_0_standard | قياسي |
| timbre_catalog_tuning_koto_standard_13_standard | اتفاقية شائعة (قم بضبطها بنفسك) |
| timbre_catalog_tuning_mallet_marimba_0_glockenspiel | غلوكنسبيل |
| timbre_catalog_tuning_mallet_marimba_0_standard | قياسي |
| timbre_catalog_tuning_mallet_marimba_0_vibraphone | فيبرافون |
| timbre_catalog_tuning_mallet_marimba_0_xylophone | إكسيليفون |
| timbre_catalog_tuning_mandocello_standard_8_standard | قياسي |
| timbre_catalog_tuning_mandola_standard_8_standard | قياسي |
| timbre_catalog_tuning_mandolin_octave_8_standard | قياسي |
| timbre_catalog_tuning_mandolin_standard_8_standard | قياسي |
| timbre_catalog_tuning_ocarina_standard_0_standard | الاصطلاح الشائع (حدد الخاص بك) |
| timbre_catalog_tuning_oud_arabic_11_standard | قياسي |
| timbre_catalog_tuning_oud_arabic_11_turkish | الدوزان التركي |
| timbre_catalog_tuning_pipa_standard_4_standard | قياسي |
| timbre_catalog_tuning_recorder_standard_0_standard | قياسي |
| timbre_catalog_tuning_sarod_standard_0_standard | العرف الشائع (قم بتعيين عرفك الخاص) |
| timbre_catalog_tuning_saxophone_standard_0_standard | قياسي |
| timbre_catalog_tuning_shakuhachi_1_8_0_shaku_1_6 | 1.6 شاكو (E) |
| timbre_catalog_tuning_shakuhachi_1_8_0_shaku_2_0 | 2.0 شاكو (C) |
| timbre_catalog_tuning_shakuhachi_1_8_0_standard | قياسي |
| timbre_catalog_tuning_shamisen_standard_3_niagari | نياغاري |
| timbre_catalog_tuning_shamisen_standard_3_standard | قياسي |
| timbre_catalog_tuning_sitar_standard_7_standard | الاصطلاح الشائع (حدد الخاص بك) |
| timbre_catalog_tuning_timpani_standard_0_standard | الاتفاقية الشائعة (حدد الخاصة بك) |
| timbre_catalog_tuning_tin_whistle_d_0_key_c | مفتاح دو (C) |
| timbre_catalog_tuning_tin_whistle_d_0_key_eb | مفتاح Eb |
| timbre_catalog_tuning_tin_whistle_d_0_standard | قياسي |
| timbre_catalog_tuning_trombone_bb_0_standard | قياسي |
| timbre_catalog_tuning_trumpet_bb_0_standard | قياسي |
| timbre_catalog_tuning_ukulele_baritone_4_standard | قياسي |
| timbre_catalog_tuning_ukulele_bass_4_standard | قياسي |
| timbre_catalog_tuning_ukulele_soprano_4_d_tuning | ضبط D |
| timbre_catalog_tuning_ukulele_soprano_4_low_g | صول منخفض (Low-G) |
| timbre_catalog_tuning_ukulele_soprano_4_standard | قياسي |
| timbre_catalog_tuning_viola_standard_4_standard | قياسي |
| timbre_catalog_tuning_violin_standard_4_cross_ae | تقاطع / AE (كمان) |
| timbre_catalog_tuning_violin_standard_4_standard | قياسي |

## 3. Course and song names
Instrument course titles use the corresponding catalogue names; remaining courses use the rows above. Songs tab and course both use الأغاني. Combine instrument name with كتاب الأغاني naturally. Use the binding Arabic title map below across all shared lessons; these are localization choices, not claims of established published titles. Translate title modifiers and all teaching prose; do not retain English titles as a blanket policy. Translate Timbre Originals consistently. Only genuine sung originals, proper names and notation may remain unchanged, with exact-string invariants requiring independent review. Prose and leaderboards must match the lesson title exactly. Preserve lyrics, personal names and years in credits; translate connecting words.

## 4. Sense distinctions
Tune verb/tab means ضبط, melody means لحن. Flat/sharp direction is not an accidental. Bar means مازورة, not a pub or UI bar. Key is مقام, not a keyboard key. Pick means ريشة, نقر or اختيار by context. Lock means stable correct pitch, not a padlock. Take is محاولة مسجلة, not taking a lesson. Run means a streak or complete performance, never running. Chart is chord notation unless the context specifies a statistics graph. Intonation is pitch accuracy over a drone, not saddle setup. Practice is musical التمرين, not a professional practice. Feel is haptic sensation, not emotion. Challenge-friend and lesson challenge use their distinct senses above.


## 5. Full lesson localization policy (2026-10-26)
All 6,080 current lesson keys require Arabic drafts; English fallback never counts as completion. Apply the neutral masculine singular teacher register. For lessons the first terminology rows override older duplicate UI anchors: chord تآلف, key مقام, concert pitch الطبقة الفعلية, temperament نظام التقسيم النغمي. Keep every ASCII digit group, note/chord symbol, newline and protected brand. Translate credit connectors (words by كلمات، music by ألحان، traditional تراثية); retain named creators. Start prose in Arabic. Any necessary U+200F or U+2068/U+2069 is individually explained in the batch note. Drafts are AI-authored, not native/device-approved.

### Binding course/title map
| English base title | Arabic base title |
|---|---|
| Guitar | جيتار |
| Ukulele | يوكوليلي |
| Bass | غيتار باس |
| Violin | كمان |
| Cello | تشيلو |
| Mandolin | مندولين |
| Banjo | بانجو |
| Singing | الغناء |
| Ear Training | تدريب الأذن |
| Music Theory | نظرية الموسيقى |
| Rhythm | الإيقاع |
| Mary Had a Little Lamb | كان لدى ماري حمل صغير |
| Ode to Joy | نشيد الفرح |
| When the Saints Go Marching In | حين يسير القديسون |
| Amazing Grace | نعمة مذهلة |
| Greensleeves | الأكمام الخضراء |
| Oh! Susanna | آه! سوزانا |
| Down by the Riverside | عند ضفة النهر |
| Row, Row, Row Your Boat | جدّف، جدّف، جدّف بقاربك |
| Twinkle, Twinkle, Little Star / Twinkle Twinkle Little Star | تلألئي، تلألئي، أيتها النجمة الصغيرة |
| Aura Lee | أورا لي |
| Camptown Races | سباقات كامبتاون |
| Red River Valley | وادي النهر الأحمر |
| The Water Is Wide | الماء واسع |
| Molly Malone | مولي مالون |
| The Skye Boat Song | أغنية قارب سكاي |
| Lightly Row | جدّف برفق |
| Boil Them Cabbage Down | اسلق ذلك الملفوف |
| Minuet in G | مينويت في G |
| Old Joe Clark | جو كلارك العجوز |
| Soldier's Joy | فرحة الجندي |
| Arkansas Traveler | مسافر أركنساس |
| Brahms' Lullaby | تهويدة برامز |
| Au clair de la lune | في ضوء القمر |
| The Swan | البجعة |
| Angeline the Baker | أنجلين الخبازة |
| Cripple Creek | كريبل كريك |
| Cumberland Gap | ممر كمبرلاند |
| Shady Grove | البستان الظليل |
| Skip to My Lou | ارقص إلى لو |
| Auld Lang Syne | الأيام الخوالي |
| Shenandoah | شيناندواه |
| Frère Jacques | الأخ جاك |
| Jingle Bells | رنين الأجراس |
| Clementine | كليمنتين |
| Old MacDonald Had a Farm | كان لماكدونالد العجوز مزرعة |
| Bobby Shafto | بوبي شافتو |
| Canon in D | كانون في D |
| Largo, New World Symphony | لارغو، سيمفونية العالم الجديد |
| In the Hall of the Mountain King | في قاعة ملك الجبل |
| Für Elise | إلى إليزه |
| My Country, 'Tis of Thee | بلادي، لك أغنّي |
| Simple Gifts | هبات بسيطة |
| Good King Wenceslas | الملك الطيب فنتسلاس |
| Deck the Halls | زيّنوا القاعات |
| We Wish You a Merry Christmas | نتمنى لكم ميلادًا سعيدًا |
| Joy to the World | فرح للعالم |
| Silent Night | ليلة صامتة |
| Eine kleine Nachtmusik | موسيقى ليلية صغيرة |
| Danny Boy (Londonderry Air) | داني بوي (لحن لندنديري) |
| Danny Boy | داني بوي |
| Mozart's Symphony No. 40 | سيمفونية موزارت رقم 40 |
| Kite Weather | طقس الطائرات الورقية |
| Porchlight | ضوء الشرفة |
| Moth and Ember | عثة وجمرة |
| Low Tide Radio | راديو الجزر |
| Dust on the Dashboard | غبار على لوحة القيادة |
| Lantern Hill | تل الفوانيس |
| Gravel Road Two-Step | رقصة ثنائية على طريق حصوي |
| First Frost | أول صقيع |
| Hammock Season | موسم الأرجوحة الشبكية |
| Glow-in-the-Dark Stars | نجوم تتوهج في الظلام |
| Sparkler Season | موسم الشرارات الاحتفالية |
| Roller Rink | حلبة التزلج |
| Echo Canyon | وادي الصدى |
| Open Windows | نوافذ مفتوحة |
| Scoreboard Lights | أضواء لوحة النتائج |
| Rust Belt Shuffle | شافل حزام الصدأ |
| Carousel at Closing Time | دوامة الخيل وقت الإغلاق |
| Cedar Smoke | دخان الأرز |
| Rain on the Skylight | مطر على النافذة السقفية |
| Neon Laundromat | مغسلة النيون |
| Late Checkout | مغادرة متأخرة |
| Saltwater Sunday | أحد المياه المالحة |
| Pocket Change | فكة الجيب |
| Kitchen Slow Dance | رقصة بطيئة في المطبخ |
| Houseplants | نباتات منزلية |
| Static on Channel Nine | تشويش على القناة التاسعة |
| Basement Weather | طقس القبو |
| Jukebox Moon | قمر صندوق الأغاني |
| Boardwalk Comet | مذنب الممشى الخشبي |
| Mile Marker Zero | علامة الميل صفر |
| Last Bell | الجرس الأخير |
| Copper Wire | سلك نحاسي |
| Cold Lake | بحيرة باردة |
| Parking Lot Cathedral | كاتدرائية موقف السيارات |
| Halogen | هالوجين |
| Keeper's Daughter | ابنة الحارس |
| Snow Globe Town | بلدة الكرة الثلجية |
| Thistle and Thread | شوك وخيط |
| Ghost Light | ضوء الشبح |
| Late Bus Home | حافلة متأخرة إلى المنزل |
| Glass Satellites | أقمار صناعية زجاجية |
| Market Day | يوم السوق |
| Velvet Hour | ساعة مخملية |
| Rooftop Choir | جوقة فوق السطح |
| Slow Motion Strobe | وميض بالحركة البطيئة |
| Bright Side of the Block | الجانب المشرق من الحي |
| Over You Soon | سأنساك قريبًا |
| Spray Paint Sunrise | شروق بطلاء الرش |
| Constellation Prize | جائزة الكوكبة |
| She'll Be Coming 'Round the Mountain | ستأتي من حول الجبل |
| Loch Lomond | بحيرة لوموند |
| All Through the Night | طوال الليل |
| O Christmas Tree | يا شجرة الميلاد |
| O Come, All Ye Faithful | هلمّوا يا جميع المؤمنين |
| The First Noel | الميلاد الأول |
| Scotland the Brave | اسكتلندا الشجاعة |
| Korobeiniki | الباعة الجائلون |
| The Blue Danube | الدانوب الأزرق |
| Can-can | كانكان |
| The Entertainer | المسلّي |
| The Liberty Bell | جرس الحرية |
| Carmen: Prelude | كارمن: المقدمة |
| The Toreador Song | أغنية مصارع الثيران |
| Morning Mood | مزاج الصباح |
| Hark! The Herald Angels Sing | أصغوا! الملائكة المبشّرون يغنّون |
| Away in a Manger | هناك في مذود |
| O Little Town of Bethlehem | يا بلدة بيت لحم الصغيرة |
| It Came Upon the Midnight Clear | أتى في منتصف الليل الصافي |
| Once in Royal David's City | ذات مرة في مدينة الملك داود |
| In the Bleak Midwinter | في منتصف الشتاء القارس |
| The Holly and the Ivy | البهشية واللبلاب |
| Angels from the Realms of Glory | ملائكة من عوالم المجد |
| O God, Our Help in Ages Past | يا إلهنا، عوننا في العصور الماضية |
| Holy, Holy, Holy | قدوس، قدوس، قدوس |
| Abide with Me | ابق معي |
| Nearer, My God, to Thee | أقرب إليك يا إلهي |
| For the Beauty of the Earth | من أجل جمال الأرض |
| Home! Sweet Home! | الوطن! ما أحلاه! |
| Hard Times Come Again No More | أيتها الأيام الصعبة، لا تعودي |
| The Last Rose of Summer | وردة الصيف الأخيرة |
| Jupiter | المشتري |
| Spring | الربيع |
| Rondo alla Turca | روندو على الطريقة التركية |
| The Stars and Stripes Forever | النجوم والخطوط إلى الأبد |

| Letters in a Shoebox | رسائل في علبة أحذية |

| Twinkle (short title) | تلألئي |
| New Britain | بريطانيا الجديدة |

| Take Me Out to the Ball Game | خذني إلى مباراة البيسبول |
| My Bonnie Lies Over the Ocean | بوني وراء المحيط |

| The alphabet song | أغنية الحروف الأبجدية |
| Baa, Baa, Black Sheep | ماء، ماء، أيتها النعجة السوداء |
| Yankee Doodle | يانكي دودل |
| One Horse Open Sleigh | مزلجة مفتوحة يجرها حصان واحد |
| Love Me Tender | أحببني برقة |
| God Save the King | حفظ الله الملك |
| Appalachian Spring | ربيع أبالاتشيا |
| Hard Times (short title) | الأيام الصعبة |

### Lesson-only retention and layout notes
Quoted English note-letter mnemonics keep their Latin initials with Arabic explanation (including FACE); they are functional teaching aids, not untranslated fallback prose. Exact original sung words and syllables stay quoted where a question or instruction refers to the score. U+2068/U+2069 isolate a whole Latin quote, including its punctuation, and notation beside mixed-direction punctuation/digits. U+200F supplies RTL paragraph direction for genuinely invariant standalone notation, names, brands or sung-word answers. Such identities require a separate source-bound independent review; marks never grant acceptance. In century/decade prose, a parenthetical ASCII source year can accompany the Arabic century/decade to preserve the required exact digit group without changing its historical meaning. These are AI draft conventions, not human or device approval.

For the bar/measure synonym lesson, use مازورة and حقل موسيقي; avoid مقياس (a literal nonmusical measurement) and keep ميزان for meter/time signature.

## Independent review additions (2026-10-26)

Keep complete LTR notation, progressions, names/year credits and original sung locators inside a single directional isolate when used in an RTL paragraph. Isolating separate tokens can reverse their order. Retain exact sung original words only as quoted teaching locators with Arabic instruction; never treat ordinary English prose as an invariant. This is AI semantic review, not device rendering or native-reader certification.
