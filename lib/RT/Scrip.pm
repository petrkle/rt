# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2012 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

=head1 NAME

  RT::Scrip - an RT Scrip object

=head1 SYNOPSIS

  use RT::Scrip;

=head1 DESCRIPTION


=head1 METHODS


=cut


package RT::Scrip;

use strict;
use warnings;


use RT::Queue;
use RT::Template;
use RT::ScripCondition;
use RT::ScripAction;
use RT::Scrips;
use RT::ObjectScrip;

use base 'RT::Record';

sub Table {'Scrips'}

# {{{ sub Create

=head2 Create

Creates a new entry in the Scrips table. Takes a paramhash with:

        Queue                  => 0,
        Description            => undef,
        Template               => undef,
        ScripAction            => undef,
        ScripCondition         => undef,
        CustomPrepareCode      => undef,
        CustomCommitCode       => undef,
        CustomIsApplicableCode => undef,




Returns (retval, msg);
retval is 0 for failure or scrip id.  msg is a textual description of what happened.

=cut

sub Create {
    my $self = shift;
    my %args = (
        Queue                  => 0,
        Template               => 0,                     # name or id
        ScripAction            => 0,                     # name or id
        ScripCondition         => 0,                     # name or id
        Stage                  => 'TransactionCreate',
        Description            => undef,
        CustomPrepareCode      => undef,
        CustomCommitCode       => undef,
        CustomIsApplicableCode => undef,
        @_
    );

    if ($args{CustomPrepareCode} || $args{CustomCommitCode} || $args{CustomIsApplicableCode}) {
        unless ( $self->CurrentUser->HasRight( Object => $RT::System,
                                               Right  => 'ExecuteCode' ) )
        {
            return ( 0, $self->loc('Permission Denied') );
        }
    }

    unless ( $args{'Queue'} ) {
        unless ( $self->CurrentUser->HasRight( Object => $RT::System,
                                               Right  => 'ModifyScrips' ) )
        {
            return ( 0, $self->loc('Permission Denied') );
        }
        $args{'Queue'} = 0;    # avoid undef sneaking in
    }
    else {
        my $QueueObj = RT::Queue->new( $self->CurrentUser );
        $QueueObj->Load( $args{'Queue'} );
        unless ( $QueueObj->id ) {
            return ( 0, $self->loc('Invalid queue') );
        }
        unless ( $QueueObj->CurrentUserHasRight('ModifyScrips') ) {
            return ( 0, $self->loc('Permission Denied') );
        }
        $args{'Queue'} = $QueueObj->id;
    }

    #TODO +++ validate input

    require RT::ScripAction;
    return ( 0, $self->loc("Action is mandatory argument") )
        unless $args{'ScripAction'};
    my $action = RT::ScripAction->new( $self->CurrentUser );
    $action->Load( $args{'ScripAction'} );
    return ( 0, $self->loc( "Action '[_1]' not found", $args{'ScripAction'} ) ) 
        unless $action->Id;

    require RT::Template;
    return ( 0, $self->loc("Template is mandatory argument") )
        unless $args{'Template'};
    my $template = RT::Template->new( $self->CurrentUser );
    $template->Load( $args{'Template'} );
    return ( 0, $self->loc( "Template '[_1]' not found", $args{'Template'} ) )
        unless $template->Id;

    require RT::ScripCondition;
    return ( 0, $self->loc("Condition is mandatory argument") )
        unless $args{'ScripCondition'};
    my $condition = RT::ScripCondition->new( $self->CurrentUser );
    $condition->Load( $args{'ScripCondition'} );
    return ( 0, $self->loc( "Condition '[_1]' not found", $args{'ScripCondition'} ) )
        unless $condition->Id;

    my ( $id, $msg ) = $self->SUPER::Create(
        Template               => $template->Id,
        ScripCondition         => $condition->id,
        ScripAction            => $action->Id,
        Description            => $args{'Description'},
        CustomPrepareCode      => $args{'CustomPrepareCode'},
        CustomCommitCode       => $args{'CustomCommitCode'},
        CustomIsApplicableCode => $args{'CustomIsApplicableCode'},
    );
    return ( $id, $msg ) unless $id;

    if ( $args{'Stage'} eq 'Disabled' ) {
        $RT::Logger->warning("Disabled Stage is deprecated");
        $args{'Stage'} = 'TransactionCreate';
        $args{'Disabled'} = 1;
    }

    (my $status, $msg) = RT::ObjectScrip->new( $self->CurrentUser )->Apply(
        Scrip    => $self,
        Stage    => $args{'Stage'},
        ObjectId => $args{'Queue'},
        Disabled => $args{'Disabled'},
    );
    $RT::Logger->error( "Couldn't apply scrip: $msg" ) unless $status;

    return ( $id, $self->loc('Scrip Created') );
}



