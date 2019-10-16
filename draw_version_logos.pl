#!/usr/bin/env perl

=head1 NAME

draw_version_logos.pl

=head1 SYNOPSIS

  draw_version_logos.pl [-v jaspar_version] [-d out_directory]
            [-db jaspar_db] [-c collection] [-t tax_group(s)]

=head1 ARGUMENTS
 
  -v jaspar_version = Optional JASPAR version to use. Should be one
                      of 2.1, 2006, 2008, 2010, 2014 or 2016. If not
                      specified, logos for all versions will be output.
  -d out_dir        = Optional output directory to which to write the
                      logo PNG image files. Only relevant if a specific
                      JASPAR version is specified. If not specified and
                      jaspar_version is specified the logos are written
                      to subdirectory "JASPAR<jaspar_version>_logos".
  -fixed_width      = Logos are fixed width (same width regarless of the
                      number of positions in the logo).
  -labeled          = Logos are labeled with the matrix ID.
  -c collection	    = Fetch only profile for this JASPAR collection (only
                      applicable to JASPAR versions that had different
                      collections.
                      DEFAULT='CORE'
  -t tax_groups	    = Taxonomic supergroups(s) of TFBS profiles to use
                      DEFAULT=NULL (all tax groups)

=head1 DESCRIPTION

For a given JASPAR version, output logos for each CORE profile to given
output directory. Logo files are named <JASPAR_ID>.png. For releases of
JASPAR that have version numbers, the <JASPAR_ID> is the full ID including
version otherwise it's just the base ID.

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

#
# Default min. score to report for sequence(s).
# Overidden by -t argument.
#
use constant COLLECTION     => "CORE";

# For JASPAR 2.1
use constant PHYLUM_STR  => "vertebrate,insect,plant";
# For JASPAR 2006 and 2008
use constant SYS_GROUP_STR  => "vertebrate,verterbrate,plant,insect,chordate";
# For JASPAR_2010 onwards
use constant TAX_GROUP_STR  => "vertebrates,plants,nematodes,insects,fungi,urochordates";

#use constant JASPAR_DB_NAME => "JASPAR_2016";
use constant JASPAR_DB_HOST => "vm5.cmmt.ubc.ca";
use constant JASPAR_DB_USER => "jaspar_r";
use constant JASPAR_DB_PASS => "";

use constant LOGO_XSIZE         => 300;  # total pixel width of logo
                                         # if using fixed width flag
use constant LOGO_YSIZE         => 75;  # total pixel height of logo
use constant LOGO_POS_XSIZE     => 12;   # per position pixel width of logo

use constant JASPAR_VERSIONS    => ['2.1', '2006', '2008', '2010', '2014',
                                    '2016'];

use constant JASPAR_VERSION_DB_NAMES => {
    '2.1'           => 'JASPAR2_1',
    '2006'          => 'JASPAR_CORE',
    '2008'          => 'JASPAR_CORE_2008',
    '2010'          => 'JASPAR_2010',
    '2014'          => 'JASPAR_2014',
    '2016'          => 'JASPAR_2016'
};


my $jaspar_version;
my $out_dir;
my $collection;
my $tax_group_str;
my $fixed_width;
my $label_logos;
GetOptions(
    'v=s'           => \$jaspar_version,
    'd=s'           => \$out_dir,
    'c=s'           => \$collection,
    't=s'           => \$tax_group_str,
    'fixed_width'   => \$fixed_width,
    'labeled'       => \$label_logos
);

#my $jaspar_version_db_names = JASPAR_VERSION_DB_NAMES;

if ($jaspar_version) {
    unless ($out_dir) {
        $out_dir = "JASPAR${jaspar_version}_logos";
    }

    write_version_logos($jaspar_version, $out_dir, $collection, $tax_group_str);
} else {
    my $jaspar_versions = JASPAR_VERSIONS;

    foreach my $jaspar_version (@$jaspar_versions) {
        $out_dir = "JASPAR${jaspar_version}_logos";

        write_version_logos($jaspar_version, $out_dir, $collection, $tax_group_str);
    }
}

exit;

sub write_version_logos
{
    my ($jaspar_version, $out_dir, $collection, $tax_group_str) = @_;

    my $jaspar_version_db_names = JASPAR_VERSION_DB_NAMES;

    my %matrix_args = (
        '-matrixtype'   => 'PFM'
    );

    my $dbh;
    my $jaspar_db;
    if ($jaspar_version eq '2.1') {
        require TFBS::DB::JASPAR2;

        $jaspar_db = $jaspar_version_db_names->{$jaspar_version};

        $dbh = TFBS::DB::JASPAR2->connect(
            "dbi:mysql:" . $jaspar_db . ":" . JASPAR_DB_HOST,
            JASPAR_DB_USER, JASPAR_DB_PASS
        );

        die "Error connecting to JASPAR database $jaspar_db for JASPAR version $jaspar_version\n" if !$dbh;

        # Don't use this! There are blanks ones's etc. and we want all
        # CORE anyway.
        #$tax_group_str = PHYLUM_STR if !$tax_group_str;
        #my @tax_groups  = split /\s*,\s*/, $tax_group_str;

        #$matrix_args{'-phylum'} = \@tax_groups;

    } elsif ($jaspar_version eq '2006' || $jaspar_version eq '2008') {
        require TFBS::DB::JASPAR4;

        $jaspar_db = $jaspar_version_db_names->{$jaspar_version};

        $dbh = TFBS::DB::JASPAR4->connect(
            "dbi:mysql:" . $jaspar_db . ":" . JASPAR_DB_HOST,
            JASPAR_DB_USER, JASPAR_DB_PASS
        );

        die "Error connecting to JASPAR database $jaspar_db for JASPAR version $jaspar_version\n" if !$dbh;

        # Don't use this! There are blanks ones's etc. and we want all
        # CORE anyway.
        #$tax_group_str = SYS_GROUP_STR if !$tax_group_str;
        #my @tax_groups  = split /\s*,\s*/, $tax_group_str;

        #$matrix_args{'-sysgroup'} = \@tax_groups;

    } elsif (   $jaspar_version eq '2010' || $jaspar_version eq '2014'
            || $jaspar_version eq '2016') {

        $jaspar_db = $jaspar_version_db_names->{$jaspar_version};

        if ($jaspar_version eq '2016') {
            require TFBS::DB::JASPAR;

            $dbh = TFBS::DB::JASPAR7->connect(
                "dbi:mysql:" . $jaspar_db . ":" . JASPAR_DB_HOST,
                JASPAR_DB_USER, JASPAR_DB_PASS
            );
        } else {
            require TFBS::DB::JASPAR5;

            $dbh = TFBS::DB::JASPAR5->connect(
                "dbi:mysql:" . $jaspar_db . ":" . JASPAR_DB_HOST,
                JASPAR_DB_USER, JASPAR_DB_PASS
            );
        }

        die "Error connecting to JASPAR database $jaspar_db for JASPAR version $jaspar_version\n" if !$dbh;

        $collection = COLLECTION if !$collection;
        $matrix_args{-collection} = $collection;

        #$tax_group_str = TAX_GROUP_STR if !$tax_group_str;
        #my @tax_groups  = split /\s*,\s*/, $tax_group_str;

        #$matrix_args{'-tax_group'} = \@tax_groups;
    }

    my $matrix_set = $dbh->get_MatrixSet(%matrix_args);

    unless (-d $out_dir) {
        mkdir $out_dir || die "Could not create output directory $out_dir\n";
    }

    my $iter = $matrix_set->Iterator();
    while (my $matrix = $iter->next(-sort_by => 'ID')) {
        my $matrix_id = $matrix->ID;
        my $name = $matrix->name();

        my $base_id;
        my $version;
        if (   $jaspar_version eq '2010' || $jaspar_version eq '2014'
            || $jaspar_version eq '2016') {

            ($base_id, $version) = split_matrix_id($matrix_id);
        } else {
            $base_id = $matrix_id;
            $version = 0;
        }


        print "Processing profile: $name\t$matrix_id\n";

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
    }
}

sub split_matrix_id
{
    my ($id) = @_;

    my ($base_id, $version) = split /\./, $id;

    return ($base_id, $version)
}
