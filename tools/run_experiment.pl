#!/usr/bin/perl

use strict;
use AI::Categorizer;

my (%opt, %do_stage);
parse_command_line(@ARGV);

my $c = new AI::Categorizer(%opt);

if (keys %do_stage) {
  $c->scan_features     if $do_stage{1};
  $c->read_training_set if $do_stage{2};
  $c->train             if $do_stage{3};
  $c->evaluate_test_set if $do_stage{4};
  print $c->stats_table if $do_stage{5};
} else {
  $c->run_experiment;
}

sub parse_command_line {

  while (@_) {
    if ($_[0] =~ /^-(\d+)$/) {
      shift;
      $do_stage{$1} = 1;
      
    } elsif ( $_[0] eq '--config_file' ) {
      shift;
      my $file = shift;
      eval {require YAML; 1}
	or die "--config_file requires the YAML Perl module to be installed.\n";
      my $href = YAML::LoadFile($file);
      @opt{keys %$href} = values %$href;
      
    } elsif ( $_[0] =~ /^--/ ) {
      my ($k, $v) = (shift, shift);
      $k =~ s/^--//;
      
      # Allow abbreviations
      if ($k =~ /^(\w+)_class$/) {
	my $name = $1;
	$v =~ s/^::/AI::Categorizer::\u${name}::/;
      }
      $opt{$k} = $v;
      
    } else {
      die "Unknown option format '$_[0]'.  Do you mean '--$_[0]'?\n";
    }
  }
}