=head2 Delete

Delete this object

=cut

sub Delete {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('ModifyScrips') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    RT::ObjectScrip->new( $self->CurrentUser )->DeleteAll( Scrip => $self );

    return ( $self->SUPER::Delete(@_) );
}

sub IsAdded {
    my $self = shift;
    my $record = RT::ObjectScrip->new( $self->CurrentUser );
    $record->LoadByCols( Scrip => $self->id, ObjectId => shift || 0 );
    return $record->id;
}

sub AddedTo {
    my $self = shift;
    return RT::ObjectScrip->new( $self->CurrentUser )
        ->AppliedTo( Scrip => $self );
}

sub NotAddedTo {
    my $self = shift;
    return RT::ObjectScrip->new( $self->CurrentUser )
        ->NotAppliedTo( Scrip => $self );
}

sub AddToObject {
    my $self = shift;
    my %args = @_%2? (ObjectId => @_) : (@_);

    my $queue;
    if ( $args{'ObjectId'} ) {
        $queue = RT::Queue->new( $self->CurrentUser );
        $queue->Load( $args{'ObjectId'} );
        return (0, $self->loc('Invalid queue'))
            unless $queue->id;
    }
    return ( 0, $self->loc('Permission Denied') )
        unless $self->CurrentUser->PrincipalObj->HasRight(
            Object => $queue || $RT::System, Right => 'ModifyScrips',
        )
    ;

    my $tname = $self->TemplateObj->Name;
    my $template = RT::Template->new( $self->CurrentUser );
    $template->LoadQueueTemplate( Queue => $queue? $queue->id : 0, Name => $tname );
    $template->LoadGlobalTemplate( $tname ) if $queue && !$template->id;
    unless ( $template->id ) {
        if ( $queue ) {
            return (0, $self->loc('No template [_1] in the queue', $tname));
        } else {
            return (0, $self->loc('No global template [_1]', $tname));
        }
    }

    my $rec = RT::ObjectScrip->new( $self->CurrentUser );
    return $rec->Apply( %args, Scrip => $self );
}

sub RemoveFromObject {
    my $self = shift;
    my %args = @_%2? (ObjectId => @_) : (@_);

    my $queue;
    if ( $args{'ObjectId'} ) {
        $queue = RT::Queue->new( $self->CurrentUser );
        $queue->Load( $args{'ObjectId'} );
        return (0, $self->loc('Invalid queue id'))
            unless $queue->id;
    }
    return ( 0, $self->loc('Permission Denied') )
        unless $self->CurrentUser->PrincipalObj->HasRight(
            Object => $queue || $RT::System, Right => 'ModifyScrips',
        )
    ;

    my $rec = RT::ObjectScrip->new( $self->CurrentUser );
    $rec->LoadByCols( Scrip => $self->id, ObjectId => $args{'ObjectId'} );
    return (0, $self->loc('Scrip is not applied') ) unless $rec->id;
    return $rec->Delete;
}

=head2 ActionObj

Retuns an RT::Action object with this Scrip\'s Action

=cut

sub ActionObj {
    my $self = shift;

    unless ( defined $self->{'ScripActionObj'} ) {
        require RT::ScripAction;

        $self->{'ScripActionObj'} = RT::ScripAction->new( $self->CurrentUser );

        #TODO: why are we loading Actions with templates like this.
        # two separate methods might make more sense
        $self->{'ScripActionObj'}->Load( $self->ScripAction, $self->Template );
    }
    return ( $self->{'ScripActionObj'} );
}



=head2 ConditionObj

Retuns an L<RT::ScripCondition> object with this Scrip's IsApplicable

=cut

