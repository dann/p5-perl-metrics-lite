package Perl::Metrics::Lite::Analysis::File;
use strict;
use warnings;

use Carp qw(cluck confess);
use English qw(-no_match_vars);
use Perl::Metrics::Lite::Analysis;
use PPI;
use PPI::Document;
use Readonly;

use Module::Pluggable
    require     => 1,
    search_path => 'Perl::Metrics::Lite::Analysis::File::Plugin',
    sub_name    => 'file_plugins';

use Module::Pluggable
    require     => 1,
    search_path => 'Perl::Metrics::Lite::Analysis::Sub::Plugin',
    sub_name    => 'sub_plugins';

our $VERSION = '0.01';

Readonly::Scalar my $ALL_NEWLINES_REGEX =>
    qr/ ( \Q$INPUT_RECORD_SEPARATOR\E ) /sxm;

Readonly::Scalar my $LAST_CHARACTER => -1;

# Private instance variables:
my %_PATH       = ();
my %_MAIN_STATS = ();
my %_SUBS       = ();
my %_PACKAGES   = ();
my %_LINES      = ();

sub new {
    my ( $class, %parameters ) = @_;
    my $self = {};
    bless $self, $class;
    $self->_init(%parameters);
    return $self;
}

sub _init {
    my ( $self, %parameters ) = @_;
    $_PATH{$self} = $parameters{'path'};

    my $path = $self->path();

    my $document = $self->_make_normalized_document($path);
    if ( !defined $document ) {
        cluck "Could not make a PPI document from '$path'";
        return;
    }

    my $packages = _get_packages($document);

    my @sub_analysis = ();
    my $sub_elements = $document->find('PPI::Statement::Sub');
    @sub_analysis = @{ $self->analyze_subs($sub_elements) };

    $_MAIN_STATS{$self}
        = $self->analyze_file( $document, $sub_elements, \@sub_analysis );
    $_SUBS{$self}     = \@sub_analysis;
    $_PACKAGES{$self} = $packages;
    $_LINES{$self}    = $self->get_node_length($document);

    return $self;
}

sub _make_normalized_document {
    my ($self, $path) = @_;

    my $document;
    if ( ref $path ) {
        if ( ref $path eq 'SCALAR' ) {
            $document = PPI::Document->new($path);
        }
        else {
            $document = $path;
        }
    }
    else {
        if ( !-r $path ) {
            Carp::confess "Path '$path' is missing or not readable!";
        }
        $document = _create_ppi_document($path);
    }
    $document = _make_pruned_document($document);

    $document;
}

sub _create_ppi_document {
    my $path = shift;
    my $document;
    if ( -s $path ) {
        $document = PPI::Document->new($path);
    }
    else {

        # The file is empty. Create a PPI document with a single whitespace
        # chararacter. This makes sure that the PPI tokens() method
        # returns something, so we avoid a warning from
        # PPI::Document::index_locations() which expects tokens() to return
        # something other than undef.
        my $one_whitespace_character = q{ };
        $document = PPI::Document->new( \$one_whitespace_character );
    }
    return $document;
}

sub _make_pruned_document {
    my $document = shift;
    $document = _prune_non_code_lines($document);
    $document->index_locations();
    $document->readonly(1);
    return $document;
}

sub all_counts {
    my $self       = shift;
    my $stats_hash = {
        path       => $self->path,
        lines      => $self->lines,
        main_stats => $self->main_stats,
        subs       => $self->subs,
        packages   => $self->packages,
    };
    return $stats_hash;
}

sub analyze_file {
    my $self         = shift;
    my $document     = shift;
    my $sub_elements = shift;
    my $sub_analysis = shift;

    if ( !$document->isa('PPI::Document') ) {
        Carp::confess('Did not supply a PPI::Document');
    }

    my $metrics = $self->measure_file_metrics($document);
    $metrics->{name} = $self->{path};
    $metrics->{path} = $self->{path};

    return $metrics;
}

sub measure_file_metrics {
    my ( $self, $file ) = @_;
    my $metrics = {};
    foreach my $plugin ( $self->file_plugins ) {
        $plugin->init;
        next unless $plugin->can('measure');
        my $metric = $plugin->measure( $self, $file );
        my $metric_name = $self->metric_name($plugin);
        $metrics->{$metric_name} = $metric;
    }
    return $metrics;
}

