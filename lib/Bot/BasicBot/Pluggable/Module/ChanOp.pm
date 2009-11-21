package Bot::BasicBot::Pluggable::Module::ChanOp;
use base 'Bot::BasicBot::Pluggable::Module';
use strict;
use warnings;

our $VERSION = '0.01';

sub init {
    my $self = shift;
    $self->config(
        {
            user_auto_op        => 0,
            user_flood_control  => 0,
            user_flood_messages => 6,
            user_flood_seconds  => 4
        }
    );
}

sub isop {
    my ( $self, $channel, $who ) = @_;
    $who ||= $self->bot->nick();
    return $self->bot->channel_data($channel)->{$who}->{op};
}

sub deop_op {
    my ( $self, $op, $who, @channels ) = @_;
    for my $channel (@channels) {
        if ( $self->isop() ) {
            $self->bot->mode("$channel $op $who");
            return "Okay, i $op you in $channel";
        }
        else {
            return "Sorry, i'm not operator in $channel";
        }
    }
}

sub op   { shift->deop_op( '+o', @_ ); }
sub deop { shift->deop_op( '-o', @_ ); }

sub help {
    return
      'ChanOp commands need to be adressed in private and after authentication.'
      . '!op #foo | !deop #foo #bar | !kick #foo user You have been warned ';
}

sub seen {
    my ( $self, $message ) = @_;
    my $who     = $message->{who};
    my $channel = $message->{channel};

    return if !$self->get('user_flood_control');
    return if !$self->isop($channel);

    push @{ $self->{data}->{$channel}->{$who} }, time;
    my @timestamps = @{ $self->{data}->{$channel}->{$who} };
    if ( @timestamps > $self->get('user_flood_messages') ) {
        my ( $min, $max ) = ( sort { $a <=> $b } @timestamps )[ 0, -1 ];
        my $seconds = $max - $min;
        if ( $seconds > $self->get('user_flood_seconds') ) {
            $self->kick(
                $channel, $who,
                "Stop flooding the channel ("
                  . @timestamps
                  . " messages in $seconds seconds)." );
        }
        delete $self->{data}->{$channel}->{$who};
    }
}

sub admin {
    my ( $self, $message ) = @_;
    my $who = $message->{who};
    if ( $self->authed($who) and $self->private($message) ) {
        my $body = $message->{body};
        my ( $command, $rest ) = split( ' ', $body, 2 );
        if ( $command eq ' !op ' ) {
            my @channels = split( ' ', $rest );
            return $self->op( $who, @channels );
        }
        elsif ( $command eq ' !deop ' ) {
            my @channels = split( ' ', $rest );
            return $self->deop( $who, @channels );
        }
        elsif ( $command eq ' !kick ' ) {
            my ( $channel, $user, $reason ) = split( ' ', $rest, 3 );
            if ( $self->isop($channel) ) {
                $self->bot->kick( $channel, $who, $reason );
                return "Okay, kicked $who from $channel.";
            }
            else {
                return "Sorry, i'm not operator in $channel . ";
            }
        }
    }
}

sub chanjoin {
    my ( $self, $message ) = @_;
    $self->isop('#botzone');
    if ( $self->get('user_auto_op') ) {
        my $who = $message->{who};
        if ( $self->authed($who) ) {
            my $channel = $message->{channel};
            $self->op( $who, $channel );
        }
    }
}

####
## Helper Functions
####

sub authed {
    my ( $self, $who ) = @_;
    return $self->bot->module('Auth')
      and $self->bot->module('Auth')->authed($who);
}

sub private {
    my ( $self, $message ) = @_;
    return $message->{address} and $message->{channel} eq ' msg ';
}

sub kick {
    my $self = shift;
    $self->bot->kick(@_);
}

1;

__END__

=head1 NAME

Bot::BasicBot::Pluggable::Module::ChanOp - Channel operator

=head1 SYNOPSIS

  msg> me: !op #botzone
  msg> bot: Okay, i +o you in #botzone
  msg> me: !kick #botzone malice Stay outta here!
  msg> bot: Okay, i kicked malice from #botzone
  msg> me: !deop #botzone
  msg> bot: Okay, i -o you in #botzone

=head1 DESCRIPTION

This module provides commands to perform basic channel management
functions with the help of your bot instance. You can op and deop
yourself any time, ask your bot to kick malicious users. It also
provides a flood control mechanism, that will kick any user who
send more than a specified amount of mesasges in a given time.

=head1 VARIABLES

=head2 user_auto_op

If true, it will op any user who joins a channel and is already
authenticated by your bot. Defaults to false.

=head2 user_flood_control

Not implemented yet.

=head1 TODO

=over 4

=item Flood control is still missing

=back

=head1 VERSION

0.01

=head1 AUTHOR

Mario Domgoergen <mdom@cpan.org>

=head1 BUGS

All users are admins. This is fine at the moment, as the only things that need
you to be logged in are admin functions. Passwords are stored in plaintext, and
are trivial to extract for any module on the system. I don't consider this a
bug, because I assume you trust the modules you're loading. If Auth is I<not>
loaded, all users effectively have admin permissions. This may not be a good
idea, but is also not an Auth bug, it's an architecture bug.

=head1 AUTHOR

Mario Domgoergen <mdom@cpan.org>

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.