# --
# Kernel/Output/HTML/OutputFilterZnunyTicketUnlockTime.pm - add ticket unlock time to ticket zoom
# Copyright (C) 2012 Znuny GmbH, http://znuny.com/
# --
# $Id: $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilterZnunyTicketUnlockTime;

use strict;
use warnings;

use Kernel::System::Queue;

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.0 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = \%Param;
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed objects (needed to be done here because of OTRS 3.0 + Survey package ->
    # public.pl?Action=PublicSurvey -> Got no DBObject! at)
    for (qw(DBObject EncodeObject TimeObject ConfigObject LogObject MainObject LayoutObject)) {
        return if !$Self->{$_};
    }

    # check needed stuff
    if ( !defined $Param{Data} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => 'Need Data!' );
        $Self->{LayoutObject}->FatalDie();
    }

    # return if it's not ticket zoom
    return if $Param{TemplateFile} !~ /^(AgentTicketZoom)/;

    # return if there is no ticket unlock time
    my $TicketID = $Self->{LayoutObject}->{ParamObject}->GetParam( Param => 'TicketID' );
    return if !$TicketID;
    my %Ticket = $Self->{LayoutObject}->{TicketObject}->TicketGet( TicketID => $TicketID );
    return if !%Ticket;
    return if !$Ticket{UnlockTimeout};
    return if $Ticket{Lock} ne 'lock';

    # return if there is no queue unlock time
    my $QueueObject = Kernel::System::Queue->new( %{ $Self } );
    my %Queue = $QueueObject->QueueGet( ID => $Ticket{QueueID} );
    return if !$Queue{UnlockTimeout};

    # do time calculation
    my $TimeDest = $Self->{TimeObject}->DestinationTime(
        StartTime => $Ticket{UnlockTimeout},
        Time      => ( $Queue{UnlockTimeout} * 60 ),
        Calendar  => $Queue{Calendar},
    );
    my $TimeDestHuman = $TimeDest - $Self->{TimeObject}->SystemTime();
    $TimeDest = $Self->{TimeObject}->SystemTime2TimeStamp(
        SystemTime => $TimeDest,
    );
    $TimeDestHuman = $Self->{LayoutObject}->CustomerAgeInHours(
         Age   => $TimeDestHuman, 
         Space => ' ',
    );

    # information markup
my $HTML = ' 
    <label>$Text{"Unlock timeout"}:</label>
    <p class="Value">
        ' . $TimeDestHuman . '
        <br/>
        $TimeShort{"' . $TimeDest . '"}
    </p>
    <div class="Clear"></div>
';

    # add information
    ${ $Param{Data} } =~ s{
        (<\!--\sdtl:block:PendingUntil\s-->)
    }
    {
       $HTML . $1;
    }sxim;

    return $Param{Data};
}

1;
