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

  RT::CustomFields - a collection of RT CustomField objects

=head1 SYNOPSIS

  use RT::CustomFields;

=head1 DESCRIPTION

=head1 METHODS



=cut


package RT::CustomFields;

use strict;
use warnings;

use DBIx::SearchBuilder::Unique;

use RT::CustomField;

use base 'RT::SearchBuilder';

sub Table { 'CustomFields'}

sub _Init {
    my $self = shift;

  # By default, order by SortOrder
  $self->OrderByCols(
	 { ALIAS => 'main',
	   FIELD => 'SortOrder',
	   ORDER => 'ASC' },
	 { ALIAS => 'main',
	   FIELD => 'Name',
	   ORDER => 'ASC' },
	 { ALIAS => 'main',
	   FIELD => 'id',
	   ORDER => 'ASC' },
     );

    return ( $self->SUPER::_Init(@_) );
}


=head2 LimitToLookupType

Takes LookupType and limits collection.

=cut

sub LimitToLookupType  {
    my $self = shift;
    my $lookup = shift;

    $self->Limit( FIELD => 'LookupType', VALUE => "$lookup" );
}

=head2 LimitToChildType

Takes partial LookupType and limits collection to records
where LookupType is equal or ends with the value.

=cut

sub LimitToChildType  {
    my $self = shift;
    my $lookup = shift;

    $self->Limit( FIELD => 'LookupType', VALUE => "$lookup" );
    $self->Limit( FIELD => 'LookupType', ENDSWITH => "$lookup" );
}


=head2 LimitToParentType

Takes partial LookupType and limits collection to records
where LookupType is equal or starts with the value.

=cut

sub LimitToParentType  {
    my $self = shift;
    my $lookup = shift;

    $self->Limit( FIELD => 'LookupType', VALUE => "$lookup" );
    $self->Limit( FIELD => 'LookupType', STARTSWITH => "$lookup" );
}


=head2 LimitToGlobalOrObjectId

Takes list of object IDs and limits collection to custom
fields that are applied to these objects or globally.

=cut

sub LimitToGlobalOrObjectId {
    my $self = shift;
    my $global_only = 1;


    foreach my $id (@_) {
	$self->Limit( ALIAS           => $self->_OCFAlias,
		    FIELD           => 'ObjectId',
		    OPERATOR        => '=',
		    VALUE           => $id || 0,
		    ENTRYAGGREGATOR => 'OR' );
	$global_only = 0 if $id;
    }

    $self->Limit( ALIAS           => $self->_OCFAlias,
                 FIELD           => 'ObjectId',
                 OPERATOR        => '=',
                 VALUE           => 0,
                 ENTRYAGGREGATOR => 'OR' ) unless $global_only;
}

=head2 LimitToNotApplied

Takes either list of object ids or nothing. Limits collection
to custom fields to listed objects or any corespondingly. Use
zero to mean global.

=cut

sub LimitToNotApplied {
    my $self = shift;
    return RT::ObjectCustomFields->new( $self->CurrentUser )
        ->LimitTargetToNotApplied( $self => @_ );
}

=head2 LimitToApplied

Limits collection to custom fields to listed objects or any corespondingly. Use
zero to mean global.

=cut

sub LimitToApplied {
    my $self = shift;
    return RT::ObjectCustomFields->new( $self->CurrentUser )
        ->LimitTargetToApplied( $self => @_ );
}

=head2 LimitToGlobalOrQueue QUEUEID

DEPRECATED since CFs are applicable not only to tickets these days.

Limits the set of custom fields found to global custom fields or those tied to the queue with ID QUEUEID

=cut

sub LimitToGlobalOrQueue {
    my $self = shift;
    my $queue = shift;
    $self->LimitToGlobalOrObjectId( $queue );
    $self->LimitToLookupType( 'RT::Queue-RT::Ticket' );
}


=head2 LimitToQueue QUEUEID

DEPRECATED since CFs are applicable not only to tickets these days.

Takes a queue id (numerical) as its only argument. Makes sure that
Scopes it pulls out apply to this queue (or another that you've selected with
another call to this method

=cut

sub LimitToQueue  {
   my $self = shift;
  my $queue = shift;

  $self->Limit (ALIAS => $self->_OCFAlias,
                ENTRYAGGREGATOR => 'OR',
		FIELD => 'ObjectId',
		VALUE => "$queue")
      if defined $queue;
  $self->LimitToLookupType( 'RT::Queue-RT::Ticket' );
}


=head2 LimitToGlobal

DEPRECATED since CFs are applicable not only to tickets these days.

Makes sure that Scopes it pulls out apply to all queues
(or another that you've selected with
another call to this method or LimitToQueue)

=cut

sub LimitToGlobal  {
   my $self = shift;

  $self->Limit (ALIAS => $self->_OCFAlias,
                ENTRYAGGREGATOR => 'OR',
		FIELD => 'ObjectId',
		VALUE => 0);
  $self->LimitToLookupType( 'RT::Queue-RT::Ticket' );
}


=head2 ApplySortOrder

Sort custom fields according to thier order application to objects. It's
expected that collection contains only records of one
L<RT::CustomField/LookupType> and applied to one object or globally
(L</LimitToGlobalOrObjectId>), otherwise sorting makes no sense.

=cut

sub ApplySortOrder {
    my $self = shift;
    my $order = shift || 'ASC';
    $self->OrderByCols( {
        ALIAS => $self->_OCFAlias,
        FIELD => 'SortOrder',
        ORDER => $order,
    } );
}


=head2 ContextObject

Returns context object for this collection of custom fields,
but only if it's defined.

=cut

sub ContextObject {
    my $self = shift;
    return $self->{'context_object'};
}


=head2 SetContextObject

Sets context object for this collection of custom fields.

=cut

sub SetContextObject {
    my $self = shift;
    return $self->{'context_object'} = shift;
}


sub _OCFAlias {
    my $self = shift;
    return RT::ObjectCustomFields->new( $self->CurrentUser )
        ->JoinTargetToThis( $self => @_ );
}


=head2 Next

Returns the next custom field that this user can see.

=cut

sub Next {
    my $self = shift;

    my $CF = $self->SUPER::Next();
    return $CF unless $CF;

    $CF->SetContextObject( $self->ContextObject );

    return $self->Next unless $CF->CurrentUserHasRight('SeeCustomField');
    return $CF;
}

=head2 NewItem

Returns an empty new RT::CustomField item
Overrides <RT::SearchBuilder/NewItem> to make sure </ContextObject>
is inherited.

=cut

sub NewItem {
    my $self = shift;
    my $res = RT::CustomField->new($self->CurrentUser);
    $res->SetContextObject($self->ContextObject);
    return $res;
}

RT::Base->_ImportOverlays();

1;