sub ConditionObj {
    my $self = shift;

    my $res = RT::ScripCondition->new( $self->CurrentUser );
    $res->Load( $self->ScripCondition );
    return $res;
}


=head2 LoadModules

Loads scrip's condition and action modules.

=cut

sub LoadModules {
    my $self = shift;

    $self->ConditionObj->LoadCondition;
    $self->ActionObj->LoadAction;
}


=head2 TemplateObj

Retuns an RT::Template object with this Scrip\'s Template

=cut

sub TemplateObj {
    my $self = shift;

    unless ( defined $self->{'TemplateObj'} ) {
        require RT::Template;
        $self->{'TemplateObj'} = RT::Template->new( $self->CurrentUser );
        $self->{'TemplateObj'}->Load( $self->Template );
    }
    return ( $self->{'TemplateObj'} );
}

=head2 Stage

Takes TicketObj named argument and returns scrip's stage when
applied to ticket's queue.

=cut

sub Stage {
    my $self = shift;
    my %args = ( TicketObj => undef, @_ );

    my $queue = $args{'TicketObj'}->Queue;
    my $rec = RT::ObjectScrip->new( $self->CurrentUser );
    $rec->LoadByCols( Scrip => $self->id, ObjectId => $queue );
    return $rec->Stage if $rec->id;

    $rec->LoadByCols( Scrip => $self->id, ObjectId => 0 );
    return $rec->Stage if $rec->id;

    return undef;
}

=head2 Disabled

Returns the current value of Disabled. 

=cut

sub Disabled {
    my $self = shift;
    # we check only one record as at this moment all applications
    # should be disabled or none, this method should be dropped when
    # we implement full functionality
    my $record = RT::ObjectScrip->new( $self->CurrentUser );
    $record->LoadByCols( Scrip => $self->id );
    return $record->Disabled;
}

=head2 SetDisabled

Takes a boolean.
1 will cause this scrip to no longer be avaialble for objects.
0 will re-enable this field.

=cut

sub SetDisabled {
    my $self = shift;
    return RT::ObjectScrip->new( $self->CurrentUser )
        ->SetDisabledOnAll( Scrip => $self->id, Value => shift );
}


=head2 Apply { TicketObj => undef, TransactionObj => undef}

This method instantiates the ScripCondition and ScripAction objects for a
single execution of this scrip. it then calls the IsApplicable method of the 
ScripCondition.
If that succeeds, it calls the Prepare method of the
ScripAction. If that succeeds, it calls the Commit method of the ScripAction.

Usually, the ticket and transaction objects passed to this method
should be loaded by the SuperUser role

=cut


# XXX TODO : This code appears to be obsoleted in favor of similar code in Scrips->Apply.
# Why is this here? Is it still called?

sub Apply {
    my $self = shift;
    my %args = ( TicketObj      => undef,
                 TransactionObj => undef,
                 @_ );

    $RT::Logger->debug("Now applying scrip ".$self->Id . " for transaction ".$args{'TransactionObj'}->id);

    my $ApplicableTransactionObj = $self->IsApplicable( TicketObj      => $args{'TicketObj'},
                                                        TransactionObj => $args{'TransactionObj'} );
    unless ( $ApplicableTransactionObj ) {
        return undef;
    }

    if ( $ApplicableTransactionObj->id != $args{'TransactionObj'}->id ) {
        $RT::Logger->debug("Found an applicable transaction ".$ApplicableTransactionObj->Id . " in the same batch with transaction ".$args{'TransactionObj'}->id);
    }

    #If it's applicable, prepare and commit it
    $RT::Logger->debug("Now preparing scrip ".$self->Id . " for transaction ".$ApplicableTransactionObj->id);
    unless ( $self->Prepare( TicketObj      => $args{'TicketObj'},
                             TransactionObj => $ApplicableTransactionObj )
      ) {
        return undef;
    }

    $RT::Logger->debug("Now commiting scrip ".$self->Id . " for transaction ".$ApplicableTransactionObj->id);
    unless ( $self->Commit( TicketObj => $args{'TicketObj'},
                            TransactionObj => $ApplicableTransactionObj)
      ) {
        return undef;
    }

    $RT::Logger->debug("We actually finished scrip ".$self->Id . " for transaction ".$ApplicableTransactionObj->id);
    return (1);

}



