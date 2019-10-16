#!/usr/bin/env perl

=head1 NAME

draw_version_logos.pl

=head1 SYNOPSIS

  draw_version_logos.pl -o out_html_file [-fixed_width] [-labeled]

=head1 ARGUMENTS
 
  -o out_table_file = Main output HTML table file.
  -fixed_width      = Logos are fixed width (same width regarless of the
                      number of positions in the logo).
  -labeled          = Logos are labeled with the matrix ID.

=head1 DESCRIPTION

For all JASPAR versions, read all CORE profiles and create an HTML table
which shows the history of how logos changed over time. The logo image
files are output to subdirectories for inclusion in the table with one
sub-directory for each JASPAR version. Logo files are named <JASPAR_ID>.png.
For releases of JASPAR that have version numbers, the <JASPAR_ID> is the
full ID including version otherwise it's just the base ID.

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
use List::Util qw(first);

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


my $out_table_file;
my $fixed_width;
my $label_logos;
GetOptions(
    'o=s'           => \$out_table_file,
    'fixed_width'   => \$fixed_width,
    'labeled'       => \$label_logos
);

unless ($out_table_file) {
    pod2usage(
        -msg    => "No output HTML table file specified\n",
        -verbose    => 1
    );
}

my $jaspar_version_matrices = get_all_jaspar_version_matrices();

my $table = write_jaspar_logos($jaspar_version_matrices);

write_table($table, $out_table_file);

exit;

sub get_all_jaspar_version_matrices
{
    my $jaspar_versions = JASPAR_VERSIONS;

    my %jaspar_version_matrices;
    foreach my $jaspar_version (@$jaspar_versions) {
        my $matrix_set = get_jaspar_version_matrices($jaspar_version);

        $jaspar_version_matrices{$jaspar_version} = $matrix_set;
    }

    return \%jaspar_version_matrices;
}

sub get_jaspar_version_matrices
{
    my ($jaspar_version) = @_;

    my $jaspar_version_db_names = JASPAR_VERSION_DB_NAMES;

    my %matrix_args = (
        '-matrixtype'   => 'PFM'
    );

    my $dbh;
    my $tax_group_str;
    if ($jaspar_version eq '2.1') {
        require TFBS::DB::JASPAR2;

        my $jaspar_db = $jaspar_version_db_names->{$jaspar_version};

        $dbh = TFBS::DB::JASPAR2->connect(
            "dbi:mysql:" . $jaspar_db . ":" . JASPAR_DB_HOST,
            JASPAR_DB_USER, JASPAR_DB_PASS
        );

        die "Error connecting to JASPAR database $jaspar_db for JASPAR version $jaspar_version\n" if !$dbh;

        # Don't use this! There are blanks ones's etc. and we want all
        # CORE anyway.
        #$tax_group_str = PHYLUM_STR;
        #my @tax_groups  = split /\s*,\s*/, $tax_group_str;

        #$matrix_args{'-phylum'} = \@tax_groups;

    } elsif ($jaspar_version eq '2006' || $jaspar_version eq '2008') {
        require TFBS::DB::JASPAR4;

        my $jaspar_db = $jaspar_version_db_names->{$jaspar_version};

        $dbh = TFBS::DB::JASPAR4->connect(
            "dbi:mysql:" . $jaspar_db . ":" . JASPAR_DB_HOST,
            JASPAR_DB_USER, JASPAR_DB_PASS
        );

        die "Error connecting to JASPAR database $jaspar_db for JASPAR version $jaspar_version\n" if !$dbh;

        # Don't use this! There are blanks ones's etc. and we want all
        # CORE anyway.
        #$tax_group_str = SYS_GROUP_STR;
        #my @tax_groups  = split /\s*,\s*/, $tax_group_str;

        #$matrix_args{'-sysgroup'} = \@tax_groups;

    } elsif (   $jaspar_version eq '2010' || $jaspar_version eq '2014'
            || $jaspar_version eq '2016') {

        my $jaspar_db = $jaspar_version_db_names->{$jaspar_version};

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

        $matrix_args{-collection} = COLLECTION;

        #$tax_group_str = TAX_GROUP_STR;
        #my @tax_groups  = split /\s*,\s*/, $tax_group_str;

        #$matrix_args{'-tax_group'} = \@tax_groups;
    }

    my $matrix_set = $dbh->get_MatrixSet(%matrix_args);

    return $matrix_set;
}

