#!/usr/bin/env python3
"""Lanceur minimal d'applications os-ken (equivalent de ryu-manager / osken-manager).

Usage : python3 lancer_controleur.py switch_acl.py
"""
from os_ken.lib import hub
hub.patch(thread=False)

import logging  # noqa: E402
import sys  # noqa: E402

from os_ken import cfg  # noqa: E402
from os_ken.base.app_manager import AppManager  # noqa: E402

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(message)s")
cfg.CONF(args=[], project="os_ken")
AppManager.run_apps(sys.argv[1:])
