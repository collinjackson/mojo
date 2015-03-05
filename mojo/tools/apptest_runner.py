#!/usr/bin/env python
# Copyright 2014 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""A test runner for gtest application tests."""

import argparse
import ast
import logging
import sys

_logging = logging.getLogger()

from mopy import android
from mopy import dart_apptest
from mopy import gtest
from mopy.config import Config
from mopy.gn import ConfigForGNArgs, ParseGNConfig


def main():
  logging.basicConfig()
  # Uncomment to debug:
  #_logging.setLevel(logging.DEBUG)

  parser = argparse.ArgumentParser(description='A test runner for gtest '
                                   'application tests.')

  parser.add_argument('apptest_list_file', type=file,
                      help='A file listing apptests to run.')
  parser.add_argument('build_dir', type=str,
                      help='The build output directory.')
  args = parser.parse_args()

  config = ConfigForGNArgs(ParseGNConfig(args.build_dir))

  execution_globals = {
      "config": config,
  }
  exec args.apptest_list_file in execution_globals
  apptest_list = execution_globals["tests"]
  _logging.debug("Test list: %s" % apptest_list)

  extra_args = []
  if config.target_os == Config.OS_ANDROID:
    extra_args.extend(android.PrepareShellRun(config))

  gtest.set_color()

  exit_code = 0
  for apptest_dict in apptest_list:
    apptest = apptest_dict["test"]
    test_args = apptest_dict.get("test-args", [])
    shell_args = apptest_dict.get("shell-args", []) + extra_args
    launched_services = apptest_dict.get("launched-services", [])

    print "Running " + apptest + "...",
    sys.stdout.flush()

    if apptest_dict.get("type", "gtest") == "dart":
      apptest_result = dart_apptest.run_test(config, apptest_dict, shell_args,
                                             {apptest: test_args})
    else:
      apptest_result = gtest.run_fixtures(config, apptest_dict, apptest,
                                          test_args, shell_args,
                                          launched_services)

    if apptest_result != "Succeeded":
      exit_code = 1
    print apptest_result

  return exit_code


if __name__ == '__main__':
  sys.exit(main())