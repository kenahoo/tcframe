#!/usr/bin/perl

use strict;
use File::Find;
use GraphViz;

my $startpath = shift
  or die "Usage: $0 <path>";

my %ignore_classes = map {+$_ => 1} qw(
				       Class::Container
				       Statistics::Contingency
				       Exporter
				       Storable
				       ObjectSet
				      );
my %abstract_classes = map {+$_ => 1} qw(
					 Learner
					 Learner::Boolean
					 FeatureSelector
					 Collection
					);

my %relations;
find( sub { add_relation(\%relations) }, $startpath );
print_graffle(\%relations);


sub print_graffle {
  my $h = shift;

  # Give each class a numeric ID
  my %ids;
  @ids{ keys %$h } = 1 .. keys %$h;
  my %rev_ids = reverse %ids;

  print <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist SYSTEM "file://localhost/System/Library/DTDs/PropertyList.dtd">
<plist version="0.9">
<dict>
	<key>GraphDocumentVersion</key>
	<integer>2</integer>
	<key>GraphicsList</key>
	  <array>
EOF

  # Add the class boxes
  foreach my $class (keys %$h) {
    my $style = $abstract_classes{$class} ? '\i' : '\b';

    print <<"EOF";
	    <dict>
	      <key>Class</key>
	      <string>ShapedGraphic</string>
	      <key>FitText</key>
	      <string>YES</string>
	      <key>ID</key>
	      <integer>$ids{$class}</integer>
	      <key>Shape</key>
	      <string>Rectangle</string>
	      <key>Text</key>
	      <dict>
		<key>Text</key>
		<string>{\\qc\\f0$style $class}</string>
	      </dict>
	    </dict>
EOF
  }
  
  my $i = %$h;
  # An inheritance arrow:
  foreach my $class (keys %$h) {
    foreach my $superclass (@{$h->{$class}}) {
      $i++;
      print <<"EOF";
	    <dict>
	      <key>Class</key>
	      <string>LineGraphic</string>
	      <key>Head</key>
	      <dict>
		<key>ID</key>
		<integer>$ids{$superclass}</integer>
	      </dict>
	      <key>ID</key>
	      <integer>$i</integer>
	      <key>Style</key>
	      <dict>
		<key>stroke</key>
		<dict>
		  <key>HeadArrow</key>
		  <string>UMLInheritance</string>
		  <key>LineType</key>
		  <integer>1</integer>
		  <key>TailArrow</key>
		  <string>0</string>
		</dict>
	      </dict>
	      <key>Tail</key>
	      <dict>
		<key>ID</key>
		<integer>$ids{$class}</integer>
	      </dict>
	    </dict>
EOF
    }
  }

  print <<'EOF';
	</array>
</dict>
</plist>
EOF

}


sub add_relation {
  my $h = shift;
  return unless /\.pm$/;
  return if /NaiveBayesBoolean|DBI2|Util|NNetTC|ObjectSet|Storable/;
  
  my $fullpath = $File::Find::name;
  open my($fh), $fullpath or die "Can't open $fullpath: $!";
  my $package;
  while (<$fh>) {
    if (/^package ([\w:]+)/) {
      ($package = $1) =~ s/^AI::Categorizer:://;
      $h->{$package} ||= [];
    }
    if (   /^use base qw\(([\w:]+)\)/
	or /^\@ISA = qw\(([\w:]+)\)/ ) {
      my @classes = grep {!exists $ignore_classes{$_}} split ' ', $1;
      s/^AI::Categorizer::// foreach @classes;
      
      print STDERR "$package: (@classes)\n";
      push @{$h->{$package}}, @classes;
    }
  }
  warn "No package found for $fullpath" unless $package;
  
}



__END__

my $g = new GraphViz;
find sub { add_to_graphviz($g) }, $startpath;

my $basename = 'doc/inheritance-uml';
my $fh;
open $fh, "> $basename.png" or die "Can't create $basename.png: $!";
print $fh $g->as_png;

open $fh, "> $basename.dot" or die "Can't create $basename.dot: $!";
print $fh $g->as_canon;


######################################################################
sub add_to_graphviz {
  my $g = shift;
  return unless /\.pm$/;
  return if /NaiveBayesBoolean|DBI2/;
  
  my $fullpath = $File::Find::name;
  open my($fh), $fullpath or die "Can't open $fullpath: $!";
  my $package;
  while (<$fh>) {
    if (/^package ([\w:]+)/) {
      $g->add_node($package = $1);
    }
    if (   /^use base qw\(([\w:]+)\)/
	or /^\@ISA = qw\(([\w:]+)\)/ ) {
      my @classes = split ' ', $1;
      print "$package: (@classes)\n";
      $g->add_edge($package => $_)
	foreach grep {!exists $ignore_classes{$_}} @classes;
    }
  }
  warn "No package found for $fullpath" unless $package;
  
}


