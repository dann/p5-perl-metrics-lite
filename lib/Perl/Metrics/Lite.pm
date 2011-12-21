package Perl::Metrics::Lite;
use strict;
use warnings;

use Carp qw(cluck confess);
use English qw(-no_match_vars);
use File::Basename qw(fileparse);
use File::Find qw(find);
use IO::File;
use Perl::Metrics::Lite::Analysis;
use Perl::Metrics::Lite::Analysis::File;
use Readonly;

our $VERSION = '0.01';

Readonly::Scalar our $PERL_FILE_SUFFIXES => qr{ \. (:? pl | pm | t ) }sxmi;
Readonly::Scalar our $SKIP_LIST_REGEX =>
    qr{ \.svn | \. git | _darcs | CVS }sxmi;
Readonly::Scalar my $PERL_SHEBANG_REGEX => qr/ \A [#] ! .* perl /sxm;
Readonly::Scalar my $DOT_FILE_REGEX     => qr/ \A [.] /sxm;

sub new {
    my ($class) = @_;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub analyze_files {
    my ( $self, @dirs_and_files ) = @_;
    my @results = ();
    my @objects = grep { ref $_ } @dirs_and_files;
    @dirs_and_files = grep { not ref $_ } @dirs_and_files;
    foreach my $file (
        (   scalar(@dirs_and_files)
            ? @{ $self->find_files(@dirs_and_files) }
            : ()
        ),
        @objects
        )
    {
        my $file_analysis
            = Perl::Metrics::Lite::Analysis::File->new( path => $file );
        push @results, $file_analysis;
    }
    my $analysis = Perl::Metrics::Lite::Analysis->new( \@results );
    return $analysis;
}

sub find_files {
    my ( $self, @directories_and_files ) = @_;
    foreach my $path (@directories_and_files) {
        if ( !-r $path ) {
            confess "Path '$path' is not readable!";
        }
    }
    my @found = $self->list_perl_files(@directories_and_files);
    return \@found;
}

sub list_perl_files {
    my ( $self, @paths ) = @_;
    my @files;

    my $wanted = sub {
        return if $self->should_be_skipped($File::Find::name);
        if ( $self->is_perl_file($File::Find::name) ) {
            push @files, $File::Find::name; ## no critic (ProhibitPackageVars)
        }
    };

    File::Find::find( { wanted => $wanted, no_chdir => 1 }, @paths );

    my @sorted_list = sort @files;
    return @sorted_list;
}

sub should_be_skipped {
    my ( $self, $fullpath ) = @_;
    my ( $name, $path, $suffix ) = File::Basename::fileparse($fullpath);
    return $path =~ $SKIP_LIST_REGEX;
}

sub is_perl_file {
    my ( $self, $path ) = @_;
    return if ( !-f $path );
    my ( $name, $path_part, $suffix )
        = File::Basename::fileparse( $path, $PERL_FILE_SUFFIXES );
    return if $name =~ $DOT_FILE_REGEX;
    if ( length $suffix ) {
        return 1;
    }
    return _has_perl_shebang($path);
}

sub _has_perl_shebang {
    my $path = shift;

    my $fh = IO::File->new( $path, '<' );
    if ( !-r $fh ) {
        cluck "Could not open '$path' for reading: $OS_ERROR";
        return;
    }
    my $first_line = <$fh>;
    $fh->close();
    return if ( !$first_line );
    return $first_line =~ $PERL_SHEBANG_REGEX;
}

1;

__END__

=encoding utf-8

=head1 NAME

Perl::Metrics::Lite - Pluggable Perl Code Metrics System

=head1 SYNOPSIS

  use Perl::Metrics::Lite;

=head1 DESCRIPTION

B<Perl::Metrics::Lite> is the pluggable perl code metrics system.

B<Perl::Metrics::Lite> provides just enough methods to run static analysis
of one or many Perl files and obtain a few metrics.

B<Perl::Metrics::Lite> is far simpler than L<Perl::Metrics> 
and more extensible than L<Perl::Metrics::Simple>.

=head1 CLASS METHODS

=head2 new

Takes no arguments and returns a new L<Perl::Metrics::Lite> object.

=head2 is_perl_file

Takes a path and returns true if the target is a Perl file.

=head1 OBJECT METHODS

=head2 analyze_files( @paths, @refs_to_file_contents )

Takes an array of files and or directory paths, and/or
SCALAR refs to file contents and returns
an L<Perl::Metrics::Lite::Analysis> object.

=head2 find_files( @directories_and_files )

Uses I<list_perl_files> to find all the readable Perl files
and returns a reference to a (possibly empty) list of paths.

=head2 list_perl_files

Takes a list of one or more paths and returns an
alphabetically sorted list of only the perl files.
Uses I<is_perl_file> so may throw an exception if a file is unreadable.

=head2 is_perl_file($path)

Takes a path to a file and returns true if the file appears to be a Perl file,
otherwise returns false.

If the file name does not match any of @Perl::Metrics::Lite::PERL_FILE_SUFFIXES
then the file is opened for reading and the first line examined for a a Perl
'shebang' line. An exception is thrown if the file cannot be opened in this case.

=head1 SOURCE AVAILABILITY

This source is in Github:

  http://github.com/dann/p5-perl-metrics-lite

=head1 CONTRIBUTORS

Many thanks to:


=head1 AUTHOR

Dann E<lt>techmemo{at}gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
