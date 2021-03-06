#!/usr/bin/perl 
# Script: getseqfromfile.pl
# Description: Provide a sequence ID and a fasta flatfile (database) and the script will return the fasta-formatted sequence
# Author: Steven Ahrendt
# email: sahrendt0@gmail.com
# Date: 8.13.14
#       v1.5 : intelligent choice if multiple sequences in a file
################################
use warnings;
use strict;
use Bio::Seq;
use Bio::SeqIO;
use Getopt::Long;

my ($org,$seqID,$acc_file);
my $multi;
my ($help,$verb);
my $dir = "/rhome/sahrendt/bigdata/Genomes/Protein";
my %acc;
my $invert;
GetOptions ('f|fasta=s'  => \$org,
            'd|dir=s'    => \$dir,
            'a|accnos=s' => \$acc_file,
            'i|id=s'     => \$seqID,
            'm|multi'    => \$multi,
            'h|help'     => \$help,
            'invert'     => \$invert,
            'v|verbose'  => \$verb     # verbose for file output
);

my $usage = "Usage: getseqfromfile.pl -f fastafile [-d dir] -i id | -a accnos_file\nOutput is STDOUT\nUse -m if multiple sequences in accnos file; omit fastafile\n";
die $usage if $help;
die "No IDs provided.\n$usage" if (!$acc_file && !$seqID && !$multi);

#####-----Main-----#####
my $seqio_obj_in;

if(!$multi)
{
  $seqio_obj_in = Bio::SeqIO->new(-file => "$dir/$org",
                                  -format => "fasta");
}

if($acc_file)
{
  open(ACC,"<$acc_file") or die "Can't open $acc_file\n";
  while(my $line = <ACC>)
  {
    next if ($line =~ /^#/);
    chomp $line;
    #my ($file,$etc) = split(/\|/,$line);
    $acc{$line}++;
  }
  close(ACC);
}
else
{
  #my $file = (split(/\|/,$org))[0];
  my @IDS = split(/,/,$seqID);
  foreach my $ID (@IDS)
  {
    $acc{$ID}++;
  }
}

my $printed = 0;
while(my $seq = $seqio_obj_in->next_seq)
{
  my $print = 0;
  if(exists $acc{$seq->display_id} && !$invert)    
  {
    $print = 1;
  }
  if($invert && !exists $acc{$seq->display_id})
  {
    $print = 1;
  }
  if($print)
  {
    my $seqio_obj_out = Bio::SeqIO->new(-fh => \*STDOUT,
                                        -format => "fasta");     
    $seqio_obj_out->write_seq($seq);
    $printed++;
  }
}

warn "$printed/".scalar(keys %acc)." sequences written\n";

warn "Done\n";
exit(0);

#####-----Subroutines-----#####
