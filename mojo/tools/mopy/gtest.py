# Copyright 2014 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import logging
import os
import re
import sys

_logging = logging.getLogger()

from mopy import test_util
from mopy.background_app_group import BackgroundAppGroup
from mopy.config import Config
from mopy.paths import Paths
from mopy.print_process_error import print_process_error


def set_color():
  """Run gtests with color if we're on a TTY (and we're not being told
  explicitly what to do)."""
  if sys.stdout.isatty() and "GTEST_COLOR" not in os.environ:
    _logging.debug("Setting GTEST_COLOR=yes")
    os.environ["GTEST_COLOR"] = "yes"

def run_fixtures(config, apptest_dict, apptest, test_args, shell_args,
                 launched_services):
  """Run the gtest fixtures in isolation."""

  mojo_paths = Paths(config)

  # List the apptest fixtures so they can be run independently for isolation.
  # TODO(msw): Run some apptests without fixture isolation?
  fixtures = get_fixtures(config, shell_args, apptest)

  if not fixtures:
    return "Failed with no tests found."

  if any(not mojo_paths.IsValidAppUrl(url) for url in launched_services):
    return ("Failed with malformed launched-services: %r" % launched_services)

  apptest_result = "Succeeded"
  for fixture in fixtures:
    apptest_args = test_args + ["--gtest_filter=%s" % fixture]
    if launched_services:
      success = RunApptestInLauncher(config, mojo_paths, apptest, apptest_args,
                                     shell_args, launched_services)
    else:
      success = RunApptestInShell(config, apptest, apptest_args, shell_args)

    if not success:
      apptest_result = "Failed test(s) in %r" % apptest_dict

  return apptest_result


def run_test(config, shell_args, apps_and_args=None, run_launcher=False):
  """Runs a command line and checks the output for signs of gtest failure.

  Args:
    config: The mopy.config.Config object for the build.
    shell_args: The arguments for mojo_shell.
    apps_and_args: A Dict keyed by application URL associated to the
        application's specific arguments.
    run_launcher: |True| is mojo_launcher must be used instead of mojo_shell.
  """
  apps_and_args = apps_and_args or {}
  output = test_util.try_run_test(config, shell_args, apps_and_args,
                                  run_launcher)
  # Fail on output with gtest's "[  FAILED  ]" or a lack of "[  PASSED  ]".
  # The latter condition ensures failure on broken command lines or output.
  # Check output instead of exit codes because mojo_shell always exits with 0.
  if (output is None or
      (output.find("[  FAILED  ]") != -1 or output.find("[  PASSED  ]") == -1)):
    print "Failed test:"
    print_process_error(
        test_util.build_command_line(config, shell_args, apps_and_args,
                                     run_launcher),
        output)
    return False
  _logging.debug("Succeeded with output:\n%s" % output)
  return True


def get_fixtures(config, shell_args, apptest):
  """Returns the "Test.Fixture" list from an apptest using mojo_shell.

  Tests are listed by running the given apptest in mojo_shell and passing
  --gtest_list_tests. The output is parsed and reformatted into a list like
  [TestSuite.TestFixture, ... ]
  An empty list is returned on failure, with errors logged.

  Args:
    config: The mopy.config.Config object for the build.
    apptest: The URL of the test application to run.
  """
  try:
    apps_and_args = {apptest: ["--gtest_list_tests"]}
    list_output = test_util.run_test(config, shell_args, apps_and_args)
    _logging.debug("Tests listed:\n%s" % list_output)
    return _gtest_list_tests(list_output)
  except Exception as e:
    print "Failed to get test fixtures:"
    print_process_error(
        test_util.build_command_line(config, shell_args, apps_and_args), e)
  return []


def _gtest_list_tests(gtest_list_tests_output):
  """Returns a list of strings formatted as TestSuite.TestFixture from the
  output of running --gtest_list_tests on a GTEST application."""

  # Remove log lines.
  gtest_list_tests_output = (
      re.sub("^\[.*\n", "", gtest_list_tests_output, flags=re.MULTILINE))

  if not re.match("^(\w*\.\r?\n(  \w*\r?\n)+)+", gtest_list_tests_output):
    raise Exception("Unrecognized --gtest_list_tests output:\n%s" %
                    gtest_list_tests_output)

  output_lines = gtest_list_tests_output.split("\n")

  test_list = []
  for line in output_lines:
    if not line:
      continue
    if line[0] != " ":
      suite = line.strip()
      continue
    test_list.append(suite + line.strip())

  return test_list


def RunApptestInShell(config, application, application_args, shell_args):
  return run_test(config, shell_args, {application: application_args})


def RunApptestInLauncher(config, mojo_paths, application, application_args,
                         shell_args, launched_services):
  with BackgroundAppGroup(
      mojo_paths, launched_services,
      test_util.build_shell_arguments(shell_args)) as apps:
    launcher_args = [
        '--shell-path=' + apps.socket_path,
        '--app-url=' + application,
        '--app-path=' + mojo_paths.FileFromUrl(application),
        '--app-args=' + " ".join(application_args)]
    return run_test(config, launcher_args, run_launcher=True)