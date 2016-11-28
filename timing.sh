#!/usr/bin/env bash

# original sequence: 199.000000 (pmc0: 3682011, pmc1: 0, pmc2: 0, pmc3: 0)

declare -a TIMES

if [ -f timing_config.sh ]
then
  source timing_config.sh
fi

if [ "x$1" = "x-a1" ]
then
  ALIGNMENTS1="$2"
  shift 2
else
  ALIGNMENTS1="0 8 16 24"
fi

if [ "x$1" = "x-a2" ]
then
  ALIGNMENTS2="$2"
  shift 2
else
  ALIGNMENTS2="0 8 16 24"
fi

COMMENT="#"
for L in `seq 100`
do
  LINE="$L"
  for A1 in $ALIGNMENTS1
  do
    for A2 in $ALIGNMENTS2
    do
      ALIGNMENT="$A1,$A2,0,0"
      if [ -n "$COMMENT" ]
      then
        COMMENT="$COMMENT $ALIGNMENT"
      fi
      for I in 1 2 3
      do
        TIMES[$I]="`~/ajs-jev $CPUBIND -m 1 -l "$L" -d "$ALIGNMENT" "$@" | grep "# original sequence" | cut -d " " -f 4 | cut -d . -f 1`" || exit 1
      done
      # Sort the timings into increasing order
      if [ "${TIMES[1]}" -gt "${TIMES[2]}" ]; then T="${TIMES[1]}"; TIMES[1]="${TIMES[2]}"; TIMES[2]="$T"; fi
      if [ "${TIMES[2]}" -gt "${TIMES[3]}" ]; then T="${TIMES[2]}"; TIMES[2]="${TIMES[3]}"; TIMES[3]="$T"; fi
      if [ "${TIMES[1]}" -gt "${TIMES[2]}" ]; then T="${TIMES[1]}"; TIMES[1]="${TIMES[2]}"; TIMES[2]="$T"; fi
      LINE="$LINE ${TIMES[2]}"
    done
  done
  if [ -n "$COMMENT" ]
  then
    echo "$COMMENT"
    unset COMMENT
  fi
  echo "$LINE"
done