=head2 IsApplicable

Calls the  Condition object\'s IsApplicable method

Upon success, returns the applicable Transaction object.
Otherwise, undef is returned.

If the Scrip is in the TransactionCreate Stage (the usual case), only test
the associated Transaction object to see if it is applicable.

For Scrips in the TransactionBatch Stage, test all Transaction objects
created during the Ticket object's lifetime, and returns the first one
that is applicable.

=cut

sub IsApplicable {
    my $self = shift;
    my %args = ( TicketObj      => undef,
                 TransactionObj => undef,
                 @_ );

    my $return;
    eval {

	my @Transactions;

        my $stage = $self->Stage( TicketObj => $args{'TicketObj'} );
        unless ( $stage ) {
	    $RT::Logger->error(
                "Scrip #". $self->id ." is not applied to"
                ." queue #". $args{'TicketObj'}->Queue
            );
	    return (undef);
        }
        elsif ( $stage eq 'TransactionCreate') {
	    # Only look at our current Transaction
	    @Transactions = ( $args{'TransactionObj'} );
        }
        elsif ( $stage eq 'TransactionBatch') {
	    # Look at all Transactions in this Batch
            @Transactions = @{ $args{'TicketObj'}->TransactionBatch || [] };
        }
	else {
	    $RT::Logger->error( "Unknown Scrip stage: '$stage'" );
	    return (undef);
	}
	my $ConditionObj = $self->ConditionObj;
	foreach my $TransactionObj ( @Transactions ) {
	    # in TxnBatch stage we can select scrips that are not applicable to all txns
	    my $txn_type = $TransactionObj->Type;
	    next unless( $ConditionObj->ApplicableTransTypes =~ /(?:^|,)(?:Any|\Q$txn_type\E)(?:,|$)/i );
	    # Load the scrip's Condition object
	    $ConditionObj->LoadCondition(
		ScripObj       => $self,
		TicketObj      => $args{'TicketObj'},
		TransactionObj => $TransactionObj,
	    );

            if ( $ConditionObj->IsApplicable() ) {
	        # We found an application Transaction -- return it
                $return = $TransactionObj;
                last;
            }
	}
    };

    if ($@) {
        $RT::Logger->error( "Scrip IsApplicable " . $self->Id . " died. - " . $@ );
        return (undef);
    }

            return ($return);

}



=head2 Prepare

Calls the action object's prepare method

=cut

sub Prepare {
    my $self = shift;
    my %args = ( TicketObj      => undef,
                 TransactionObj => undef,
                 @_ );

    my $return;
    eval {
        $self->ActionObj->LoadAction( ScripObj       => $self,
                                      TicketObj      => $args{'TicketObj'},
                                      TransactionObj => $args{'TransactionObj'},
        );

        $return = $self->ActionObj->Prepare();
    };
    if ($@) {
        $RT::Logger->error( "Scrip Prepare " . $self->Id . " died. - " . $@ );
        return (undef);
    }
        unless ($return) {
        }
        return ($return);
}



=head2 Commit

Calls the action object's commit method

=cut

sub Commit {
    my $self = shift;
    my %args = ( TicketObj      => undef,
                 TransactionObj => undef,
                 @_ );

    my $return;
    eval {
        $return = $self->ActionObj->Commit();
    };

#Searchbuilder caching isn't perfectly coherent. got to reload the ticket object, since it
# may have changed
    $args{'TicketObj'}->Load( $args{'TicketObj'}->Id );

    if ($@) {
        $RT::Logger->error( "Scrip Commit " . $self->Id . " died. - " . $@ );
        return (undef);
    }

    # Not destroying or weakening hte Action and Condition here could cause a
    # leak

    return ($return);
}





