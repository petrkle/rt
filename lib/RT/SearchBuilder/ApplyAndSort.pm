use strict;
use warnings;

package RT::SearchBuilder::ApplyAndSort;
use base 'RT::SearchBuilder';

=head1 NAME

RT::SearchBuilder::ApplyAndSort - base class for 'apply and sort' collections

=head1 DESCRIPTION

Base class for collections where records can be applied to objects with order.
See also L<RT::Record::ApplyAndSort>. Used by L<RT::ObjectScrips> and
L<RT::ObjectCustomFields>.

As it's about sorting then collection is sorted by SortOrder field.

=head1 METHODS

=cut

sub _Init {
    my $self = shift;

    # By default, order by SortOrder
    $self->OrderByCols(
         { ALIAS => 'main',
           FIELD => 'SortOrder',
           ORDER => 'ASC' },
         { ALIAS => 'main',
           FIELD => 'id',
           ORDER => 'ASC' },
    );

    return $self->SUPER::_Init(@_);
}

=head2 RecordClass

Returns class name of records in this collection. This generic implementation
just strips trailing 's'.

=cut

sub RecordClass {
    my $class = ref($_[0]) || $_[0];
    $class =~ s/s$// or return undef;
    return $class;
}

=head2 LimitToObjectId

Takes id of an object and limits collection.

=cut

sub LimitToObjectId {
    my $self = shift;
    my $id = shift || 0;
    $self->Limit( FIELD => 'ObjectId', VALUE => $id );
}

=head2 NewItem

Returns an empty new collection's item

=cut

sub NewItem {
    my $self = shift;
    return $self->RecordClass->new( $self->CurrentUser );
}

=head1 METHODS FOR TARGETS

Rather than implementing a base class for targets (L<RT::Scrip>,
L<RT::CustomField>) and its collections. This class provides
class methods to limit target collections.

=head2 LimitTargetToNotApplied

Takes a collection object and optional list of object ids. Limits
the collection to records not applied to listed objects or if
the list is empty then any object. Use 0 (zero) to mean global.

=cut

sub LimitTargetToNotApplied {
    my $self = shift;
    my $collection = shift;
    my @ids = @_;

    my $alias = $self->JoinTargetToApplied($collection => @ids);

    $collection->Limit(
        ENTRYAGGREGATOR => 'AND',
        ALIAS    => $alias,
        FIELD    => 'id',
        OPERATOR => 'IS',
        VALUE    => 'NULL',
    );
    return $alias;
}

=head2 LimitTargetToApplied

L</LimitTargetToNotApplied> with reverse meaning. Takes the same
arguments.

=cut

sub LimitTargetToApplied {
    my $self = shift;
    my $collection = shift;
    my @ids = @_;

    my $alias = $self->JoinTargetToApplied($collection => @ids);

    $collection->Limit(
        ENTRYAGGREGATOR => 'AND',
        ALIAS    => $alias,
        FIELD    => 'id',
        OPERATOR => 'IS NOT',
        VALUE    => 'NULL',
    );
    return $alias;
}

=head2 JoinTargetToApplied

Joins collection to this table using left join, limits joined table
by ids if those are provided.

Returns alias of the joined table. Join is cached and re-used for
multiple calls.

=cut

sub JoinTargetToApplied {
    my $self = shift;
    my $collection = shift;
    my @ids = @_;

    my $alias = $self->JoinTargetToThis( $collection, New => 0, Left => 1 );
    return $alias unless @ids;

    # XXX: we need different EA in join clause, but DBIx::SB
    # doesn't support them, use IN (X) instead
    my $dbh = $self->_Handle->dbh;
    $collection->Limit(
        LEFTJOIN   => $alias,
        ALIAS      => $alias,
        FIELD      => 'ObjectId',
        OPERATOR   => 'IN',
        QUOTEVALUE => 0,
        VALUE      => "(". join( ',', map $dbh->quote($_), @ids ) .")",
    );

    return $alias;
}

=head3 JoinTargetToThis

Joins target collection to this table using TargetField.

Takes New and Left arguments. Use New to avoid caching and re-using
this join. Use Left to create LEFT JOIN rather than inner.

=cut

sub JoinTargetToThis {
    my $self = shift;
    my $collection = shift;
    my %args = ( New => 0, Left => 0, @_ );

    my $table = $self->Table;
    my $key = "_sql_${table}_alias";

    return $collection->{ $key } if $collection->{ $key } && !$args{'New'};

    my $alias = $collection->Join(
        $args{'Left'} ? (TYPE => 'LEFT') : (),
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => $table,
        FIELD2 => $self->RecordClass->TargetField,
    );
    return $alias if $args{'New'};
    return $collection->{ $key } = $alias;
}

RT::Base->_ImportOverlays();

1;
