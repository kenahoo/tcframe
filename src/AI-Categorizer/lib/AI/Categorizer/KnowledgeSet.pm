package AI::Categorizer::KnowledgeSet;

use strict;
use Class::Container;
use AI::Categorizer::Storable;
use base qw(Class::Container AI::Categorizer::Storable);

use Params::Validate qw(:types);
use AI::Categorizer::ObjectSet;
use AI::Categorizer::Document;
use AI::Categorizer::Category;
use AI::Categorizer::FeatureVector;
use AI::Categorizer::Util;

__PACKAGE__->valid_params
  (
   categories => {
		  type => ARRAYREF,
		  default => [],
		  callbacks => { 'all are Category objects' => 
				 sub { ! grep !UNIVERSAL::isa($_, 'AI::Categorizer::Category'), @_ },
			       },
		 },
   documents  => {
		  type => ARRAYREF,
		  default => [],
		  callbacks => { 'all are Document objects' => 
				 sub { ! grep !UNIVERSAL::isa($_, 'AI::Categorizer::Document'), @_ },
			       },
		 },
   features_kept => {
		     type => SCALAR,
		     default => 0.2,
		    },
   verbose => {
	       type => SCALAR,
	       default => 0,
	      },
  );

__PACKAGE__->contained_objects
  (
   document => { delayed => 1,
		 class => 'AI::Categorizer::Document' },
   category => { delayed => 1,
		 class => 'AI::Categorizer::Category' },
   collection => { delayed => 1,
		   class => 'AI::Categorizer::Collection' },
   features => { delayed => 1,
		 class => 'AI::Categorizer::FeatureVector' },
  );

sub new {
  my $self = shift()->SUPER::new(@_);

  # Convert to AI::Categorizer::ObjectSet sets
  $self->{categories} = new AI::Categorizer::ObjectSet( @{$self->{categories}} );
  $self->{documents}  = new AI::Categorizer::ObjectSet( @{$self->{documents}}  );
  $self->{category_names} = { map {($_->name => $_)} $self->{categories}->members };
  return $self;
}

sub features {
  my $self = shift;

  if (@_) {
    $self->{features} = shift;
    $self->trim_doc_features if $self->{features};
  }
  return $self->{features} if $self->{features};

  # Create a feature vector encompassing the whole set of documents
  my $v;
  foreach my $document ($self->documents) {
    $v ||= ref($document->features)->new( features => {} );
    $v->add( $document->features );
  }
  return $self->{features} = $v;
}

sub categories {
  my $c = $_[0]->{categories};
  return wantarray ? $c->members : $c->size;
}

sub documents {
  my $d = $_[0]->{documents};
  return wantarray ? $d->members : $d->size;
}

sub verbose {
  my $self = shift;
  $self->{verbose} = shift if @_;
  return $self->{verbose};
}

sub trim_doc_features {
  my ($self) = @_;
  
  foreach my $doc ($self->documents) {
    $doc->features( $doc->features->intersection($self->features) );
  }
}

sub scan {
  # Should determine:
  #  - number of documents
  #  - number of categories
  #  - avg. number of categories per document (whole corpus)
  #  - avg. number of tokens per document (whole corpus)
  #  - avg. number of types per document (whole corpus)
  #  - number of documents, tokens, & types for each category
  #  - "category skew index" (% variance?) by num. documents, tokens, and types

  my ($self, %args) = @_;
  my $collection = $self->create_delayed_object('collection', %args);
  #my $collection = $self->create_delayed_object('collection', path => $args{path});

  my %stats;

  local $| = 1;
  while (my $doc = $collection->next) {
    print "." if $self->verbose;
    $stats{category_count_with_duplicates} += $doc->categories;

    my ($sum, $length) = ($doc->features->sum, $doc->features->length);
    $stats{document_count}++;
    $stats{token_count} += $sum;
    $stats{type_count}  += $length;
    
    foreach my $cat ($doc->categories) {
#warn $doc->name, ": ", $cat->name, "\n";
      $stats{categories}{$cat->name}{document_count}++;
      $stats{categories}{$cat->name}{token_count} += $sum;
      $stats{categories}{$cat->name}{type_count}  += $length;
    }
  }
  print "\n" if $self->verbose;

  my @cats = keys %{ $stats{categories} };

  $stats{category_count}          = @cats;
  $stats{categories_per_document} = $stats{category_count_with_duplicates} / $stats{document_count};
  $stats{tokens_per_document}     = $stats{token_count} / $stats{document_count};
  $stats{types_per_document}      = $stats{type_count}  / $stats{document_count};

  foreach my $thing ('type', 'token', 'document') {
    $stats{"${thing}s_per_category"} = AI::Categorizer::Util::average
      ( map { $stats{categories}{$_}{"${thing}_count"} } @cats );

    next unless @cats;

    # Compute the variance
    my $ssum;
    foreach my $cat (@cats) {
      $ssum += ($stats{categories}{$cat}{"${thing}_count"} - $stats{"${thing}s_per_category"}) ** 2;
    }
    $stats{"${thing}_skew_by_category"} = sqrt($ssum/@cats) / $stats{"${thing}s_per_category"};
  }

  return \%stats;
}

