#!/usr/bin/perl

use strict;
use AI::Categorizer;
use AI::Categorizer::Learner::NaiveBayes;
use AI::Categorizer::Collection::Files;
use Statistics::Contingency;

# Load the categorizers from disk
my $level_c = AI::Categorizer::Learner->restore_state('/tmp/drmath-NB-level');
my $topic_c = AI::Categorizer::Learner->restore_state('/tmp/drmath-NB-topic');

# Access the test collection
my $cat_file = 'corpora/drmath-1.00/cats.txt';
my $test_set = AI::Categorizer::Collection::Files->new
  (
   path => 'corpora/drmath-1.00/test',
   category_file => $cat_file,
  );


# Get list of valid categories
my %valid_cats;
open my($fh), $cat_file or die "Can't open $cat_file: $!";
while (<$fh>) {
  my ($doc, @cats) = split;
  @valid_cats{@cats} = ();
}

my $e = new Statistics::Contingency(categories => [keys %valid_cats]);

# Categorize
while (my $doc = $test_set->next) {
  my $level_h = $level_c->categorize($doc);
  my $topic_h = $topic_c->categorize($doc);

  my @assigned;
  foreach my $level ($level_h->categories) {
    foreach my $topic ($topic_h->categories) {
      my $cat = "$topic.$level";
      #print "$cat\n";
      push @assigned, $cat if exists $valid_cats{$cat};
    }
  }

  $e->add_result(\@assigned, [map $_->name, $doc->categories]);
  
  print STDERR '.';
}
print STDERR "\n";

# Show results
print $e->stats_table;
