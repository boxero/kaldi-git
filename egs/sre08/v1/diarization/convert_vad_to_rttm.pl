#!/usr/bin/perl -w
# Copyright 2015  Vimal Manohar (Johns Hopkins University)
# Apache 2.0.

use strict;
use POSIX;
use Getopt::Long;
use File::Basename;

my $frame_shift = 0.01;

GetOptions('frame-shift:f' => \$frame_shift);

my $in;

if (@ARGV > 1) {
  print STDERR "$0:\n" .
               "Usage: convert_vad_to_rttm.pl [options] [<vad-file>] > <rttm-out>\n";
  exit 1;
}

if (@ARGV == 0) {
  $in = *STDIN;
} else {
  open $in, $ARGV[0] or die "Could not open $ARGV[0]";
}
($frame_shift > 0.0001 && $frame_shift <= 1.0) ||
  die "Very strange frame-shift value '$frame_shift'";

print STDERR "Extracting RTTM from VAD\n";

while (<$in>) {
  chomp;
  my @A = split;
  my $utt_id = $A[0];
  my $state = 1;       # silence state
  print STDOUT "SPKR-INFO $utt_id 1 <NA> <NA> <NA> unknown speech <NA>\n";
  my $begin_time = 0;
  my $end_time = 0;
  for (my $i = 1; $i < $#A; $i++) {
    if ($state == 1 && $A[$i] == 2) { # speech start
      $begin_time = ($i-1) * $frame_shift;
      $state = 2;
    } elsif ($state == 2 && $A[$i] == 1) { # silence start
      $end_time = ($i-1) * $frame_shift;
      $state = 1;
      my $dur = $end_time - $begin_time;
      print STDOUT sprintf("SPEAKER $utt_id 1 %5.2f %5.2f <NA> <NA> speech <NA>\n", $begin_time, $dur);
    }
  }
  if ($state == 2) {
    my $dur = ($#A-1)*$frame_shift - $begin_time;
    print STDOUT sprintf("SPEAKER $utt_id 1 %5.2f %5.2f <NA> <NA> speech <NA>\n", $begin_time, $dur);
  }
}
