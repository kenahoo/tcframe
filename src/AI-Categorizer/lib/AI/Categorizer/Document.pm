package AI::Categorizer::Document;

use strict;
use Class::Container;
use base qw(Class::Container);

use Params::Validate qw(:types);
use AI::Categorizer::ObjectSet;
use AI::Categorizer::FeatureVector;

__PACKAGE__->valid_params
  (
   name       => {
		  type => SCALAR, 
		 },
   categories => {
		  type => ARRAYREF,
		  default => [],
		  callbacks => { 'all are Category objects' => 
				 sub { ! grep !UNIVERSAL::isa($_, 'AI::Categorizer::Category'), @{$_[0]} },
			       },
		  public => 0,
		 },
   stopwords => {
		 type => ARRAYREF|HASHREF,
		 default => []
		},
   content   => {
		 type => HASHREF|SCALAR,
		 default => '',
		},
   content_weights => {
		       type => HASHREF,
		       default => {},
		      },
   front_bias => {
		  type => SCALAR,
		  default => 0,
		  },
   term_weighting  => {
		       type => SCALAR,
		       default => 'natural',
		      },
   use_features => {
		    type => HASHREF|UNDEF,
		    default => undef,
		   },
   stemming => {
		type => SCALAR|UNDEF,
		optional => 1,
	       },
  );

__PACKAGE__->contained_objects
  (
   features => { delayed => 1,
		 class => 'AI::Categorizer::FeatureVector' },
  );

### Constructors

sub new {
  my $self = shift()->SUPER::new(@_);

  # Get efficient internal data structures
  $self->{categories} = new AI::Categorizer::ObjectSet( @{$self->{categories}} );
  $self->{stopwords} = { map {($_ => 1)} @{ $self->{stopwords} } }
    if UNIVERSAL::isa($self->{stopwords}, 'ARRAY');

  # Allow a simple string as the content
  $self->{content} = { body => $self->{content} } unless ref($self->{content});

  $self->create_feature_vector;

  # Now we're done with all the content stuff
  delete @{$self}{'content', 'content_weights', 'stopwords', 'term_weighting', 'use_features'};
  
  return $self;
}

# Parse a document format - a virtual method
sub parse;

### Accessors

sub name { $_[0]->{name} }

sub features {
  my $self = shift;
  if (@_) {
    $self->{features} = shift;
  }
  return $self->{features};
}

sub categories {
  my $c = $_[0]->{categories};
  return wantarray ? $c->members : $c->size;
}


### Workers

sub create_feature_vector {
  my $self = shift;
  my $content = $self->{content};
  my $weights = $self->{content_weights};

  my %features;
  while (my ($name, $data) = each %$content) {
    my $t = $self->tokenize($data);
    $self->stem_words($t);
    my $h = $self->vectorize(tokens => $t, weight => exists($weights->{$name}) ? $weights->{$name} : 1 );
    @features{keys %$h} = values %$h;
  }
  $self->{features} = $self->create_delayed_object('features', features => \%features);
}

sub is_in_category {
  return $_[0]->{categories}->includes( $_[1] );
}

sub tokenize {
  my $self = shift;
  my @tokens;
  while ($_[0] =~ /([-\w]+)/g) {
    my $word = lc $1;
    next unless $word =~ /[a-z]/;
    $word =~ s/^[^a-z]+//;  # Trim leading non-alpha characters (helps with ordinals)
    push @tokens, $word;
  }
  return \@tokens;
}

sub stem_words {
  my ($self, $tokens) = @_;
  return unless $self->{stemming};
  return if $self->{stemming} eq 'none';
  die "Unknown stemming option '$self->{stemming}' - options are 'porter' or 'none'"
    unless $self->{stemming} eq 'porter';
  
  eval {require Lingua::Stem; 1}
    or die "Porter stemming requires the Lingua::Stem module, available from CPAN.\n";

  @$tokens = @{ Lingua::Stem::stem(@$tokens) };
}

sub _filter_tokens {
  my ($self, $tokens_in) = @_;

  if ($self->{use_features}) {
    my $f = $self->{use_features}->as_hash;
    return [ grep  exists($f->{$_}), @$tokens_in ];
  } elsif ($self->{stopwords}) {
    my $s = $self->{stopwords};
    return [ grep !exists($s->{$_}), @$tokens_in ];
  }
  return $tokens_in;
}

sub _weigh_tokens {
  my ($self, $tokens, $weight) = @_;

  my %counts;
  if (my $b = 0+$self->{front_bias}) {
    die "'front_bias' value must be between -1 and 1"
      unless -1 < $b and $b < 1;
    
    my $n = @$tokens;
    my $r = ($b-1)**2 / ($b+1);
    my $mult = $weight * log($r)/($r-1);
    
    my $i = 0;
    foreach my $feature (@$tokens) {
      $counts{$feature} += $mult * $r**($i/$n);
      $i++;
    }
    
  } else {
    foreach my $feature (@$tokens) {
      $counts{$feature} += $weight;
    }
  }

  return \%counts;
}

