#!/bin/bash
/tmp/nso --local-install --non-interactive /nso-install
source /nso-install/ncsrc
ncs-setup --dest /nso-run