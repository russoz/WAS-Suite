package WAS::Script::UpdateEAR;

use Moose;
extends 'WAS::Script';
use common::sense;

use version; our $VERSION = qv('0.0.5');

=head1 NAME

WAS::Script::UpdateEAR - A simple script to update an application in WAS.

=head1 SYNOPSIS

	use WAS::Profile;
	use WAS::Script::UpdateEAR;
	
	my $profile = WAS::Profile->new( ... );
    my $script  = WAS::Script::UpdateEAR->new;

    $profile->run_script($script, 'MyApp', '/path/to/MyApp.ear' );

=head1 DESCRIPTION

This is a simple Moose-based class that represents a WAS profile. 

=head1 ATTRIBUTES

=head2 name

Name of the WAS profile. Although no validation is performed to check whether
there is a profile with that name, it is B<strongly> recommended that only
a real profile name be used in here. There might be some actual validation
in the future, and using an invalid profile name might break your application.

=head2 path

Path for the WAS profile root directory. There is no validation either, but
path is actually used to run C<wsadmin> scripts later on, so it must be valid.

=head2 host

Optional parameter specifying the hostname for this WAS profile. If empty,
C<< WAS::Profile >> will assume WAS is installed locally. If set, it will try
to determine whether the host name specified corresponds to the local host.

=cut

has '+name' => (
    default => 'WAS::Script::Update',
);
has path => (
    default => '',
);

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

