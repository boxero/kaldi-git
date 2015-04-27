#!/usr/bin/perl -w
# Copyright 2015  Vimal Manohar (Johns Hopkins University)
# Apache 2.0.

use strict;
use POSIX;
use Getopt::Long;
use File::Basename;

if (@ARGV != 1) {
  print STDERR "$0:\n" .
               "Usage: convert_ref_to_rttm.pl [options] <file-name> > <vad-out>\n";
  exit 1;
}

my $filename = $ARGV[0];

print STDERR "Extracting RTTM from ref $filename\n";

my $basename = basename($filename);
(my $utt_id = $basename) =~ s/\.[^.]+$//;

open IN, $filename or die "Could not open $filename";

my %speakers;

while (<IN>) {
  chomp;
  my @A = split;
  my $begin_time = $A[0];
  my $end_time = $A[1];
  my $spkr = $A[2];

  if (! defined $speakers{$spkr}) {
    print STDOUT "SPKR-INFO $utt_id 1 <NA> <NA> <NA> unknown $spkr <NA>\n";
    $speakers{$spkr} = 1;
  }

  my $dur = $end_time - $begin_time;

  printf STDOUT "SPEAKER $utt_id 1 %5.2f %5.2f <NA> <NA> $spkr <NA>\n", $begin_time, $dur;
}
