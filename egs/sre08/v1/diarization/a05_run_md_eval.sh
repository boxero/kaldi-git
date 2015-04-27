#!/bin/bash

tmpref="/home/hltcoe/gsell/projects/diarization/e12_dnn_diag/rttm/tmpref.rttm"
tmpsys="/home/hltcoe/gsell/projects/diarization/e12_dnn_diag/rttm/tmpsys.rttm"
fullref="/home/hltcoe/gsell/projects/diarization/e12_dnn_diag/rttm/fullref.rttm"
fullsys="/home/hltcoe/gsell/projects/diarization/e12_dnn_diag/rttm/fullsys.rttm"
spkrrefbase="/home/hltcoe/gsell/projects/diarization/e12_dnn_diag/rttm/ref_"
spkrsysbase="/home/hltcoe/gsell/projects/diarization/e12_dnn_diag/rttm/sys_"

rm -f $fullref
rm -f $fullsys
for n in `seq 2 7`; do
    rm -f ${spkrrefbase}_${n}.rttm
    rm -f ${spkrsysbase}_${n}.rttm
done

for m in /home/hltcoe/gsell/projects/diarization/e12_dnn_diag/marks/*; do
    w=$(basename $m .mrk) 
    echo $w
    r="/home/hltcoe/gsell/code/diarization/keys/chome.v0/$w.ref"
     
    cat $m | cut -d " " -f 1,2,3 | awk -v w=$w '{dur=$2-$1;print "SPEAKER "w" 0 "$1" "dur" <NA> <NA> "$3" <NA> <NA>"}' > $tmpsys
    cat $r | cut -d " " -f 1,2,3 | awk -v w=$w '{dur=$2-$1;print "SPEAKER "w" 0 "$1" "dur" <NA> <NA> "$3" <NA> <NA>"}' > $tmpref

    cat $tmpsys >> $fullsys
    cat $tmpref >> $fullref
    
    num_spkr=$(grep $w /home/hltcoe/gsell/code/diarization/keys/Key.chome.spkr.cnt.txt | tr -s ' ' | cut -d ' ' -f 2)
    cat $tmpsys >> ${spkrsysbase}_${num_spkr}.rttm
    cat $tmpref >> ${spkrrefbase}_${num_spkr}.rttm

    perl /home/hltcoe/gsell/tools/md-eval/md-eval.pl -1 -c 0.25 -r $tmpref -s $tmpsys > /home/hltcoe/gsell/projects/diarization/e12_dnn_diag/eval/$w.out

    rm $tmpsys
    rm $tmpref
done

perl /home/hltcoe/gsell/tools/md-eval/md-eval.pl -1 -c 0.25 -r $fullref -s $fullsys > /home/hltcoe/gsell/projects/diarization/e12_dnn_diag/eval/full.out
for n in `seq 2 7`; do
    perl /home/hltcoe/gsell/tools/md-eval/md-eval.pl -1 -c 0.25 -r ${spkrrefbase}_${n}.rttm -s ${spkrsysbase}_${n}.rttm > /home/hltcoe/gsell/projects/diarization/e12_dnn_diag/eval/spkr${n}.out
done
