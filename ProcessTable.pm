# ProcessTable.pm
#
# Copyright 2007-2016 Kevin Spencer <kevin@kevinspencer.org>
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
# PURPOSE: Simple process table utility.
#
# Usage:
#
#   my $pt = Utils::ProcessTable->new();
#
#   if ($pt->isRunning('mysqld')) {
#       print "mysqld is running\n";
#   }
#
################################################################################

package Utils::ProcessTable;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = bless {}, $class;
    return $self->getProcessTable();
}

sub isRunning {
    my ($self, $processWanted) = @_;

    return unless $processWanted;

    my $runningStatus = 0;
    for my $process (@{$self->{table}}) {
        if ($process =~ /\b$processWanted\b/) {
            $runningStatus = 1;
            last;
        }
    }
    return $runningStatus;
}

#
# NOTE: not using Proc::ProcessTable because on the Solaris 10 Opteron hosts
# Proc::ProcessTable only recognizes processes owned by the current user.  So
# we are left with no other option than to scrape the output from ps
#

sub getProcessTable {
    my $self = shift;

    @{$self->{table}} = `ps -eo args`;
    return $self;
}

1;
