package Perl::Metrics::Lite::Analysis::Util;
use Readonly;

Readonly::Scalar my $ALL_NEWLINES_REGEX =>
    qr/ ( \Q$INPUT_RECORD_SEPARATOR\E ) /sxm;

Readonly::Scalar my $LAST_CHARACTER => -1;

sub get_node_length {
    my $node = shift;
    my $eval_result = eval { $node = prune_non_code_lines($node); };
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

sub get_packages {
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

sub prune_non_code_lines {
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
