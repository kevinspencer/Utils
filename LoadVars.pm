# LoadVars.pm
#
# Copyright 2004-2016 Kevin Spencer <kevin@kevinspencer.org>
#
# Permission to use, copy, modify, distribute, and sell this software and its
# documentation for any purpose is hereby granted without fee, provided that
# the above copyright notice appear in all copies and that both that
# copyright notice and this permission notice appear in supporting
# documentation. No representations are made about the suitability of this
# software for any purpose. It is provided "as is" without express or
# implied warranty.
#
# Purpose: Loads in variables used by Perl programs that would otherwise have
#          been hardcoded.  The variables are listed in /var/variable.list
#          The variable.list file name/location can be overriden by an ENV
#          variable VARLIST.
#
# Usage: my $vars = Utils::LoadVars->new() || die Utils::LoadVars::errstr, "\n";
#        print $vars->USER_CRON;
#
# NOTE: Uses AUTOLOAD instead of multiple accessor methods to retrieve
#       variables.  When you want a variable, just call it as a method:
#
#       # we want the CONF_DB variable from variable.list
#       my $var = $vars->CONF_DB;
#
#       if the variable you are requesting does not exist, undef is returned
#       and you can retrieve the error via errstr()
#
################################################################################

package Utils::LoadVars;

use strict;
use vars qw($AUTOLOAD $errstr);

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->{varlist} = $ENV{VARLIST} || $self->_findVarList();
    return if (! $self->{varlist});
    $self->_loadvars() || return;
    return $self;
}

sub _findVarList {
    if ( -s '/var/variable.list' ) {
        return '/var/variable.list';
    } else {
        $errstr = "Could not find a variable.list file.";
        return;
    }
}

sub _loadvars {
    my $self = shift;

    open(my $fh, '<', $self->{varlist}) || do {
        $errstr = "Could not open $self->{varlist} - $!";
        return;
    };
    while (<$fh>) {
        # skip commented lines
        next if (substr($_, 0, 1) eq '#');
        chomp;
        my ($name, $val) = (/(\S+?):(.+)/);
        next if (! defined $val);
        $self->{$name} = $val;
    }
    close($fh);
    return 1;
}

sub AUTOLOAD {
    my $self = shift;

    no strict 'refs';    # evil - boo, hiss
    $AUTOLOAD =~ /.*::(\w+)/;
    my $var = $1;
    return if ($var =~ /DESTROY/);
    *{$AUTOLOAD} = sub { return $_[0]->{$var} };
    if ($self->{$var}) {
        return $self->{$var};
    } else {
        return $self->error("$var not found in $self->{varlist}");
    }
}

sub error {
    $_[0]->{_error} = $_[1];
    return;
}

sub errstr {
    return $_[0]->{_error};
}

1;