# does an acl check and then passes off the call
sub _Set {
    my $self = shift;
    my %args = (
        Field => undef,
        Value => undef,
        @_,
    );

    unless ( $self->CurrentUserHasRight('ModifyScrips') ) {
        $RT::Logger->debug( "CurrentUser can't modify Scrips" );
        return ( 0, $self->loc('Permission Denied') );
    }


    if (exists $args{Value}) {
        if ($args{Field} eq 'CustomIsApplicableCode' || $args{Field} eq 'CustomPrepareCode' || $args{Field} eq 'CustomCommitCode') {
            unless ( $self->CurrentUser->HasRight( Object => $RT::System,
                                                   Right  => 'ExecuteCode' ) ) {
                return ( 0, $self->loc('Permission Denied') );
            }
        }
        elsif ($args{Field} eq 'Queue') {
            if ($args{Value}) {
                # moving to another queue
                my $queue = RT::Queue->new( $self->CurrentUser );
                $queue->Load($args{Value});
                unless ($queue->Id and $queue->CurrentUserHasRight('ModifyScrips')) {
                    return ( 0, $self->loc('Permission Denied') );
                }
            } else {
                # moving to global
                unless ($self->CurrentUser->HasRight( Object => RT->System, Right => 'ModifyScrips' )) {
                    return ( 0, $self->loc('Permission Denied') );
                }
            }
        }
        elsif ($args{Field} eq 'Template') {
            my $template = RT::Template->new( $self->CurrentUser );
            $template->Load($args{Value});
            unless ($template->Id and $template->CurrentUserCanRead) {
                return ( 0, $self->loc('Permission Denied') );
            }
        }
    }

    return $self->SUPER::_Set(@_);
}


# does an acl check and then passes off the call
sub _Value {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('ShowScrips') ) {
        $RT::Logger->debug( "CurrentUser can't see scrip #". $self->__Value('id') );
        return (undef);
    }

    return $self->__Value(@_);
}



=head2 CurrentUserHasRight

Helper menthod for HasRight. Presets Principal to CurrentUser then 
calls HasRight.

=cut

sub CurrentUserHasRight {
    my $self  = shift;
    my $right = shift;
    return ( $self->HasRight( Principal => $self->CurrentUser->UserObj,
                              Right     => $right ) );

}



=head2 HasRight

Takes a param-hash consisting of "Right" and "Principal"  Principal is 
an RT::User object or an RT::CurrentUser object. "Right" is a textual
Right string that applies to Scrips.

=cut

sub HasRight {
    my $self = shift;
    my %args = ( Right     => undef,
                 Principal => undef,
                 @_ );

    my $queues = $self->AddedTo;
    my $found = 0;
    while ( my $queue = $queues->Next ) {
        return 1 if $args{'Principal'}->HasRight(
            Right  => $args{'Right'},
            Object => $queue,
        );
        $found = 1;
    }
    return $args{'Principal'}->HasRight(
        Object => $RT::System,
        Right  => $args{'Right'},
    ) unless $found;
    return 0;
}



=head2 CompileCheck

This routine compile-checks the custom prepare, commit, and is-applicable code
to see if they are syntactically valid Perl. We eval them in a codeblock to
avoid actually executing the code.

If one of the fields has a compile error, only the first is reported.

Returns an (ok, message) pair.

=cut

sub CompileCheck {
    my $self = shift;

    for my $method (qw/CustomPrepareCode CustomCommitCode CustomIsApplicableCode/) {
        my $code = $self->$method;
        next if !defined($code);

        do {
            no strict 'vars';
            eval "sub { $code }";
        };
        next if !$@;

        my $error = $@;
        return (0, $self->loc("Couldn't compile [_1] codeblock '[_2]': [_3]", $method, $code, $error));
    }
}


=head2 SetScripAction

=cut

sub SetScripAction {
    my $self  = shift;
    my $value = shift;

    return ( 0, $self->loc("Action is mandatory argument") ) unless $value;

    require RT::ScripAction;
    my $action = RT::ScripAction->new( $self->CurrentUser );
    $action->Load($value);
    return ( 0, $self->loc( "Action '[_1]' not found", $value ) )
      unless $action->Id;

    return $self->_Set( Field => 'ScripAction', Value => $action->Id );
}

=head2 SetScripCondition

=cut

sub SetScripCondition {
    my $self  = shift;
    my $value = shift;

    return ( 0, $self->loc("Condition is mandatory argument") )
      unless $value;

    require RT::ScripCondition;
    my $condition = RT::ScripCondition->new( $self->CurrentUser );
    $condition->Load($value);

    return ( 0, $self->loc( "Condition '[_1]' not found", $value ) )
      unless $condition->Id;

    return $self->_Set( Field => 'ScripCondition', Value => $condition->Id );
}

