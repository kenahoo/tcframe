#!/usr/bin/perl

my $name = pop @ARGV or die "Usage: $0 [options] <corpus-directory>\n";
$name =~ s,/$,,;

use strict;

use Getopt::Long;
my %opt = (learner => 'AI::Categorizer::Learner::NaiveBayes', features_kept => 1000);
Getopt::Long::Configure("bundling");
GetOptions( \%opt, 'format=s', 'features_kept=s', 'learner=s', 1, 2, 3, 4, 5 );

use vars qw(%format);
%format = 
  $opt{format} eq 'SMART' ?
  (
   collection_class => 'AI::Categorizer::Collection::SingleFile',
   document_class   => 'AI::Categorizer::Document::SMART',
   delimiter        => "\n.I",
   training         => 'doc.smart',
   test             => 'query.smart',
  ) :

  (
   collection_class => 'AI::Categorizer::Collection::Files',
   document_class   => 'AI::Categorizer::Document::Text',
   categories       => 'cats.txt',
   training         => 'training',
   test             => 'test',
  );


use lib "$ENV{HOME}/src/tcframe/src/AI-Categorizer/lib";
use AI::Categorizer::KnowledgeSet;
use AI::Categorizer::Experiment;

eval "use $opt{learner}";
eval "use $format{document_class}";

# Useful for debugging
use Carp; $SIG{__DIE__} = \&Carp::confess;

# Scan features
if ($opt{1}) {
  ### Read stopwords
  my @stopwords = `cat $name/SMART.stoplist`;
  chomp @stopwords;

  local %format = %format;
  my ($training) = delete @format{'training', 'test', 'categories'};
  
  ### Create knowledge set object
  my $k = new AI::Categorizer::KnowledgeSet
    (
     name => $name,
     stopwords => { map {($_ => 1)} @stopwords },
     %format,
     features_kept => $opt{features_kept},
     verbose => 1,
    );
  
  $k->scan_features( path => "$name/$training", verbose => 1, document_class => $format{document_class} );

  warn "saving to $name-save1";
  $k->save_state("$name-save1") or die $!;
}

# Read training corpus
if ($opt{2}) {
  ### Use new features
  warn "restoring from $name-save1";
  my $k = AI::Categorizer::KnowledgeSet->restore_state("$name-save1");

  my $categories = $format{categories} ? read_cats("$name/$format{categories}") : {};
  
  $k->read( path => "$name/$format{training}", document_class => $format{document_class}, categories => $categories );

  my $v = $k->features->as_hash;
  printf "Features: %d\nUnique tokens: %d\n", scalar(keys %$v), $k->features->sum;

  #warn "categories are ", map {" ".$_->name." "} $k->categories;
  #warn "documents are ", map {" ".$_->name." "} $k->documents;
  warn "saving to $name-save2";
  $k->save_state("$name-save2") or die $!;
}

# Train the categorizer
if ($opt{3}) {
  warn "restoring from $name-save2";
  my $k = AI::Categorizer::KnowledgeSet->restore_state("$name-save2");

  warn "training categorizer";
  my $l = $opt{learner}->new
    (
     verbose => 1,
    );
  $l->train(knowledge => $k);

  warn "saving to $name-save3";
  $l->save_state("$name-save3") or die $!;
}

# Categorize test set
if ($opt{4}) {
  warn "restoring from $name-save3";
  my $l = $opt{learner}->restore_state("$name-save3");
  $l->verbose(0);

  my $e = new AI::Categorizer::Experiment;
  
  my $categories = $format{categories} ? read_cats("$name/$format{categories}") : {};
  local %format = %format;
  my ($test) = delete @format{'test', 'training', 'categories'};
  
  my $collection_class = delete $format{collection_class};
  eval "use $collection_class";
  my $c = $collection_class->new
      (
       %format,
       path => "$name/$test",
       verbose => 1,
       categories => $categories,
      );

  while (my $d = $c->next) {
    my $h = $l->categorize($d);
    printf "%s: assigned=(%s) correct=(%s)\n", $d->name, join(', ', $h->categories), join(', ', map $_->name, $d->categories);
    $e->add_hypothesis($h, [map $_->name, $d->categories]);
  }

  Storable::store($e, 'experiment');

  print $e->stats_table;
}

if ($opt{5}) {
  my $e = Storable::retrieve('experiment');
  my $cats = $e->category_stats;
  my @metrics = qw(precision recall F1 error);
  print join("\t", 'category', @metrics), "\n";
  while (my ($cat, $stats) = each %$cats) {
    print join("\t", $cat, map $stats->{$_}, @metrics), "\n";
  }
}

########################################################################
sub read_cats {
  my $file = shift;

  my %cats;
  open my $fh, $file or die "$file: $!";
  while (<$fh>) {
    my ($doc, @cats) = split;
    $cats{$doc} = [@cats];
  }
  return \%cats;
}

