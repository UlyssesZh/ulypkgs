unpackCmdHooks+=(_try7zz)

_try7zz() {
  7zz x $curSrc -osource
  files=(source/*)
  if [[ ${#files[@]} -eq 1 && -d "${files[0]}" ]]; then
    dir="$(basename "${files[0]}")"
    if [[ "$dir" == source ]]; then
      mv source source-renamed
      mv source-renamed/source source
      rm -r source-renamed
    else
      mv "source/$dir" .
      rm -r source
    fi
  fi
}