sub metric_name {
    my ( $self, $plugin ) = @_;
    my $metric_name = $plugin;
    $metric_name =~ s/.*::(.*)$/$1/;
    $metric_name = _decamelize($metric_name);
    $metric_name;
}

sub _decamelize {
    my $s = shift;
    $s =~ s{([^a-zA-Z]?)([A-Z]*)([A-Z])([a-z]?)}{
        my $fc = pos($s)==0;
        my ($p0,$p1,$p2,$p3) = ($1,lc$2,lc$3,$4);
        my $t = $p0 || $fc ? $p0 : '_';
        $t .= $p3 ? $p1 ? "${p1}_$p2$p3" : "$p2$p3" : "$p1$p2";
        $t;
    }ge;
    $s;
}

sub get_node_length {
    my ( $self, $node ) = @_;
    my $eval_result = eval { $node = _prune_non_code_lines($node); };
    return 0 if not $eval_result;
    return 0 if ( !defined $node );
    my $string = $node->content;
    return 0 if ( !length $string );

    # Replace whitespace-newline with newline
    $string
        =~ s/ \s+ \Q$INPUT_RECORD_SEPARATOR\E /$INPUT_RECORD_SEPARATOR/smxg;
    $string =~ s/\Q$INPUT_RECORD_SEPARATOR\E /$INPUT_RECORD_SEPARATOR/smxg;
    $string =~ s/ \A \s+ //msx;    # Remove leading whitespace
    my @newlines = ( $string =~ /$ALL_NEWLINES_REGEX/smxg );
    my $line_count = scalar @newlines;

# if the string is not empty and the last character is not a newline then add 1
    if ( length $string ) {
        my $last_char = substr $string, $LAST_CHARACTER, 1;
        if ( $last_char ne "$INPUT_RECORD_SEPARATOR" ) {
            $line_count++;
        }
    }

    return $line_count;
}

sub path {
    my ($self) = @_;
    return $_PATH{$self};
}

sub main_stats {
    my ($self) = @_;
    return $_MAIN_STATS{$self};
}

sub subs {
    my ($self) = @_;
    return $_SUBS{$self};
}

sub packages {
    my ($self) = @_;
    return $_PACKAGES{$self};
}

sub lines {
    my ($self) = @_;
    return $_LINES{$self};
}

sub _get_packages {
    my $document = shift;

    my @unique_packages = ();
    my $found_packages  = $document->find('PPI::Statement::Package');

    return \@unique_packages
        if (
        !Perl::Metrics::Lite::Analysis::is_ref( $found_packages, 'ARRAY' ) );

    my %seen_packages = ();

    foreach my $package ( @{$found_packages} ) {
        $seen_packages{ $package->namespace() }++;
    }

    @unique_packages = sort keys %seen_packages;

    return \@unique_packages;
}

sub analyze_subs {
    my $self       = shift;
    my $found_subs = shift;

    return []
        if ( !Perl::Metrics::Lite::Analysis::is_ref( $found_subs, 'ARRAY' ) );

    my @subs = ();
    foreach my $sub ( @{$found_subs} ) {
        my $metrics = $self->measure_sub_metrics($sub);
        $self->add_basic_sub_info( $sub, $metrics );
        push @subs, $metrics;
    }
    return \@subs;
}

sub measure_sub_metrics {
    my ( $self, $sub ) = @_;
    my $metrics = {};
    foreach my $plugin ( $self->sub_plugins ) {
        $plugin->init;
        next unless $plugin->can('measure');
        my $metric = $plugin->measure( $self, $sub );
        my $metric_name = $self->metric_name($plugin);
        $metrics->{$metric_name} = $metric;
    }
    return $metrics;
}

sub add_basic_sub_info {
    my ( $self, $sub, $metrics ) = @_;
    $metrics->{path} = $self->path;
    $metrics->{name} = $sub->name;
}

sub _prune_non_code_lines {
    my $document = shift;
    if ( !defined $document ) {
        Carp::confess('Did not supply a document!');
    }
    $document->prune('PPI::Token::Comment');
    $document->prune('PPI::Token::Pod');
    $document->prune('PPI::Token::End');

    return $document;
}

1;

__END__

