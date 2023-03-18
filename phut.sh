#!/bin/sh
#        _           _
#       | |         | |
#  _ __ | |__  _   _| |_
# | '_ \| '_ \| | | | __|
# | |_) | | | | |_| | |_
# | .__/|_| |_|\__,_|\__|
# | | ------------------------------------------------------------------
# |_|  a command line interface for <https://paste.sr.ht>
# ----------------------------------------------------------------------

prog="${0##*/}"
api="https://paste.sr.ht/api"
blob_url="https://paste.sr.ht/blob"
run_cmd=create_paste

PHUT_PAGER="${PHUT_PAGER:-${PAGER:-cat}}"

_curl() {
  curl --silent --header "Authorization: token $SOURCEHUT_TOKEN" "$@"
}

# ----------------------------------------------------------------------
# Error handling/messages.
# ----------------------------------------------------------------------

# error :: Integer -> String -> Void/IO
error() {
  case $1 in
    1) msg='no such file or directory' ;;
    2) msg='invalid option' ;;
    3) msg='environment variable not set' ;;
    4) msg='404 resource not found' ;;
    5) msg='invalid positional option(s)' ;;
    6) msg='reqeust error' ;;
    7) msg='file exists' ;;
    127) msg='command not found' ;;
  esac

  printf '%s%s: %s: %s\n' "$icon_error" "$prog" "$2" "$msg" >&2
  exit "$1"
}

# ----------------------------------------------------------------------
# Exit if missing required environment variables or dependencies.
# ----------------------------------------------------------------------

if test -z "$SOURCEHUT_TOKEN"; then
  error 3 SOURCEHUT_TOKEN
fi

if ! command -p curl --version >/dev/null 2>&1; then
  error 127 curl
fi

if ! command -p jq --version >/dev/null 2>&1; then
  error 127 jq
fi

# ----------------------------------------------------------------------
# Process command line options.
# ----------------------------------------------------------------------

while getopts :punelrsdjtaANqh opt; do
  case $opt in
    p) opt_visibility=private ;;
    u) opt_visibility="${opt_visibility:-unlisted}" ;;
    n) opt_filename=null ;;
    e) if ! command -p gpg --version >/dev/null 2>&1; then
         error 127 gpg
       fi
       opt_encryption=true ;;
    l) run_cmd=list_pastes ;;
    r) run_cmd=read_blob ;;
    s) run_cmd=save_paste ;;
    d) run_cmd=delete_paste ;;
    j) opt_json=true ;;
    a) opt_ascii=true; disable_nerdfont=true ;;
    A) disable_ansi=true ;;
    N) disable_nerdfont=true ;;
    q) opt_quiet=true ;;
    h) run_cmd=help; break ;;
    *) error 2 "-$OPTARG" ;;
  esac
done
shift $((OPTIND - 1))

# ----------------------------------------------------------------------
# Set up colors.
# ----------------------------------------------------------------------

if test -z "$disable_ansi"; then
  color_paste=$(printf '\e[%bm' "${PHUT_COLOR_PASTE:-34}")
  color_blob=$(printf '\e[%bm' "${PHUT_COLOR_BLOB:-0}")
  color_filename=$(printf '\e[%bm' "${PHUT_COLOR_FILENAME:-3;33}")
  color_meta=$(printf '\e[%bm' "${PHUT_COLOR_META:-90}")

  color_reset=$(printf '%b' '\e[0m')
  color_error=$(printf '%b' '\e[31m')
  color_success=$(printf '%b' '\e[32m')
  # color_warning=$(printf '%b' '\e[33m')
fi

# ----------------------------------------------------------------------
# Configure UI elements.
# ----------------------------------------------------------------------

branch_T='  '
branch_L='  '
icon_trunk=
icon_leaf=

if test -z "$disable_nerdfont"; then
  icon_trunk=' '
  icon_leaf=' '

  icon_error="$color_error  $color_reset"
  icon_success="$color_success  $color_reset"
  # icon_warning="$color_success  $color_reset"
fi

if test -z "$opt_ascii"; then
  branch_T='├──'
  branch_L='└──'
fi

# ----------------------------------------------------------------------
# The help menu.
# ----------------------------------------------------------------------

