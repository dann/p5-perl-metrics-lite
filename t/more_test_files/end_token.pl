# $Header: /Library/VersionControl/CVS/Perl-Metrics-Simple/t/more_test_files/end_token.pl,v 1.1 2008/03/15 18:07:51 matisse Exp $
# $Revision: 1.1 $
# $Author: matisse $
# $Source: /Library/VersionControl/CVS/Perl-Metrics-Simple/t/more_test_files/end_token.pl,v $
# $Date: 2008/03/15 18:07:51 $

package end_token; # 1

our $VERSION = '1.0'; # 2

our $EXPECTED_LOC = 4; #3

# the __END__ token also counts as a line of code
__END__

The idea here is that the count of lines for this file should
not include anything after the __END__ token.
