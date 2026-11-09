#!/usr/bin/env bash
# politique_multisite.sh — déclare la connectivité autorisée par l'API REST d'ONOS.
# Prérequis : fwd désactivé (défaut-refus).  À lancer sur lab-a : sudo bash politique_multisite.sh
set -euo pipefail
API=http://localhost:8181/onos/v1; AUTH=onos:rocks
DEV=00:00:00:00:00:01; PROD=00:00:00:00:00:02; REC=00:00:00:00:00:03; ADM=00:00:00:00:00:04

autoriser() {   # <mac1> <mac2>
  curl -s -u "$AUTH" -X POST -H 'Content-Type: application/json' "$API/intents" \
    -d "{\"type\":\"HostToHostIntent\",\"appId\":\"org.onosproject.cli\",\"priority\":100,
         \"one\":\"$1/None\",\"two\":\"$2/None\"}" \
    -o /dev/null -w "intent %{http_code} : $1 <-> $2\n"
}

autoriser "$DEV" "$PROD"    # dev     <-> prod
autoriser "$REC" "$PROD"    # recette <-> prod
autoriser "$ADM" "$DEV"     # admin   <-> dev
autoriser "$ADM" "$PROD"    # admin   <-> prod
autoriser "$ADM" "$REC"     # admin   <-> recette
# dev <-> recette : AUCUNE intention déclarée -> interdit par le défaut-refus
