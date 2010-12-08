package WAS::App;

use Moose::Role;

use version; our $VERSION = qv('0.0.5');

=head1 NAME

WAS::App - A simple representation of a WAS application

=head1 SYNOPSIS

	use WAS::App;
	
	my $app = WAS::App->new( name => 'myApplication' );

=head1 DESCRIPTION

This is a simple Moose-based class that represents a WAS application. 

In the near future it should contain more methods to perform some useful 
actions. Right now it is more a placeholder than anything else.

=head1 ATTRIBUTES

=head2 name

Name of the application, as configured within WAS.

=head2 server

A weak reference, non-mandatory, 

=cut

has name   => ( is => 'ro', isa => 'Str',         required => 1, );
has server => ( is => 'rw', isa => 'WAS::Server', weak_ref => 1,
 handles => { profile => 'server->profile', }, );

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

1;

__END__

