#!/usr/bin/perl

# Finds N random SMART documents in the given SMART file

use strict;

die "Usage: $0 <file> <N>\n" unless @ARGV == 2;
my ($file, $n) = @ARGV;
print STDERR "Finding $n documents\n";

my $total = 0;
open FILE, "< $file" or die "$file: $!";
while (<FILE>) {
  $total++ if /^\.I/;
}
print STDERR "$total total documents\n";
die "Not enough documents to choose from" unless $n < $total;

print STDERR "Choosing $n random values from 0..$total\n";
# If $n > $total/2, it would be much more efficient to find non-chosen
# documents and exclude them.
my %chosen;
while (keys %chosen < $n) {
  $chosen{int rand $total} = 1;
}

my $i = 0;
seek FILE, 0, 0;
File:
while (<FILE>) {
  if (/^\.I/) {
    next unless $chosen{$i++};
    print $_;
  Doc:
    while (<FILE>) {
      if (/^\.I/) {
	seek FILE, -length($_), 1;
	last Doc;
      }
      print $_;
    }
  }
}

__END__

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
