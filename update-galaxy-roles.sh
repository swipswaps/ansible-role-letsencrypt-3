#!/bin/bash

REQUIREMENTS_FILE=requirements.yaml
ROLES_DIR=roles

ansible-galaxy install -r $REQUIREMENTS_FILE -p $ROLES_DIR -v -f
