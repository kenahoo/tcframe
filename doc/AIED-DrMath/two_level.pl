#!/usr/bin/perl

use AI::Categorizer;
use AI::Categorizer::Learner::NaiveBayes;
use AI::Categorizer::Collection::Files;

my $level_c = AI::Categorizer::Learner->restore_state('/tmp/drmath-NB-level');
my $topic_c = AI::Categorizer::Learner->restore_state('/tmp/drmath-NB-topic');

my $test_set = AI::Categorizer::Collection::Files->new
  (
   path => 'corpora/drmath-1.00/test',
   category_file => 'corpora/drmath-1.00/cats.txt',
  );

my %valid_cats = (); # ... get list of valid categories ...


while (my $doc = $test_set->next) {
  my $level_h = $level_c->categorize($doc);
  my $topic_h = $topic_c->categorize($doc);
  print STDERR '.';

  # ... combine the hypotheses into a set of categories to assign
}
