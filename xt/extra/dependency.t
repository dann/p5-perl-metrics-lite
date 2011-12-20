use Test::Dependencies
    exclude => [qw/Test::Dependencies Test::Base Test::Perl::Critic Perl::Metrics::Lite/],
    style   => 'light';
ok_dependencies();
