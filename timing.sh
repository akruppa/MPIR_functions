
# original sequence: 199.000000 (pmc0: 3682011, pmc1: 0, pmc2: 0, pmc3: 0)

declare -a TIMES

for L in `seq 50`
do
  for I in 1 2 3
  do
    TIMES[$I]="`~/ajs-jev -m 1 -l "$L" "$@" | grep "# original sequence" | cut -d " " -f 4 | cut -d . -f 1`"
  done
  if [ "${TIMES[1]}" -gt "${TIMES[2]}" ]; then T="${TIMES[1]}"; TIMES[1]="${TIMES[2]}"; TIMES[2]="$T"; fi
  if [ "${TIMES[2]}" -gt "${TIMES[3]}" ]; then T="${TIMES[2]}"; TIMES[2]="${TIMES[3]}"; TIMES[3]="$T"; fi
  if [ "${TIMES[1]}" -gt "${TIMES[2]}" ]; then T="${TIMES[1]}"; TIMES[1]="${TIMES[2]}"; TIMES[2]="$T"; fi
  echo "$L ${TIMES[2]}"
done