sub scan_features {
  my ($self, %args) = @_;

  my $features = $self->create_delayed_object('features', features => {});
  
  if (my $dir = $args{directory}) {
    
    local (*DIRH, *FH);
    opendir DIRH, $dir or die "$dir: $!";
    while (defined (my $file = readdir DIRH)) {
      next if $file =~ /^\./;
      print "$file\n" if $self->{verbose};

      open FH, "< $dir/$file" or die "$dir/$file: $!";
      my $body = do {local $/; <FH>};
      close FH;

      my $doc = $self->create_delayed_object('document', 
					     name => $file,
					     content => $body,
					     term_weighting => 'boolean',
					    );
      $features->add( $doc->features );
    }
    closedir DIRH;

  } else {
    die "Must specify 'directory' argument to scan_features()";
  }

  $features = $self->_reduce_features($features);
  
  $self->delayed_object_params('document', use_features => $features);
}

sub _reduce_features {
  # Takes a feature vector whose weights are "feature scores", and
  # chops to the highest n features.  n is specified by the
  # 'features_kept' parameter.  If it's zero, all features are kept.
  # If it's between 0 and 1, we multiply by the present number of
  # features.  If it's greater than 1, we treat it as the number of
  # features to use.

  my ($self, $f) = @_;
  return $f unless $self->{features_kept};

  my $kept = ($self->{features_kept} < 1 ? 
	      $f->length * $self->{features_kept} :
	      $self->{features_kept});

  print "Trimming features - # features = " . $f->length . "\n" if $self->{verbose};
  
  # This is algorithmic overkill, but the sort seems fast enough.  Will revisit later.
  my $features = $f->as_hash;
  my @new_features = (sort {$features->{$b} <=> $features->{$a}} keys %$features)
                      [0 .. $kept];

  my $result = $f->intersection( \@new_features );
  print "Finished trimming features - # features = " . $result->length . "\n" if $self->{verbose};
  return $result;
}


sub select_features {
  # This just uses a simple document-frequency criterion, controlled
  # by 'features_kept'.  Other algorithms may follow later, controlled
  # by other parameters.

# XXX this is doing word-frequency right now, not document-frequency

  my ($self, %args) = @_;
  my $kept = exists($args{features_kept}) ? $args{features_kept} : $self->{features_kept};
  return unless $kept;
  
  my $f = $self->_reduce_features($self->features, $kept);
  $self->features($f);
}

sub partition {
  my ($self, @sizes) = @_;
  my $num_docs = my @docs = $self->documents;
  my @groups;

  while (@sizes > 1) {
    my $size = int ($num_docs * shift @sizes);
    push @groups, [];
    for (0..$size) {
      push @{ $groups[-1] }, splice @docs, rand(@docs), 1;
    }
  }
  push @groups, \@docs;

  return map { ref($self)->new( documents => $_ ) } @groups;
}

sub make_document {
  my ($self, %args) = @_;
  my $cats = delete $args{categories};
  my @cats = map { $self->category_by_name($_) } @$cats;
  my $d = $self->create_delayed_object('document', %args, categories => \@cats);
  $self->add_document($d);
}

sub add_document {
  my ($self, $doc) = @_;

  foreach ($doc->categories) {
    $_->add_document($doc);
  }
  $self->{documents}->insert($doc);
  $self->{categories}->insert($doc->categories);
}

sub category_by_name {
  my ($self, $cat) = @_;
  return $cat if ref $cat;
  return $self->{category_names}{$cat} if exists $self->{category_names}{$cat};
  return $self->{category_names}{$cat} = $self->create_delayed_object('category', name => $cat);
}

#  sub save_state {
#    my $self = shift;
  
#    # With large corpora it's infeasible to save the whole knowledge
#    # base.  We'll just save feature vectors & relationships.

#    local $self->{documents_save} = {};
#    foreach my $doc ($self->documents) {
#      $self->
#    }

#    return $self->SUPER::save_state(@_);
#  }

1;