=head2 SetTemplate

=cut

sub SetTemplate {
    my $self  = shift;
    my $value = shift;

    return ( 0, $self->loc("Template is mandatory argument") ) unless $value;

    require RT::Template;
    my $template = RT::Template->new( $self->CurrentUser );
    $template->Load($value);
    return ( 0, $self->loc( "Template '[_1]' not found", $value ) )
      unless $template->Id;

    return $self->_Set( Field => 'Template', Value => $template->Id );
}

1;






=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 Description

Returns the current value of Description.
(In the database, Description is stored as varchar(255).)



=head2 SetDescription VALUE


Set Description to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Description will be stored as a varchar(255).)


=cut


=head2 ScripCondition

Returns the current value of ScripCondition.
(In the database, ScripCondition is stored as int(11).)



=head2 SetScripCondition VALUE


Set ScripCondition to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ScripCondition will be stored as a int(11).)


=cut


=head2 ScripConditionObj

Returns the ScripCondition Object which has the id returned by ScripCondition


=cut

sub ScripConditionObj {
	my $self = shift;
	my $ScripCondition =  RT::ScripCondition->new($self->CurrentUser);
	$ScripCondition->Load($self->__Value('ScripCondition'));
	return($ScripCondition);
}

=head2 ScripAction

Returns the current value of ScripAction.
(In the database, ScripAction is stored as int(11).)



=head2 SetScripAction VALUE


Set ScripAction to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ScripAction will be stored as a int(11).)


=cut


=head2 ScripActionObj

Returns the ScripAction Object which has the id returned by ScripAction


=cut

sub ScripActionObj {
	my $self = shift;
	my $ScripAction =  RT::ScripAction->new($self->CurrentUser);
	$ScripAction->Load($self->__Value('ScripAction'));
	return($ScripAction);
}

=head2 ConditionRules

Returns the current value of ConditionRules.
(In the database, ConditionRules is stored as text.)



=head2 SetConditionRules VALUE


Set ConditionRules to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ConditionRules will be stored as a text.)


=cut


=head2 ActionRules

Returns the current value of ActionRules.
(In the database, ActionRules is stored as text.)



=head2 SetActionRules VALUE


Set ActionRules to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ActionRules will be stored as a text.)


=cut


=head2 CustomIsApplicableCode

Returns the current value of CustomIsApplicableCode.
(In the database, CustomIsApplicableCode is stored as text.)



=head2 SetCustomIsApplicableCode VALUE


Set CustomIsApplicableCode to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, CustomIsApplicableCode will be stored as a text.)


=cut


=head2 CustomPrepareCode

Returns the current value of CustomPrepareCode.
(In the database, CustomPrepareCode is stored as text.)



=head2 SetCustomPrepareCode VALUE


Set CustomPrepareCode to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, CustomPrepareCode will be stored as a text.)


=cut


=head2 CustomCommitCode

Returns the current value of CustomCommitCode.
(In the database, CustomCommitCode is stored as text.)



=head2 SetCustomCommitCode VALUE


Set CustomCommitCode to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, CustomCommitCode will be stored as a text.)


=cut


=head2 Template

Returns the current value of Template.
(In the database, Template is stored as int(11).)



=head2 SetTemplate VALUE


Set Template to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Template will be stored as a int(11).)


=cut


=head2 Creator

Returns the current value of Creator.
(In the database, Creator is stored as int(11).)


=cut


=head2 Created

Returns the current value of Created.
(In the database, Created is stored as datetime.)


=cut


=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy.
(In the database, LastUpdatedBy is stored as int(11).)


=cut


=head2 LastUpdated

Returns the current value of LastUpdated.
(In the database, LastUpdated is stored as datetime.)


=cut



sub _CoreAccessible {
    {

        id =>
		{read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Description =>
		{read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        ScripCondition =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        ScripAction =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        ConditionRules =>
		{read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        ActionRules =>
		{read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        CustomIsApplicableCode =>
		{read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        CustomPrepareCode =>
		{read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        CustomCommitCode =>
		{read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        Template =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Creator =>
		{read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created =>
		{read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy =>
		{read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated =>
		{read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},

 }
};

RT::Base->_ImportOverlays();

1;
