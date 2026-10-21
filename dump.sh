#!/usr/bin/env bash
# usage (run from inside the tool dir): bash dump.sh partitions.txt
# set PYTHON=/path/to/python3 to override the interpreter
# to get the partitions file go on a dump folder and run 'ls > partitions.txt', then remove this partitions.txt file name from the generated file
list=$1
out=dumps
py=${PYTHON:-python3}

[[ -f $list ]] || { echo "usage: bash dump.sh partitions.txt"; exit 1; }
[[ -f main.py ]] || { echo "main.py not found: run this from inside the tool dir"; exit 1; }

# the tool uses f-strings, so it needs Python 3.6+; fail once instead of once per partition
"$py" -c 'import sys; sys.exit(sys.version_info < (3, 6))' ||
    { echo "$py is missing or older than 3.6 (set PYTHON=/path/to/python3)"; exit 1; }

mkdir -p "$out"
dumped=()
failed=()

while IFS= read -r line || [[ -n $line ]]; do
    # strip comments and surrounding whitespace
    name=$(echo "$line" | sed 's/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//')
    [[ -z $name ]] && continue
    part=${name%.img}    # the list may hold filenames; the device wants the bare partition name

    echo "== $part"
    rm -f data.out    # never keep the previous partition's dump

    # </dev/null so python can't swallow the rest of the list from stdin
    if "$py" main.py oem pull "$part" </dev/null && [[ -s data.out ]]; then
        mv data.out "$out/$part.img"
        dumped+=("$part")
    else
        echo "!! $part failed"
        failed+=("$part")
    fi
done < "$list"

echo
echo "dumped (${#dumped[@]}): ${dumped[*]}"
echo "failed (${#failed[@]}): ${failed[*]}"
printf '%s\n' "${failed[@]}" > "$out/failed.txt"
