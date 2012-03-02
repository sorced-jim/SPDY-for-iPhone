#!/usr/bin/env python

__author__ = 'Jim Morrison <jim@twist.com>'


import logging
import os
import subprocess
import sys
import time


_PORT = 9793


def _run_server(builddir, testdata, port):
  base_args = ['%s/spdyd' % builddir, '-d', testdata]
  base_args.extend([str(port), '%s/privkey.pem' % testdata,
                    '%s/cacert.pem' % testdata])
  return subprocess.Popen(base_args)

def _check_server_up(port):
  # Check this check for now.
  time.sleep(1)

def _kill_server(server):
  tries = 0
  while server.returncode is None:
    if tries < 3:
      server.terminate()
    else:
      server.kill()
    tries += 1
    time.sleep(1)
    server.poll()


def main(basedir, test_driver):
  builddir = basedir + '/../build/i386/bin'
  datadir = basedir + '/../spdylay/tests/testdata'
  result = -2
  server = _run_server(builddir, datadir, _PORT)
  _check_server_up(_PORT)
  try:
    result = subprocess.call([test_driver])
  except:
    pass
  
  _kill_server(server)
  sys.exit(result)

if __name__ == '__main__':
  if len(sys.argv) < 3:
    sys.exit(-1)

  main(sys.argv[1], sys.argv[2])
