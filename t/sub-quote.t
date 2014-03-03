use strictures 1;
use Test::More;
use Test::Fatal;

use Sub::Quote;

our %EVALED;

my $one = quote_sub q{
    BEGIN { $::EVALED{'one'} = 1 }
    42
};

my $two = quote_sub q{
    BEGIN { $::EVALED{'two'} = 1 }
    3 + $x++
} => { '$x' => \do { my $x = 0 } };

ok(!keys %EVALED, 'Nothing evaled yet');

my $u_one = unquote_sub $one;

is_deeply(
  [ sort keys %EVALED ], [ qw(one) ],
  'subs one evaled'
);

is($one->(), 42, 'One (quoted version)');

is($u_one->(), 42, 'One (unquoted version)');

is($two->(), 3, 'Two (quoted version)');
is(unquote_sub($two)->(), 4, 'Two (unquoted version)');
is($two->(), 5, 'Two (quoted version again)');

my $three = quote_sub 'Foo::three' => q{
    $x = $_[1] if $_[1];
    die +(caller(0))[3] if @_ > 2;
    return $x;
} => { '$x' => \do { my $x = 'spoon' } };

is(Foo->three, 'spoon', 'get ok (named method)');
is(Foo->three('fork'), 'fork', 'set ok (named method)');
is(Foo->three, 'fork', 're-get ok (named method)');
like(
  exception { Foo->three(qw(full cutlery set)) }, qr/Foo::three/,
  'exception contains correct name'
);

quote_sub 'Foo::four' => q{
  return 5;
};

my $quoted = quoted_from_sub(\&Foo::four);
like $quoted->[1], qr/return 5;/,
  'can get quoted from installed sub';
Foo::four();
my $quoted2 = quoted_from_sub(\&Foo::four);
is $quoted2->[1], undef,
  "can't get quoted from installed sub after undefer";
undef $quoted;

my $broken_quoted = quote_sub q{
  return 5$;
};

like(
  exception { $broken_quoted->() }, qr/Eval went very, very wrong/,
  "quoted sub with syntax error dies when called"
);

sub in_main { 1 }
is exception { quote_sub(q{ in_main(); })->(); }, undef, 'context preserved in quoted sub';

{
  no strict 'refs';
  is exception { quote_sub(q{ my $foo = "some_variable"; $$foo; })->(); }, undef, 'hints are preserved';
}

my $foo = quote_sub '{}';
my $foo2 = quote_sub '{}';
my $foo_string = "$foo";
my $foo2_string = "$foo2";

undef $foo;
is quoted_from_sub($foo_string), undef,
  "quoted subs don't leak";

Sub::Quote->CLONE;
ok !exists $Sub::Quote::QUOTED{$foo_string},
  'CLONE cleans out expired entries';

undef $foo2;
is quoted_from_sub($foo2_string), undef,
  "CLONE doesn't strengthen refs";

my $foo3 = quote_sub '{}';
my $foo3_string = "$foo3";
my $foo3_info = quoted_from_sub($foo3_string);
undef $foo3;
is exception { Sub::Quote->CLONE }, undef,
  'CLONE works when quoted info kept alive externally';

ok !exists $Sub::Quote::QUOTED{$foo3_string},
  'CLONE removes expired entries that were kept alive externally';

my @stuff = (qsub q{ print "hello"; }, 1, 2);
is scalar @stuff, 3, 'qsub only accepts a single parameter';

done_testing;
