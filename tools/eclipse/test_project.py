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
from unittest.mock import call, mock_open, patch
from subprocess import CalledProcessError

import project
from project import EclipseProject

class EclipseProjectTestCase(unittest.TestCase):

  @patch.object(project, 'EclipseProject')
  def test_script_entrypoint(self, ep):
    with patch.object(project.sys, 'argv', ['project.py', '-r', '/dev/null']):
      project.main()
      ep.assert_has_calls([
          call(),
          call().parse_args(args=['-r', '/dev/null']),
          call().main(),
      ])

  @patch('sys.stderr', new_callable=StringIO)
  def test_script_entrypoint_handles_control_c(self, stderr):

    with self.assertRaises(SystemExit) as c:
      with patch.object(project.EclipseProject, 'parse_args',
                        side_effect=KeyboardInterrupt):
        project.main()

    self.assertIn('Interrupted by user\n', stderr.getvalue())
    self.assertEqual(c.exception.code, 1)

  @patch('sys.stderr', new_callable=StringIO)
  def test_requires_root_option(self, stderr):
    with self.assertRaises(SystemExit) as c:
      ep = EclipseProject()
      ep.parse_args([])
    self.assertEqual(c.exception.code, 2)
    self.assertIn(
      'the following arguments are required: -r/--root',
      stderr.getvalue()
    )

  def test_batch_option_is_passed_to_bazel(self):
      ep = EclipseProject()
      ep.parse_args(['-r', '/dev/null'])
      ep.bazel_exe = 'my_bazel'
      self.assertEqual(ep._build_bazel_cmd(), ['my_bazel'])

      ep.parse_args(['-r', '/dev/null', '--batch'])
      self.assertEqual(ep._build_bazel_cmd(), ['my_bazel', '--batch'])

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
    ep = EclipseProject()
    ep.parse_args(['-r' '/dev/null', '--bazel', 'my_bazel'])
    assert not ep.retrieve_ext_location().endswith('\n')

class GenClassPathTestCase(unittest.TestCase):

  maxDiff = None

  def gen_classpath(self, classpath):
    ep = EclipseProject()
    ep.parse_args(['-r', '/dev/null'])
    ep.ROOT = '/path/to'

    with patch.object(ep, '_query_classpath', return_value=[classpath]):
      opener = mock_open()
      with patch('builtins.open', opener):
        ep.gen_classpath(ext='ext_loc')

    written = ''
    for write_call in opener().write.mock_calls:
      written += write_call[1][0]

    return written

  def test_includes_external_gerrit_plugin_api(self):
    self.assertIn(
      ('<classpathentry kind="lib" '
       'path="ext_loc/external/gerrit_plugin_api/jar/gerrit-plugin-api-3.4.0.jar"'
      ),
      # TODO we should check the sourcepath has been detected by mocking os.path.exists
      self.gen_classpath(
        'external/gerrit_plugin_api/jar/gerrit-plugin-api-3.4.0.jar'
        ),
      msg='plugin code is included'
      )

  def test_recognizes_maven_jar_dependencies(self):
    self.assertIn(
      ('<classpathentry kind="lib" '
        'path="ext_loc/external/gerrit_plugin_api/jar/'
        'gerrit-plugin-api-X.X.X.jar"/>'),
      self.gen_classpath(
        'external/gerrit_plugin_api/jar/gerrit-plugin-api-X.X.X.jar',
        ),
      msg='maven_jar() dependency listed as a "lib" classpathentry'
      )

  def test_finds_rules_jvm_external_dependencies(self):
    self.assertIn(
      ('<classpathentry kind="lib" '
       'path="ext_loc/external/unpinned_maven/v1/https/repo1.maven.org'
       '/maven2/com/fasterxml/classmate/1.5.1/classmate-1.5.1.jar" '
       'sourcepath="ext_loc/external/unpinned_maven/v1/https/repo1.maven.org'
       '/maven2/com/fasterxml/classmate/1.5.1/classmate-1.5.1-sources.jar"/>'),
      self.gen_classpath(
        ('bazel-out/k8-fastbuild/bin/external/maven/v1/'
         'https/repo1.maven.org/maven2/'
         'com/fasterxml/classmate/1.5.1/classmate-1.5.1.jar')
      ),
      msg='artifact on Maven Central'
    )

  def test_finds_rules_jvm_external_dependencies_out_of_maven_central(self):
    self.assertIn(
      ('<classpathentry kind="lib" '
       'path="ext_loc/external/unpinned_maven/v1/https/archiva.wikimedia.org'
       '/repository/releases/org/wikimedia/eventutilities/1.1.0/eventutilities-1.1.0.jar" '
       'sourcepath="ext_loc/external/unpinned_maven/v1/https/archiva.wikimedia.org'
       '/repository/releases/org/wikimedia/eventutilities/1.1.0/eventutilities-1.1.0-sources.jar"/>'
      ),
      self.gen_classpath(
        ('bazel-out/k8-fastbuild/bin/external/maven/v1/'
         'https/archiva.wikimedia.org/repository/releases/'
         'org/wikimedia/eventutilities/1.1.0/eventutilities-1.1.0.jar')
      ),
      msg='artifact hosted outside of Maven Central'
    )


if __name__ == "__main__":
  unittest.main(verbosity=2)
