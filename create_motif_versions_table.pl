#!/usr/bin/env perl

=head1 NAME

create_motif_version_table.pl

=head1 SYNOPSIS

  create_motif_version_table.pl -d out_directory
            [-db jaspar_db] [-c collection] [-t tax_group(s)]

=head1 ARGUMENTS
 
  -d out_dir		= Output directory to which to write the HTML page and
                      TFBS logos.
  -fixed_width      = Logos are fixed width (same width regarless of the
                      number of positions in the logo).
  -labeled          = Logos are labeled with the matrix ID.
  -centered         = Logos are centered in the output table.
  -db   			= JASPAR database name.
  	           		  DEFAULT = JASPAR_2016
  -c collection	    = JASPAR collection of TFBS profile with which
			          to search the sequence(s)
                      DEFAULT='CORE'
  -t tax_groups	    = Taxonomic supergroups(s) of TFBS profiles to use
                      DEFAULT=NULL (all tax groups)

=head1 DESCRIPTION

Create an HTML JASPAR motifs version table so that each line corresponds
to a JASPAR profile and each column corresponds to the version number.

This script DOES NOT indicate which version of each motif corresponds to
which JASPAR version! For that functionality, please use the
create_jaspar_motif_versions_table.pl script.

=head1 AUTHOR

  David Arenillas
  Wasserman Lab
  Centre for Molecular Medicine and Therapeutics
  University of British Columbia
  
  E-mail: dave@cmmt.ubc.ca

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use File::Spec;
use TFBS::Matrix::PFM;
use TFBS::DB::JASPAR;

#
# Default min. score to report for sequence(s).
# Overidden by -t argument.
#
use constant COLLECTION     => "CORE";
use constant TAX_GROUP_STR  => "vertebrates,plants,nematodes,insects,fungi,urochordates";

use constant JASPAR_DB_NAME => "JASPAR_2016";
use constant JASPAR_DB_HOST => "vm5.cmmt.ubc.ca";
use constant JASPAR_DB_USER => "jaspar_r";
use constant JASPAR_DB_PASS => "";

use constant HTML_TABLE_FILE    => "profile_versions_table.html";
use constant LOGO_XSIZE         => 300;  # total pixel width of logo
use constant LOGO_YSIZE         => 100;  # total pixel height of logo
use constant LOGO_POS_XSIZE     => 22;   # per position pixel width of logo

my $out_dir;
my $jaspar_db;
my $collection;
my $tax_group_str;
my $fixed_width;
my $label_logos;
my $center_logos;
GetOptions(
    'd=s'           => \$out_dir,
    'db=s'          => \$jaspar_db,
    'c=s'           => \$collection,
    't=s'           => \$tax_group_str,
    'fixed_width'   => \$fixed_width,
    'labeled'       => \$label_logos,
    'centered'      => \$center_logos
);

unless ($out_dir) {
    die "No output directory specified!\n";
}

unless (-d $out_dir) {
    mkdir $out_dir || die "Could not create output directory $out_dir\n";
}

$jaspar_db  = JASPAR_DB_NAME if !$jaspar_db;
$collection = COLLECTION if !$collection;

my $db = TFBS::DB::JASPAR7->connect(
    "dbi:mysql:" . $jaspar_db . ":" . JASPAR_DB_HOST,
    JASPAR_DB_USER, JASPAR_DB_PASS);
die "Error connecting to JASPAR database\n" if !$db;

my %matrix_args = (
    '-all_versions' => 1,
    '-matrixtype'   => 'PFM',
    '-collection'   => $collection
);

$tax_group_str = TAX_GROUP_STR if !$tax_group_str;

my @tax_groups  = split /\s*,\s*/, $tax_group_str;
$matrix_args{'-tax_group'} = \@tax_groups;

my $matrix_set = $db->get_MatrixSet(%matrix_args);

my $out_table_file = File::Spec->catfile("$out_dir", HTML_TABLE_FILE);
open(OFH, ">$out_table_file")
    || die "Error opening output HTML file $out_table_file\n";

# Get the maximum version number of any profile in the JASPAR DB.
my $max_version = 0;
my $iter = $matrix_set->Iterator();
while (my $matrix = $iter->next()) {
    my ($base_id, $version) = split_matrix_id($matrix->ID);

    if ($version > $max_version) {
        $max_version = $version;
    }
}

my $td_text_align = "left";
if ($center_logos) {
    $td_text_align = "center";
}

print OFH "<html>\n";
print OFH "<body>\n";
print OFH <<"EOT";
<style type="text/css">
table {
    border: 1px solid black;
    border-collapse: collapse;
}

th, td {
    border: 1px solid black;
    text-align: left;
    padding:    2px 5px 2px 5px;
}
</style>
EOT
print OFH "<table>\n";

# XXX assumes CORE! XXX
my $last_name = '';
my $last_base_id = '';
my $last_version = 0;

$iter = $matrix_set->Iterator(-sort_by => 'ID');
while (my $matrix = $iter->next()) {
    my $matrix_id = $matrix->ID;
    my ($base_id, $version) = split_matrix_id($matrix_id);

    my $name = $matrix->name();

    print "Processing profile: $name\t$base_id\t$version\n";

    if ($base_id ne $last_base_id) {
        if ($last_base_id) {
            # If we are not on the very first pass through,
            # end the previous table row.
            if ($last_version < $max_version) {
                # If the last matrix didn't have versions for all columns,
                # add extra columns to fill out the row last row.
                my $col = $last_version;
                while ($col < $max_version) {
                    print OFH "<td></td>";
                    $col++;
                }
            }
            print OFH "</tr>\n";
        }

        # Start new row with column entry for profile name/base_id
        # If we are labelling the individual profiles don't bother putting
        # a specific base ID column
        print OFH "<tr><th>$name</th>";
        unless ($label_logos) {
            print OFH "<td>$base_id</td>";
        }

        printf OFH "<td>%s</td>", $matrix->tag('tax_group');

        # If for some reason the first version number for this profile is
        # not 1, add blank columns to the table.
        if ($version > 1) {
            warn "First version number $version of profile $name is > 1\n";

            my $col = 1;
            while ($col < $version) {
                print OFH "<td></td>";
                $col++;
            }
        }

        $last_base_id = $base_id;
    }

    my $matrix_length = $matrix->length();
    my $logo_file = sprintf("%s.png", $matrix_id);

    my $xsize;
    if ($fixed_width) {
        $xsize = LOGO_XSIZE;
    } else {
        $xsize = LOGO_POS_XSIZE * $matrix_length;
    }

    my %draw_logo_args = (
        -xsize  => $xsize,
        -ysize  => LOGO_YSIZE,
        -file   => File::Spec->catfile($out_dir, $logo_file),
    );

    # This doesn't display properly (depending on scaling?)
    #if ($label_logos) {
    #    $draw_logo_args{'-x_title'} = $matrix_id;
    #}

    my $logo = $matrix->draw_logo(
        %draw_logo_args
    );

    
    # Label this way (not ideal)
    if ($label_logos) {
        #print OFH "<td><img src=\"./$logo_file\"><br>$matrix_id</td>";
        print OFH "<td>&nbsp;&nbsp;&nbsp;$matrix_id<br><img src=\"./$logo_file\"></td>";
    } else {
        print OFH "<td><img src=\"./$logo_file\"></td>";
    }

    $last_version = $version;
}

print OFH "</table>\n";
print OFH "</body>\n";
print OFH "</html>\n";

close(OFH);
 
exit;

sub split_matrix_id
{
    my ($id) = @_;

    my ($base_id, $version) = split /\./, $id;

    return ($base_id, $version)
}
