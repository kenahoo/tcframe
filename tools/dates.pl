#!/usr/bin/perl

# Finds the earliest and latest announcement dates from Signal G SMART corpus file(s)

use strict;

my ($earliest, $latest) = ('99999999 99:99:99', '00000000 00:00:00');

die "Usage: $0 <file1> <file2> ...\n" unless @ARGV;

my $i;
while (<>) {
  if (/^\.W/) {
    $_ = <> until /^(\d{8})$/;
    my $date = $1;

    $_ = <> until /^(\d+:\d+:\d+)$/;
    my $time = $1;
    $time =~ s/(^|:)(\d)(:|$)/${1}0$2$3/g;  # Convert times from 9:30:56 to 09:30:56

    my $date_time = "$date $time";
    $earliest = $date_time if $date_time lt $earliest;
    $latest   = $date_time if $date_time gt $latest;
  }
  #last if $i++ > 500_000;
}

print "earliest: $earliest\nlatest: $latest\n\n";
