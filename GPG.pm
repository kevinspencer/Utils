# GPG.pm
#
# Copyright 2005-2016 Kevin Spencer <kevin@kevinspencer.org>
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
# PURPOSE:  GnuPG encryption/decryption routines
#
# Usage: 
#        #
#        # to encrypt a file...
#        # 
#
#        my $crypt = Utils::GPG->new();
#        # specify the file you want to encrypt
#        $crypt->plaintextfile($plainTextFile);
#        # specify which public key to encrypt it with
#        $crypt->key($key);
#        # perform the encryption 
#        $crypt->encrypt() or die $crypt->errstr();
#        # encrypted filename will be $plainTextFile.gpg
#
#        #
#        # to decrypt a file...
#        #
#
#        my $crypt = Utils::GPG->new();
#        $crypt->ciphertextfile($encryptedFile);
#        $crypt->decrypt() or die $crypt->errstr();
#
################################################################################

package Utils::GPG;

use lib 'Utils';
use IO::Handle;
use IPC::Open3;
use Utils::LoadVars;
use strict;
use warnings;

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(plaintextfile key cipherfile));

$SIG{CHLD} = 'IGNORE'; # IPC::Open3 does not wait() on child pids...

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    return $self;
}

sub encrypt {
    my $self = shift;

    if ($self->plaintextfile()) {
        if (! -e $self->plaintextfile()) {
            return $self->error($self->plaintextfile() . " does not exist.");
        }
        if ($self->key()) {
            # if we did not receive a forced cipherfilename then we
            # default the cipherfilename to plaintextfile() . '.gpg'
            if (! $self->cipherfile()) {
                my $cipherfile = $self->plaintextfile() . '.gpg';
                $self->cipherfile($cipherfile);
            }
            my $gpgInput = " -q --no-secmem-warning --default-recipient " .
                "'" . $self->key() . "' -e " . $self->plaintextfile();
            return $self->gpgdo($gpgInput, $self->cipherfile());
        } else {
            return $self->error("No key specified for encryption.");
        }
    } else {
        return $self->error("No plaintextfile specified for encryption.");
    }
}

sub decrypt {
    my $self = shift;

    if ($self->cipherfile()) {
        if (! -e $self->cipherfile()) {
            return $self->error($self->cipherfile() . " does not exist.");
        }
        return $self->_decrypt();
    } else {
        return $self->_error("No cipherfile has been specified to decrypt.");
    }
}

sub gpgdo {
    my ($self, $gpgargs, $outfile) = @_;

    my $vars = Utils::LoadVars->new() ||
        return $self->error($Utils::LoadVars::errstr);

    my $gpgcmd = $vars->CMD_GPG or return $self->_error($vars->errstr());

    my $stdin  = IO::Handle->new();
    my $stdout = IO::Handle->new();
    my $stderr = IO::Handle->new();

    my $command = $gpgcmd . ' ' . $gpgargs;

    my $pid;
    eval {
        $pid = open3($stdin, $stdout, $stderr, $command);
    };
    if ($@) {
        return $self->error($@);
    }
    if (! $pid) {
        return $self->error("Could not fork $command");
    }
    close($stdin);
    close($stdout);
    
    my $error = join('', <$stderr>);
    close($stderr);
    if ($error) {
        return $self->error($error);
    }
    # no errors reported thus far from open3() or GnuPG but does outfile exist?
    if (! -s $outfile) {
        return $self->error("$outfile did not get created.");
    }
    return 1;
}

sub errstr {
    return $_[0]->{error};
}

sub error {
    $_[0]->{error} = $_[1];
    return;
}

1;
