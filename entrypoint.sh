#!/bin/sh
set -e

if [ -n "${CI_WORKSPACE}" ]; then
    cd "${CI_WORKSPACE}" || exit
    git config --global --add safe.directory "${CI_WORKSPACE}" || exit 1
fi

PLUGIN_LEVEL="${PLUGIN_LEVEL:-warning}"
PLUGIN_REPORTER="${PLUGIN_REPORTER:-github-pr-review}"
PLUGIN_STANDARD="${PLUGIN_STANDARD:-cleancode,codesize,controversial,design,naming,unusedcode}"
PLUGIN_TARGET_DIRECTORY="${PLUGIN_TARGET_DIRECTORY:-src}"
PLUGIN_EXCLUDE="${PLUGIN_EXCLUDE:-}"
PLUGIN_NAME="${PLUGIN_NAME:-PHPMD}"
PLUGIN_BASELINE_FILE="${PLUGIN_BASELINE_FILE:-}"
PLUGIN_FAIL_ON_ERROR="${PLUGIN_FAIL_ON_ERROR:-false}"
PLUGIN_CHANGED_ONLY="${PLUGIN_CHANGED_ONLY:-false}"

if [ -z "${PLUGIN_GITHUB_TOKEN}" ] && [ "${PLUGIN_REPORTER}" != "local" ]; then
    echo "github_token is required. Pass it via settings with from_secret."
    exit 1
fi

if [ -n "${PLUGIN_GITHUB_TOKEN}" ]; then
    export REVIEWDOG_GITHUB_API_TOKEN="${PLUGIN_GITHUB_TOKEN}"
fi

excludeOption=""
if [ "${PLUGIN_EXCLUDE}" != "" ]; then
    excludeOption=" --exclude ${PLUGIN_EXCLUDE}"
fi

baselineFileOption=""
if [ "${PLUGIN_BASELINE_FILE}" != "" ]; then
    baselineFileOption=" --baseline-file ${PLUGIN_BASELINE_FILE}"
fi

FAIL_LEVEL_ARGS=""
if [ "${PLUGIN_FAIL_ON_ERROR}" = "true" ]; then
    FAIL_LEVEL_ARGS="-fail-level=any"
fi

# changed_only: lint only the PHP files this PR changed. Woodpecker lists them in CI_PIPELINE_FILES
# (a JSON array). GitHub caps that list, so it can be empty on a very large PR; then lint everything.
if [ "${PLUGIN_CHANGED_ONLY}" = "true" ]; then
    if [ -n "${CI_PIPELINE_FILES}" ] && [ "${CI_PIPELINE_FILES}" != "[]" ]; then
        set -f
        CHANGED=$(echo "${CI_PIPELINE_FILES}" | tr -d '[]" ' | tr ',' '\n' | grep '\.php$' || true)
        TARGETS=""
        for dir in $(echo "${PLUGIN_TARGET_DIRECTORY}" | tr ',' ' '); do
            dir="${dir#./}"
            dir="${dir%/}"
            for f in ${CHANGED}; do
                case "${dir}" in
                    .|"") match=1 ;;
                    *) case "$f" in "${dir}"|"${dir}"/*) match=1 ;; *) match=0 ;; esac ;;
                esac
                # [ -f ] skips files the PR deleted; the second case skips duplicates
                if [ "${match}" = 1 ] && [ -f "$f" ]; then
                    case " ${TARGETS} " in *" $f "*) ;; *) TARGETS="${TARGETS} $f" ;; esac
                fi
            done
        done
        set +f
        if [ -z "${TARGETS}" ]; then
            echo "No changed PHP files under ${PLUGIN_TARGET_DIRECTORY}; nothing to lint."
            exit 0
        fi
        PLUGIN_TARGET_DIRECTORY=$(echo ${TARGETS} | tr ' ' ',')
        echo "changed_only: linting${TARGETS}"
    else
        echo "warning: CI_PIPELINE_FILES is empty, linting all of ${PLUGIN_TARGET_DIRECTORY}"
    fi
fi

set +e
php -d display_errors=stderr -d memory_limit=-1 /usr/local/bin/phpmd.phar ${PLUGIN_TARGET_DIRECTORY}${excludeOption}${baselineFileOption} text ${PLUGIN_STANDARD} > /tmp/lint.out
LINT_EXIT=$?
set -e

# phpmd: 0 = clean, 2 = violations, 3 = some files could not be parsed, anything else = crash or config error
if [ "${LINT_EXIT}" -ne 0 ] && [ "${LINT_EXIT}" -ne 2 ] && [ "${LINT_EXIT}" -ne 3 ]; then
    cat /tmp/lint.out
    echo "phpmd failed with exit code ${LINT_EXIT}"
    exit 1
fi

if [ "${LINT_EXIT}" -eq 3 ]; then
    echo "phpmd could not parse some files. See the lines without a line number below."
fi

sed -r "s/([0-9]+)\s+/\1:/gI" /tmp/lint.out \
    | reviewdog -name="${PLUGIN_NAME}" -f=phpstan -reporter=${PLUGIN_REPORTER} ${FAIL_LEVEL_ARGS} -level=${PLUGIN_LEVEL} -diff='git diff' -tee
