
use strict;
use warnings;

use RT::Test tests => 8;


use_ok('RT::Template');

{
    my $template = RT::Template->new(RT->SystemUser);
    isa_ok($template, 'RT::Template');
    my ($val,$msg) = $template->Create(
        Queue => 1,
        Name => 'InsertTest',
        Content => 'This is template content'
    );
    ok($val,$msg);

    is( $template->Name, 'InsertTest');
    is( $template->Content, 'This is template content', "We created the object right");

    ($val, $msg) = $template->SetContent( 'This is new template content');
    ok($val,$msg);
    is($template->Content, 'This is new template content', "We managed to _Set_ the content");
}

{
    my $t = RT::Template->new(RT->SystemUser);
    $t->Create(Name => "Foo", Queue => 1);
    my $t2 = RT::Template->new(RT->Nobody);
    $t2->Load($t->Id);
    ok($t2->QueueObj->id, "Got the template's queue objet");
}
