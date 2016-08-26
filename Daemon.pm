# Daemon.pm
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
################################################################################
#
# Purpose: Common daemon functions for Perl programs
#
# Usage: my $daemon = Utils::Daemon->new("/path-to/pids");
#        $daemon->init or die $daemon->errstr, "\n";
#
################################################################################
# 
# vim: tabstop=4
# vim: expandtab
#
################################################################################

package Utils::Daemon;

use Errno qw(ESRCH EPERM);
use File::Basename;
use File::Path;
use IO::File;
use POSIX qw(:signal_h setsid);
use strict;
use warnings;

sub new {
    my ($class, $pidpath) = @_;

    my $self = {};
    bless $self, $class;
    $pidpath ||= '/work/pids';
    my $pidFile = $pidpath . "/" . basename((caller)[1]) . ".pid";
    $self->_pidFile($pidFile);
    return $self;
}

sub init {
    my $self = shift;

    return if (! $self->_checkPidFile());
    return if (! $self->_fork());
    return $self;
}

sub errstr {
    return $_[0]->_error ? $_[0]->_error : undef;
}

sub cleanup {
    my $self = shift;

    if ($self->_PID() && ($self->_PID() == $$)) {
        if (-e $self->_pidFile()) {
            unlink($self->_pidFile()) || return $self->_error("Could not unlink " . $self->_pidFile() . ' ' . $!);
            return 1;
        }
    }
}

sub _error {
    my ($self, $msg) = @_;

    if (defined($msg)) {
        $self->{err} = $msg;
        return;
    } else {
        return $self->{err};
    }
}

sub _pidFile {
    my ($self, $file) = @_;

    if (defined($file)) {
        $self->{pidfile} = $file;
        return $self;
    } else {
        return $self->{pidfile};
    }
}

sub _PID {
    my ($self, $pid) = @_;

    if (defined($pid)) {
        $self->{pid} = $pid;
        return $self;
    } else {
        return $self->{pid};
    }
}

sub _checkPidFile {
    my $self = shift;

    if (-e $self->_pidFile()) {
        # file exists so we might already be running
        my $fh = IO::File->new($self->_pidFile()) || return $self->_error("Could not open " . $self->_pidFile() . " $!");
        my $pid = <$fh>;
        $fh->close();
        if ($pid =~ /^(\d+)$/) {
            my $PID = $1;
            # see if the process is actually running
            if ($self->_processIsRunning($PID)) {
                return $self->_error("Daemon already running with pid $PID");
            } else {
                # that process does not exist in the process table, perhaps
                # previous process died without removing the PID file
                unlink($self->_pidFile()) || return $self->_error("Could not unlink " . $self->_pidFile() . " $!");
                return 1;
            }
        } else {
            return $self->_error("Invalid PID $pid found in " . $self->_pidFile());
        }
    } else {
        return 1;
    }
}

sub _processIsRunning {
    my ($self, $PID) = @_;

    if (kill 0, $PID) {
        # process exists and is running as the current user
        return 1;
    } elsif ($! == EPERM) {
        # process exists but is running as a different user
        return 1;
    } elsif ($! == ESRCH) {
        # no such process exists in the process table
        return;
    }
}

sub _fork {
    my $self = shift;

    return if (! $self->_createPidDir());
    my $signals = POSIX::SigSet->new(SIGTERM, SIGHUP);
    sigprocmask(SIG_BLOCK, $signals);
    my $child;
    unless (defined($child = fork())) {
        return $self->_error("Could not fork - $!");
    }
    exit 0 if $child; # wave goodbye to your parent, buh-bye...
    # now disassociate ourselves from the terminal
    sigprocmask(SIG_UNBLOCK, $signals);
    setsid();
    open(STDIN,  "</dev/null");
    open(STDOUT, "</dev/null");
    open(STDERR, ">&STDOUT"); # use a $SIG{__WARN__} handler instead
    return $self->_writePidFile();
}

sub _createPidDir {
    my $self = shift;

    return 1 if (-d dirname($self->_pidFile()));
    eval { mkpath(dirname($self->_pidFile())) };
    if ($@) {
        return $self->_error("Could not create " . dirname($self->_pidFile()) . $@);
    }
    return 1;
}

sub _writePidFile {
    my $self = shift;

    my $pidFile = $self->_pidFile();
    my $fh = IO::File->new(">$pidFile") || return $self->_error("Could not create $pidFile - $!");
    print $fh $$, "\n";
    $fh->close();
    $self->_PID($$);
    chmod(0644, $self->_pidFile());
    return 1;
}

1;
