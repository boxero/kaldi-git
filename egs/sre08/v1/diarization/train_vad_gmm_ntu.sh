#!/bin/bash
# Copyright 2015  Vimal Manohar
# Apache 2.0.

set -e 
set -o pipefail

# Begin configuration section.
cmd=run.pl
nj=4
speech_max_gauss=20
sil_max_gauss=20
num_iters=20
stage=-10
cleanup=true
top_frames_threshold=0.1
bottom_frames_threshold=0.2
# End configuration section.

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

if [ $# != 2 ]; then
  echo "Usage: diarization/train_vad_gmm_ntu.sh <data> <exp>"
  echo " e.g.: diarization/train_vad_gmm_ntu.sh data/dev exp/vad_dev"
  echo "main options (for others, see top of script file)"
  echo "  --config <config-file>                           # config containing options"
  echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
  echo "  --num-iters <#iters>                             # Number of iterations of E-M"
  exit 1;
fi

data=$1
dir=$2

for f in $data/feats.scp $data/vad.scp; do
  [ ! -s $f ] && echo "$0: could not find $f or $f is empty" && exit 1
done 

utils/split_data.sh $data $nj || exit 1

all_feats="ark:copy-feats scp:$data/feats.scp ark:- |"
feats="ark:copy-feats scp:$data/split$nj/JOB/feats.scp ark:- |"

speech_num_gauss=2
sil_num_gauss=2

if [ $stage -le -1 ]; then
  $cmd $dir/log/init_gmm_speech.log \
    gmm-global-init-from-feats --num-gauss=$speech_num_gauss --num-iters=$[speech_num_gauss*4] \
    "$all_feats select-top-frames --top-frames-proportion=$top_frames_threshold ark:- ark:- |" \
    $dir/speech.0.mdl || exit 1
  $cmd $dir/log/init_gmm_silence.log \
    gmm-global-init-from-feats --num-gauss=$sil_num_gauss --num-iters=$[sil_num_gauss*4] \
    "$all_feats select-top-frames --bottom-frames-proportion=$bottom_frames_threshold --top-frames-proportion=0.0 ark:- ark:- |" \
    $dir/silence.0.mdl || exit 1
fi

x=0
while [ $x -le $num_iters ]; do 
  if [ $stage -le $x ]; then
    $cmd JOB=1:$nj $dir/log/get_likes_speech.$x.JOB.log \
      gmm-global-get-frame-likes $dir/speech.$x.mdl \
      "$feats" ark:$dir/speech_likes.$x.JOB.ark || exit 1

    $cmd JOB=1:$nj $dir/log/get_likes_silence.$x.JOB.log \
      gmm-global-get-frame-likes $dir/silence.$x.mdl \
      "$feats" ark:$dir/silence_likes.$x.JOB.ark || exit 1

    $cmd JOB=1:$nj $dir/log/predict_class.$x.JOB.log \
      loglikes-to-class ark:$dir/silence_likes.$x.JOB.ark ark:$dir/speech_likes.$x.JOB.ark \
      ark:$dir/vad.$x.JOB.ark || exit 1

    $cmd JOB=1:$nj $dir/log/acc_stats_speech.$x.JOB.log \
      gmm-global-acc-stats $dir/speech.$x.mdl \
      "$feats select-voiced-frames ark:- ark:$dir/vad.$x.JOB.ark ark:- | select-top-frames --top-frames-proportion=$top_frames_threshold ark:- ark:- |" \
      $dir/speech.$x.JOB.acc || exit 1

    $cmd JOB=1:$nj $dir/log/acc_stats_silence.$x.JOB.log \
      gmm-global-acc-stats $dir/silence.$x.mdl \
      "$feats select-voiced-frames --select-unvoiced-frames=true ark:- ark:$dir/vad.$x.JOB.ark ark:- | select-top-frames --top-frames-proportion=0.0 --bottom-frames-proportion=$bottom_frames_threshold ark:- ark:- |" \
      $dir/silence.$x.JOB.acc || exit 1

    $cmd $dir/log/update_speech_gmm.$x.log \
      gmm-global-est --mix-up=$speech_num_gauss $dir/speech.$x.mdl "gmm-global-sum-accs - $dir/speech.$x.*.acc |" \
      $dir/speech.$[x+1].mdl || exit 1

    $cmd $dir/log/update_silence_gmm.$x.log \
      gmm-global-est --mix-up=$sil_num_gauss $dir/silence.$x.mdl "gmm-global-sum-accs - $dir/silence.$x.*.acc |" \
      $dir/silence.$[x+1].mdl || exit 1

    rm $dir/silence.$x.*.acc $dir/speech.$x.*.acc $dir/{speech,silence}_likes.$x.*.ark $dir/vad.*.ark
  fi

  if [ $speech_num_gauss -le $speech_max_gauss ]; then
    speech_num_gauss=$[speech_num_gauss + 2]
  fi

  if [ $sil_num_gauss -le $sil_max_gauss ]; then
    sil_num_gauss=$[sil_num_gauss + 2]
  fi

  x=$[x+1]
done

# Summarize warning messages...
utils/summarize_warnings.pl  $dir/log

