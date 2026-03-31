_afterShrinking() {
  local file="$1"
  local shrinkedFile="$2"
  local oldFileSize="$(stat -c%s "$file")"
  local newFileSize="$(stat -c%s "$shrinkedFile")"
  if [[ "$newFileSize" -lt "$oldFileSize" ]]; then
    echo "shrinkAssets: $file: $oldFileSize -> $newFileSize ($((100 * newFileSize / oldFileSize))%)"
    mv "$shrinkedFile" "$file"
  else
    echo "shrinkAssets: $file: $oldFileSize -> $newFileSize (skipping)"
    rm "$shrinkedFile"
  fi
}

shrinkPng() {
  local targetDir="${1:-.}"
  local tempDir="${2:-"$(mktemp -d)"}"

  pngShrinkQualityTarget="${pngShrinkQualityTarget:-95}"

  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$targetDir" -type f \( -iname "*.png" \) -print0)
  local i=0
  for file in "${files[@]}"; do
    i=$((i%shrinkAssetsParallelJobs))
    if ((i++==0)); then
      wait
    fi
    {
      shrinkedFile="$tempDir/$(basename "$file")"
      magick "$file" -strip -quality "$pngShrinkQualityTarget" "$shrinkedFile"
      _afterShrinking "$file" "$shrinkedFile"
    } &
  done
  wait
}

shrinkJpeg() {
  local targetDir="${1:-.}"
  local tempDir="${2:-"$(mktemp -d)"}"

  jpegShrinkQualityTarget="${jpegShrinkQualityTarget:-50}"

  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$targetDir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -print0)
  local i=0
  for file in "${files[@]}"; do
    i=$((i%shrinkAssetsParallelJobs))
    if ((i++==0)); then
      wait
    fi
    {
      shrinkedFile="$tempDir/$(basename "$file")"
      quality="$(magick identify -format "%Q" "$file")"
      flags=(-strip)
      if [[ "$quality" -gt "$jpegShrinkQualityTarget" ]]; then
        flags+=(-quality "$jpegShrinkQualityTarget")
      fi
      magick "$file" ${flags[@]} "$shrinkedFile"
      _afterShrinking "$file" "$shrinkedFile"
    } &
  done
  wait
}

shrinkWebp() {
  local targetDir="${1:-.}"
  local tempDir="${2:-"$(mktemp -d)"}"

  webpShrinkQualityTarget="${webpShrinkQualityTarget:-50}"

  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$targetDir" -type f -iname "*.webp" -print0)
  local i=0
  for file in "${files[@]}"; do
    i=$((i%shrinkAssetsParallelJobs))
    if ((i++==0)); then
      wait
    fi
    {
      shrinkedFile="$tempDir/$(basename "$file")"
      flags=(-strip)
      if [[ "$(magick identify -format "%Q" "$file")" -gt "$webpShrinkQualityTarget" ]]; then
        flags+=(-quality "$webpShrinkQualityTarget")
      fi
      magick "$file" ${flags[@]} "$shrinkedFile"
      _afterShrinking "$file" "$shrinkedFile"
    } &
  done
  wait
}

