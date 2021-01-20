# --
# Copyright (C) 2012-2021 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::FilterElementPost::ZnunyTicketUnlockTime;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = \%Param;
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TimeObject   = $Kernel::OM->Get('Kernel::System::ZnunyTime');
    my $QueueObject  = $Kernel::OM->Get('Kernel::System::Queue');

    # return 1 if it's not ticket zoom
    return 1 if $Param{TemplateFile} !~ /^(AgentTicketZoom)/;

    # return 1 if there is no ticket unlock time
    my $TicketID = $ParamObject->GetParam( Param => 'TicketID' );
    return 1 if !$TicketID;

    my %Ticket = $TicketObject->TicketGet( TicketID => $TicketID );

    return 1 if !%Ticket;
    return 1 if !$Ticket{UnlockTimeout};
    return 1 if $Ticket{Lock} ne 'lock';

    # return 1 if there is no queue unlock time
    my %Queue = $QueueObject->QueueGet( ID => $Ticket{QueueID} );
    return 1 if !$Queue{UnlockTimeout};

    # do time calculation
    my $TimeDest = $TimeObject->DestinationTime(
        StartTime => $Ticket{UnlockTimeout},
        Time      => ( $Queue{UnlockTimeout} * 60 ),
        Calendar  => $Queue{Calendar},
    );

    my $TimeDestHuman = $TimeDest - $TimeObject->SystemTime();

    $TimeDest = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $TimeDest,
    );

    $TimeDestHuman = $LayoutObject->CustomerAgeInHours(
        Age   => $TimeDestHuman,
        Space => ' ',
    );

    # information markup
    my $HTML = '
    <label>' . $LayoutObject->{LanguageObject}->Translate('Unlock timeout') . ':</label>
    <p id="UnlockTimeout" class="Value">
        ' . $TimeDestHuman . '
        <br>
        ' . $TimeDest . '
    </p>
    <div class="Clear"></div>
';

    # add information
    return 1 if ${ $Param{Data} } !~ m{ <div [^>]* ContentColumn [^>]* > }xmsi;

    my $QueueLabel = '<label>' . $LayoutObject->{LanguageObject}->Translate('Queue') . ':</label>';
    ${ $Param{Data} } =~ s{\Q$QueueLabel\E .*? <div \s class="Clear"><\/div> }{$& $HTML}xms;

    return 1;
}

1;
