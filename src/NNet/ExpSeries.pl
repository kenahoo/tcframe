#!/usr/local/bin/perl

#### Installation Parameters

# Directory where experiment are going to live
my $data = "/home/kenw/work/signalg/data";

# Directory where corpus lives
my $orig = "/home/halvards/work/signalg";

# Directory for binaries
my $bin = "/home/halvards/bin";
$nnet = "$bin/nntc";

# original
my $train= "$orig/signalg.train";
my $test= "$orig/signalg.test";
my $topicfile= "signalg.topics";
$topics = $data . "/" . $topicfile;

# Experiment series parameters
my $MTHD = "chi";
my $STEM = "m";
#CVsize
#$CVexps  number of cv experiments
$MONEMTUM = 0.5;

$EPOCHS =	5;
$N = 		500;
$HIDDEN=	50;
$SAVE = 	0;
my $COR = 		"signalg";
my $WT= 		"ntc";
my $K=		50;
$THRES= 	500;
$CV = 		200;
$CVEXP = 	3;
$EXP 	=	$COR;
$ALPHA 	= 	0.9;


print "Cleaning up:\n";
veryclean();

print "Preparing a series of experiments:\n";
prepare();

print "\nCreating vector:\n";
create_vec();

#########################################################
# shouldn't need any changes below this
##########################################################
##### top level

use strict;
sub mycall;

use File::Path;

sub veryclean {
    print "rmtree [$data, $COR.eval, core]\n";
    rmtree([$data, "$COR.eval", "core"], 0, 0);
}

sub clean {
    return unless -e $data;

    chdir $data or die "chdir $data: $!";
    mycall("rm *.list *.$::MTHD *.nnt *.net* *.smart query.* *var *.vec *out *loc $COR *.nn");
}

sub all {
    mycall(" prepare $COR.vec $COR.trn.nnt  $COR.tst.nnt thres");
}

## Mid level: running each bit

# put smart data in the right place
# the data directory passes from the command line
sub prepare {
    print "mkdir $data\n";
    mkdir $data, 0755 or die $!;
    chdir $data or die $!;

    print "symlink $train doc.smart\n";
    symlink $train,  'doc.smart' or die "$train -> doc.smart: $!";
    print "symlink $test query.smart\n";
    symlink $test, 'query.smart' or die "$test -> query.smart: $!";
}

# creates vec file from smart and runs fsel on it
# index.tc.sh indexes, weighting and then saves test and train data sets as vec
#       it also saves the dictionary (dict.tct)
# it seems that smart and data should be in same machine (???)
sub create_vec {
    chdir $data or die $!;

    print "# Creating spec file $data/spec\n";
    #mycall "$bin/create_spec.sh $train $test $WT $K";
    create_spec("$bin/smart.11.0/lib", $K);

    # Taken from the $bin/index.tc.sh script
    mycall "$bin/smart index.doc spec";
    mycall "$bin/smart convert spec proc convert.obj.weight_doc in doc.nnn out doc.$WT doc_weight $WT";
    mycall "$bin/smprint vec doc.$WT > train.vec";

    mycall "$bin/smart index.query spec";
    mycall "$bin/smart convert spec proc convert.obj.weight_query in query.nnn out query.$WT query_weight $WT";
    mycall "$bin/smprint vec query.$WT > test.vec";

    mycall "$bin/smprint dict dict > dict.txt";

    mycall "$bin/fsel -i $data/doc.smart -o $COR.$MTHD -s $MTHD $STEM";
}



# Saving train and test data in nnt format.
sub create_trn_nnt {
    my ($data,$bin,$cor,$mthd,$n) = @_;
    chdir $data or die $!;

    mycall "$bin/Smart2NNT.pl -s doc.smart -v train.vec \
                -d dict.txt -c $topicfile \
                -f $cor.$mthd -n $n \
                -o $cor.trn.nnt";
    mycall "$bin/Smart2NNT.pl -s query.smart -v test.vec \
                -d dict.txt -c $topicfile \
                -f $cor.$mthd -n $n \
                -o $cor.tst.nnt";
}

