#!/usr/bin/perl

my $name = shift or die "Usage: $0 <corpus-directory>\n";
$name =~ s,/$,,;

my $categorizer = 'AI::Categorizer::Categorizer::NaiveBayes';

my %format = (
	      collection_class => 'AI::Categorizer::Collection::SingleFile',
	      document_class   => 'AI::Categorizer::Document::SMART',
	      delimiter        => "\n.I",
	     );

my $train_file = 'signalg.train';
my $test_path = 'signalg.test';

use strict;

use lib "$ENV{HOME}/src/tcframe/AI-Categorizer-0.01/lib";
#use lib "$ENV{HOME}/src/tcframe/src/AI-Categorizer/lib";
use AI::Categorizer::KnowledgeSet;
use AI::Categorizer::Categorizer::NaiveBayes;
use AI::Categorizer::Experiment;

eval "use $categorizer";
eval "use $format{document_class}";

# Useful for debugging
use Carp; $SIG{__DIE__} = \&Carp::confess;

# Scan features
if (0) {
  ### Read stopwords
  my @stopwords = `cat $name/SMART.stoplist`;
  chomp @stopwords;
  
  ### Create knowledge set object
  my $k = new AI::Categorizer::KnowledgeSet
    (
     name => $name,
     stopwords => { map {($_ => 1)} @stopwords },
     %format,
     features_kept => 1000,
     verbose => 1,
    );
  
  $k->scan_features( path => "$name/$train_file", verbose => 1, document_class => 'AI::Categorizer::Document::SMART', max_docs => 40_000 );

  warn "saving to $name-save";
  $k->save_state("$name-save") or die $!;
}

# Read training corpus
if (0) {
  ### Use new features
  warn "restoring from $name-save";
  my $k = AI::Categorizer::KnowledgeSet->restore_state("$name-save");

  $k->read( path => "$name/$train_file", document_class => 'AI::Categorizer::Document::SMART', max_docs => 40_000 );

  #my $v = $k->features->as_hash;
  #printf "Features: %d\nUnique tokens: %d\n", scalar(keys %$v), $k->features->sum;

  #warn "categories are ", map {" ".$_->name." "} $k->categories;
  #warn "documents are ", map {" ".$_->name." "} $k->documents;
  warn "saving to $name-save2";
  $k->save_state("$name-save2") or die $!;
}

# Train the categorizer
if (0) {
  warn "restoring from $name-save2";
  my $k = AI::Categorizer::KnowledgeSet->restore_state("$name-save2");

  warn "training categorizer";
  my $nb = $categorizer->new
    (
     verbose => 1,
    );
  $nb->train(knowledge => $k);

  warn "saving to $name-save3";
  $nb->save_state("$name-save3") or die $!;
}

# Categorize test set
if (1) {
  warn "restoring from $name-save3";
  my $nb = $categorizer->restore_state("$name-save3");
  my $e = new AI::Categorizer::Experiment;
  
  eval "use $format{collection_class}";
  my $c = $format{collection_class}->new
      (
       delimiter => "\n.I",
       path => "$name/$test_path",
       verbose => 1,
      );

  while (my $d = $c->next) {
    my $h = $nb->categorize($d);
    $e->add_hypothesis($h, [$d->categories]);
  }

  Storable::store($e, 'experiment');

  print $e->stats_table;
}

if (0) {
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

