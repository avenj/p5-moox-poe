package MooX::POE;
# ABSTRACT: POE::Session combined with Moo (or Moose, if you want)

use Moo::Role;
use Package::Stash;

use POE qw(
  Session
);

sub BUILD {
  my $self = shift;
  my $ps = Package::Stash->new(ref $self);
  my $session = POE::Session->create(
    inline_states => {
      _start => sub { POE::Kernel->yield('STARTALL', \$_[5] ) },
      map {
        my $func = $_;
        my ( $event ) = $func =~ /^on_(.*)$/;
        $event, sub {
          my ( @args ) = @_[ ARG0..$#_ ];
          $self->$func(@args);
        };
      } grep { /^on_/ } $ps->list_all_symbols('CODE'),
    },
    object_states => [
      $self => {
        STARTALL => 'STARTALL',
        _stop    => 'STOPALL',
        $self->can('CHILD') ? ( _child => 'CHILD' ) : (),
        $self->can('PARENT') ? ( _parent => 'PARENT' ) : (),
        _call_kernel_with_my_session => '_call_kernel_with_my_session',
      },
    ],
    args => [ $self ],
    heap => ( $self->{heap} ||= {} ),
  );
  $self->{session_id} = $session->ID;
}

sub get_session_id {
  my ( $self ) = @_;
  return $self->{session_id};
}

sub yield { my $self = shift; POE::Kernel->post( $self->get_session_id, @_ ) }
sub call { my $self = shift; POE::Kernel->call( $self->get_session_id, @_ ) }

sub _call_kernel_with_my_session {
  my ( $self, $function, @args ) = @_[ OBJECT, ARG0..$#_ ];
  POE::Kernel->$function( @args );
}
 
sub delay { my $self = shift; $self->call( _call_kernel_with_my_session => 'delay' => @_ ) }
sub alarm { my $self = shift; $self->call( _call_kernel_with_my_session => 'alarm', @_ ) }
sub alarm_add { my $self = shift; $self->call( _call_kernel_with_my_session => 'alarm_add', @_ ) }
sub delay_add { my $self = shift; $self->call( _call_kernel_with_my_session => 'delay_add', @_ ) }
sub alarm_set { my $self = shift; $self->call( _call_kernel_with_my_session => 'alarm_set', @_ ) }
sub alarm_adjust { my $self = shift; $self->call( _call_kernel_with_my_session => 'alarm_adjust', @_ ) }
sub alarm_remove { my $self = shift; $self->call( _call_kernel_with_my_session => 'alarm_remove', @_ ) }
sub alarm_remove_all { my $self = shift; $self->call( _call_kernel_with_my_session => 'alarm_remove_all', @_ ) }
sub delay_set { my $self = shift; $self->call( _call_kernel_with_my_session => 'delay_set', @_ ) }
sub delay_adjust { my $self = shift; $self->call( _call_kernel_with_my_session => 'delay_adjust', @_ ) }
 
sub STARTALL {
  my ( $self, @params ) = @_;
  $params[4] = pop @params;
  my @isa = @{mro::get_linear_isa(ref $self)};
  for my $caller (@isa) {
    my $can = $caller->can('START');
    $can->( $self, @params ) if $can;
  }
}
 
sub STOPALL {
  my ( $self, $params ) = @_;
  my @isa = @{mro::get_linear_isa(ref $self)};
  for my $caller (@isa) {
    my $can = $caller->can('STOP');
    $can->( $self, $params ) if $can;
  }
}

1;

=head1 SYNOPSIS

  package Counter;

  use Moo;
  with qw( MooX::POE );

  has count => (
    is => 'rw',
    lazy_build => 1,
    default => sub { 1 },
  );

  sub START {
    my ($self) = @_;
    $self->yield('increment');
  }

  sub on_increment {
    my ( $self ) = @_;
    print "Count is now " . $self->count . "\n";
    $self->count( $self->count + 1 );
    $self->yield('increment') unless $self->count > 3;
  }

  Counter->new();
  POE::Kernel->run();

=head1 DESCRIPTION

This role adds a L<POE::Session> and event handling to a L<Moo> or L<Moose>
class.

Based on L<MooseX::POE>; usage is similar, but rather than
providing an C<event> keyword, events are regular methods prefixed with B<on_>
(see the L</SYNOPSIS> for an example).

=head1 METHODS

=head2 get_session_id

Returns the L<POE::Session> ID for use with other POE-aware methods.

=head2 yield

=head2 call

=head2 delay

=head2 delay_add

=head2 delay_set

=head2 delay_adjust

=head2 alarm

=head2 alarm_add

=head2 alarm_set

=head2 alarm_adjust

=head2 alarm_remove

=head2 alarm_remove_all

These methods are aliases for the L<POE::Kernel> methods of the same name &
guarantee posting to the object's session.

=head1 SUPPORT

IRC

  Join #poe on irc.perl.org. Highlight Getty for fast reaction :).

Repository

  http://github.com/Getty/p5-moox-poe
  Pull request and additional contributors are welcome
 
Issue Tracker

  http://github.com/Getty/p5-moox-poe