sub write_jaspar_logos
{
    my ($jaspar_version_matrices) = @_;

    my $jaspar_versions = JASPAR_VERSIONS;
    my $last_jaspar_version = $jaspar_versions->[$#$jaspar_versions];

    my $table = {};

    foreach my $jaspar_version (@$jaspar_versions) {
        my $matrix_set = $jaspar_version_matrices->{$jaspar_version};

        my $out_dir = "JASPAR${jaspar_version}_logos";
        unless (-d $out_dir) {
            mkdir $out_dir
                || die "Could not create output logos directory $out_dir\n";
        }

        my $iter = $matrix_set->Iterator();
        while (my $matrix = $iter->next(-sort_by => 'ID')) {
            my $matrix_id = $matrix->ID;
            my $matrix_name = $matrix->name();

            print "Processing profile: $matrix_id\t$matrix_name\n";

            my $base_id;
            my $version;
            if (   $jaspar_version eq '2010' || $jaspar_version eq '2014'
                || $jaspar_version eq '2016') {

                ($base_id, $version) = split_matrix_id($matrix_id);
            } else {
                $base_id = $matrix_id;
                $version = 0;
            }

            my $prev_matrix;
            if ($table->{$base_id}) {
                $prev_matrix = $table->{$base_id}->{'-last_matrix'};
            }

            my $new_matrix = 0;
            my $matrix_differs = 0;
            if ($prev_matrix) {
                unless (compare_matrices($matrix, $prev_matrix)) {
                    # Matrix differs from previous version
                    print "Profile $matrix_id\t$matrix_name has changed\n";
                    $matrix_differs = 1;
                }
            } else {
                # The first time this matrix appears
                print "Profile $matrix_id\t$matrix_name is new\n";
                $new_matrix = 1;
            }

            #
            # Use this if statement if we want to always show the latest
            # version of a motif in JASPAR 2016 regarless of whether it is
            # new or changed in 2016.
            #
            #my $display_logo = $new_matrix || $matrix_differs
            #                   || ($jaspar_version eq $last_jaspar_version);
            #
            # Use this if statement if we only want to show new motifs or
            # where motifs have changed.
            #
            my $display_logo = $new_matrix || $matrix_differs;

            $table->{$base_id}->{$jaspar_version} = {
                -matrix_id      => $matrix_id,
                -name           => $matrix_name,
                -base_id        => $base_id,
                -version        => $version,
                -is_new         => $new_matrix,
                -differs        => $matrix_differs,
                -display_logo   => $display_logo,
                -logo_file      => undef
            };

            $table->{$base_id}->{'-last_matrix'} = $matrix;

            if ($display_logo) {
                my $matrix_length = $matrix->length();

                my $xsize;
                if ($fixed_width) {
                    $xsize = LOGO_XSIZE;
                } else {
                    $xsize = LOGO_POS_XSIZE * $matrix_length;
                }

                my $logo_file = File::Spec->catfile(
                    $out_dir, sprintf("%s.png", $matrix_id)
                );

                my %draw_logo_args = (
                    -xsize  => $xsize,
                    -ysize  => LOGO_YSIZE,
                    -file   => $logo_file,
                );

                # This doesn't display properly (depending on scaling?)
                #if ($label_logos) {
                #    $draw_logo_args{'-x_title'} = $matrix_id;
                #}

                my $logo = $matrix->draw_logo(
                    %draw_logo_args
                );

                $table->{$base_id}->{$jaspar_version}->{'-logo_file'}
                    = $logo_file;
            } else {
                print "Profile $matrix_id\t$matrix_name is not new or hasn't"
                    . " changed - skipping\n";
            }
        }
    }

    return $table;
}

sub write_table
{
    my ($table, $out_file) = @_;

    my $jaspar_versions = JASPAR_VERSIONS;

    my @base_ids = sort(keys %$table);

    open(OFH, ">$out_file")
        || die "Error opening output HTML file $out_file\n";

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

    print OFH "<tr>";
    print OFH "<th></th><td></td>";
    foreach my $jv (@$jaspar_versions) {
        print OFH "<th>$jv</th>";
    }
    print OFH "</tr>\n";

    foreach my $base_id (@base_ids) {
        my $last_matrix = $table->{$base_id}->{-last_matrix};

        print OFH "<tr>";
        printf OFH "<th><a href=\"http://jaspar.genereg.net/cgi-bin/jaspar_db.pl?ID=%s&rm=present&collection=CORE\" target=_blank>$base_id</a></th>",
            $last_matrix->ID;
        printf OFH "<td>%s</td>", $last_matrix->name;

        foreach my $jv (@$jaspar_versions) {
            if ($table->{$base_id}->{$jv}) {
                if ($table->{$base_id}->{$jv}->{'-display_logo'}) {
                    my $logo_file = $table->{$base_id}->{$jv}->{-logo_file};
                    my $matrix_id = $table->{$base_id}->{$jv}->{-matrix_id};

                    # Only give links to JASPAR profiles that occured in
                    # 2010 onward.
                    # XXX Use better logic here to check for 2010 onwards XXX
                    if ($jv eq '2010' || $jv eq '2014' || $jv eq '2016') {
                        print OFH "<td title=\"$matrix_id\"><a href=\"http://jaspar.genereg.net/cgi-bin/jaspar_db.pl?ID=$matrix_id&rm=present&collection=CORE\" target=_blank><img src=\"$logo_file\"></a></td>";
                    } else {
                        print OFH "<td title=\"$matrix_id\"><img src=\"$logo_file\"></td>";
                    }
                } else {
                    print OFH "<td></td>";
                }
            } else {
                if (future_matrix_versions($table, $base_id, $jv)) {
                    print OFH "<td></td>";
                } else {
                    # Should we only output "removed" for the first JASPAR
                    # version for which this motif was removed? If so, we
                    # also need to check if the previous JASPAR version
                    # contained this motif.
                    print OFH "<td>removed</td>";
                }
            }
        }

        print OFH "</tr>\n";
    }

    print OFH "</table>\n";
    print OFH "</body>\n";
    print OFH "</html>\n";

    close(OFH);
}

sub split_matrix_id
{
    my ($id) = @_;

    my ($base_id, $version) = split /\./, $id;

    return ($base_id, $version);
}

sub future_matrix_versions
{
    my ($table, $base_id, $jaspar_version) = @_;

    my $jaspar_versions = JASPAR_VERSIONS;

    my $last_jaspar_version = $jaspar_versions->[$#$jaspar_versions];

    if ($jaspar_version eq $last_jaspar_version) {
        if ($table->{$base_id}->{$jaspar_version}) {
            return 1;
        } else {
            return 0;
        }
    }

    my $this_jv_found = 0;
    foreach my $jv (@$jaspar_versions) {
        if ($this_jv_found) {
            # If we've already hit the current JASPAR version entry, check
            # future versions exists.
            if ($table->{$base_id}->{$jv}) {
                return 1;
            }
        } elsif ($jv eq $jaspar_version) {
            # Found the current JASPAR version entry
            $this_jv_found = 1;
        }
    }

    return 0;
}

#
# Compare 2 matrices based on IDs and PFM and return 1 if they are the same
# or 0 if they differ.
#
sub compare_matrices
{
    my ($matrix1, $matrix2) = @_;

    my $id1 = $matrix1->ID;
    my $id2 = $matrix2->ID;

    my ($base_id1, $version1) = split_matrix_id($id1);
    my ($base_id2, $version2) = split_matrix_id($id2);

    if ($base_id1 ne $base_id2) {
        # Matrices have different base IDs
        return 0;
    }

    if ($version1 && $version2) {
        # Both matrices have version numbers
        if ($version1 eq $version2) {
            return 1;
        } else {
            return 0;
        }
    } else {
        # One or both matrices don't have a version numbers. At least
        # one profile is from a pre-2010 JASPAR version. Therefore, compare
        # their PFMs.
        return compare_pfms($matrix1, $matrix2);
    }

    return 0;
}

sub compare_pfms
{
    my ($matrix1, $matrix2) = @_;

    if ($matrix1->matrix ~~ $matrix2->matrix) {
        return 1;
    } else {
        return 0;
    }
}
