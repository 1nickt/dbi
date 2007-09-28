#!perl -w                                         # -*- perl -*-
# vim:sw=4:ts=8
$|=1;

use strict;
use warnings;

use DBI;
use Data::Dumper;
use Test::More;
use DBI::Util::Cache;

plan 'no_plan';

my @cache_classes = qw(DBI::Util::Cache);
push @cache_classes, "Cache::Memory" if eval { require Cache::Memory };
push @cache_classes, "1";

for my $cache_class (@cache_classes) {
    my $cache_obj = ($cache_class eq "1") ? $cache_class : $cache_class->new();
    run_tests($cache_obj);
}

sub run_tests {
    my $cache_obj = shift;

    my $tmp;
    my $dsn = "dbi:Gofer:transport=null;policy=classic;dsn=dbi:ExampleP:";
    print " using $cache_obj for $dsn\n";

    my $dbh = DBI->connect($dsn, undef, undef, {
        go_cache => $cache_obj,
        RaiseError => 1, PrintError => 0, ShowErrorStatement => 1,
    } );
    ok my $go_transport = $dbh->{go_transport};
    ok my $go_cache = $go_transport->go_cache;

    # setup
    $go_cache->clear;
    is $go_cache->count, 0, 'cache should be empty after clear';

    $go_transport->transmit_count(0);
    is $go_transport->transmit_count, 0, 'transmit_count should be 0';

    $go_transport->cache_hit(0);
    $go_transport->cache_miss(0);
    $go_transport->cache_store(0);

    # request 1
    ok my $rows1 = $dbh->selectall_arrayref("select name from ?", {}, ".");
    cmp_ok $go_cache->count, '>', 0, 'cache should not be empty after select';

    my $expected = ($ENV{DBI_AUTOPROXY}) ? 2 : 1;
    is $go_transport->cache_hit, 0;
    is $go_transport->cache_miss, $expected;
    is $go_transport->cache_store, $expected;

    is $go_transport->transmit_count, $expected, 'should make 1 round trip';
    $go_transport->transmit_count(0);
    is $go_transport->transmit_count, 0, 'transmit_count should be 0';

    # request 2
    ok my $rows2 = $dbh->selectall_arrayref("select name from ?", {}, ".");
    is_deeply $rows2, $rows1;
    is $go_transport->transmit_count, 0, 'should make 1 round trip';

    is $go_transport->cache_hit, $expected;
    is $go_transport->cache_miss, $expected;
    is $go_transport->cache_store, $expected;

}

1;