help() {
  cat <<EOF | "$PHUT_PAGER"
  $prog is a command line interface to post and retrieve pastes using
  the <https://paste.sr.ht> API.

  Usage:

      $prog [options] [FILE] ...
      ... | $prog [options] [FILENAME]

  Options:

      -p        Set visibility to private.
      -u        Set visibility to unlisted.
      -n        Don't attach FILE names to blobs.
      -e        Encrypt FILE with gpg (FILE can be a directory).
      -l        List all pastes (and attached blobs).
      -r BLOB   Print BLOB to stdout.
      -s PASTE  Save all blobs from PASTE in current directory.
      -d PASTE  Delete PASTE (and all of the attached blobs/files).
      -j        Output JSON.
      -a        Output ASCII.
      -A        Disable ANSI escapes.
      -N        Disable Nerd Font (icons).
      -q        Be less verbose.
      -h        Show this help menu.

  Examples:

      Create new pastes.

          $prog public.txt

          # private, encrypted & no name
          $prog -pen secret.txt

      Read/print a paste blob (file).

          $prog -r aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d

      Delete a paste.

          $prog -d 7c211433f02071597741e6ff5a8ea34789abbf43

      Print list of all pastes.

          $prog -l

  Environment Variables:

      SOURCEHUT_TOKEN       Required. Generate your token on sourcehut
                            at <https://meta.sr.ht/oauth>.

      PHUT_COLOR_PASTE      Set the ANSI escape for displaying the SHA1
                            sum for the paste and the directory icon.
                            Default is \`0;34\`.

      PHUT_COLOR_BLOB       Set the ANSI escape for displaying the SHA1
                            sums and file icons for each file blob
                            attached to the paste. Default is \`0;0\`.

      PHUT_COLOR_FILENAME   Set the ANSI escape for displaying
                            filenames. Default is \`3;33\`.

      PHUT_COLOR_META       Set the ANSI escape for displaying the file
                            metadata (data and visibility icon) and
                            tree branch lines. Default is \`0;90\`.

      PHUT_PAGER            Set the pager for reading content that
                            overflows the terminal window. The default
                            is the PAGER environment variable or
                            \`cat\` if PAGER is unset.
EOF
}

# ----------------------------------------------------------------------
# Print formatted output (file tree or URLs)
# ----------------------------------------------------------------------

print_tree() {
  while read -r created sha visibility files; do
    # skip empty lines
    test -z "$sha" && continue

    if test -n "$opt_quiet"; then
      output=
    else
      case $visibility in
        private)
          icon_visibility="${disable_nerdfont:+[P]}"
          icon_visibility="${icon_visibility:-}"
          ;;
        unlisted)
          icon_visibility="${disable_nerdfont:+[U]}"
          icon_visibility="${icon_visibility:-}"
          ;;
        *) icon_visibility= ;;
      esac

      formatted_date=$(printf '%s' "$created" | grep -oE '^[^T]+')

      output=$(printf '%s%s%s%s %s%s %s%s\\n' \
        "$color_paste" "$icon_trunk" "$sha" "$color_reset" \
        "$color_meta" "$formatted_date" "$icon_visibility" "$color_reset")
    fi

    while read -r line; do
      blob_id=$(printf '%s' "$line" | cut -d ' ' -f 1)
      file_name=$(printf '%s' "$line" | cut -d ' ' -f 2-)

      if test -n "$opt_quiet"; then
        output="$output${output:+\n}$blob_url/$blob_id"
      else
        output="$output$(printf '%s%s%s %s%s%s%s %s%s%s\\n' \
          "$color_meta" "$branch_T" "$color_reset" \
          "$color_blob" "$icon_leaf" "$blob_id" "$color_reset" \
          "$color_filename" "$file_name" "$color_reset")"
      fi
    done <<EOF
      $(printf '%s' "$files" | sed 's/:::\ */\n/g')
EOF

    printf '%b' "$output" | sed "\$s/$branch_T/$branch_L/"
    printf '\n'
  done
}

# ----------------------------------------------------------------------
# Parse JSON responses from <https://paste.sr.ht>.
# ----------------------------------------------------------------------

if test "$run_cmd" = list_pastes; then
  _match="${opt_visibility:+.visibility == \"$opt_visibility\"}"

  _match="$_match${opt_filename:+${_match:+ and }(
    .files | .[0] | .filename == null
  )}"

  _match="$_match${opt_encryption:+${_match:+ and }(
    .files | .[0] | .filename | tostring | endswith(\".asc\")
  )}"

  filter_list=".results ${_match:+| map(select($_match))} | sort_by(.created)"
fi

# Each filename gets 3 colons appended to the end of their name to make it
# easier to parse later (hope nobody uses a triple colon in their filenames).
# The `$p` variables are for use by jq and shouldn't be expanded by the shell.
# shellcheck disable=SC2016
to_shell_list='| reduce .[] as $p (""; . +
  "\($p.created) \($p.sha) \($p.visibility) \($p.files |
    map(.blob_id, "\(.filename):::") | join(" "))\n")'

jq_parse() {
  jq -r "${filter_list:-[.]} $to_shell_list" | print_tree
}

jq_parse_json() {
  jq -r "${filter_list:-[.]}"
}

jq_parse_error() {
  jq -r '.errors | map(.reason) | join(", ")'
}

# ----------------------------------------------------------------------
# Create paste.
# ----------------------------------------------------------------------

create_paste() {
  trap 'rm -fr "$tmp_stdin" "$tmp"' EXIT INT TERM

  if ! tty >/dev/null 2>&1; then
    tmp_stdin=$(mktemp -d)
    cat > "$tmp_stdin/${1:-data.txt}"
    set -- "$tmp_stdin/${1:-data.txt}"
  fi

  if test "$opt_encryption" = true; then
    if test $# -ne 1; then
      error 5 "$#"
    fi

    base_name=$(basename "$1")
    tmp=$(mktemp -d)

    if test -d "$1"; then
      ext='tgz.asc'
      tar -C "$(dirname "$1")" -czf - "$base_name" | \
        gpg --armor --symmetric --output "$tmp/$base_name.$ext"
    elif test -f "$1"; then
      ext='asc'
      gpg --armor --symmetric --output "$tmp/$base_name.$ext" "$1"
    else
      error 1 "$1"
    fi

    set -- "$tmp/$base_name.$ext"
  fi

  files=

  for f in "$@"; do
    test -f "$f" || error 1 "$f"

    file="$f"
    name="$(printf '%s' "$(basename "$f")" | jq --raw-input --slurp)"

    if test "$opt_filename" = null; then
      name=null
    fi

    files="$files${files:+,}"
    files="$files{\"filename\":$name,"
    files="$files\"contents\":$(jq --null-input --rawfile txt "$file" '$txt')}"
  done

  json=$(printf '{"visibility":"%s","files":[%s]}' \
    "${opt_visibility:-public}" "$files" | jq -c .)

  _curl --json "$json" "$api"/pastes | jq_parse${opt_json:+_json}
}

# ----------------------------------------------------------------------
# Delete paste.
# ----------------------------------------------------------------------

delete_paste() {
  if test $# -ne 1; then
    error 5 "accepts one positional arg"
  fi

  delete_error=$(_curl --request DELETE "$api"/pastes/"$1")

  if test -n "$delete_error"; then
    error 6 "$(printf '%s' "$delete_error" | jq_parse_error)"
  fi

  if test -z "$opt_quiet"; then
    test -z "$disable_nerdfont" && printf '%s' "$icon_success"
    printf 'Deleted: %s\n' "$1"
  fi
}

# ----------------------------------------------------------------------
# List pastes.
# ----------------------------------------------------------------------

list_pastes() {
  _curl "$api"/pastes | jq_parse${opt_json:+_json} | "$PHUT_PAGER"
}

# ----------------------------------------------------------------------
# Read/Print blob to stdout.
# ----------------------------------------------------------------------

read_blob() {
  if test $# -ne 1; then
    error 5 "accepts one positional arg"
  fi

  blob_content=$(_curl "$api"/blobs/"$1" | jq -r .contents)

  if test "$blob_content" = null; then
    error 4 "$1"
  fi

  printf '%s\n' "$blob_content"
}

# ----------------------------------------------------------------------
# Save blob to current working directory.
# ----------------------------------------------------------------------

save_paste() {
  file_list=$(_curl "$api"/pastes/"$1" | jq -r '.files')

  if test "$file_list" = null; then
    error 4 "$1"
  fi

  while read -r blob fname; do
    if test -f "$fname"; then
      error 7 "can't create $fname"
    fi

    read_blob "$blob" > "$fname"

    if test -z "$opt_quiet"; then
      test -z "$disable_nerdfont" && printf '%s' "$icon_success"
      printf 'Saved: %s\n' "$fname"
    fi
  done <<EOF
    $(printf '%s' "$file_list" | \
      jq -r 'map("\(.blob_id) \(.filename)") | join("\n")')
EOF
}

# ----------------------------------------------------------------------
# Let's Go!
# ----------------------------------------------------------------------

$run_cmd "$@"
