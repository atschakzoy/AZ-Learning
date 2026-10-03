#!/usr/bin/env bash


echo "step 1: startign"

az group show --name rg-does-not-exist-xyz

echo "step 2: this should not print"
