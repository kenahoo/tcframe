#!/usr/bin/perl

use strict;

use AI::Categorizer::KnowledgeSet;
use AI::Categorizer::Categorizer::NaiveBayes;

use Carp; $SIG{__DIE__} = \&Carp::confess;

my $name = "reuters-21578";

if (0) {
  ### Read stopwords
  my @stopwords = `cat $name/SMART.stoplist`;
  chomp @stopwords;
  
  ### Create knowledge set object
  my $k = new AI::Categorizer::KnowledgeSet
    (
     name => $name,
     stopwords => \@stopwords,
    );
  
  ### Read categories
  my $cats = read_cats("$name/cats.txt");

  ### Read documents
  opendir TRAIN_DIR, "$name/training" or die $!;
  while (my $file = readdir TRAIN_DIR) {
    next if $file =~ /^\./;
    
    print "$file: @{$cats->{$file}}\n";
    my $body = do {open my $fh, "$name/training/$file" or die $!; local $/; <$fh>};  
    $k->make_document( name => $file,
		       categories => $cats->{$file},
		       content => $body );
#last if $::i++ > 500;
  }
  closedir TRAIN_DIR;

  #warn "categories are ", map {" ".$_->name." "} $k->categories;
  #warn "documents are ", map {" ".$_->name." "} $k->documents;
  #warn "saving to $name-save";
  #$k->save_state("$name-save") or die $!;



  ### Do feature selection
  #warn "restoring from $name-save";
  #my $k = AI::Categorizer::KnowledgeSet->restore_state("$name-save");

  { 
    local $k->{verbose} = 1;
    $k->select_features(features_kept => 0.2);
  }

  warn "saving features";
  my @f = keys %{ $k->features->as_hash };  
  Storable::store(\@f, 'features');
}

if (0) {
  ### Use new features
  my $f = Storable::retrieve('features');

  my $k = new AI::Categorizer::KnowledgeSet
    (
     name => $name,
     use_features => { map {($_ => 1)} @$f },
    );
  
  ### Read categories
  my %cats;
  open CATS, "$name/cats.txt" or die $!;
  while (<CATS>) {
    my ($doc, @cats) = split;
    $cats{$doc} = [@cats];
  }
  close CATS;
  
  ### Read documents
  opendir TRAIN_DIR, "$name/training" or die $!;
  while (my $file = readdir TRAIN_DIR) {
    next if $file =~ /^\./;
    
    print "$file: @{$cats{$file}}\n";
    my $body = do {open my $fh, "$name/training/$file" or die $!; local $/; <$fh>};  
    $k->make_document( name => $file,
		       categories => $cats{$file},
		       content => $body );
#last if $::i++ > 500;
  }
  closedir TRAIN_DIR;

  #warn "categories are ", map {" ".$_->name." "} $k->categories;
  #warn "documents are ", map {" ".$_->name." "} $k->documents;
  warn "saving to $name-save2";
  $k->save_state("$name-save2") or die $!;
}

if (0) {
  ### Train the categorizer
  warn "restoring from $name-save2";
  my $k = AI::Categorizer::KnowledgeSet->restore_state("$name-save2");

  warn "training categorizer";
  my $nb = new AI::Categorizer::Categorizer::NaiveBayes();
  $nb->train(knowledge => $k);

  warn "saving to $name-save3";
  $nb->save_state("$name-save3") or die $!;
}

if (1) {
  warn "restoring from $name-save3";
  my $nb = AI::Categorizer::Categorizer::NaiveBayes->restore_state("$name-save3");

  my $cats = read_cats("$name/cats.txt");

  opendir my($dir), "$name/test" or die $!;
  while (my $file = readdir $dir) {
    next if $file =~ /^\./;
    
    print "$file: @{$cats->{$file}}";
    my $body = do {open my $fh, "$name/test/$file" or die $!; local $/; <$fh>};  
    my $d = new AI::Categorizer::Document(
					  name => $file,
					  content => $body,
					 );
    my $h = $nb->categorize($d->features);
    print " => @{[ $h->categories ]}\n";
#last if $::i++ > 500;
  }
  closedir $dir;
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

