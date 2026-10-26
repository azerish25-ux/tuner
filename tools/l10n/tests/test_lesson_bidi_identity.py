import unittest
from unittest.mock import patch
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import report as m

class Regression(unittest.TestCase):
 def test_every_bidi_control_cannot_disguise_english(self):
  with patch.object(m,'lesson_invariants',return_value={}):
   for cp in m._BIDI_CONTROLS:
    with self.subTest(codepoint=hex(cp)):
     self.assertTrue(m.check(m.LEARN,'L1','Play 2 notes.',chr(cp)+'Play 2 notes.','ar'))
 def test_empty_layout_marks_do_not_count(self):
  self.assertTrue(m.check(m.LEARN,'L1','Play notes.','\u200f \u061c','ar'))
 def test_rtl_note_needs_exact_source_bound_review(self):
  with patch.object(m,'lesson_invariants',return_value={}):
   self.assertTrue(m.check(m.LEARN,'L1','C♯','\u200fC♯','ar'))
  rows={'ar':{'L1':{'source':'C♯','reason':'Exact note notation, RLM only for RTL layout','reviewed_by':'unit-test fixture'}}}
  with patch.object(m,'lesson_invariants',return_value=rows):
   self.assertEqual(m.check(m.LEARN,'L1','C♯','\u200fC♯','ar'),[])
   self.assertTrue(m.check(m.LEARN,'L1','D♯','\u200fD♯','ar'))
 def test_canonical_unicode_does_not_disguise_identity(self):
  with patch.object(m,'lesson_invariants',return_value={}):
   self.assertTrue(m.check(m.LEARN,'L1','Café','Cafe\u0301','ar'))
 def test_registry_binding_remains_byte_exact(self):
  rows={'ar':{'L1':{'source':'Café','reason':'fixture','reviewed_by':'fixture'}}}
  with patch.object(m,'lesson_invariants',return_value=rows):
   self.assertFalse(m.reviewed_lesson_identity('ar','L1','Cafe\u0301'))
 def test_protected_tokens_and_newlines_still_checked(self):
  for source,value in [('2 notes','\u200fملاحظات'),('C♯','\u200fدو'),('A\nB','\u200fأ ب'),('50%','\u200f50')]:
   self.assertTrue(m.check(m.LEARN,'L1',source,value,'ar'))
 def test_real_translation_with_rlm_still_valid(self):
  self.assertEqual(m.check(m.LEARN,'L1','Play 2 notes.','\u200fاعزف 2 نغمتين.','ar'),[])
if __name__=='__main__':unittest.main()