shrinkMp3() {
  local targetDir="${1:-.}"
  local tempDir="${2:-"$(mktemp -d)"}"

  mp3ShrinkBitrateTarget="${mp3ShrinkBitrateTarget:-128}"

  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$targetDir" -type f -iname "*.mp3" -print0)
  local i=0
  for file in "${files[@]}"; do
    i=$((i%shrinkAssetsParallelJobs))
    if ((i++==0)); then
      wait
    fi
    {
      shrinkedFile="$tempDir/$(basename "$file")"
      flags=(-map_metadata -1 -vn)
      if [[ "$(ffprobe -v error -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$file")" -gt "$mp3ShrinkBitrateTarget" ]]; then
        flags+=(-b:a "${mp3ShrinkBitrateTarget}k")
      else
        flags+=(-c:a copy)
      fi
      ffmpeg -v error -i "$file" ${flags[@]} "$shrinkedFile"
      _afterShrinking "$file" "$shrinkedFile"
    } &
  done
  wait
}

shrinkOgg() {
  local targetDir="${1:-.}"
  local tempDir="${2:-"$(mktemp -d)"}"

  oggShrinkBitrateTarget="${oggShrinkBitrateTarget:-128}"

  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$targetDir" -type f -iname "*.ogg" -print0)
  local i=0
  for file in "${files[@]}"; do
    i=$((i%shrinkAssetsParallelJobs))
    if ((i++==0)); then
      wait
    fi
    {
      shrinkedFile="$tempDir/$(basename "$file")"
      flags=(-map_metadata -1 -vn)
      if [[ "$(ffprobe -v error -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$file")" -gt "$oggShrinkBitrateTarget" ]]; then
        flags+=(-b:a "${oggShrinkBitrateTarget}k")
      else
        flags+=(-c:a copy)
      fi
      ffmpeg -v error -i "$file" ${flags[@]} "$shrinkedFile"
      _afterShrinking "$file" "$shrinkedFile"
    } &
  done
  wait
}

shrinkWebm() {
  local targetDir="${1:-.}"
  local tempDir="${2:-"$(mktemp -d)"}"

  webmShrinkCrfTarget="${webmShrinkCrfTarget:-35}"

  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$targetDir" -type f -iname "*.webm" -print0)
  local i=0
  for file in "${files[@]}"; do
    i=$((i%shrinkAssetsParallelJobs))
    if ((i++==0)); then
      wait
    fi
    {
      shrinkedFile="$tempDir/$(basename "$file")"
      ffmpeg -v error -i "$file" -crf "$webmShrinkCrfTarget" -b:v 0 -map_metadata -1 "$shrinkedFile"
      _afterShrinking "$file" "$shrinkedFile"
    } &
  done
  wait
}

shrinkMpeg() {
  local targetDir="${1:-.}"
  local tempDir="${2:-"$(mktemp -d)"}"

  mpegShrinkCrfTarget="${mpegShrinkCrfTarget:-35}"

  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$targetDir" -type f \( -iname "*.mp4" -o -iname "*.mpg" -o -iname "*.mpeg" \) -print0)
  local i=0
  for file in "${files[@]}"; do
    i=$((i%shrinkAssetsParallelJobs))
    if ((i++==0)); then
      wait
    fi
    {
      shrinkedFile="$tempDir/$(basename "$file")"
      ffmpeg -v error -i "$file" -crf "$mpegShrinkCrfTarget" -b:v 0 -map_metadata -1 "$shrinkedFile"
      _afterShrinking "$file" "$shrinkedFile"
    } &
  done
  wait
}

shrinkAssets() {
  [ -z "${shrinkAssetsHasRun-}" ] || return
  shrinkAssetsHasRun=1

  echo Executing shrinkAssetsPhase
  shrinkAssetsParallelJobs="${shrinkAssetsParallelJobs:-"$NIX_BUILD_CORES"}"
  runHook preShrinkAssets

  local tempDir="$(mktemp -d)"

  if [[ -z "${dontShrinkPng-}" ]]; then
    shrinkPng . "$tempDir"
  fi

  if [[ -z "${dontShrinkJpeg-}" ]]; then
    shrinkJpeg . "$tempDir"
  fi

  if [[ -z "${dontShrinkWebp-}" ]]; then
    shrinkWebp . "$tempDir"
  fi

  if [[ -z "${dontShrinkMp3-}" ]]; then
    shrinkMp3 . "$tempDir"
  fi

  if [[ -z "${dontShrinkOgg-}" ]]; then
    shrinkOgg . "$tempDir"
  fi

  if [[ -z "${dontShrinkWebm-}" ]]; then
    shrinkWebm . "$tempDir"
  fi

  if [[ -z "${dontShrinkMpeg-}" ]]; then
    shrinkMpeg . "$tempDir"
  fi

  rm -r "$tempDir"

  runHook postShrinkAssets
  echo Finished shrinkAssetsPhase
}

if [[ -z "${dontShrinkAssets-}" ]]; then
  postBuildHooks+=(shrinkAssets)
fi
