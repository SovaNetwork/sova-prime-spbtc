#!/bin/bash
echo "Generating coverage data..."
forge coverage --report lcov --report-file coverage.lcov

echo "Generating HTML report..."
genhtml --ignore-errors inconsistent,corrupt coverage.lcov -o coverage-report --branch-coverage

echo "Opening report..."
open coverage-report/index.html