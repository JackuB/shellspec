#shellcheck shell=sh disable=SC2004

[ "${ZSH_VERSION:-}" ] && setopt shwordsplit

# shellcheck source=lib/general.sh
. "${SHELLSPEC_LIB:-./lib}/general.sh"

use() {
  while [ $# -gt 0 ]; do
    case $1 in
      constants) shellspec_constants ;;
      reset_params)
        reset_params() {
          shellspec_reset_params "$@"
          eval 'RESET_PARAMS=$SHELLSPEC_RESET_PARAMS'
        }
        ;;
      *) shellspec_proxy "$1" "shellspec_$1" ;;
    esac
    shift
  done
}

load() {
  while [ "$#" -gt 0 ]; do
    # shellcheck disable=SC1090
    . "${SHELLSPEC_LIB:-./lib}/libexec/$1.sh"
    shift
  done
}

unixtime() {
  IFS=" $IFS"
  #shellcheck disable=SC2046
  set -- $(date -u +'%Y %m %d %H %M %S') "$1"
  IFS=${IFS# }
  set -- "$1" "${2#0}" "${3#0}" "${4#0}" "${5#0}" "${6#0}" "$7"
  set -- $(( 365*$1 + $1/4 - ($1/100) + $1/400 )) "$2" "$3" "$4" "$5" "$6" "$7"
  set -- "$1" $(( (306 * ($2 + 1) / 10) - 428 )) "$3" "$4" "$5" "$6" "$7"
  set -- $(( ($1 + $2 + $3 - 719163) * 86400 + $4 * 3600 + $5 * 60 + $6 )) "$7"
  eval "$2=$1"
}

is_specfile() {
  shellspec_match "${1%%:*}" "$SHELLSPEC_PATTERN"
}

found_specfile() {
  set -- "$@" "${2%%:*}"
  case $2 in (*:*)
    set -- "$@" "${2#*:}"
    until case $4 in (*:*) false; esac; do
      set -- "$1" "$2" "$3" "${4%%:*} ${4#*:}"
    done
  esac
  "$@"
}

find_specfiles() {
  eval "found_() { ! is_specfile \"\$1\" || found_specfile \"$1\" \"\$1\"; }"
  shift
  if [ "${1:-}" = "-" ]; then
    [ -e "$SHELLSPEC_INFILE" ] || return 0
    while IFS= read -r line || [ "$line" ]; do
      [ "$line" ] || continue
      eval shellspec_find_files found_ "$line"
    done < "$SHELLSPEC_INFILE" &&:
  else
    eval shellspec_find_files found_ ${1+'"$@"'}
  fi
}

edit_in_place() {
  if [ -e "$1" ]; then
    eval 'shift; putsn "$("$@" < "'"$1"'")" > "'"$1"'"'
  fi
}

display() {
  (
    while IFS= read -r line || [ "$line" ]; do
      putsn "$line"
    done < "$1"
  )
}

warn() {
  if [ "$SHELLSPEC_COLOR" ]; then
    printf '\033[33m%s\033[0m\n' "${*:-}" >&2
  else
    printf '%s\n' "${*:-}" >&2
  fi
}

info() {
  if [ "$SHELLSPEC_COLOR" ]; then
    printf '\033[33m%s\033[0m\n' "$*"
  else
    printf '%s\n' "$*"
  fi
}

error() {
  if [ "$SHELLSPEC_COLOR" ]; then
    printf '\033[2;31m%s\033[0m\n' "${*:-}" >&2
  else
    printf '%s\n' "${*:-}" >&2
  fi
}

abort() {
  error "$@"
  exit 1
}

sleep_wait() {
  case $1 in
    *[!0-9]*) while "$@"; do sleep 0; done; return 0 ;;
  esac
}

signal() {
  if $SHELLSPEC_KILL -0 $$ 2>/dev/null; then
    signal() {
      "$SHELLSPEC_KILL" "$1" "$2"
    }
  else
    signal() {
      "$SHELLSPEC_KILL" -s "${1#-}" "$2"
    }
  fi
  signal "$@"
}

read_quickfile() {
  eval "{ IFS= read -r $1 || [ \"\$$1\" ]; } &&:" && {
    case $# in
      2) eval "$2=\${$1%%:*}" ;;
      *) eval "$2=\${$1%%:*} $3=\${$1#*:}" ;;
    esac
  }
}

match_files_pattern() {
  SHELLSPEC_EVAL="
    shift; \
    while [ \$# -lt $(($#*2-2)) ]; do \
      $1=\$1; \
      escape_pattern $1; \
      set -- \"\$@\" \"\$1\"; \
      set -- \"\$@\" \"\$1/*\"; \
      shift; \
    done; \
    $1=''; \
    while [ \$# -gt 0 ]; do \
      $1=\"\${$1}\${$1:+|}\$1\"; \
      shift; \
    done \
  "
  eval "$SHELLSPEC_EVAL"
}

use puts putsn escape_pattern
