use strict;
use warnings;
use English qw(-no_match_vars);
use FindBin qw($Bin);
use lib "$Bin/lib";
use PPI;
use Perl::Metrics::Lite::Analysis::File;
use Readonly;
use Test::More tests => 2;

Readonly::Scalar my $TEST_DIRECTORY => "$Bin/test_files";
Readonly::Scalar my $EMPTY_STRING   => q{};

test_get_node_length();

exit;

sub test_get_node_length {
    my $test_file    = "$TEST_DIRECTORY/not_a_perl_file";
    my $file_counter =
      Perl::Metrics::Lite::Analysis::File->new( path => $test_file );
    my $one_line_of_code = q{print "Hello world\n";};
    my $one_line_node    = PPI::Document->new( \$one_line_of_code );
    is( $file_counter->get_node_length($one_line_node),
        1, 'get_node_length for one line of code.' );

    my $four_lines_of_code = <<'EOS';
    use Foo;
    my $object = Foo->new;
    # This is a comment.
    my $result = $object->calculate();
    return $result;
EOS
    my $four_line_node = PPI::Document->new( \$four_lines_of_code );
    is( $file_counter->get_node_length($four_line_node),
        4, 'get_node_length for 4 lines of code.' ) ||diag $four_lines_of_code;
    return 1;
}

