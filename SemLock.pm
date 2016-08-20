# SemLock.pm
#
# Copyright 2003-2016 Kevin Spencer <kevin@kevinspencer.org>
#
# Permission to use, copy, modify, distribute, and sell this software and its
# documentation for any purpose is hereby granted without fee, provided that
# the above copyright notice appear in all copies and that both that
# copyright notice and this permission notice appear in supporting
# documentation. No representations are made about the suitability of this
# software for any purpose. It is provided "as is" without express or
# implied warranty.
#
# PURPOSE: Simple semaphore file locking.
#
# Usage:
#
#       my $locker = Utils::SemLock->new();
#
#       my $semfile = '/tmp/semlock.lock';
#
#       # we don't lock with LOCK_NB by default so you have to set it if
#       # you need it...
#       $locker->setnonblock();
#       if (! $locker->lock($semfile)) {
#          die "Could not lock $semfile: " . $locker->error() . "\n";
#       }
#
#       $locker->unlock();
#
################################################################################

package Utils::SemLock;

use Fcntl ':flock';
use strict;
use warnings;

sub new {
    my $class = shift;

    my $self  = {};
    $self->{lock_method} = LOCK_EX;
    return bless $self, $class;
}

sub setnonblock {
    my $self = shift;

    $self->lockmethod(LOCK_EX|LOCK_NB);
}

sub lock {
    my ($self, $lockFile) = @_;

    if (! $lockFile) {
        return $self->error("No file specified to lock.");
    };
    open(my $lockFH, ">", $lockFile) ||
        return $self->error("Could not create $lockFile - $!");

    if (! flock $lockFH, $self->lockmethod()) {
        close($lockFile);
        unlink($lockFile);
        return $self->error("Could not lock $lockFile - $!");
    }
    $self->lockfilename($lockFile);
    $self->{fh} = $lockFH;
    return $self;
}

sub unlock {
    my $self = shift;

    close (delete $self->{fh}) || return;
    unlink($self->lockfilename());
    return 1;
}

sub lockfilename {
    my ($self, $name) = @_;

    if (defined($name)) {
        $self->{name} = $name;
        return;
    } else {
        return $self->{name};
    }
}

sub lockmethod {
    my ($self, $method) = @_;

    if (defined($method)) {
        $self->{lock_method} = $method;
        return;
    } else {
        return $self->{lock_method};
    }
}

sub error {
    my ($self, $message) = @_;

    if (defined($message)) {
        $self->{error_message} = $message;
        return;
    } else {
        return $self->{error_message};
    }
}
1;