sub vectorize {
  my ($self, %args) = @_;
  my $tokens = $self->_filter_tokens($args{tokens});

  return { map {( $_ => $args{weight})} @$tokens }
    if $self->{term_weighting} eq 'boolean';

  my $counts = $self->_weigh_tokens($tokens, $args{weight});

  if ($self->{term_weighting} eq 'natural') {
    # Nothing to do
  } elsif ($self->{term_weighting} eq 'log') {
    $_ = 1 + log($_) foreach values %$counts;
  } else {
    die "term_weighting must be one of 'natural', 'log', or 'boolean'";
  }
  
  return $counts;
}

sub read {
  my ($class, %args) = @_;
  my $path = delete $args{path} or die "Must specify 'path' argument to read()";
  $args{name} ||= $path;

  local *FH;
  open FH, "< $path" or die "$path: $!";
  my $body = do {local $/; <FH>};
  close FH;

  my $doc = $class->parse(content => $body);
  return $class->new(%args, content => $doc);
}

1;

__END__

=head1 NAME

AI::Categorizer::Document - Embodies a document

=head1 SYNOPSIS

 use AI::Categorizer::Document;
 
 # Simplest way to create a document:
 my $d = new AI::Categorizer::Document(name => $string,
                                       content => $string);
 
 # Other parameters are accepted:
 my $d = new AI::Categorizer::Document(name => $string,
                                       categories => \@category_objects,
                                       content => { subject => $string,
                                                    body => $string2, ... },
                                       content_weights => { subject => 3,
                                                            body => 1, ... },
                                       stopwords => \%skip_these_words,
                                       stemming => $string,
                                       term_weighting => $string,
                                       front_bias => $float,
                                       use_features => $feature_vector,
                                      );
 
 # Specify explicit feature vector:
 my $d = new AI::Categorizer::Document(name => $string);
 $d->features( $feature_vector );
 
 # Now pass the document to a categorization algorithm:
 my $learner = AI::Categorizer::Learner::NaiveBayes->restore_state($path);
 my $hypothesis = $learner->categorize($document);

=head1 DESCRIPTION

The Document class embodies the data in a single document, and
contains methods for turning this data into a FeatureVector.  Usually
documents are plain text, but subclasses of the Document class may
handle any kind of data.

=head1 METHODS

=over 4

=item new(%parameters)

Creates a new Document object.  Accepts the following parameters:

=over 4

=item name

A string that identifies this document.  Required.

=item content

The raw content of this document.  May be specified as either a string
or as a hash reference, allowing structured document types.

=item content_weights

A hash reference indicating the weights that should be assigned to
features in different sections of a structured document when creating
its feature vector.  The weight is a multiplier of the feature vector
values.  For instance, if a C<subject> section has a weight of 3 and a
C<body> section has a weight of 1, and word counts are used as feature
vector values, then it will be as if all words appearing in the
C<subject> appeared 3 times.

If no weights are specified, all weights are set to 1.

=item front_bias

Allows smooth bias of the weights of words in a document according to
their position.  The value should be a number between -1 and 1.
Positive numbers indicate that words toward the beginning of the
document should have higher weight than words toward the end of the
document.  Negative numbers indicate the opposite.  A bias of 0
indicates that no biasing should be done.

=item term_weighting

Specifies how word counts should be converted to feature vector
values.  If C<term_weighting> is set to C<natural>, the word counts
themselves will be used as the values.  C<boolean> indicates that each
positive word count will be converted to 1 (or whatever the
C<content_weight> for this section is).  C<log> indicates that the
values will be set to C<1+log(count)>.

=item categories

A reference to an array of Category objects that this document belongs
to.  Optional.

=item stopwords

A list/hash of features (words) that should be ignored when parsing
document content.  A hash reference is preferred, with the features as
the keys.  If you pass an array reference containing the features, it
will be converted to a hash reference internally.

=item use_features

A Feature Vector specifying the only features that should be
considered when parsing this document.  This is an alternative to
using C<stopwords>.

=item stemming

Indicates the linguistic procedure that should be used to convert
tokens in the document to features.  Possible values are C<none>,
which indicates that the tokens should be used without change, or
C<porter>, indicating that the Porter stemming algorithm should be
applied to each token.  This requires the C<Lingua::Stem> module from
CPAN.

=back

=item read( path =E<gt> $path )

An alternative constructor method which reads a file on disk and
returns a document with that file's contents.

=item name()

Returns this document's C<name> property as specified when the
document was created.

=item features()

Returns the Feature Vector associated with this document.

=item categories()

In a list context, returns a list of Category objects to which this
document belongs.  In a scalar context, returns the number of such
categories.

=item create_feature_vector()

Creates this document's Feature Vector by parsing its content.  You
won't call this method directly, it's called by C<new()>.

=back



=head1 AUTHOR

Ken Williams <kenw@ee.usyd.edu.au>

=head1 COPYRIGHT

This distribution is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.  These terms apply to
every file in the distribution - if you have questions, please contact
the author.

=cut
