#!/bin/bash

set -o pipefail

ref_rttm=
trans_model=
iter=final
stage=0
cmd=run.pl
md_eval_opts="-c 0.25"
s=0

. path.sh
. parse_options.sh 

if [ $# != 3 ] && [ $# != 2 ]; then
  echo "Usage: run_md_eval.sh <ref-path> <exp-dir> [<tmp-dir>]"
  echo " e.g.: run_md_eval.sh data/callhome_eval/chome.v0 exp/vad_callhome_eval exp/vad_callhome_eval/vad_score"
  exit 1
fi

ref_path=$1
exp_dir=$2

if [ $# == 3 ]; then
  tmpdir=$3
else
  tmpdir=$exp_dir/vad_score
fi

mkdir -p $tmpdir

if [ $stage -le 1 ]; then
  if [ -z $ref_rttm ]; then
    for i in $ref_path/*.ref; do 
      diarization/convert_ref_to_rttm.pl $i || exit 1
    done | rttmSort.pl > $tmpdir/ref.rttm.raw || exit 1
  fi
fi

if [ -z $ref_rttm ]; then
  ref_rttm=$tmpdir/ref.rttm.raw
fi

if [ $stage -le 2 ]; then

  [ -z "$trans_model" ] && trans_model=$exp_dir/trans_test.mdl

  $cmd $tmpdir/log/create_sys_rttm.log \
    ali-to-phones --per-frame=true $trans_model \
    "ark:cat $exp_dir/*.$iter.ali |" ark,t:- \| \
    diarization/convert_vad_to_rttm.pl \| \
    rttmSort.pl '>' $tmpdir/sys.rttm.raw || exit 1
fi

[ ! -s $tmpdir/sys.rttm.raw ] && echo "$0: System RTTM $tmpdir/sys.rttm.raw is empty!" && exit 1

if [ $stage -le 3 ]; then
  [ ! -s $ref_rttm ] && echo "$0: Reference RTTM $ref_rttm is empty!" && exit 1
  rttmSmooth.pl -s 0.3 < $ref_rttm | rttmSort.pl > $tmpdir/ref.rttm.smoothed || exit 1
  rttmValidator.pl -i $tmpdir/ref.rttm.smoothed -f || { echo "$0: Invalid RTTM $tmpdir/ref.rttm.smoothed" && exit 1; }
  spkr2sad.pl < $ref_rttm | rttmSmooth.pl -s 0.3 | rttmSort.pl > $tmpdir/ref.rttm.vad || exit 1
fi


if [ $stage -le 4 ]; then
  rttmValidator.pl -f -i $tmpdir/sys.rttm.raw || { echo "$0: Invalid RTTM $tmpdir/sys.rttm.raw" && exit 1; }
  spkr2sad.pl < $tmpdir/sys.rttm.raw | rttmSmooth.pl -s $s |  rttmSort.pl > $tmpdir/sys.rttm.vad || exit 1
fi

if [ $stage -le 5 ]; then
  md-eval.pl -afc $md_eval_opts -r $tmpdir/ref.rttm.vad -s $tmpdir/sys.rttm.vad | tee $tmpdir/vad_eval || exit 1
fi
