#!/usr/bin/perl

use strict;
use AI::Categorizer;
use YAML;

my ($opt, $do_stage, $outfile) = parse_command_line(@ARGV);
@ARGV = grep !/^-\d$/, @ARGV;

my $c = new AI::Categorizer(%$opt);

%$do_stage = map {$_, 1} 1..5 unless keys %$do_stage;

run_section('scan_features',     1, $do_stage);
run_section('read_training_set', 2, $do_stage);
run_section('train',             3, $do_stage);
run_section('evaluate_test_set', 4, $do_stage);
if ($do_stage->{5}) {
  my $result = $c->stats_table;
  print $result;
  if ( $outfile ) {
    local *FH;
    open  FH, "> $outfile" or die "$outfile: $!";
    print FH "# ", scalar(localtime), "\n";
    print FH YAML::Dump($c->dump_parameters);
    print FH $result;
    close FH;
  }
}

sub run_section {
  my ($section, $stage, $do_stage) = @_;
  return unless $do_stage->{$stage};
  if (keys %$do_stage > 1) {
    print " % $0 @ARGV -$stage\n";
    system($0, @ARGV, "-$stage") == 0
      or die "$0 returned nonzero status, \$?=$?";
    return;
  }
  return $c->$section();
}

sub parse_command_line {
  my (%opt, %do_stage);

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

  my $outfile;
  unless ($outfile = delete $opt{outfile}) {
    $outfile = $opt{progress_file} ? "$opt{progress_file}-results.txt" : "results.txt";
  }

  return (\%opt, \%do_stage, $outfile);
}
