#!/usr/bin/env python3
#
# You can run tests using:
#
#   bazel test --test_output=streamed //tools/eclipse:test
#
# Or directly:
#
# ./tools/eclipse/test_project.py
#

from io import StringIO
import unittest
from unittest.mock import call, patch
from subprocess import CalledProcessError

from project import EclipseProject

class EclipseProjectTestCase(unittest.TestCase):

  @patch('sys.stderr', new_callable=StringIO)
  def test_requires_root_option(self, stderr):
    with self.assertRaises(SystemExit) as c:
      EclipseProject().main([])
    self.assertEqual(c.exception.code, 2)
    self.assertIn(
      'the following arguments are required: -r/--root',
      stderr.getvalue()
    )

  def test_find_root_raises_when_no_WORKSPACE_found(self):
    with patch('os.path.exists') as exists:
      exists.return_value = False
      with self.assertRaises(Exception):
        EclipseProject().find_root('/tmp/path/to')
      exists.assert_has_calls([
        call('/tmp/path/to/WORKSPACE'),
        call('/tmp/path/WORKSPACE'),
        call('/tmp/WORKSPACE'),
      ])

  def test_find_root_in_grandparent_directory(self):
    with patch('os.path.exists') as exists:
      exists.side_effect = [False, False, True, False]
      root = EclipseProject().find_root('/tmp/path/to/foo')
      exists.assert_has_calls([
        call('/tmp/path/to/foo/WORKSPACE'),
        call('/tmp/path/to/WORKSPACE'),
        call('/tmp/path/WORKSPACE'),
      ])
      self.assertEqual('/tmp/path', root)

  @patch('subprocess.check_output')
  def test_find_bazel_finds_bazelisk_first(self, check_output):
    check_output.return_value = b'/path/to/bazelisk'
    self.assertEqual(EclipseProject().find_bazel(), '/path/to/bazelisk')

  @patch('subprocess.check_output')
  def test_find_bazel_fallback_to_bazel(self, check_output):
    check_output.side_effect = [
        CalledProcessError(1, 'which bazelisk',
                           '', '[TEST] bazelisk not found'),
        b'/path/to/bazel',
    ]
    self.assertEqual(EclipseProject().find_bazel(), '/path/to/bazel')

  @patch('subprocess.check_output')
  def test_find_bazel_raise_without_bazel_and_bazelisk(self, check_output):
    check_output.side_effect = [
        CalledProcessError(1, 'which bazelisk',
                           '', '[TEST] bazelisk not found'),
        CalledProcessError(1, 'which bazel',
                           '', '[TEST] bazel not found'),
    ]
    with self.assertRaisesRegex(Exception, "Neither bazelisk nor bazel found"):
      EclipseProject().find_bazel()

  @patch('subprocess.check_output')
  def test_find_given_existing_bazel_exe(self, check_output):
    check_output.return_value = b'/path/to/bin/mybazel'
    self.assertEqual(EclipseProject().find_bazel('my_bazel'),
                     '/path/to/bin/mybazel')

  @patch('subprocess.check_output')
  def test_find_given_not_existing_bazel_exe(self, check_output):
    check_output.side_effect = CalledProcessError(
      1, 'which mybazel', '', '[TEST] mybazel not found')
    with self.assertRaisesRegex(Exception, 'Bazel command: mybazel not found'):
      EclipseProject().find_bazel('mybazel')

  @patch('subprocess.check_output')
  def test_retrieve_ext_location_strips_newline(self, check_output):
    check_output.return_value = '/path/to/.cache/bazel/xxxx\n'
    ec = EclipseProject()
    ec.bazel_exe = 'my_bazel'
    ec.batch = None
    assert not ec.retrieve_ext_location().endswith('\n')


if __name__ == "__main__":
  unittest.main(verbosity=2)
