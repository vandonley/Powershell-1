﻿function Get-MailboxExtendedRight {
    <#
    .SYNOPSIS
    Retrieves a list of mailbox extended rights.
    .DESCRIPTION
    Get-MailboxExtendedRight gathers a list of extended rights like 'send-as' on exchange mailboxes.
    .PARAMETER MailboxNames
    Array of mailbox names in string format.    
    .PARAMETER MailboxObject
    One or more mailbox objects.
    .LINK
    http://www.the-little-things.net
    .LINK
    https://github.com/zloeber/Powershell/
    .NOTES
    Version
    1.1.1 11/20/2014
    - Included filtering for nt authority/self and got rid of parameter.
    1.1.0 11/04/2014
    - Minor structual changes and input parameter updates
    1.0.0 10/04/2014
    - Initial release
    Author      :   Zachary Loeber
    .EXAMPLE
    Get-MailboxExtendedRight -MailboxName "Test User1" -Verbose

    Description
    -----------
    Gets the send-as rights for "Test User1" and shows verbose information.

    .EXAMPLE
    Get-MailboxExtendedRight -MailboxName "user1","user2" | Format-List

    Description
    -----------
    Gets the send-as rights on mailboxes "user1" and "user2" and returns the info as a format-list.

    .EXAMPLE
    (Get-Mailbox -Database "MDB1") | Get-MailboxExtendedRight

    Description
    -----------
    Gets all mailboxes in the MDB1 database and pipes it to Get-MailboxExtendedRight and returns the 
    send-as rights.
    #>
    [CmdLetBinding(DefaultParameterSetName='AsStringArray')]
    param(
        [Parameter(ParameterSetName='AsStringArray', Mandatory=$True, ValueFromPipeline=$True, Position=0, HelpMessage="Enter an Exchange mailbox name")]
        [string[]]$MailboxNames,
        [Parameter(ParameterSetName='AsMailbox', Mandatory=$True, ValueFromPipeline=$True, Position=0, HelpMessage="Enter an Exchange mailbox name")]
        $MailboxObject,
        [Parameter(HelpMessage='Rights to check for. Defaults to Send-As.')]
        [string]$Rights="send-as",
        [Parameter(HelpMessage='Includes unresolved names (typically deleted accounts) and NT Authority/Self')]
        [switch]$ShowAll
    )
    begin {
        $FunctionName = $MyInvocation.MyCommand.Name
        Write-Verbose "$($FunctionName): Begin"
        $Mailboxes = @()
    }
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'AsStringArray' {
                try {
                    $Mailboxes = @($MailboxNames | Foreach {Get-Mailbox $_ -erroraction Stop})
                }
                catch {
                    Write-Warning = "$($FunctionName): $_.Exception.Message"
                }
            }
            'AsMailbox' {
               $Mailboxes = @($MailboxObject)
            }
        }

        Foreach ($Mailbox in $Mailboxes)
        {
            Write-Verbose "$($FunctionName): Processing Mailbox $($Mailbox.Name)"
            $extendedperms = @(Get-ADPermission $Mailbox.identity | Where {$_.ExtendedRights} | 
                             Where {$_.extendedrights -like $Rights} | 
                             Select @{n='Mailbox';e={$Mailbox.Name}},User,ExtendedRights,isInherited,Deny)
            if ($extendedperms.Count -gt 0)
            {
                if ($ShowAll)
                {
                    $extendedperms
                }
                else
                {
                    $extendedperms | Where {($_.User -notlike 'S-1-*') -and ($_.User -notlike 'NT AUTHORITY\SELF')}
                }
            }
        }
    }
    end {
        Write-Verbose "$($FunctionName): End"
    }
}
