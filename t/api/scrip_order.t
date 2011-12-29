
use strict;
use warnings;

use RT;
use RT::Test tests => 9;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, 'loaded or created queue';

{
    my $ten = main->create_scrip_ok(
        Description => "Set priority to 10",
        Queue => $queue->id, 
        CustomCommitCode => '$self->TicketObj->SetPriority(10);',
    );

    my $five = main->create_scrip_ok(
        Description => "Set priority to 5",
        Queue => $queue->id,
        CustomCommitCode => '$self->TicketObj->SetPriority(5);', 
    );

    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ($id, $msg) = $ticket->Create( 
        Queue => $queue->id, 
        Subject => "Scrip order test $$",
    );
    ok($ticket->id, "Created ticket? id=$id");
    is($ticket->Priority , 5, "By default newer scrip is last");

    main->move_scrip_ok( $five, $queue->id, 'up' );

    $ticket = RT::Ticket->new(RT->SystemUser);
    ($id, $msg) = $ticket->Create(
        Queue => $queue->id,
        Subject => "Scrip order test $$",
    );
    ok($ticket->id, "Created ticket? id=$id");
    is($ticket->Priority , 10, "Moved scrip and result is different");
}

sub create_scrip_ok {
    my $self = shift;
    my %args = (
        ScripCondition => 'On Create',
        ScripAction => 'User Defined', 
        CustomPrepareCode => 'return 1',
        CustomCommitCode => 'return 1', 
        Template => 'Blank',
        Stage => 'TransactionCreate',
        @_
    );

    my $scrip = RT::Scrip->new( RT->SystemUser );
    my ($id, $msg) = $scrip->Create( %args );
    ok($id, "Created scrip") or diag "error: $msg";

    return $scrip;
}

sub move_scrip_ok {
    my $self = shift;
    my ($scrip, $queue, $dir) = @_;

    my $rec = RT::ObjectScrip->new( RT->SystemUser );
    $rec->LoadByCols( Scrip => $scrip->id, ObjectId => $queue );
    ok $rec->id, 'found application of the scrip';

    my $method = 'Move'. ucfirst lc $dir;
    my ($status, $msg) = $rec->$method();
    ok $status, "moved scrip $dir" or diag "error: $msg";
}


