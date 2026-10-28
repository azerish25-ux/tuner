"""Portable collector regressions; simulator access is mocked in every test."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

import collect_song_page_trace as collector

DEVICE = "11111111-1111-1111-1111-111111111111"
OTHER_DEVICE = "22222222-2222-2222-2222-222222222222"
APP = "33333333-3333-3333-3333-333333333333"
SESSION = "44444444-4444-4444-4444-444444444444"


class SongPageTraceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.container = self.root / "CoreSimulator/Devices" / DEVICE / "data/Containers/Data/Application" / APP
        self.session = self.container / "Library/Application Support/TimbreUITests" / SESSION
        self.session.mkdir(parents=True)
        self.metadata = self.container / ".com.apple.mobile_container_manager.metadata.plist"
        self.metadata.write_bytes(plistlib.dumps({"MCMMetadataIdentifier": collector.BUNDLE_ID}))
        self.source = self.session / collector.CURRENT
        self.source.write_bytes(self.event())
        self.output = self.root / "collected"
        self.runner = Mock(return_value=subprocess.CompletedProcess([], 0, str(self.container) + "\n", ""))

    def event(self, **changes):
        event = {"schema": 1, "sessionID": SESSION, "diagnosticOnly": True,
                 "sequence": 1, "kind": "position", "position": "songs.known", "wallTimeUTC": 123.5}
        event.update(changes)
        return (json.dumps(event, ensure_ascii=False) + "\n").encode()

    def collect(self, **kwargs):
        return collector.collect(kwargs.get("device", DEVICE), kwargs.get("output", self.output), self.runner)

    def rejected(self, **kwargs):
        result = self.collect(**kwargs)
        self.assertEqual(result["status"], "rejected", result)
        self.assertTrue(result["errors"])
        self.assertEqual(result["files"], [])
        self.assertFalse((self.output / SESSION).exists())
        return result

    def test_exact_copy_current_previous_and_manifest(self):
        data = self.event(position="آهنگ") + self.event(sequence=2)
        self.source.write_bytes(data)
        previous = self.session / "song-page-trace.previous.ndjson"
        previous.write_bytes(self.event(sequence=0))
        (self.session / "ordinary-store.json").write_text("private unrelated data")
        result = self.collect()
        self.assertEqual(result["status"], "collected")
        self.assertEqual(result["eventCount"], 3)
        self.assertEqual(result["sessions"], [SESSION])
        self.assertEqual((self.output / SESSION / collector.CURRENT).read_bytes(), data)
        self.assertEqual((self.output / SESSION / previous.name).read_bytes(), previous.read_bytes())
        self.assertFalse((self.output / SESSION / "ordinary-store.json").exists())
        self.assertEqual(json.loads((self.output / "manifest.json").read_text()), result)
        entry = next(f for f in result["files"] if f["path"].endswith("/" + collector.CURRENT))
        self.assertEqual(entry["sha256"], hashlib.sha256(data).hexdigest())
        self.runner.assert_called_once_with(
            ["xcrun", "simctl", "get_app_container", DEVICE, collector.BUNDLE_ID, "data"],
            capture_output=True, text=True, timeout=30, check=False)
        self.assertEqual(self.source.read_bytes(), data)

    def test_invalid_device_never_invokes_simctl(self):
        self.rejected(device="booted")
        self.runner.assert_not_called()

    def test_foreign_device_container(self):
        self.rejected(device=OTHER_DEVICE)

    def test_wrong_bundle_metadata(self):
        self.metadata.write_bytes(plistlib.dumps({"MCMMetadataIdentifier": "another.app"}))
        self.rejected()

    def test_missing_and_malformed_metadata(self):
        self.metadata.unlink()
        self.rejected()
        self.assertFalse(self.metadata.exists())

    def test_malformed_metadata(self):
        self.metadata.write_bytes(b"not a plist")
        self.rejected()

    def test_wrong_container_path(self):
        self.runner.return_value.stdout = str(self.root)
        self.rejected()

    def test_nul_container_path_is_structured(self):
        self.runner.return_value.stdout = str(self.container) + "\x00"
        self.rejected()

    def test_path_traversal_and_non_uuid_app_rejected(self):
        self.runner.return_value.stdout = str(self.container) + "/../" + APP
        self.rejected()

    def test_non_uuid_application_segment(self):
        self.runner.return_value.stdout = str(self.container.parent / "not-a-uuid")
        self.rejected()

    def test_foreign_event_session(self):
        self.source.write_bytes(self.event(sessionID=OTHER_DEVICE))
        self.rejected()

    def test_invalid_session_folder_with_trace(self):
        self.session.rename(self.session.parent / "invalid-session")
        self.rejected()

    def test_invalid_session_folder_without_trace(self):
        (self.session.parent / "invalid-session").mkdir()
        self.rejected()

    def test_invalid_event_forms(self):
        for number, data in enumerate([b"bad\n", b"[]\n", b"\n", b"", self.event().rstrip(b"\n"),
                                       self.event(schema=True), self.event(schema=2),
                                       self.event(diagnosticOnly=1), self.event(diagnosticOnly=False),
                                       self.event().replace(b'"schema": 1', b'"schema": 1, "schema": 1'),
                                       self.event().replace(b"123.5", b"NaN")]):
            with self.subTest(data=data):
                self.source.write_bytes(data)
                result = self.collect(output=self.root / ("invalid-" + str(number)))
                self.assertEqual(result["status"], "rejected")
                self.assertEqual(result["files"], [])

    def test_symlink_trace_rejected(self):
        other = self.root / "foreign.ndjson"
        other.write_bytes(self.event())
        self.source.unlink()
        self.source.symlink_to(other)
        self.rejected()
        self.assertEqual(other.read_bytes(), self.event())

    def test_symlink_metadata_rejected(self):
        other = self.root / "metadata.plist"
        self.metadata.rename(other)
        self.metadata.symlink_to(other)
        self.rejected()

    def test_symlink_session_rejected(self):
        target = self.root / "foreign-session"
        self.session.rename(target)
        self.session.symlink_to(target, target_is_directory=True)
        self.rejected()

    def test_symlink_ancestor_rejected(self):
        actual = self.root / "real-simulators"
        (self.root / "CoreSimulator").rename(actual)
        (self.root / "CoreSimulator").symlink_to(actual, target_is_directory=True)
        self.rejected()

    def test_oversize(self):
        self.source.write_bytes(b" " * (collector.MAX_BYTES + 1))
        self.rejected()

    def test_nonregular_trace_rejected(self):
        self.source.unlink()
        self.source.mkdir()
        self.rejected()

    def test_directory_scan_is_bounded(self):
        for i in range(collector.MAX_SCANNED_ENTRIES):
            (self.session / ("ordinary-" + str(i))).write_text("{}")
        self.rejected()

    def test_read_change_is_rejected(self):
        actual_fstat = collector.os.fstat
        calls = 0

        def changed(fd):
            nonlocal calls
            result = actual_fstat(fd)
            calls += 1
            # Metadata has two calls; mutate the trace before its second fstat.
            if calls == 4:
                with self.source.open("ab") as stream:
                    stream.write(self.event(sequence=2))
                result = actual_fstat(fd)
            return result

        with patch.object(collector.os, "fstat", changed):
            self.rejected()

    def test_later_bad_trace_copies_nothing(self):
        (self.session / "song-page-trace.previous.ndjson").write_bytes(b"bad\n")
        self.rejected()

    def test_extra_trace_name(self):
        (self.session / "song-page-trace.extra.ndjson").write_bytes(self.event())
        self.rejected()

    def test_trace_outside_session(self):
        (self.session.parent / collector.CURRENT).write_bytes(self.event())
        self.rejected()

    def test_previous_without_current(self):
        self.source.rename(self.session / "song-page-trace.previous.ndjson")
        self.rejected()

    def test_no_trace(self):
        self.source.unlink()
        (self.session / "store.json").write_text("{}")
        self.rejected()

    def test_three_sessions_allowed_four_rejected(self):
        for i in range(2):
            session = f"55555555-5555-5555-5555-{i:012d}"
            folder = self.session.parent / session
            folder.mkdir()
            (folder / collector.CURRENT).write_bytes(self.event(sessionID=session))
        result = self.collect()
        self.assertEqual(result["status"], "collected")
        self.assertEqual(len(result["sessions"]), 3)
        session = "66666666-6666-6666-6666-666666666666"
        folder = self.session.parent / session
        folder.mkdir()
        (folder / collector.CURRENT).write_bytes(self.event(sessionID=session))
        result = self.collect(output=self.root / "too-many")
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(result["files"], [])

    def test_ordinary_nontrace_namespaces_are_not_copied(self):
        folder = self.session.parent / "77777777-7777-7777-7777-777777777777"
        folder.mkdir()
        (folder / "store.json").write_text("{}")
        (self.session.parent / "settings.json").write_text("{}")
        self.assertEqual(self.collect()["status"], "collected")
        self.assertEqual(sorted(p.name for p in self.output.iterdir()), [SESSION, "manifest.json"])

    def test_output_cannot_be_inside_app_data(self):
        self.rejected(output=self.container / "new-output")
        self.assertFalse((self.container / "new-output").exists())
        self.runner.assert_not_called()

    def test_output_symlink_and_nonempty_rejected(self):
        self.output.symlink_to(self.root, target_is_directory=True)
        self.rejected()

    def test_nonempty_output_rejected_without_overwrite(self):
        self.output.mkdir()
        old = self.output / "manifest.json"
        old.write_text("existing")
        self.rejected()
        self.assertEqual(old.read_text(), "existing")

    def test_simctl_failure_and_cli_structured_exit(self):
        self.runner.return_value.returncode = 1
        with patch.object(collector.subprocess, "run", self.runner), contextlib.redirect_stdout(io.StringIO()) as output:
            code = collector.main(["--device", DEVICE, "--output", str(self.output)])
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(output.getvalue())["status"], "rejected")
        self.assertEqual(json.loads((self.output / "manifest.json").read_text())["files"], [])

    def test_simctl_timeout_is_structured(self):
        self.runner.side_effect = subprocess.TimeoutExpired("xcrun", 30)
        self.rejected()


if __name__ == "__main__":
    unittest.main()
