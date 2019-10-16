#!/usr/bin/env perl

=head1 NAME

create_jaspar_motif_version_table.pl

=head1 SYNOPSIS

  create_jaspar_motif_version_table.pl -t table_file [-labeled] [-centered]

=head1 ARGUMENTS
 
  -t table_file		= Output HTML versions table.
  -labeled          = Logos are labeled with the matrix ID.
  -centered         = Logos are centered in the output table.

=head1 DESCRIPTION

Create an HTML table so that each column corresponds to a JASPAR version.
For each JASPAR version show the motif version which first appeared in that
JASPAR version.

This scripts requires directories to be created with all the motifs for each
JASPAR version. These directories are created using the draw_version_logos.pl.

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
use Cwd;
use TFBS::DB::JASPAR;

#
# Default min. score to report for sequence(s).
# Overidden by -t argument.
#
use constant LOGO_XSIZE         => 300;  # total pixel width of logo
use constant LOGO_YSIZE         => 100;  # total pixel height of logo
use constant LOGO_POS_XSIZE     => 22;   # per position pixel width of logo

use constant JASPAR_VERSIONS    => ['2.1', '2006', '2008', '2010', '2014',
                                    '2016'];

use constant JASPAR_VERSION_LOGO_DIRS => {
    '2.1'           => 'JASPAR2.1_logos',
    '2006'          => 'JASPAR2006_logos',
    '2008'          => 'JASPAR2008_logos',
    '2010'          => 'JASPAR2010_logos',
    '2014'          => 'JASPAR2014_logos',
    '2016'          => 'JASPAR2016_logos'
};

use constant JASPAR_DB_NAME => "JASPAR_2016";
use constant JASPAR_DB_HOST => "vm5.cmmt.ubc.ca";
use constant JASPAR_DB_USER => "jaspar_r";
use constant JASPAR_DB_PASS => "";


my $out_table_file;
my $label_logos;
my $center_logos;
GetOptions(
    't=s'           => \$out_table_file,
    'labeled'       => \$label_logos,
    'centered'      => \$center_logos
);

unless ($out_table_file) {
    die "No output HTML table file specified!\n";
}

my $jaspar_versions = JASPAR_VERSIONS;
my $jaspar_version_dirs = JASPAR_VERSION_LOGO_DIRS;

my $dir = getcwd;
my %jv_logo_files;
my %base_ids;
my %matrix_ids;
my $base_id_versions;
foreach my $jv (@$jaspar_versions) {
    my $logo_dir = $jaspar_version_dirs->{$jv};

    unless (chdir "$dir/$logo_dir") {
        die "Could not change directory to ./$logo_dir\n";
    }

    my @logo_files = <"*.png">;

    $jv_logo_files{$jv} = \@logo_files;

    foreach my $lf (@logo_files) {
        my $matrix_id;
        my $base_id;
        my $version;

        if ($lf =~ /(MA\d+)\.png/) {
            $matrix_id = $1;
            $base_id = $1;
            $version = 0;
        } elsif ($lf =~ /(MA\d+)\.(\d+)\.png/) {
            $base_id = $1;
            $version = $2;
            $matrix_id = "$base_id.$version";
        }

        $base_ids{$base_id} = 1;
        $matrix_ids{$matrix_id} = 1;
        $base_id_versions->{$jv}->{$base_id} = {
            -version    => $version,
            -logo_file  => "./$logo_dir/$lf"
        }
    }
}

# Back to top level
chdir($dir);

my @unique_base_ids = sort(keys %base_ids);

#
# Get names from current JASPAR. Some names have changed across the JASPAR
# versions, but we are assuming the profiles are referring to the same TF.
#
my $dbh = TFBS::DB::JASPAR7->connect(
    "dbi:mysql:" . JASPAR_DB_NAME . ":" . JASPAR_DB_HOST,
    JASPAR_DB_USER, JASPAR_DB_PASS
);

open(OFH, ">$out_table_file")
    || die "Error opening output HTML table file $out_table_file\n";

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
    padding: 2px 5px 2px 5px;
    text-align: left;
}

th {
    font-weight: normal;
    text-align: center;
}
</style>
EOT

print OFH "<table>\n";

# Blank columns for motif ID and name which appear after header line
#print OFH "<tr><th></th><th></th>";
print OFH "<tr><th></th>";
foreach my $jv (@$jaspar_versions) {
    print OFH "<th><b>$jv</b></th>";
}
print OFH "</tr>\n";

print OFH "<tr>";
foreach my $base_id (@unique_base_ids) {
    my $matrix = $dbh->get_Matrix_by_ID($base_id, 'PFM');

    if ($matrix) {
        printf OFH "<th><b>%s</b><br>$base_id</th>", $matrix->name;
    } else {
        print OFH "<th>$base_id</th>";
    }

    foreach my $jv (@$jaspar_versions) {
        my $vlf = $base_id_versions->{$jv}->{$base_id};
        if ($vlf) {
            #printf OFH "<td><img src=\"\%s\"><br>\"%s.%s\"</td>", $vlf->{-logo_file}, $base_id, $vlf->{-version};
            printf OFH "<td><img src=\"\%s\"></td>", $vlf->{-logo_file};
        } else {
            print OFH "<td></td>"
        }
    }
    print OFH "</tr>\n";
}

print OFH "</table>\n";
print OFH "</body>\n";
print OFH "</html>\n";

close(OFH);