# Low level: Subs to run all above
sub mycall {
    my $cmd = shift;
    print "% $cmd\n";
    system $cmd;
}

sub create_spec {
    my ($smart_lib, $K) = @_;
    chomp(my $pwd = `pwd`);

    my $spec = <<EOS;
## INFORMATION LOCATIONS
include_file            $smart_lib/spec.default
database                $pwd
doc_loc                 $pwd/doc_loc
query_loc               $pwd/query_loc

#### GENERIC PREPARSER
num_pp_sections                 4
pp_section.0.string             ".I"
pp_section.0.action		discard
pp_section.0.oneline_flag       true
pp_section.0.newdoc_flag        true
pp_section.1.string             ".W"
pp_section.1.section_name       w
pp_section.2.string             ".T"
pp_section.2.section_name       t
pp_section.3.string		".C"
pp_section.3.action		discard
pp_section.3.string		".M"
pp_section.3.action		discard

#### DESCRIPTION OF PARSE INPUT
index.num_sections              2
index.section.0.name            w
  index.section.0.method        index.parse_sect.full
  index.section.0.word.ctype    0
  index.section.0.proper.ctype  0
index.section.1.name            t
  index.section.1.method        index.parse_sect.full
  index.section.1.word.ctype    0
  index.section.1.proper.ctype  0
title_section 1

#### DESCRIPTION OF FINAL VECTORS
num_ctypes                      1
ctype.0.name                    words
#index.ctype.0.stemmer           index.stem.none
#index.ctype.0.stopword          index.stop.stop_dict

## ALTERATIONS OF STANDARD PARAMETERS
dict_file_size                  65535
rmode                           SRDONLY|SMMAP
rwmode                          SRDWR|SINCORE
rwcmode                         SRDWR|SCREATE|SINCORE

doc_file			doc.nnn
inv_file			inv.nnn
query_file			query.nnn

query.textloc_file 		q_textloc
index.query.addtextloc		index.addtextloc.add_textloc
doc.store			index.store.store_vec_aux
indivtext			print.indivtext.text_form
get_query			retrieve.get_query.get_q_vec

tr_file         tr.Retrieve
num_wanted      $K

EOS

    local *FH;
    open  FH, "> spec" or die "spec: $!";
    print FH $spec;
    close FH;

    foreach ('doc', 'query') {
	open  FH, "> ${_}_loc" or die "${_}_loc: $!";
	print FH "$pwd/$_.smart\n";
	close FH;
    }
}

__END__

####
####  if smart not available in platform this should be portable without smart
sub create_net {
        cd ${DATA}; \
        ${BIN}/time.csh "${NNET} -r ${EXP}.ttrn.nnt -t ${EXP}.cv.nnt -e ${EPOCHS} \
                -s ${SAVE} \
                -n ${EXP}.net -h ${HIDDEN} -a 0.9 -m 0.5 " ${EXP}.${EPOCHS}.log ;
        ${BIN}/time.csh "${NNET} -r ${EXP}.ttrn.nnt  -t ${EXP}.cv.nnt -e ${EPOCHS} -s ${SAVE} \
                -n ${EXP}.net -h ${HIDDEN} -a 0.5 -m 0.5 " ${EXP}.${EPOCHS}.log
        ${BIN}/time.csh "${NNET} -r ${EXP}.ttrn.nnt  -t ${EXP}.cv.nnt -e ${EPOCHS} -s ${SAVE} \
                -n ${EXP}.net -h ${HIDDEN} -a 0.1 -m 0.5 " ${EXP}.${EPOCHS}.log

%.out : ${COR}.net
        cd ${DATA}; \
        ${NNET} -t ${COR}.tst.nnt -o ${COR}.out -n ${COR}.net

# all the training with thresholding and cross validation
thres: 
        ${BIN}/train_nnt.pl -c ${CV} -d ${DATA} -t ${THRES} -e ${COR} -n ${EPOCHS} -h ${HIDDEN} -x ${CVEXP} -a ${ALPHA}



# Saving Results and back ups
