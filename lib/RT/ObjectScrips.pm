use strict;
use warnings;

package RT::ObjectScrips;
use base 'RT::SearchBuilder::ApplyAndSort';

use RT::Scrips;
use RT::ObjectScrip;

=head1 NAME

RT::ObjectScrips - collection of RT::ObjectScrip records

=head1 DESCRIPTION

Collection of L<RT::ObjectScrip> records. Inherits methods from L<RT::SearchBuilder::ApplyAndSort>.

=head1 METHODS

=cut

sub _Init {
    my $self = shift;
    $self->{'with_disabled_column'} = 1;
    return $self->SUPER::_Init( @_ );
}

=head2 Table

Returns name of the table where records are stored.

=cut

sub Table { 'ObjectScrips'}

=head2 LimitToScrip

Takes id of a L<RT::Scrip> object and limits this collection.

=cut

sub LimitToScrip {
    my $self = shift;
    my $id = shift;
    $self->Limit( FIELD => 'Scrip', VALUE => $id );
}

RT::Base->_ImportOverlays();

1;
