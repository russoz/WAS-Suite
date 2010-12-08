package WAS::Script;

use Moose::Role;
use Moose::Util::TypeConstraints;

use version; our $VERSION = qv('0.0.5');

=head1 NAME

WAS::Script - Represents a WAS' wsadmin script

=head1 SYNOPSIS

	use WAS::Script;
	
	my $script = WAS::Script->new(
		name => 'update',
		path => '/usr/local/lib/was-scripts/update.py',
	);
	
	my $jacl_script = WAS::Script->new(
		name => 'showHeap',
		path => '/usr/local/lib/was-scripts/showHeap.jacl',
		lang => 'jacl',
	);

=head1 DESCRIPTION

A C<WAS::Script> represents one script suitable to be run by C<wsadmin>, the
WAS administrative command line tool.

=head1 ATTRIBUTES

=over

=item name

A simple name for your script. It is not used within WAS.

=item path

The actual path to your script. There is no validation whether the path exists
or not, for you can define a C<WAS::Script> object in one host, but the script
is going to be executed on another one, thus, it must be a valid path on the
remote host rather than the local one.

=item lang

The script language. Per wsadmin, ou can use 'jython' or 'jacl'. Although many
WAS installations, maybe most of them, use JACL by default, the move towards
Jython seems inevitable and this class uses 'jython' as its default choice.

=back

=cut

has name => ( is => 'ro', isa => 'Str', required => 1, );
has path => ( is => 'ro', isa => 'Str', required => 1, );

enum _wsadmin_lang => [qw[jython jacl]];

has lang => ( is => 'ro', isa => '_wsadmin_lang', default => 'jython', );

=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.

=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-was-suite@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

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


