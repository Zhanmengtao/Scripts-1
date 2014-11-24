#!/usr/bin/perl
# Script: pfam2taxa.pl
# Description: Gets taxonomy information for a PFAM protein id 
# Author: Steven Ahrendt
# email: sahrendt0@gmail.com
# Date: 10.30.2014
##################################
# http://pfam.xfam.org/help#tabview=tab10
#######################
use warnings;
use strict;
use Getopt::Long;
use lib '/rhome/sahrendt/Scripts';
use SeqAnalysis;
#use Bio::LITE::Taxonomy::NCBI::Gi2taxid qw/new_dict/;
#use Bio::LITE::Taxonomy::NCBI;
#use TokyoCabinet;

## For PFAM stuff
use LWP::UserAgent;
use XML::LibXML;

#####-----Global Variables-----#####
my $input;	         # filename of ids to search
my %gi2tax;
my ($agent,$search);     # objects for http querying
my $out_form = "xml";    # output format is xml for parsing
my ($xml,$xml_parser);   # objects for xml parsing
my $simple_tax;          # filename for a simplified taxonomy list, including NCBI taxIDs
my ($help,$verb);
my ($NCBI_TAX,$NCBI_TAXlite);
my $ncbi = "ncbi";

#my $gi2taxa_idx = '/scratch/gbacc/gi2taxon.tch';
my $gi2taxon = '/rhome/sahrendt/bigdata/Data/Taxonomy/gi_taxid_prot.dmp.gz';

GetOptions ('i|input=s' => \$input,
            'h|help'   => \$help,
            'v|verbose' => \$verb,
            'm|mode=s'  => \$ncbi);
my $usage = "Usage: pfam2taxa.pl -i input [-m pfam]\nGets taxonomy information for a PFAM protein id\n";
die $usage if $help;
die "No input.\n$usage" if (!$input);

#####-----Main-----#####
$agent = LWP::UserAgent->new;
$agent->env_proxy;

my $NC = initNCBI("flatfile");
open(IN,"<",$input) or die "Can't open file $input: $!\n";
while(my $id = <IN>)
{
  chomp $id;
  print "$id\t";
  my $pfam_id = parseId($id) if ($ncbi eq "pfam");  # turn what was in the file into a PFAM readable id
  my $gi_id = getGI($id);

  if($pfam_id || $gi_id)
  {
    my $tax_id;
    if($ncbi eq "pfam")
    {
      $tax_id = getXMLInfo($pfam_id,"tax_id");
    }
    else
    {
      $tax_id =  (split(/\t/, `zgrep -P \"\^$gi_id\\t\" $gi2taxon`))[1];
      chomp $tax_id;
    }
#    my $simple_id = simpleId($tax_id);
#    my $simple_id = simpleId(getXMLInfo($pfam_id,"tax_id"); 
    print "$tax_id\t";
   # print getRank($tax_id,"species"),"\n";
    #print shift (@{getRank($tax_id,"species")}),"\n";
    #print getRank($tax_id,"phylum"),"\n";
     getTaxonomybyID
#    print "$simple_id\n";
  }
  else
  {
    print "NA\tClat\n";
  }
  
}
close(IN);

warn "Done.\n";
exit(0);

#####-----Subroutines-----#####
sub getGI {
  my $id = shift @_;
  my @data = split(/\|/,$id);
  if(scalar @data > 2)  # clat ids fail here
  {
    $id = $data[1]; #$NCBI_TAXlite->get_taxonomy_from_gi($data[1]);
  }
  return $id;
}
#
#sub initNCBI {
#  my $tax_dir = "/rhome/sahrendt/bigdata/Data/Taxonomy";
#  my $nodesfile = "$tax_dir/nodes.dmp";
#  my $namesfile = "$tax_dir/names.dmp";
#  my $indexdir = "$tax_dir";
#  my $dictfile = "$tax_dir/gi_taxid_prot.dmp";
#  my $dictbin = "$tax_dir/gi_taxid_prot.bin";
#  $NCBI_TAX = Bio::DB::Taxonomy->new(-source    => 'flatfile',
#                                     -directory => $tax_dir,
#                                     -namesfile => $namesfile,
#                                     -nodesfile => $nodesfile);
#}

sub getRank {
  my $taxonid = shift @_;
  my $rankname = shift @_;
  my $name = "no_phylum\t0";

  if($taxonid != 0)
  {
    my $taxon = $NCBI_TAX->get_taxon(-taxonid => $taxonid);
    while((my $rank = $taxon->rank) ne $rankname)
    {
#       $taxonid = $taxon->parent_id();
      $taxon = $NCBI_TAX->get_taxon(-taxonid => $taxon->parent_id());
      if (!defined($taxon))
      {
        $name = "no_phylum\t0";
        last;
      }
      $name = join("\t",shift(@{$taxon->name("scientific")}),$taxon->id());
    }
  }
  return $name;
}

#######
## Subroutine: simpleId
#       Input: an NCBI taxonomy id
#     Returns: a simple string denoting relative placement
#               like something found in the taxonlist file
##############
sub simpleId {
  my $id = shift @_;
  my $simple_id = "";
  return $simple_id;
}

#######
## Subroutine: parseId
#       Input: works on a specific coded file, specific to this analysis
#     Returns: the Ids which correspond to PFAM formatted strings
##############
sub parseId {
  my $id = shift @_;
  my $parsed_id = ""; 
  my @data = split(/[\_\/]/,$id);
  if(scalar @data > 1)  # clat ids will fail here
  {
    $parsed_id = join("\_",$data[2],$data[3]);
  }
  return $parsed_id;
}

###########
## Subroutine: getXMLInfo
#       Input: an id and an attribute value
#               currently only works with PFAM protein Ids
#                and searches to find NCBI tax ids for them
#     Returns: the NCBI taxid for each string
################
sub getXMLInfo {
  my $id = shift @_;
  my $attribute = shift @_;
  my $return_value = "";

  my $search = $agent->get("http://pfam.xfam.org/protein?id=$id&output=xml"); # search for something with id
  die "Failed to retrieve XML: ".$search->status_line,"\n" unless $search->is_success;

  my $xml = $search->content;
  my $xml_parser = XML::LibXML->new();
  my $dom = $xml_parser->parse_string( $xml );

  my $root = $dom->documentElement();
  my ($entry) = $root->getChildrenByTagName("entry");
  
  if($attribute eq "tax_id")
  {
    my ($taxonomy) = $entry->getChildrenByTagName("taxonomy");
    $return_value = $taxonomy->getAttribute($attribute);
  }
  return $return_value;

}