#!/usr/bin/perl

use strict;
use File::Find;
use GraphViz;

my $startpath = shift
  or die "Usage: $0 <path>";

my %ignore_classes = ( Class::Container => 1,
		       Statistics::Contingency => 1,
		       Exporter => 1,
		     );

my %relations;
find( sub { add_relation(\%relations) }, $startpath );
print_graffle(\%relations);


sub print_graffle {
  my $h = shift;
  print <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist SYSTEM "file://localhost/System/Library/DTDs/PropertyList.dtd">
<plist version="0.9">
<dict>
	<key>GraphDocumentVersion</key>
	<integer>2</integer>
	<key>GraphicsList</key>
	  <array>
	    <dict>
	      <key>Class</key>
	      <string>LineGraphic</string>
	      <key>Head</key>
	      <dict>
		<key>ID</key>
		<integer>1</integer>
	      </dict>
	      <key>ID</key>
	      <integer>3</integer>
	      <key>Points</key>
	      <array>
		<string>{190.395, 155.925}</string>
		<string>{223.312, 92.175}</string>
	      </array>
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
		<integer>2</integer>
	      </dict>
	    </dict>

EOF
  
  
}


sub add_relation {
  my $h = shift;
  return unless /\.pm$/;
  return if /NaiveBayesBoolean|DBI2|Util/;
  
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


# A .graffle file that works:
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist SYSTEM "file://localhost/System/Library/DTDs/PropertyList.dtd">
<plist version="0.9">
<dict>
	<key>CanvasColor</key>
	<dict>
		<key>w</key>
		<real>1.000000e+00</real>
	</dict>
	<key>ColumnAlign</key>
	<integer>0</integer>
	<key>ColumnSpacing</key>
	<real>3.600000e+01</real>
	<key>GraphDocumentVersion</key>
	<integer>2</integer>
	<key>GraphicsList</key>
	<array>
		<dict>
			<key>Class</key>
			<string>LineGraphic</string>
			<key>Head</key>
			<dict>
				<key>ID</key>
				<integer>1</integer>
			</dict>
			<key>ID</key>
			<integer>3</integer>
			<key>Points</key>
			<array>
				<string>{190.395, 155.925}</string>
				<string>{223.312, 92.175}</string>
			</array>
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
				<integer>2</integer>
			</dict>
		</dict>
		<dict>
			<key>Bounds</key>
			<string>{{127.575, 155.925}, {90, 78}}</string>
			<key>Class</key>
			<string>MultiTextGraphic</string>
			<key>FitText</key>
			<string>Vertical</string>
			<key>ID</key>
			<integer>2</integer>
			<key>ListOrientation</key>
			<string>Vertical</string>
			<key>Style</key>
			<dict>
				<key>fill</key>
				<dict>
					<key>GradientAngle</key>
					<real>3.040000e+02</real>
					<key>GradientCenter</key>
					<string>{-0.294118, -0.264706}</string>
				</dict>
			</dict>
			<key>TextList</key>
			<array>
				<dict>
					<key>Align</key>
					<integer>0</integer>
					<key>Text</key>
					<string>{\qc\f0\b SubClass}</string>
				</dict>
				<dict>
					<key>Align</key>
					<integer>0</integer>
					<key>Text</key>
					<string>{Attribute1\
Attribute2}</string>
				</dict>
				<dict>
					<key>Align</key>
					<integer>0</integer>
					<key>Text</key>
					<string>{Operation1\
Operation2}</string>
				</dict>
			</array>
			<key>TextPlacement</key>
			<integer>0</integer>
		</dict>
		<dict>
			<key>Bounds</key>
			<string>{{198.45, 14.175}, {90, 78}}</string>
			<key>Class</key>
			<string>MultiTextGraphic</string>
			<key>FitText</key>
			<string>Vertical</string>
			<key>ID</key>
			<integer>1</integer>
			<key>ListOrientation</key>
			<string>Vertical</string>
			<key>Style</key>
			<dict>
				<key>fill</key>
				<dict>
					<key>GradientAngle</key>
					<real>3.040000e+02</real>
					<key>GradientCenter</key>
					<string>{-0.294118, -0.264706}</string>
				</dict>
			</dict>
			<key>TextList</key>
			<array>
				<dict>
					<key>Align</key>
					<integer>0</integer>
					<key>Text</key>
					<string>{\qc\f0\b ParentClass}</string>
				</dict>
				<dict>
					<key>Align</key>
					<integer>0</integer>
					<key>Text</key>
					<string>{Attribute1\
Attribute2}</string>
				</dict>
				<dict>
					<key>Align</key>
					<integer>0</integer>
					<key>Text</key>
					<string>{Operation1\
Operation2}</string>
				</dict>
			</array>
			<key>TextPlacement</key>
			<integer>0</integer>
		</dict>
	</array>
</dict>
</plist>
