import io
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch, MagicMock
import hashlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import art
import font_assets


class FakeFont:
    size = 10
    def getlength(self, text, **kwargs):
        return len(text)
    def getbbox(self, text, **kwargs):
        return (0, -3 if text == 'high' else 1, len(text), 20)


class CaptionFontTests(unittest.TestCase):
    def test_unknown_glyph_coverage_fails_closed(self):
        with patch.object(art, '_cmap', return_value=None), patch.object(art, 'collection_face', return_value=0):
            self.assertFalse(art.covers('bad.ttf', 'Timbre'))

    def test_cmap_uses_rendered_collection_face_not_union(self):
        face = MagicMock()
        face.getBestCmap.return_value = {65: 'A'}
        factory = MagicMock()
        factory.return_value.__enter__.return_value = face
        art._cmap.cache_clear()
        with patch('fontTools.ttLib.TTFont', factory):
            self.assertEqual(art._cmap('collection.ttc', 2), frozenset({65}))
        factory.assert_called_once_with('collection.ttc', fontNumber=2, lazy=True)

    def test_rtl_direction_is_explicit_even_with_latin_brand_first(self):
        with patch.dict(os.environ, {'TIMBRE_CAPTION_LOCALE': 'ar-SA'}):
            self.assertEqual(art.text_layout(), {'direction': 'rtl', 'language': 'ar-SA'})
        with patch.dict(os.environ, {'TIMBRE_CAPTION_LOCALE': 'de-DE'}):
            self.assertEqual(art.text_layout()['direction'], 'ltr')
        with patch.dict(os.environ, {'TIMBRE_CAPTION_LOCALE': 'zh-Hant'}):
            self.assertEqual(art.text_layout()['language'], 'zh-Hant')

    def test_graphemes_not_individual_combining_marks_are_wrapped(self):
        self.assertEqual(art.wrap('किक्षि', FakeFont(), 3), ['कि', 'क्षि'])

    def test_japanese_wrap_does_not_start_with_a_prolongation_mark(self):
        rows = art.wrap('無料チューナー。広告なし。', FakeFont(), 7)
        self.assertFalse(rows[-1].startswith(('ー', '。')))
        self.assertEqual(''.join(rows), '無料チューナー。広告なし。')

    def test_cjk_sentence_break_is_preferred_when_it_fits(self):
        rows = art.wrap('無料チューナー。広告なし。', FakeFont(), 9)
        self.assertEqual(rows, ['無料チューナー。', '広告なし。'])

    def test_overflow_cannot_silently_return_an_oversized_caption(self):
        with patch.object(art, 'caption_font', return_value=FakeFont()):
            with self.assertRaises(ValueError):
                art.fit_lines('abcdef', 'Medium', 10, 8, 1, lines=1)

    def test_exact_minimum_is_tried_when_size_range_has_odd_difference(self):
        class SizedFont(FakeFont):
            def __init__(self, size):
                self.size = size
            def getlength(self, text, **kwargs):
                return self.size
        with patch.object(art, 'caption_font', side_effect=lambda text, weight, size: SizedFont(size)):
            font, lines = art.fit_lines('x', 'Medium', 11, 8, 8, lines=1)
            self.assertEqual(font.size, 8)

    def test_line_spacing_accounts_for_shaped_marks_and_descenders(self):
        self.assertGreaterEqual(art.line_step(FakeFont(), ['high', 'low']), 24)

    def test_bad_download_hash_does_not_write_a_font(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / 'font.ttf'
            with patch('urllib.request.urlopen', return_value=io.BytesIO(b'wrong')):
                with self.assertRaises(ValueError):
                    font_assets.fetch_checked('https://raw.githubusercontent.com/google/fonts/abc/ofl/test/font.ttf', '0' * 64, target, 'abc')
            self.assertFalse(target.exists())

    def test_download_is_bound_to_pinned_official_repository(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(ValueError):
                font_assets.fetch_checked('https://example.com/font.ttf', '0' * 64, Path(folder) / 'font.ttf', 'abc')

    def test_verified_cache_does_not_download_again(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / 'font.ttf'
            target.write_bytes(b'verified')
            with patch('urllib.request.urlopen') as request:
                font_assets.fetch_checked('https://raw.githubusercontent.com/google/fonts/abc/ofl/test/font.ttf', hashlib.sha256(b'verified').hexdigest(), target, 'abc')
                request.assert_not_called()

    def test_collection_locales_select_named_regional_faces(self):
        from types import SimpleNamespace
        families = ['Noto Sans CJK JP', 'Noto Sans CJK KR', 'Noto Sans CJK SC', 'Noto Sans CJK TC']
        faces = [{'name': SimpleNamespace(getDebugName=lambda field, name=name: name)} for name in families]
        factory = MagicMock()
        factory.return_value.__enter__.return_value = SimpleNamespace(fonts=faces)
        art.collection_face.cache_clear()
        with patch('fontTools.ttLib.TTCollection', factory):
            for locale, index in [('ja', 0), ('ko', 1), ('zh-Hans', 2), ('zh-Hant', 3)]:
                self.assertEqual(art.collection_face('regional.ttc', locale), index)

    def test_managed_cjk_fonts_never_substitute_another_region(self):
        with tempfile.TemporaryDirectory() as folder:
            for name in ['NotoSansJP[wght].ttf', 'NotoSansSC[wght].ttf', 'NotoSansTC[wght].ttf', 'NotoSansKR[wght].ttf', 'NotoSansThai[wght].ttf']:
                (Path(folder) / name).touch()
            with patch.dict(os.environ, {'TIMBRE_CAPTION_FONT_DIR': folder, 'TIMBRE_CAPTION_LOCALE': 'zh-Hant'}):
                names = [Path(p).name for p in art.managed_fonts()]
                self.assertIn('NotoSansTC[wght].ttf', names)
                self.assertNotIn('NotoSansSC[wght].ttf', names)
                self.assertNotIn('NotoSansJP[wght].ttf', names)
                self.assertNotIn('NotoSansKR[wght].ttf', names)
                self.assertIn('NotoSansThai[wght].ttf', names)



if __name__ == '__main__':
    unittest.main()
