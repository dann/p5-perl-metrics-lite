package Perl::Metrics::Lite::Report::Text;
use strict;
use warnings;
use Text::ASCIITable;

sub new {
    my ($class) = @_;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub report {
    my ( $self, $analysis ) = @_;

    my $file_stats = $analysis->file_stats;
    $self->report_file_stats($file_stats);

    my $sub_stats = $analysis->sub_stats;
    $self->report_sub_stats($sub_stats);
}

sub report_file_stats {
    my ( $self, $file_stats ) = @_;
    _print_file_stats_report_header();

    my @rows = ();
    foreach my $file_stat ( @{$file_stats} ) {
        push @rows,
            {
            path     => $file_stat->{path},
            packages => $file_stat->{main_stats}->{packages},
            loc      => $file_stat->{main_stats}->{lines},
            subs     => $file_stat->{main_stats}->{number_of_methods}
            };
    }
    if (@rows) {
        my $keys = [ "path", "loc", "subs", "packages" ];
        my $table = $self->_create_table( $keys, \@rows );
        print $table;
    }
}

sub _print_file_stats_report_header {
    print "#======================================#\n";
    print "#           File Metrics               #\n";
    print "#======================================#\n";
}

sub report_sub_stats {
    my ( $self, $sub_stats ) = @_;
    $self->_print_sub_stats_report_header;
    foreach my $file_path ( keys %{$sub_stats} ) {
        my $sub_metrics = $sub_stats->{$file_path};
        $self->_report_sub_metrics($file_path, $sub_metrics); 
    }
}

sub _print_sub_stats_report_header {
    print "#======================================#\n";
    print "#         Subroutine Metrics           #\n";
    print "#======================================#\n";
}

sub _report_sub_metrics {
    my ( $self, $path, $sub_metrics ) = @_;
    my @rows        = ();
    foreach my $sub_metric ( @{$sub_metrics} ) {
        push @rows,
            {
            name              => $sub_metric->{name},
            loc               => $sub_metric->{lines},
            line_number       => $sub_metric->{line_number},
            mccabe_complexity => $sub_metric->{mccabe_complexity}
            };
    }
    if (@rows) {
        my $keys = [ "name", "loc", "line_number", "mccabe_complexity" ];
        my $table = $self->_create_table( $keys, \@rows );

        print "\nPath: ${path}\n";
        print $table;
    }

}

sub _create_table {
    my ( $self, $keys, $rows ) = @_;
    my $t = Text::ASCIITable->new();
    $t->setCols(@$keys);
    $t->addRow( @$_{@$keys} ) for @$rows;
    $t;
}

1;

__END__
