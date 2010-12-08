package WAS::Server;

use Moose::Role;
use common::sense;

use version; our $VERSION = qv('0.0.5');

=head1 NAME

WAS::Script - Represents a WAS' wsadmin script

=head1 SYNOPSIS

	use WAS::Server;
	
	my $server = WAS::Server->new(
		name => 'AppSrv01',
	);
	
=head1 DESCRIPTION

A C<WAS::Script> represents one script suitable to be run by C<wsadmin>, the
WAS administrative command line tool.

=head1 ATTRIBUTES

=over

=item name

The assigned server name, as defined in WAS configuration.

=item profile

A weak reference to the C<WAS::Profile> where this server sits.

=item apps

The list of applications installed in this server.

=back

=cut

has name => ( is => 'ro', isa => 'Str', required => 1, );
has profile => ( is => 'ro', isa => 'WAS::Profile', weak_ref => 1 );
has apps => 
	( is => 'ro', isa => 'ArrayRef[WAS::App]', default => sub { [] }, );

=head1 AUTHOR

Alexei Znamensky  C<< <russoz@cpan.org> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2010, Alexei Znamensky C<< <russoz@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

1;    # Magic true value required at end of module

__END__

