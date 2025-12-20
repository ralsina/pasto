#!/usr/bin/env crystal

# Test runner for kcov coverage analysis
# This script runs all the tests in a way that kcov can track coverage

require "../spec/spec_helper"
require "../spec/pasto_spec"
require "../spec/paste_spec"
require "../spec/user_spec"
require "../spec/ssh_key_spec"
require "../spec/auth_token_spec"
require "../spec/theme_helper_spec"
require "../spec/rate_limiting_spec"
require "../spec/web_server_spec"
require "../spec/ssh_server_spec"
require "../spec/ssh_commands_spec"
require "../spec/api_spec"
require "../spec/backup_spec"
