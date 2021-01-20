# --
# Copyright (C) 2012-2021 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use vars (qw($Self));

# create configuration backup
# get the Znuny4OTRS Selenium object
my $SeleniumObject = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

# store test function in variable so the Selenium object can handle errors/exceptions/dies etc.
my $SeleniumTest = sub {

    # initialize Znuny4OTRS Helpers and other needed objects
    my $ZnunyHelperObject = $Kernel::OM->Get('Kernel::System::ZnunyHelper');
    my $HelperObject      = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
    my $QueueObject       = $Kernel::OM->Get('Kernel::System::Queue');
    my $TicketObject      = $Kernel::OM->Get('Kernel::System::Ticket');

    $ZnunyHelperObject->_RebuildConfig();

    # create test user and login
    my %TestUser = $SeleniumObject->AgentLogin(
        Groups => ['users'],
    );

    my @Tests = (
        {
            Name => "Queue - Postmaster - No UnlockTimeout",
            Data => {
                Queue => {
                    Name          => 'Postmaster',
                    UnlockTimeout => 0,
                },
                Ticket => {
                    Queue => 'Postmaster',
                },
            },
            ExpectedResult => {
                ElementExists => 'ElementExistsNot',
            },
        },
        {
            Name => "Queue - ShowTicketUnlockTime - unlock - UnlockTimeout: 100",
            Data => {
                Queue => {
                    Name          => 'ShowTicketUnlockTime',
                    UnlockTimeout => 100,
                },
                Ticket => {
                    Queue => 'ShowTicketUnlockTime',
                    Lock  => 'unlock',
                },
            },
            ExpectedResult => {
                ElementExists => 'ElementExistsNot',
            },
        },
        {
            Name => "Queue - ShowTicketUnlockTime - lock - UnlockTimeout: 100",
            Data => {
                Queue => {
                    Name          => 'ShowTicketUnlockTime',
                    UnlockTimeout => 100,
                },
                Ticket => {
                    Queue => 'ShowTicketUnlockTime',
                    Lock  => 'lock',
                },
            },
            ExpectedResult => {
                ElementExists => 'ElementExists',
            },
        },
    );

    TEST:
    for my $Test (@Tests) {

        if ( $Test->{Data}->{Queue} ) {

            my $QueueID = $ZnunyHelperObject->_QueueCreateIfNotExists(
                Name    => $Test->{Data}->{Queue}->{Name},
                GroupID => 1,
            );

            my $Success = $QueueObject->QueueUpdate(
                QueueID         => $QueueID,
                Name            => $Test->{Data}->{Queue}->{Name},
                ValidID         => 1,
                GroupID         => 1,
                SystemAddressID => 1,
                SalutationID    => 1,
                SignatureID     => 1,
                UserID          => 1,
                FollowUpID      => 1,
                Comment         => 'Some Comment2',
                DefaultSignKey  => '',
                UnlockTimeout   => $Test->{Data}->{Queue}->{UnlockTimeout},
                FollowUpLock    => 1,
                ParentQueueID   => '',
            );

            my %Queue = $QueueObject->QueueGet(
                Name => $Test->{Data}->{Queue}->{Name},
            );

            $Self->Is(
                $Queue{UnlockTimeout},
                $Test->{Data}->{Queue}->{UnlockTimeout},
                "UnlockTimeout is $Test->{Data}->{Queue}->{UnlockTimeout}.",
            );

        }

        my $TicketID;

        if ( $Test->{Data}->{Ticket} ) {
            $TicketID = $HelperObject->TicketCreate(
                %{ $Test->{Data}->{Ticket} },
            );
        }

        my $Success = $TicketObject->TicketUnlockTimeoutUpdate(
            UnlockTimeout => 100,
            TicketID      => $TicketID,
            UserID        => 1,
        );

        # navigate to AgentTicketZoom
        $SeleniumObject->AgentInterface(
            Action      => 'AgentTicketZoom',
            TicketID    => $TicketID,
            WaitForAJAX => 0,
        );

        if ( $Test->{ExpectedResult}->{ElementExists} ) {

            my $Function = $Test->{ExpectedResult}->{ElementExists};

            $SeleniumObject->$Function(
                Selector     => '#UnlockTimeout',
                SelectorType => 'css',
            );
        }

    }
};

# finally run the test(s) in the browser
$SeleniumObject->RunTest($SeleniumTest);

1;
