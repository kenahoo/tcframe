#!/usr/bin/perl

my $name = shift or die "Usage: $0 <corpus-directory>\n";
$name =~ s,/$,,;

my $categorizer = 'AI::Categorizer::Categorizer::NaiveBayes';

my %format = (
	      collection_class => 'AI::Categorizer::Collection::SingleFile',
	      document_class   => 'AI::Categorizer::Document::SMART',
	      delimiter        => "\n.I",
	     );

use strict;

use lib "$ENV{HOME}/src/tcframe/src/AI-Categorizer/lib";
use AI::Categorizer::KnowledgeSet;
use AI::Categorizer::Categorizer::NaiveBayes;
use AI::Categorizer::Experiment;

eval "use $categorizer";

# Useful for debugging
use Carp; $SIG{__DIE__} = \&Carp::confess;

# Scan features
if (1) {
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
  
  $k->scan_features( path => "$name/doc.smart", verbose => 1, document_class => 'AI::Categorizer::Document::SMART' );

  warn "saving to $name-save";
  $k->save_state("$name-save") or die $!;
}

# Read training corpus
if (1) {
  ### Use new features
  warn "restoring from $name-save";
  my $k = AI::Categorizer::KnowledgeSet->restore_state("$name-save");

  $k->read( path => "$name/doc.smart", document_class => 'AI::Categorizer::Document::SMART' );

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
if (0) {
  warn "restoring from $name-save3";
  my $nb = $categorizer->restore_state("$name-save3");
  my $e = new AI::Categorizer::Experiment;

  my $cats = read_cats("$name/cats.txt");
  my %totals;
  my @metrics = qw(precision recall F1);

  local $|=1;
  opendir my($dir), "$name/test" or die $!;
  while (my $file = readdir $dir) {
    next if $file =~ /^\./;
    
    my $body = do {open my $fh, "$name/test/$file" or die $!; local $/; <$fh>};  
    my $d = new AI::Categorizer::Document(
					  name => $file,
					  content => $body,
					 );
    my $h = $nb->categorize($d);
    $e->add_hypothesis($h, $cats->{$file});
    print '.';
    #print "$file: @{$cats->{$file}} => @{[ $h->categories ]}\n";
  }
  print "\n";
  closedir $dir;

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
  open my $fh, $file or die $!;
  while (<$fh>) {
    my ($doc, @cats) = split;
    $cats{$doc} = [@cats];
  }
  return \%cats;
}

