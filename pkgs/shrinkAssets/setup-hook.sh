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

shrinkJpeg() {
  local targetDir="${1:-.}"
  local tempDir="${2:-"$(mktemp -d)"}"
  local shrinkedFile

  jpegShrinkQualityThreshold="${jpegShrinkQualityThreshold:-85}"
  jpegShrinkQualityTarget="${jpegShrinkQualityTarget:-60}"

  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$targetDir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -print0)
  for file in "${files[@]}"; do
    if [[ "$(magick identify -format "%Q" "$file")" -lt "$jpegShrinkQualityThreshold" ]]; then
      continue
    fi
    shrinkedFile="$tempDir/$(basename "$file")"
    magick "$file" -quality "$jpegShrinkQualityThreshold" "$shrinkedFile"
    _afterShrinking "$file" "$shrinkedFile"
  done
}

shrinkMp3() {
  local targetDir="${1:-.}"
  local tempDir="${2:-"$(mktemp -d)"}"
  local shrinkedFile

  mp3ShrinkBitrateThreshold="${mp3ShrinkBitrateThreshold:-192}"
  mp3ShrinkBitrateTarget="${mp3ShrinkBitrateTarget:-128}"

  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$targetDir" -type f -iname "*.mp3" -print0)
  for file in "${files[@]}"; do
    if [[ "$(ffprobe -v error -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$file")" -lt "$mp3ShrinkBitrateThreshold" ]]; then
      continue
    fi
    shrinkedFile="$tempDir/$(basename "$file")"
    ffmpeg -v error -i "$file" -b:a "${mp3ShrinkBitrateTarget}k" "$shrinkedFile"
    _afterShrinking "$file" "$shrinkedFile"
  done
}

shrinkOgg() {
  local targetDir="${1:-.}"
  local tempDir="${2:-"$(mktemp -d)"}"
  local shrinkedFile

  oggShrinkBitrateThreshold="${oggShrinkBitrateThreshold:-192}"
  oggShrinkQualityTarget="${oggShrinkQualityTarget:-4}"

  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$targetDir" -type f -iname "*.ogg" -print0)
  for file in "${files[@]}"; do
    if [[ "$(ffprobe -v error -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$file")" -lt "$oggShrinkBitrateThreshold" ]]; then
      continue
    fi
    shrinkedFile="$tempDir/$(basename "$file")"
    ffmpeg -v error -i "$file" -q:a "$oggShrinkQualityTarget" "$shrinkedFile"
    _afterShrinking "$file" "$shrinkedFile"
  done
}

shrinkAssets() {
  [ -z "${shrinkAssetsHasRun-}" ] || return
  shrinkAssetsHasRun=1

  echo Executing shrinkAssetsPhase
  runHook preShrinkAssets

  local tempDir="$(mktemp -d)"

  if [[ -z "${dontShrinkJpeg-}" ]]; then
    shrinkJpeg . "$tempDir"
  fi

  if [[ -z "${dontShrinkMp3-}" ]]; then
    shrinkMp3 . "$tempDir"
  fi

  if [[ -z "${dontShrinkOgg-}" ]]; then
    shrinkOgg . "$tempDir"
  fi

  rm -r "$tempDir"

  runHook postShrinkAssets
  echo Finished shrinkAssetsPhase
}

if [[ -z "${dontShrinkAssets-}" ]]; then
  postBuildHooks+=(shrinkAssets)
fi
