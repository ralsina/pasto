#!/usr/bin/env crystal

# Test runner for kcov coverage analysis
# This script runs all the tests in a way that kcov can track coverage
# It also requires source files that can be safely included without conflicts

# Include testable source files (avoiding entry points and files that conflict with mocks)
require "../src/paste"
require "../src/backup_manager"
require "../src/ratelimit"
require "../src/logging"
require "../src/theme_helper"
require "../src/time_helper"
require "../src/ssh_utils"
require "../src/gcm_fix"
require "../src/models/user"
require "../src/models/ssh_key"
require "../src/models/auth_token"
require "../src/models/api_key"
require "../src/models/backup"
require "../src/models/ssh_key_challenge"

# Note: server.cr, api.cr, ssh_server.cr and other high-level files are excluded
# because they require the full app context and conflict with test mocks.
# This means coverage numbers will be lower than actual test coverage.

# Now require all the test specs
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
