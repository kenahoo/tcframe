#!/usr/bin/perl

use strict;
use AI::Categorizer;
use YAML;

my (%opt, %do_stage);
parse_command_line(@ARGV);
@ARGV = grep !/^-\d$/, @ARGV;

my $c = new AI::Categorizer(%opt);

my $stats = $c->knowledge_set->scan_stats(path => [$c->{training_set}, $c->{test_set}]);
foreach my $k (sort keys %$stats) {
  next if $k eq 'categories';
  print "$k: $stats->{$k}\n";
}

print "\nCategories:\n";
foreach my $k (sort keys %{$stats->{categories}}) {
  print "$k: $stats->{categories}{$k}{document_count}\n";
}

##################################################################
sub parse_command_line {

  while (@_) {
    if ($_[0] =~ /^-(\d+)$/) {
      shift;
      $do_stage{$1} = 1;
      
    } elsif ( $_[0] eq '--config_file' ) {
      shift;
      my $file = shift;
      my $href = YAML::LoadFile($file);
      @opt{keys %$href} = values %$href;
      
    } elsif ( $_[0] =~ /^--/ ) {
      my ($k, $v) = (shift, shift);
      $k =~ s/^--//;
      $opt{$k} = $v;
      
    } else {
      die "Unknown option format '$_[0]'.  Do you mean '--$_[0]'?\n";
    }
  }

  while (my ($k, $v) = each %opt) {
    # Allow abbreviations
    if ($k =~ /^(\w+)_class$/) {
      my $name = $1;
      $v =~ s/^::/AI::Categorizer::\u${name}::/;
      $opt{$k} = $v;
    }
  }
}
